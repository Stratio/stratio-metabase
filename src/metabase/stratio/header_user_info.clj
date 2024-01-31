(ns metabase.stratio.header-user-info
  (:require
   [buddy.core.codecs :as codecs]
   [buddy.core.codecs.base64 :as b64]
   [buddy.core.keys :as keys]
   [buddy.sign.jwt :as jwt]
   [cheshire.core :as json]
   [clj-http.client :as http]
   [clojure.string :as str]
   [metabase.config :as config]
   [metabase.stratio.config :as st.config]
   [metabase.stratio.util :as st.util]
   [metabase.util :as u]
   [metabase.util.log :as log]))

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
        alg (assoc :alg (keyword (u/lower-case-en alg)))))
    (catch com.fasterxml.jackson.core.JsonParseException _
      (throw (ex-info "Message seems corrupt or manipulated."
               {:type :validation :cause :header})))))


(defn- get-alg
  [token]
  (:alg (parse-header token)))


(defn- http-headers->jwt-token
  [headers]
  (let [header-name       (st.config/config-str :jwt-header-name)
        header-name-lower (u/lower-case-en header-name)]
    (cond
      (contains? headers header-name)       (get headers header-name)
      (contains? headers header-name-lower) (get headers header-name-lower)
      :else                                 (throw (Exception. "Could not find Authorization header")))))


(defn- http-cookies->jwt-token
  [cookies]
  (or (get-in cookies [st.config/jwt-cookie-name :value])
      (throw (Exception. (str "Could not find cookie '" st.config/jwt-cookie-name "'")))))


(defn- http-request->jwt-token
  [{:keys [headers cookies]}]
  (cond
    st.config/gosec-sso? (http-cookies->jwt-token cookies)
    st.config/jwt?       (http-headers->jwt-token headers)))


(defn- verify-token
  [token pkey]
  (let [alg (get-alg token)]
    (jwt/unsign token pkey {:alg alg})))


(defn- http-request->user-info-jwt
  "Gets user info map {:user username, :groups [group1 ... groupN], :email email, :tenant tenant}
    from jwt token in headers or in cookie. The :email and :tenant may not be present in the jwt.
    If some error happens a map with an :error key is returned."
  [request]
  (log/debug "Getting user info from JWT token")
  (try
    (let [username-claim (st.config/config-kw :jwt-username-claim)
          groups-claim   (st.config/config-kw :jwt-groups-claim)
          email-claim    (st.config/config-kw :jwt-email-claim)
          tenant-claim   (st.config/config-kw :jwt-tenant-claim)
          token          (http-request->jwt-token request)
          pkey           @st.config/jwt-public-key]
      (cond
        (not token) {:error "Could not obtain jwt token from request headers"}
        (not pkey) {:error "Could not obtain verification key for jwt token"}
        pkey (let [info (-> token
                            (verify-token pkey)
                            (select-keys [username-claim groups-claim email-claim tenant-claim])
                            (update-in [groups-claim] st.util/ensure-vector))
                   user-name (username-claim info)]
               (if (empty? user-name)
                 {:error "No username claim found in token"}
                 {:user   user-name
                  :groups (groups-claim info)
                  :email  (email-claim  info)
                  :tenant (tenant-claim info)}))))
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
  [{headers :headers, :as request}]
  (if st.config/headers?
    (http-headers->user-info-headers headers)
    (http-request->user-info-jwt     request)))
