(ns metabase.stratio.config
  (:require [clojure.string :as str]
            [metabase.config :as config]
            [metabase.models.setting :refer [defsetting]]
            [metabase.stratio.util :as st.util]))

(def ^:private stratio-defaults
  {:authenticator "gosec-sso"

   ;; settings for jwt authentication
   :jwt-header-name "X-USER-TOKEN"
   :jwt-username-claim "sub"
   :jwt-groups-claim "groups"
   :jwt-public-key-endpoint ""
   :jwt-insecure-request-pkey "false"

   ;; settings for authentication via headers
   :mb-user-header ""
   :mb-group-header ""
   :dummy-email-domain "@example.com"

   ;; Authorization based on groups
   :use-group-whitelist "true"
   :allowed-groups ""
   :admin-group ""
   :create-and-sync-groups "true"})


(defn config-str  [k] (or (config/config-str k) ((keyword k) stratio-defaults)))
(defn config-int  [k] (some-> k config-str Integer/parseInt))
(defn config-bool [k] (some-> k config-str Boolean/parseBoolean))
(defn config-kw   [k] (some-> k config-str keyword))
(defn config-vector [k] (st.util/make-vector (config-str k)))

(def auto-login-authenticators #{:jwt :headers :gosec-sso})
(def authenticator (config-kw :authenticator))
(def should-auto-login?  (contains? auto-login-authenticators authenticator))
(def jwt? (= authenticator :jwt))
(def gosec-sso? (= authenticator :gosec-sso))

;; We need to define a setting so it can reach frontend via MetabaseSettings object
(defsetting gosec-sso-enabled
  "flag to tell the front end if we are behing the sso proxy so when logout redirect to proxy logout"
  :type        :boolean
  :default     gosec-sso?
  :visibility  :public
  :setter      :none)
