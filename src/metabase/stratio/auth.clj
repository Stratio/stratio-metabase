(ns metabase.stratio.auth
  (:require
   [clojure.set :as set]
   [metabase.permissions.models.permissions-group :as perms-group]
   [metabase.request.core :as request]
   [metabase.session.models.session :as session]
   [metabase.sso.core :as sso]
   [metabase.stratio.config :as st.config]
   [metabase.stratio.header-user-info :refer [http-headers->user-info]]
   [metabase.stratio.util :as st.util]
   [metabase.util :as u]
   [metabase.util.log :as log]
   [toucan2.core :as t2]))

(def ^:private dummy-email-domain      (st.config/config-str :dummy-email-domain))
(def ^:private create-and-sync-groups? (st.config/config-bool :create-and-sync-groups))
(def ^:private admin-group             (st.config/config-str :admin-group))
(def ^:private whitelist               (-> :allowed-groups
                                           st.config/config-vector
                                           (conj admin-group)
                                           ((partial remove empty?))
                                           set))
(def ^:private whitelist-enabled?      (st.config/config-bool :use-group-whitelist))
(def ^:private whitelist-disabled?     (not whitelist-enabled?))

(defn- allowed?
  [groups]
  (or whitelist-disabled?
      ;; a set can act as a predicate!
      (some whitelist groups)))

(defn- tenant-allowed?
  [user-tenants]
  (let [app-tenant (st.config/config-str :tenant)]
    (or (not (seq user-tenants))
        (not app-tenant)
        (contains? (set user-tenants) app-tenant))))

(defn- admin?
  [groups]
  (contains? (set groups) admin-group))

(defn- effective-groups
  [groups superuser?]
  (cond-> (set groups)
    whitelist-enabled? (set/intersection whitelist)
    true               (disj (:name (perms-group/admin)))  ;; prevent a SSO "Administrators: group to trigger admin status
    superuser?         (conj (:name (perms-group/admin)))))

(defn- allowed-user
  [{:keys [user groups email tenants error]}]
  (if error
    {:error error}
    (if (and (allowed? groups) (tenant-allowed? tenants))
      {:first_name user
       :last_name ""
       :is_superuser (admin? groups)
       :email (cond (u/email? email) email
                    (u/email? user) user
                    :else (u/lower-case-en (str user dummy-email-domain)))
       :login_attributes {:groups groups}}
      {:error (str "User " user " not allowed")})))

(defn- insert-new-user!
  "Creates a new user, defaulting the password when not provided"
  [new-user]
  (t2/insert-returning-instance! :model/User (update new-user :password #(or % (str (random-uuid))))))

(defn- group-name->group-id []
  (t2/select-fn->pk :name :model/PermissionsGroup))

(defn- insert-groups! [group-names]
  (t2/insert-returning-pks! :model/PermissionsGroup (map (fn [name] {:name name}) group-names)))

(defn- create-and-sync-groups!
  [user-id group-names]
  (try
    (let [group-name->group-id (group-name->group-id)
          groups-to-create     (remove group-name->group-id group-names)
          created-group-ids    (insert-groups! groups-to-create)
          existing-group-ids   (->> group-names
                                    (map group-name->group-id)
                                    (filter some?))
          user-group-ids       (concat existing-group-ids created-group-ids)
          all-metabase-groups  (t2/select-pks-set :model/PermissionsGroup)]
      (sso/sync-group-memberships! user-id user-group-ids all-metabase-groups))
    (catch Exception e
      ;; if race condition reraise so it is catched later and handled correctly
      (if (re-find #"duplicate key|unique constraint" (.getMessage e))
        (throw e)
        (log/error "Could not create and sync groups. Error:" (st.util/stack-trace e))))))

(defn- fetch-or-create-user!
  [{first_name :first_name {groups :groups} :login_attributes superuser? :is_superuser, :as allowed-user}]
  (try
    (or (when-let [user-in-db (t2/select-one :model/User :first_name first_name)]
          ;; Check if superuser status has changed and update if necessary
          (when (or (apply not= (map :is_superuser [user-in-db allowed-user]))
                    (apply not= (map :login_attributes [user-in-db allowed-user])))
            (t2/update! :model/User (:id user-in-db) {:is_superuser superuser?
                                                      :login_attributes (:login_attributes allowed-user)}))
          (when create-and-sync-groups?
            (create-and-sync-groups! (:id user-in-db) (effective-groups groups superuser?)))
          user-in-db)
        (let [user-inserted (insert-new-user! allowed-user)]
          (when create-and-sync-groups?
            (create-and-sync-groups! (:id user-inserted) (effective-groups groups superuser?)))
          user-inserted))
    (catch Exception e
      ;; if we have run into a race condition between the two autologin endpoints, and we have tried to
      ;; insert something that has just been inserted by the other autologin (detected by the error
      ;; message) just fetch the user that the other endpoint has just created, otherwise raise the error
      (if (re-find #"duplicate key|unique constraint" (.getMessage e))
        (t2/select-one :model/User :first_name first_name)
        (throw e))
      )))

(defn create-session-from-headers!
  "Reads the SSO user info in the request (either as jwt or as plain headers) and returs a 'user' (a map with some
  user-related keys, including a valid Metbase session in :session. If the user does not exists in the Metabse DB,
  it is created, and optionally, their groups are also created and synced."
  [request]
  (log/debug "No user info found associated to request, trying to auto-login...")
  (let [user-info (http-headers->user-info request)
        allowed-user (allowed-user user-info)]
    (log/debug "received user info " user-info)
    (if (:error allowed-user)
      allowed-user
      (try
        (let [session (session/create-session! :sso (fetch-or-create-user! allowed-user) (request/device-info request))]
          (assoc allowed-user :session session))
        (catch Exception e
          {:error (st.util/stack-trace e)})))))
