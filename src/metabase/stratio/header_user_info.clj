(ns metabase.stratio.header-user-info
  (:require [buddy.sign.jwt :as jwt]
            [buddy.core.keys :as keys]
            [buddy.core.codecs :as codecs]
            [buddy.core.codecs.base64 :as b64]
            [clj-http.client :as http]
            [clj-time.core :as time]
            [clojure.string :as str]
            [cheshire.core :as json]
            [metabase.config :as config]
            [metabase.stratio
             [config :as st.config]
             [util :as st.util]]
            [clojure.tools.logging :as log]))

(defn- split-token
  [token]
  (str/split token #"\." 3))


(defn- parse-data
  [^String data]
  (-> (b64/decode data)
      (codecs/bytes->str)
      (json/parse-string true)))


(defn- parse-header
  [token]
  (try
    (let [[header-b64] (split-token token)
          header       (parse-data header-b64)
          alg          (:alg header)]
      (cond-> header
        alg (assoc :alg (keyword (str/lower-case alg)))))
    (catch com.fasterxml.jackson.core.JsonParseException e
      (throw (ex-info "Message seems corrupt or manipulated."
               {:type :validation :cause :header})))))


(defn- get-alg
  [token]
  (:alg (parse-header token)))


(defn- http-header->jwt-token
  [headers]
  (let [header-name       (st.config/config-str :jwt-header-name)
        header-name-lower (str/lower-case header-name)]
    (cond
      (contains? headers header-name)       (get headers header-name)
      (contains? headers header-name-lower) (get headers header-name-lower)
      :else                                 (throw (Exception. "Could not find Authorization header")))))

(defn- verify-token
  [token pkey]
  (let [alg (get-alg token)]
    (jwt/unsign token pkey {:alg alg})))


(defn- ssl-config []
  (if (st.config/config-bool :jwt-insecure-request-pkey)
    {:insecure? true}
    {:trust-store      (config/config-str :mb-jetty-ssl-truststore)
     :trust-store-pass (config/config-str :mb-jetty-ssl-truststore-password)}))

(defn- get-verification-key
  [url]
  (-> url
      (http/get (ssl-config))
      (:body)
      (keys/str->public-key)))


(defn- http-headers->user-info-jwt
  "Gets user info map {:user username :groups [group1 ... groupN]} from jwt token in headers
  or map with :error key if some error happens"
  [headers]
  (log/debug "Getting user info from JWT token")
  (try
    (let [username-claim (st.config/config-kw :jwt-username-claim)
          groups-claim   (st.config/config-kw :jwt-groups-claim)
          token          (http-header->jwt-token headers)
          pkey           (get-verification-key (st.config/config-str :jwt-public-key-endpoint))]
      (cond
        (not token) {:error "Could not obtain jwt token from request headers"}
        (not pkey) {:error "Could not obtain verification key for jwt token"}
        pkey (let [info (-> token
                            (verify-token pkey)
                            (select-keys [username-claim groups-claim])
                            (update-in [groups-claim] st.util/make-vector))
                   user-name (username-claim info)]
               (if (empty? user-name)
                 {:error "No username claim found in token"}
                 {:user user-name :groups (groups-claim info)}))))
    (catch Exception e
      {:error (st.util/stack-trace e)})))


(defn- http-headers->user-info-headers
  "Gets user info map {:user username :groups [group1 ... groupN]} from user/groups http headers
  or map with :error key if some error happens"
  [headers]
  (log/debug "Getting user info from user/group HTTP headers")
  (try
    (let [user-name  (get headers (st.config/config-str :mb-user-header))
          groups-str (get headers (st.config/config-str :mb-group-header) "")
          groups     (st.util/make-vector groups-str)]
      (if (empty? user-name)
        {:error "No user header found"}
        {:user user-name :groups groups}))
    (catch Exception e
      {:error (st.util/stack-trace e)})))


(defn http-headers->user-info
  "Gets user info map {:user username :groups [group1 ... groupN]} either form jwt token
  or headers depending on config; or map with :error key if some error happens"
  [headers]
  (if st.config/jwt?
    (http-headers->user-info-jwt     headers)
    (http-headers->user-info-headers headers)))
