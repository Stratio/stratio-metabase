(ns metabase.stratio.audit-log
  (:require [cheshire.core :as json]
            [clj-time
             [format :as f]
             [core :as t]]))

(defn log
  [user ns msg]
  (println (f/unparse (f/formatters :date-time) (t/now))
           "AUDIT"
           (or user "-")
           1
           1
           ns
           (json/generate-string {"@message" msg})))
