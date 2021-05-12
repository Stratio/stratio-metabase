(ns metabase.stratio.middleware
  (:require
   [clojure.tools.logging :as log]
   [metabase.api.common :as api]
   [metabase.server.middleware.session :as mw.session]
   [metabase.stratio
    [auth :as st.auth]
    [config :as st.config]]))

(def ^:dynamic ^Boolean *is-sync-request?* false)

(defn- email-login-request?
  [{:keys [:request-method :uri]}]
  (and (= uri "/api/session") (= request-method :post)))

(defn- sync-db-request?
  [{:keys [:request-method :uri]}]
  (boolean
   (and
    (= request-method :post)
    (or (re-matches #"/api/database/[0-9]+/sync_schema" uri)
        (re-matches #"/api/database/[0-9]+/rescan_values" uri)))))

(defn- editing-user-name?
  [{:keys [:uri :request-method :body]}]
  (when (and (re-matches #"/api/user/[0-9]+/?" uri) (= request-method :put))
    (or (apply not= (map :first_name [@api/*current-user* body]))
        (apply not= (map :last_name  [@api/*current-user* body])))))

(defn- forbid-email-login
  "Midleware that checks for email login request and responds with 403 to those"
  [handler]
  (fn [request respond raise]
    (if (email-login-request? request)
      (respond {:status 403, :body "Email login is disabled"})
      (handler request respond raise))))

(defn- wrap-with-auto-login-session
  "Middleware that checks if the metabase session id has been included in the request (this is done
  by a previous middleware). If it is not included we look for the user info in the requests headers
  (either user/groups remoste headers or jwt token), create the user if needed, create the session,
  add it to the request map and set the session cookie in the response."
  [handler]
  (fn [{uri :uri, :as request} respond raise]
    ;; if we are not requesting current user, or we already have a session-id, we do not autologin
    (if (or (:metabase-session-id request) (not= uri "/api/user/current"))
      (handler request respond raise)
      (let [{:keys [session first_name error]} (st.auth/create-session-from-headers! request)]
        (if error
          (do
            (log/error "Could not perform auto-login. Error: " error)
            (handler request respond raise))
          (let [wrap-request (assoc request :metabase-session-id (-> session :id str))
                wrap-respond #(respond (mw.session/set-session-cookie request % session))]
            (log/info "User" first_name "auto-logged-in through headers")
            (handler wrap-request wrap-respond raise)))))))

(defn- wrap-with-username-header
  "Middleware to add a reponse header with the current user name (to be used by the nginx access log)"
  [handler]
  (letfn [(add-username-response-header [response]
            (update response :headers merge {"Metabase-User" (get @api/*current-user* :first_name "-")}))]
    (fn [request respond raise]
      (handler request (comp respond add-username-response-header) raise))))

(defn- delete-invalid-session-cookie
  "Middleware that deletes the session cookie whenever the handler responds with a 401"
  [handler]
  (letfn [(delete-cookie-if-no-auth [response]
            (if (= (:status response) 401)
              (mw.session/clear-session-cookie response)
              response))]
    (fn [request respond raise]
      (handler request (comp respond delete-cookie-if-no-auth) raise))))

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
      forbid-email-login
      delete-invalid-session-cookie))

(def stratio-middleware
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
        (respond {:status 403 :body "Editing user name is forbidden"})
        (handler request respond raise)))))
