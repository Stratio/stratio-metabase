(ns metabase.stratio.middleware-test
  (:require
   [clojure.test :refer :all]
   [metabase.mcp.settings :as mcp.settings]
   [metabase.stratio.config :as st.config]
   [metabase.stratio.middleware :as st.mw]
   [metabase.test :as mt]
   [metabase.test.http-client :as client]))

(set! *warn-on-reflection* true)

(defn- impersonate
  "Run `request` through the impersonation middleware with a handler that returns the request it receives, so the
  result is either that request or the middleware's own response."
  [request]
  ((#'st.mw/wrap-with-mcp-impersonation (fn [request respond _raise] (respond request)))
   (merge {:uri "/api/metabase-mcp" :request-method :post} request)
   identity
   identity))

(defn- trusted [& [uid]]
  {:headers (cond-> {"x-mcp-trusted-client" "true"}
              uid (assoc "x-mcp-impersonate" uid))})

(deftest impersonation-test
  (with-redefs [st.config/mcp-impersonation-enabled? true]
    (mt/with-temp [:model/User {user-id :id} {:login_attributes {"uid" "mcp-uid"} :is_superuser true :locale "es"}
                   :model/User _             {:login_attributes {"uid" "mcp-inactive-uid"} :is_active false}
                   :model/User _             {:login_attributes {"uid" "mcp-twice-uid"}}
                   :model/User _             {:login_attributes {"uid" "mcp-twice-uid"}}
                   :model/User _             {:first_name "mcp-name-uid"}]
      (testing "the user with the uid in its login attributes is impersonated, with its flags"
        (is (=? {:metabase-user-id user-id :is-superuser? true :is-data-analyst? false :user-locale "es"}
                (impersonate (trusted "mcp-uid")))))
      (testing "unknown, inactive or ambiguous users can't be impersonated"
        (doseq [uid ["mcp-unknown-uid" "mcp-inactive-uid" "mcp-twice-uid" "mcp-name-uid" "mcp"]]
          (testing uid
            (is (=? {:status 401} (impersonate (trusted uid)))))))
      (testing "without a user to impersonate the placeholder user is used"
        (is (=? {:metabase-user-id @#'st.mw/mcp-service-user-id} (impersonate (trusted))))))
    (testing "requests are left untouched"
      (testing "without the trusted client header"
        (is (nil? (:metabase-user-id (impersonate {:headers {"x-mcp-impersonate" "mcp-uid"}})))))
      (testing "when already authenticated"
        (is (= 1 (:metabase-user-id (impersonate (merge (trusted "mcp-uid") {:metabase-user-id 1}))))))
      (testing "outside the MCP endpoints"
        (is (nil? (:metabase-user-id (impersonate (merge (trusted) {:uri "/api/card"}))))))
      (testing "with the MCP server disabled"
        (mt/with-temporary-setting-values [mcp.settings/mcp-enabled? false]
          (is (nil? (:metabase-user-id (impersonate (trusted)))))))))
  (testing "with impersonation disabled requests are left untouched"
    (with-redefs [st.config/mcp-impersonation-enabled? false]
      (is (nil? (:metabase-user-id (impersonate (trusted))))))))

(deftest mcp-discovery-as-placeholder-user-test
  (testing "the MCP transport serves the calls made without impersonation to a user that is not in the database"
    (with-redefs [st.config/mcp-impersonation-enabled? true]
      (let [headers    {"x-mcp-trusted-client" "true"}
            init       (client/client-full-response :post 200 "metabase-mcp"
                                                    {:request-options {:headers headers}}
                                                    {:jsonrpc "2.0" :method "initialize" :params {} :id 1})
            session-id (get-in init [:headers "Mcp-Session-Id"])
            tools      (client/client-full-response :post 200 "metabase-mcp"
                                                    {:request-options {:headers (assoc headers "mcp-session-id" session-id)}}
                                                    {:jsonrpc "2.0" :method "tools/list" :params {} :id 2})]
        (is (some? session-id))
        (is (seq (get-in tools [:body :result :tools])))))))

(deftest mcp-impersonated-initialize-test
  (testing "an impersonated user can open an MCP session"
    (with-redefs [st.config/mcp-impersonation-enabled? true]
      (mt/with-temp [:model/User _ {:login_attributes {"uid" "mcp-http-uid"}}]
        (is (some? (get-in (client/client-full-response
                            :post 200 "metabase-mcp"
                            {:request-options {:headers {"x-mcp-trusted-client" "true"
                                                         "x-mcp-impersonate"    "mcp-http-uid"}}}
                            {:jsonrpc "2.0" :method "initialize" :params {} :id 1})
                           [:headers "Mcp-Session-Id"])))))))
