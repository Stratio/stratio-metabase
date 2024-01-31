(ns metabase.stratio.auth
  (:require [clojure.set :as set]
            [clojure.string :as str]
            [clojure.tools.logging :as log]
            [metabase.api.session :as session]
            [metabase.integrations.common :as integrations]
            [metabase.models
             [permissions-group :as group :refer [PermissionsGroup]]
             [user :as user :refer [User]]]
            [metabase.stratio
             [config :as st.config]
             [header-user-info :refer [http-headers->user-info]]
             [util :as st.util]]
            [metabase.server.request.util :as request.u]
            [metabase.util :as u]
            [toucan.db :as db]
            [toucan.hydrate :refer [hydrate]])
  (:import java.util.UUID))

(def dummy-email-domain      (st.config/config-str :dummy-email-domain))
(def create-and-sync-groups? (st.config/config-bool :create-and-sync-groups))
(def admin-group             (st.config/config-str :admin-group))
(def whitelist               (-> :allowed-groups
                                 st.config/config-vector
                                 (conj admin-group)
                                 ((partial remove empty?))
                                 set))
(def whitelist-enabled?      (st.config/config-bool :use-group-whitelist))
(def whitelist-disabled?     (not whitelist-enabled?))

(defn- allowed?
  [groups]
  (or whitelist-disabled?
      ;; a set can act as a predicate!
      (some whitelist groups)))

(defn- tenant-allowed?
  [user-tenant]
  (let [app-tenant (st.config/config-str :tenant)]
    (or (not user-tenant)
        (not app-tenant)
        (= user-tenant app-tenant))))

(defn- admin?
  [groups]
  (contains? (set groups) admin-group))

(defn- effective-groups
  [groups superuser?]
  (cond-> (set groups)
    whitelist-enabled? (set/intersection whitelist)
    true               (disj group/admin-group-name)  ;; prevent a SSO "Administrators" group to trigger admin status
    superuser?         (conj group/admin-group-name)))

(defn- allowed-user
  [{:keys [user groups email tenant error]}]
  (if error
    {:error error}
    (if (and (allowed? groups) (tenant-allowed? tenant))
      {:first_name user
       :last_name ""
       :is_superuser (admin? groups)
       :email (cond email email
                    (u/email? user) user
                    :else (u/lower-case-en (str user dummy-email-domain)))
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
          user-group-ids       (concat existing-group-ids created-group-ids)
          all-metabase-groups  (db/select-ids PermissionsGroup)]
      (integrations/sync-group-memberships! user-id user-group-ids all-metabase-groups))
    (catch Exception e
      (log/error "Could not create and sync groups. Error:" (st.util/stack-trace e)))))

(defn- fetch-or-create-user!
  [{first_name :first_name {groups :groups} :login_attributes superuser? :is_superuser, :as allowed-user}]
  (or (if-let [user-in-db (db/select-one [User :id :last_login :is_superuser] :first_name first_name)]
        (do
          ;; Check if superuser status has changed and update if necessary
          (if (or (apply not= (map :is_superuser     [user-in-db allowed-user]))
                  (apply not= (map :login_attributes [user-in-db allowed-user])))
            (db/update! User (:id user-in-db)
                        :is_superuser     superuser?
                        :login_attributes (:login_attributes allowed-user)))
          (if create-and-sync-groups?
            (create-and-sync-groups! (:id user-in-db) (effective-groups groups superuser?)))
          user-in-db))
      (let [user-inserted (insert-new-user! allowed-user)]
        (if create-and-sync-groups?
          (create-and-sync-groups! (:id user-inserted) (effective-groups groups superuser?)))
        user-inserted)))

(defn create-session-from-headers!
  [request]
  (let [user-info    (http-headers->user-info request)
        allowed-user (allowed-user user-info)]
    (log/debug "received user info " user-info)
    (if (:error allowed-user)
      allowed-user
      (try
        (let [session (session/create-session! :sso (fetch-or-create-user! allowed-user) (request.u/device-info request))]
          (assoc allowed-user :session session))
        (catch Exception e
          {:error (st.util/stack-trace e)})))))

