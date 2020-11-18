(ns metabase.stratio.constraints
  "Adds a limit to the maximum number of exported rows as a constraint if the variable STRATIO_ABSOLUTE_MAX_RESULTS is defined.")


(def ^:private max-results-stratio
  "General maximum number of rows to return from an API query. Returns nil if not defined or not parsable to Long"
  (try (let [s (System/getenv "STRATIO_ABSOLUTE_MAX_RESULTS")] (Long/valueOf s)) (catch Exception _)))

(def default-query-constraints-stratio
  "Default map of constraints that we apply on dataset queries executed by the api.
  The keywords max-results and max-results-bare-rows can have the same value as shown in add-row-count-and-status"
  (let [parsed-limit  (or max-results-stratio metabase.query-processor.interface/absolute-max-results)]
   {:max-results           parsed-limit
    :max-results-bare-rows parsed-limit}))

(defn add-query-constraints-stratio
  "If defined via environment variable"
  [query]
  (cond-> query
          max-results-stratio (assoc :constraints default-query-constraints-stratio)))


