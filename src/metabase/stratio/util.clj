(ns metabase.stratio.util
  (:require [clojure.string :as str]))


(defn make-vector
  [comma-separated-values]
  (if (empty? comma-separated-values)
    []
    (->> comma-separated-values
         (#(str/split % #","))
         (mapv str/trim)
         (filterv #(not (empty? %))))))


(defn stack-trace [e]
  (with-out-str (clojure.stacktrace/print-stack-trace e)))
