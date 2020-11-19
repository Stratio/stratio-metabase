(ns metabase.stratio.constraints
  "Adds a limit to the maximum number of exported rows as a constraint if the variable STRATIO_ABSOLUTE_MAX_RESULTS is defined."
  (:require [metabase
             [config :as config]]))

(def ^:private max-results-stratio
  "General maximum number of rows to return from an API query.
  Returns nil if STRATIO_ABSOLUTE_MAX_RESULTS is not defined or not parsable to a number"
  (config/config-int :stratio-absolute-max-results))

(defn default-query-constraints-stratio
  "Default map of constraints that we apply on dataset queries executed by the api.
  The keywords max-results and max-results-bare-rows can have the same value as shown in add-row-count-and-status"
  [max-results]
  (when max-results
   {:max-results           max-results
    :max-results-bare-rows max-results}))

(defn add-query-constraints-stratio
  "If the environment variable is defined, add the constraints"
  [query]
  (cond-> query
          max-results-stratio (assoc :constraints (default-query-constraints-stratio max-results-stratio))))

