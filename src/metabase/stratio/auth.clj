(ns metabase.stratio.auth
  (:require
   [clojure.set :as set]
   [metabase.api.session :as api.session]
   [metabase.integrations.common :as integrations]
   [metabase.models.permissions-group :as perms-group]
   [metabase.server.request.util :as req.util]
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

(defn- admin?
  [groups]
  (contains? (set groups) admin-group))

(defn- effective-groups
  [groups superuser?]
  (cond-> (set groups)
    whitelist-enabled? (set/intersection whitelist)
    true               (disj perms-group/admin-group-name)  ;; prevent a SSO "Administrators" group to trigger admin status
    superuser?         (conj perms-group/admin-group-name)))

(defn- allowed-user
  [{:keys [user groups error]}]
  (if error
    {:error error}
    (if (allowed? groups)
      {:first_name user
       :last_name ""
       :is_superuser (admin? groups)
       :email (if (u/email? user) user (u/lower-case-en (str user dummy-email-domain)))
       :login_attributes {:groups groups}}
      {:error (str "User " user " not allowed")})))

(defn- insert-new-user!
  "Creates a new user, defaulting the password when not provided"
  [new-user]
  (t2/insert-returning-instance! :model/User (update new-user :password #(or % (str (random-uuid))))))

(defn- group-name->group-id []
  (t2/select-fn->pk :name :model/PermissionsGroup))

(map (fn [x] {:a x}) [1 2 3])

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
      (integrations/sync-group-memberships! user-id user-group-ids all-metabase-groups))
    (catch Exception e
      (log/error "Could not create and sync groups. Error:" (st.util/stack-trace e)))))

(defn- fetch-or-create-user!
  [{first_name :first_name {groups :groups} :login_attributes superuser? :is_superuser, :as allowed-user}]
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
        user-inserted)))

(defn create-session-from-headers!
  "Reads the SSO user info in the request (either as jwt or as plain headers) and returs a 'user' (a map with some
  user-related keys, including a valid Metbase session in :session. If the user does not exists in the Metabse DB,
  it is created, and optionally, their groups are also created and synced."
  [{headers :headers, :as request}]
  (let [user-info    (http-headers->user-info headers)
        allowed-user (allowed-user user-info)]
    (log/debug "received user info " user-info)
    (if (:error allowed-user)
      allowed-user
      (try
        (let [session (api.session/create-session! :sso (fetch-or-create-user! allowed-user) (req.util/device-info request))]
          (assoc allowed-user :session session))
        (catch Exception e
          {:error (st.util/stack-trace e)})))))

