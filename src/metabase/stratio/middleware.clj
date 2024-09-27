(ns metabase.stratio.middleware
  (:require
   [clojure.string :as str]
   [java-time.api :as t]
   [metabase.api.common :as api]
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
  "The username of an existing user should never be edited"
  [{:keys [uri request-method body]}]
  (when (and (re-matches #"/api/user/[0-9]+/?" uri) (= request-method :put))
    (let [user-id (Integer/parseInt (last (str/split uri #"/")))
          old-username (t2/select-one-fn :first_name :model/User :id user-id)
          new-username (:first_name body)]
      (and old-username (not= old-username new-username)))))

(defn- add-session-to-request-and-response
  [handler session]
  (fn [request respond raise]
    (handler (assoc request :metabase-session-id (-> session :id str) :metabase-session-type :normal)
             #(respond (mw.session/set-session-cookies request % session (t/zoned-date-time (t/zone-id "GMT"))))
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
    (if (or (:metabse-user-id request)
             (not (autologin-endpoint? uri)))
      (handler request respond raise)
      (let [{:keys [session first_name error]} (st.auth/create-session-from-headers! request)]
        (log/debug "No user info found associated to session, trying to auto-login...")
        (if error
          (do
            (log/error "Could not perform auto-login. Error: " error)
            (handler request respond raise))
          (let [wrapped-handler (-> handler
                                    mw.session/wrap-current-user-info
                                    (add-session-to-request-and-response session))]
            (log/info "User" first_name "auto-logged-in through headers")
            (log/debug "Request triggering the auto-login:"
                       (u/upper-case-en (name (:request-method request)))
                       (:uri request))
            (wrapped-handler request respond raise)))))))

(defn- wrap-with-username-header
  "Middleware to add a reponse header with the current user name (to be used by the nginx access log)"
  [handler]
  (letfn [(add-username-response-header [response]
            (update response :headers merge {"Metabase-User" (get @api/*current-user* :first_name "-")}))]
    (fn [request respond raise]
      (handler request (comp respond add-username-response-header) raise))))

(defn- bind-is-sync-db-request-info
  "Middleware that binds the dynamic variable *is-sync-request* to true if
  the request is asking to sync a database schema or re-scan field values."
  [handler]
  (fn [request respond raise]
    (binding [*is-sync-request?* (sync-db-request? request)]
      (handler request respond raise))))

(defn- default-middleware
  "Middleware to be always added"
  [handler]
  (-> handler
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
        (respond {:status 403 :body "Editing user first name is forbidden"})
        (handler request respond raise)))))
