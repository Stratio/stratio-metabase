(ns metabase.stratio.util
  (:require
   [clojure.stacktrace :refer [print-stack-trace]]
   [clojure.string :as str]))

(defn make-vector
  "takes a string containing a coma-seperated list of values an returns a vetor containing those values"
  [comma-separated-values]
  (if (empty? comma-separated-values)
    []
    (->> comma-separated-values
         (#(str/split % #","))
         (mapv str/trim)
         (filterv seq))))

(defn stack-trace
  "returns the stack trace of the exception as a string"
  [e]
  (with-out-str (print-stack-trace e)))
