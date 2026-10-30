(ns metabase.stratio.middleware
  (:require
   [clojure.string :as str]
   [java-time.api :as t]
   [metabase.api.common :as api]
   [metabase.mcp.core :as mcp]
   [metabase.request.core :as request]
   [metabase.server.middleware.session :as mw.session]
   [metabase.stratio.auth :as st.auth]
   [metabase.stratio.config :as st.config]
   [metabase.util :as u]
   [metabase.util.log :as log]
   [toucan2.core :as t2]))

(set! *warn-on-reflection* true)

(def ^:dynamic ^Boolean *is-sync-request?*
  "Dynamic variable set by the sync endpoint to let us know if we are handling a sync database request"
  false)

(def ^:private public-api-endpoints
  ["/api/embed" "/api/geojson" "/api/public" "/api/setup" "/api/util" "/api/session/properties" "/api/health"])

(def ^:private autologin-endpoints
  ["/api/user/current" "/api/session/properties"])

(defn- email-login-request?
  [{:keys [request-method uri]}]
  (and (= uri "/api/session") (= request-method :post)))

(defn- sync-db-request?
  [{:keys [request-method uri]}]
  (boolean
   (and
    (= request-method :post)
    (or (re-matches #"/api/database/[0-9]+/sync_schema" uri)
        (re-matches #"/api/database/[0-9]+/rescan_values" uri)))))

(defn- editing-user-name?
  "The field used to identify an existing user (first name or email) should never be edited"
  [{:keys [uri request-method body]}]
  (when (and (re-matches #"/api/user/[0-9]+/?" uri) (= request-method :put))
    (let [user-id (Integer/parseInt (last (str/split uri #"/")))
          old-identifier (t2/select-one-fn st.config/user-identifier :model/User :id user-id)
          new-identifier (st.config/user-identifier body)]
      (and old-identifier
           (contains? body st.config/user-identifier)
           (not= old-identifier new-identifier)))))

(defn- add-session-to-request-and-response
  [handler session]
  (fn [request respond raise]
    (handler (assoc request :metabase-session-key (-> session :key str) :metabase-session-type :normal)
             #(respond (request/set-session-cookies request % session (t/zoned-date-time (t/zone-id "GMT"))))
             raise)))

(defn- forbid-email-login
  "Middleware that checks for email login request and responds with 403 to those"
  [handler]
  (fn [request respond raise]
    (if (email-login-request? request)
      (respond {:status 403, :body "Email login is disabled"})
      (handler request respond raise))))

(defn- public-endpoint?
  [uri]
  (or (not (str/starts-with? uri "/api"))
      (some (partial str/starts-with? uri) public-api-endpoints)))

(defn- autologin-endpoint?
  [uri]
  (some (partial str/starts-with? uri) autologin-endpoints))

(defn wrap-with-auto-login-session
  "Middleware that checks if the metabase user id has been included in the request (this is done
  by a previous middleware). If it is not included we look for the user info in the requests headers
  (either user/groups remote headers or jwt token), create the user if needed, create the session,
  add it to the request map, set the session cookie in the response, and add the user info by
  calling the metabase middleware. "
  [handler]
  (fn [{uri :uri :as request} respond raise]
    (if (or (:metabase-user-id request)
            (not (autologin-endpoint? uri)))
      (handler request respond raise)
      (let [{:keys [session first_name error]} (st.auth/create-session-from-headers! request)]
        (if error
          (do
            (log/error "Could not perform auto-login. Error: " error)
            (handler request respond raise))
          (let [wrapped-handler (-> handler
                                    mw.session/wrap-current-user-info
                                    (add-session-to-request-and-response session))]
            (log/info "User" first_name "auto-loged-in through endpoint " uri)
            (wrapped-handler request respond raise)))))))

(defn- wrap-with-username-header
  "Middleware to add a reponse header with the current user name (to be used by the nginx access log)"
  [handler]
  (letfn [(add-username-response-header [response]
            ;; users without "uid" were created when first_name could not be edited, so it still holds their uid
            (update response :headers merge {"Metabase-User" (or (get-in @api/*current-user* [:login_attributes "uid"])
                                                                 (get @api/*current-user* :first_name "-"))}))]
    (fn [request respond raise]
      (handler request (comp respond add-username-response-header) raise))))

(defn- bind-is-sync-db-request-info
  "Middleware that binds the dynamic variable *is-sync-request* to true if
  the request is asking to sync a database schema or re-scan field values."
  [handler]
  (fn [request respond raise]
    (binding [*is-sync-request?* (sync-db-request? request)]
      (handler request respond raise))))

(def ^:private mcp-endpoints
  ["/api/mcp" "/api/metabase-mcp"])

;; Placeholder user for the calls the trusted MCP client makes without impersonating anyone, such as LiteLLM
;; registering the server or listing its tools. The MCP transport serves initialize and tools/list without
;; loading the user, so the id does not need to exist in the database.
(def ^:private mcp-service-user-id Integer/MAX_VALUE)

(defn- mcp-impersonated-user-info
  "Request user info for the active user with `uid` in its login attributes. Nil unless exactly one user matches."
  [uid]
  (let [;; login_attributes is a JSON text column, so LIKE only narrows the candidates down
        users (filter #(= uid (get-in % [:login_attributes "uid"]))
                      (t2/select [:model/User :id :is_superuser :is_data_analyst :locale :login_attributes]
                                 {:where [:and
                                          [:= :is_active true]
                                          [:like :login_attributes (str "%" uid "%")]]}))]
    (when (= 1 (count users))
      (let [{:keys [id is_superuser is_data_analyst locale]} (first users)]
        {:metabase-user-id  id
         :is-superuser?     is_superuser
         :is-data-analyst?  is_data_analyst
         :user-locale       locale}))))

(defn- wrap-with-mcp-impersonation
  "Middleware that lets the MCP client trusted by the proxy (a verified client cert with a whitelisted CN) act as the
  user named in the X-Mcp-Impersonate header, or as a placeholder user for the calls it makes without one. Requests
  already authenticated (session, API key...) are left untouched. Must run before the current user is bound."
  [handler]
  (fn [{:keys [uri headers] :as request} respond raise]
    (if-not (and st.config/mcp-impersonation-enabled?
                 (not (:metabase-user-id request))
                 (= "true" (get headers "x-mcp-trusted-client"))
                 (some (partial str/starts-with? uri) mcp-endpoints)
                 (mcp/mcp-enabled?))
      (handler request respond raise)
      (if-let [uid (get headers "x-mcp-impersonate")]
        (if-let [user-info (mcp-impersonated-user-info uid)]
          (handler (merge request user-info) respond raise)
          (respond {:status 401 :body (str "Cannot impersonate user " uid)}))
        (handler (assoc request :metabase-user-id mcp-service-user-id) respond raise)))))

(defn- default-middleware
  "Middleware to be always added"
  [handler]
  (-> handler
      wrap-with-mcp-impersonation
      bind-is-sync-db-request-info
      wrap-with-username-header))

(defn- auto-login-middleware
  "Middleware needed when auto-login is activated"
  [handler]
  (-> handler
      wrap-with-auto-login-session
      forbid-email-login))

(def stratio-middleware
  "Packs all needed middleware depending on login strategy"
  (if st.config/should-auto-login?
    (comp auto-login-middleware default-middleware)
    default-middleware))

(defn forbid-editing-username
  "Middleware that checks if we are dealing with a request to change the user name. If that is the case we
  respond with forbidden. Must be placed after *current-user* is bind and after the json body is processed"
  [handler]
  (if-not st.config/should-auto-login?
    handler
    (fn [request respond raise]
      (if (editing-user-name? request)
        (respond {:status 403 :body (str "Editing user " (name st.config/user-identifier) " is forbidden")})
        (handler request respond raise)))))
