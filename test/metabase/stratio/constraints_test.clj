(ns metabase.stratio.constraints-test
  (:require [clojure.test :refer :all]
            [expectations :refer [expect]]
            [metabase.stratio.constraints :as stratio-constraints]))

;; don't do anything to queries without [:middleware :add-default-userland-constraints?] set
(expect
  {}
  (stratio-constraints/add-query-constraints-stratio {}))

;; if it is *truthy* add the constraints
(expect
  {:constraints {:max-results           10
                 :max-results-bare-rows 10}}
  (with-redefs [stratio-constraints/max-results-stratio 10]
    (stratio-constraints/add-query-constraints-stratio {})))

;; don't do anything if it's not truthy
(expect
  {:middleware {:add-default-userland-constraints? false}}
  (with-redefs [stratio-constraints/max-results-stratio nil]
  (stratio-constraints/add-query-constraints-stratio
    {:middleware {:add-default-userland-constraints? false}})))
