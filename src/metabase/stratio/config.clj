(ns metabase.stratio.config
  (:require
   [buddy.core.keys :as keys]
   [clj-http.client :as http]
   [metabase.config :as config]
   [metabase.models.setting :refer [defsetting]]
   [metabase.stratio.util :as st.util]))

(set! *warn-on-reflection* true)

(def ^:private stratio-defaults
  {:authenticator "gosec-sso"

   ;; settings for jwt authentication
   :jwt-header-name "X-USER-TOKEN"
   :jwt-username-claim "sub"
   :jwt-groups-claim "groups"
   :jwt-tenant-claim "tenant"
   :jwt-email-claim "mail"
   :jwt-public-key-location "url"
   :jwt-public-key-endpoint ""
   :jwt-public-key-file "/etc/pki/jwt-public-key.pem"
   :jwt-insecure-request-pkey "false"
   :jwt-cookie-name "stratio-cookie"

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

(defn- ssl-config []
  (if (config-bool :jwt-insecure-request-pkey)
    {:insecure? true}
    {:trust-store      (config-str :mb-jetty-ssl-truststore)
     :trust-store-pass (config-str :mb-jetty-ssl-truststore-password)}))

(def auto-login-authenticators #{:jwt :headers :gosec-sso})
(def authenticator             (config-kw :authenticator))
(def jwt-public-key-location   (config-kw :jwt-public-key-location))
(def should-auto-login?        (contains? auto-login-authenticators authenticator))
(def jwt?                      (= authenticator :jwt))
(def gosec-sso?                (= authenticator :gosec-sso))
(def headers?                  (= authenticator :headers))
(def jwt-cookie-name           (config-str :jwt-cookie-name))
(def jwt-public-key            (delay
                                 (if (= jwt-public-key-location :file)
                                   (-> (config-str :jwt-public-key-file)
                                       (slurp)
                                       (keys/str->public-key))
                                   (-> (config-str :jwt-public-key-endpoint)
                                       (http/get (ssl-config))
                                       (:body)
                                       (keys/str->public-key)))))

;; We need to define a setting so it can reach frontend via MetabaseSettings object
(defsetting gosec-sso-enabled
  "flag to tell the front end if we are behind the sso proxy so when logout redirect to proxy logout"
  :type        :boolean
  :default     gosec-sso?
  :visibility  :public
  :setter      :none
  :export?     false)
