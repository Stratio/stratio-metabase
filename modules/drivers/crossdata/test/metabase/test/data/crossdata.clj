(ns metabase.test.data.crossdata
  "Code for creating / destroying a Crossdata database from a `DatabaseDefinition`."
  (:require [clojure.java.jdbc :as jdbc]
            [clojure.string :as str]
            [honeysql
             [core :as hsql]
             [format :as hformat]]
            [metabase.driver.sql-jdbc.connection :as sql-jdbc.conn]
            [metabase.test.data
             [interface :as tx]
             [sql :as sql.tx]
             [sql-jdbc :as sql-jdbc.tx]]
            [metabase.driver.sql
             [query-processor :as sql.qp]
             [util :as sql.u]]
            [metabase.driver.sql.util.unprepare :as unprepare]
            [metabase
             [config :as config]
             [driver :as driver]
             [util :as u]]
            [metabase.test.data.sql.ddl :as ddl]
            [metabase.test.data.sql-jdbc
             [execute :as execute]
             [load-data :as load-data]]
            [toucan.db :as db]
            [metabase.models
             [field :refer [Field]]
             [table :refer [Table]]]))

(sql-jdbc.tx/add-test-extensions! :crossdata)

;; during unit tests don't treat Spark SQL as having FK support
(defmethod driver/supports? [:crossdata :foreign-keys] [_ _] (not config/is-test?))

(defmethod sql.tx/field-base-type->sql-type [:crossdata :type/BigInteger] [_ _] "BIGINT")
(defmethod sql.tx/field-base-type->sql-type [:crossdata :type/Boolean]    [_ _] "BOOLEAN")
(defmethod sql.tx/field-base-type->sql-type [:crossdata :type/Date]       [_ _] "DATE")
(defmethod sql.tx/field-base-type->sql-type [:crossdata :type/DateTime]   [_ _] "TIMESTAMP")
;(defmethod sql.tx/field-base-type->sql-type [:crossdata :type/Time]       [_ _] "DATE")
(defmethod sql.tx/field-base-type->sql-type [:crossdata :type/Decimal]    [_ _] "DECIMAL")
(defmethod sql.tx/field-base-type->sql-type [:crossdata :type/Float]      [_ _] "DOUBLE")
(defmethod sql.tx/field-base-type->sql-type [:crossdata :type/Integer]    [_ _] "INTEGER")
(defmethod sql.tx/field-base-type->sql-type [:crossdata :type/Text]       [_ _] "STRING")


;;; If someone tries to run Time column tests with SparkSQL give them a heads up that SparkSQL does not support it
(defmethod sql.tx/field-base-type->sql-type [:crossdata :type/Time] [_ _]
  (throw (UnsupportedOperationException. "Crossdata does not have a TIME data type.")))


(defmethod sql.tx/pk-sql-type :crossdata [_] "INT")

(defmethod sql.tx/qualified-name-components :crossdata
  [driver & args]
  [(tx/format-name driver (u/qualified-name (last args)))])


(defmethod tx/format-name :crossdata
  [_ s]
  (str/replace s #"-" "_"))

(defmethod tx/dbdef->connection-details :crossdata [driver context {:keys [database-name]}]
  (merge
   {:host     (tx/db-test-env-var-or-throw :crossdata :host "localhost")
    :port     (Integer/parseInt (tx/db-test-env-var-or-throw :crossdata :port "13422"))
    :user     (tx/db-test-env-var-or-throw :crossdata :user "crossdata-1")
    :impersonate false
    :ssl      true
    :ssl-option false}
   (when (= context :db)
     {:db (tx/format-name driver database-name)})))


;;; SparkSQL doesn't support specifying the columns in INSERT INTO statements, so remove it
(defmethod ddl/insert-rows-honeysql-form :crossdata
  [driver table-identifier row-or-rows]
  (let [honeysql ((get-method ddl/insert-rows-honeysql-form :sql-jdbc/test-extensions)
                   driver table-identifier row-or-rows)]
    (dissoc honeysql :columns)))

(defmethod ddl/insert-rows-ddl-statements :crossdata
  [driver table-identifier row-or-rows]
  [(unprepare/unprepare driver
                        (binding [hformat/*subquery?* false]
                          (hsql/format (ddl/insert-rows-honeysql-form driver table-identifier row-or-rows)
                                       :quoting             (sql.qp/quote-style driver)
                                       :allow-dashed-names? false)))])


(defmethod load-data/do-insert! :crossdata
  [driver spec table-identifier row-or-rows]
  (println "crossdata.clj->load-data/do-insert! spec:" spec " table-identifier:" table-identifier " row-or-rows:" row-or-rows)
  (let [statements (ddl/insert-rows-ddl-statements driver table-identifier row-or-rows)]
    (with-open [conn (jdbc/get-connection spec)]
      (try
        (.setAutoCommit conn false)
        (doseq [sql+args statements]
          (jdbc/execute! {:connection conn} sql+args {:transaction? false}))
        (catch java.sql.SQLException e
          (println "Error inserting data:" (u/pprint-to-str 'red statements))
          (jdbc/print-sql-exception-chain e)
          (throw e))))))

(defmethod load-data/load-data! :crossdata [& args]
  (apply load-data/load-data-add-ids! args))
;
(defmethod sql.tx/create-table-sql :crossdata
  [driver {:keys [database-name], :as dbdef} {:keys [table-name field-definitions]}]
  (let [quote-name    #(sql.u/quote-name driver :field (tx/format-name driver %))
        pk-field-name (quote-name (sql.tx/pk-field-name driver))]
    (format "CREATE TABLE %s (%s, %s %s)"
            (sql.tx/qualify-and-quote driver database-name table-name)
            (->> field-definitions
                 (map (fn [{:keys [field-name base-type]}]
                        (format "%s %s" (quote-name field-name) (if (map? base-type)
                                                                  (:native base-type)
                                                                  (sql.tx/field-base-type->sql-type driver base-type)))))
                 (interpose ", ")
                 (apply str))
            pk-field-name (sql.tx/pk-sql-type driver)
            pk-field-name)))

(defmethod sql.tx/drop-table-if-exists-sql :crossdata
  [driver {:keys [database-name]} {:keys [table-name]}]
  (format "DROP TABLE IF EXISTS %s" (sql.tx/qualify-and-quote driver database-name table-name)))

(defmethod sql.tx/drop-db-if-exists-sql :crossdata
  [driver {:keys [database-name]}]
  (format "DROP DATABASE IF EXISTS %s CASCADE" (sql.tx/qualify-and-quote driver database-name)))


(defmethod execute/execute-sql! :crossdata [& args]
  (println "test/data/crossdata.clj->execute/execute-sql!" args)
  (apply execute/sequentially-execute-sql! args))


(defmethod sql.tx/add-fk-sql :crossdata [& _] nil)
