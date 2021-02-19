(ns metabase.stratio.auth
  (:require [clojure.set :as set]
            [clojure.tools.logging :as log]
            [metabase.api
             [common :as api]
             [session :as session]]
            [metabase.integrations.common :as integrations]
            [metabase.server.middleware.session :as mw.session]
            [metabase.models
             [permissions-group :as group :refer [PermissionsGroup]]
             [user :as user :refer [User]]]
            [metabase.stratio
             [config :as st.config]
             [header-user-info :refer [http-headers->user-info]]
             [util :as st.util]]
            [metabase.util :as u]
            [toucan.db :as db]
            [toucan.hydrate :refer [hydrate]])
  (:import java.util.UUID))

(def dummy-email-domain      (st.config/config-str :dummy-email-domain))
(def create-and-sync-groups? (st.config/config-bool :create-and-sync-groups))
(def admin-group             (st.config/config-str :admin-group))
(def whitelist               (set (st.config/config-vector :allowed-groups)))
(def whitelist-enabled?      (st.config/config-bool :use-group-whitelist))
(def whitelist-disabled?     (not whitelist-enabled?))

(defn- allowed?
  [groups]
  (or whitelist-disabled?
      ;; a set can act as a predicate!
      (some whitelist groups)))

(defn- admin?
  [groups]
  (contains? (set groups) admin-group))

(defn- effective-groups
  [groups]
  (if whitelist-disabled?
    (set groups)
    (set/intersection (set groups) whitelist)))

(defn- allowed-user
  [{:keys [user groups error]}]
  (if error
    {:error error}
    (if (allowed? groups)
      {:first_name user
       :last_name ""
       :is_superuser (admin? groups)
       :email (str user dummy-email-domain)
       :login_attributes {:groups groups}}
      {:error (str "User " user " not allowed")})))

(defn- insert-new-user!
  "Creates a new user, defaulting the password when not provided"
  [new-user]
  (db/insert! User (update new-user :password #(or % (str (UUID/randomUUID))))))

(defn- group-name->group-id []
  (db/select-field->id :name PermissionsGroup))

(defn- insert-groups! [group-names]
  (db/insert-many! PermissionsGroup (map (fn [name] {:name name}) group-names)))

(defn- create-and-sync-groups!
  [user-id group-names]
  (try
    (let [group-name->group-id (group-name->group-id)
          groups-to-create     (remove group-name->group-id group-names)
          created-group-ids    (insert-groups! groups-to-create)
          existing-group-ids   (->> group-names
                                    (map group-name->group-id)
                                    (filter some?))
          user-group-ids       (concat existing-group-ids created-group-ids)]
      (integrations/sync-group-memberships! user-id user-group-ids))
    (catch Exception e
      (log/error "Could not create and sync groups. Error:" (st.util/stack-trace e)))))

(defn- fetch-or-create-user!
  [{email :email {groups :groups} :login_attributes, :as allowed-user}]
  (or (if-let [user-in-db (db/select-one [User :id :last_login :is_superuser] :email email)]
        (do
          ;; Check if superuser status has changed and update if necessary
          (if (or (apply not= (map :is_superuser     [user-in-db allowed-user]))
                  (apply not= (map :login_attributes [user-in-db allowed-user])))
            (db/update! User (:id user-in-db)
                        :is_superuser     (:is_superuser allowed-user)
                        :login_attributes (:login_attributes allowed-user)))
          (if create-and-sync-groups?
            (create-and-sync-groups! (:id user-in-db) (effective-groups groups)))
          user-in-db))
      (let [user-inserted (insert-new-user! allowed-user)]
        (if create-and-sync-groups?
          (create-and-sync-groups! (:id user-inserted) (effective-groups groups)))
        user-inserted)))

(defn- create-session-from-headers!
  [{headers :headers, :as request}]
  (let [user-info    (http-headers->user-info headers)
        allowed-user (allowed-user user-info)]
    (log/debug "received user info " user-info)
    (if (:error allowed-user)
      allowed-user
      (try
        (let [session (session/create-session! :sso (fetch-or-create-user! allowed-user))]
          (assoc allowed-user :session session))
        (catch Exception e
          {:error (st.util/stack-trace e)})))))

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
      (let [{:keys [session first_name error]} (create-session-from-headers! request)]
        (if error
          (do
            (log/error "Could not perform auto-login. Error: " error)
            (handler request respond raise))
          (let [wrap-request (assoc request :metabase-session-id (-> session :id str))
                wrap-respond #(respond (mw.session/set-session-cookie request % session))]
            (log/info "User" first_name "auto-logged-in through headers")
            (handler wrap-request wrap-respond raise)))))))

(defn auto-login
   [handler]
   (if-not st.config/should-auto-login?
     handler
     (wrap-with-auto-login-session handler)))
