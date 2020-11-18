(ns metabase.stratio.constraints
  "Middleware that adds default constraints to limit the maximum number of rows returned to queries that specify the
  variable STRATIO_ABSOLUTE_MAX_RESULTS."
  )

(def ^:private max-results-stratio
  "General maximum number of rows to return from an API query."
  (or (try (let [s (System/getenv "STRATIO_ABSOLUTE_MAX_RESULTS")] (Long/valueOf s)) (catch Exception _))
      metabase.query-processor.interface/absolute-max-results)
  )

(def defined-stratio-constraints?
  "Check if a limit is set via environment variables"
  (some? (System/getenv "STRATIO_ABSOLUTE_MAX_RESULTS"))
  )

(def default-query-constraints-stratio
  "Default map of constraints that we apply on dataset queries executed by the api.
  The keywords max-results and max-results-bare-rows can have the same value as shown in add-row-count-and-status"
  (if defined-stratio-constraints?
    {:max-results           max-results-stratio
     :max-results-bare-rows max-results-stratio}
    {}))
