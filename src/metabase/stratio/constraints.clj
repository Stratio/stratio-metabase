(ns metabase.stratio.constraints
  "Adds a limit to the maximum number of exported rows as a constraint if the variable STRATIO_ABSOLUTE_MAX_RESULTS is defined."
  (:require [metabase
             [config :as config]]))

(def ^:private max-results-stratio
  "General maximum number of rows to return from an API query.
  Returns nil if STRATIO_ABSOLUTE_MAX_RESULTS is not defined or not parsable to a number"
  (config/config-int :stratio-absolute-max-results))

(defn add-query-constraints-stratio
  "If the environment variable is defined, add the constraints"
  [query]
  (cond-> query
          max-results-stratio (assoc :constraints
                                 {:max-results           max-results-stratio
                                  :max-results-bare-rows max-results-stratio})))
