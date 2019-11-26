(ns metabase.api.header-authenticator
  (:require [metabase.public-settings :as public-settings]
            [clojure.tools.logging :as log]))


(defn http-headers->user-info
  [headers]
  (log/debug "Getting user info from user/group HTTP headers")
  (try
    (let [user-name (get headers (public-settings/user-header))
          groups-str (get headers (public-settings/group-header) "")
          groups (clojure.string/split groups-str (re-pattern (public-settings/group-header-delimiter)))]
      {:user user-name :groups groups})
    (catch Exception e
      {:error (.toString e)})))
