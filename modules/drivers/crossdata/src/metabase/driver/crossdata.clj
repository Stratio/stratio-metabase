(ns metabase.driver.crossdata
    "Driver for Stratio Crossdata databases. Uses the official Stratio JDBC driver under the hood."
    (:require
      [clojure.java.jdbc :as jdbc]
      [clojure
       [set :as set]
       [string :as str]]
      [metabase.util :as u]
      [honeysql
       [core :as hsql]
       [format :as hformat]
       [helpers :as h]]
      [clojure.tools.logging :as log]
      [metabase.driver :as driver]
      [metabase.models
       [field :refer [Field]]
       [table :refer [Table]]]
      [metabase.driver.sql.query-processor :as sql.qp]
      [metabase.query-processor
       [store :as qp.store]
       [util :as qputil]]
      [metabase.mbql.util :as mbql.u]
      [metabase.driver.sql-jdbc
       [common :as sql-jdbc.common]
       [connection :as sql-jdbc.conn]
       [execute :as sql-jdbc.execute]
       [sync :as sql-jdbc.sync]]
      [metabase.driver.sql.util.unprepare :as unprepare]
      [toucan.db :as db]
      [metabase.util
       [honeysql-extensions :as hx]
       [date :as du]] )
  (:import [java.sql PreparedStatement Time] java.util.Date))

;; Register Crossdata driver
(driver/register! :crossdata, :parent :sql-jdbc)

(defmethod driver/display-name :crossdata [_]
  "Stratio Crossdata")


;(defmethod driver/can-connect? :crossdata [_ details]
;  (log/debug "crossdata/can-connect? call")
;  )


;; Connection to Crossdata database
(defmethod sql-jdbc.conn/connection-details->spec :crossdata [_ {:keys [host port dbname user ssl-option]
                                                                 :or {host "localhost", port 13422, dbname "", user "crossdata-1"}
                                                                 :as details}]
  (println "sql-jdbc.conn/connection-details->spec. Host:" host "port:" port " details:" details)
  (-> (merge {:classname "com.stratio.jdbc.core.jdbc4.StratioDriver"
              :subprotocol "crossdata"
              :subname (if ssl-option
                         (str "//Server=" host ":" port ";UID=" user ";SSL=true;LogLevel=3;LogPath=/tmp/crossdata-jdbc-logs")
                         (str "//Server=" host ":" port ";UID=" user ";LogLevel=3;LogPath=/tmp/crossdata-jdbc-logs"))}
             (dissoc details :host :port :user :ssl :db :ssl-option))
      (sql-jdbc.common/handle-additional-options details,:seperator-style :semicolon)))


;; Querys against Crossdata database
(def ^:private database-type->base-type
  (sql-jdbc.sync/pattern-based-database-type->base-type
   [[#"BIGINT"   :type/BigInteger]
    [#"BIG INT"  :type/BigInteger]
    [#"INT"      :type/Integer]
    [#"TINYINT"  :type/Integer]
    [#"SMALLINT" :type/Integer]
    [#"CHAR"     :type/Text]
    [#"TEXT"     :type/Text]
    [#"CLOB"     :type/Text]
    [#"BLOB"     :type/*]
    [#"REAL"     :type/Float]
    [#"DOUB"     :type/Float]
    [#"FLOA"     :type/Float]
    [#"NUMERIC"  :type/Float]
    [#"DECIMAL"  :type/Decimal]
    [#"BOOLEAN"  :type/Boolean]
    [#"DATETIME" :type/DateTime]
    [#"TIMESTAMP" :type/DateTime]
    [#"DATE"     :type/Date]
    [#"TIME"     :type/Time]
    [#"BINARY"   :type/*]
    [#"ARRAY"    :type/Array]
    [#"MAP"      :type/Dictionary]
    [#"STRUCT"   :type/*]]))

;; Type conversion
(defmethod sql-jdbc.sync/database-type->base-type :crossdata [_ database-type]
    (database-type->base-type database-type))

(def ^:private source-table-alias
  "Default alias for all source tables. (Not for source queries; those still use the default SQL QP alias of `source`.)"
  "default")

;; use `source-table-alias` for the source Table, e.g. `t1.field` instead of the normal `schema.table.field`
(defmethod sql.qp/->honeysql [:crossdata (class Field)]
  [driver field]
  (binding [sql.qp/*table-alias* (or sql.qp/*table-alias* source-table-alias)]
    ((get-method sql.qp/->honeysql [:sql (class Field)]) driver field)))

(defmethod sql.qp/apply-top-level-clause [:crossdata :source-table]
  [driver _ honeysql-form {source-table-id :source-table}]
  (let [{table-name :name, schema :schema} (qp.store/table source-table-id)]
    (h/from honeysql-form [(sql.qp/->honeysql driver (hx/identifier :table schema table-name))
                           (sql.qp/->honeysql driver (hx/identifier :table-alias source-table-alias))])))

(defmethod sql.qp/apply-top-level-clause [:crossdata :page] [_ _ honeysql-form {{:keys [items page]} :page}]
           (let [offset (* (dec page) items)]
                (if (zero? offset)
                  ;; if there's no offset we can simply use limit
                  (h/limit honeysql-form items)
                  ;; if we need to do an offset we have to do nesting to generate a row number and where on that
                  (let [over-clause (format "row_number() OVER (%s)"
                                            (first (hsql/format (select-keys honeysql-form [:order-by])
                                                                :allow-dashed-names? true
                                                                :quoting :mysql)))]
                       (-> (apply h/select (map last (:select honeysql-form)))
                           (h/from (h/merge-select honeysql-form [(hsql/raw over-clause) :__rownum__]))
                           (h/where [:> :__rownum__ offset])
                           (h/limit items))))))

;; refresh values in Metabase cache
(defmethod driver/describe-table :crossdata
  [driver {:keys [details] :as database} {table-name :name, schema :schema, :as table}]
  ; Do a "refresh schema.table" to update metadata. This is mandatory.
  (with-open [conn (jdbc/get-connection (sql-jdbc.conn/db->pooled-connection-spec database))]
    (jdbc/query {:connection conn}
                [(format "refresh table %s.%s" schema table-name) ]))
  ((get-method driver/describe-table :sql-jdbc) driver database table)

  )


(defn- run-query
  "Run the query itself."
  [{sql :query, :keys [params remark max-rows]} connection]
  (let [options {:identifiers identity
                 :as-arrays?  true
                 :max-rows    max-rows}]
    (with-open [connection (jdbc/get-connection connection)]
      (with-open [^PreparedStatement statement (jdbc/prepare-statement connection sql options)]
        (let [statement        (into [statement] params)
              [columns & rows] (jdbc/query connection statement options)]
          {:rows    (or rows [])
           :columns (map u/qualified-name columns)})))))

(defn run-query-without-timezone
  "Runs the given query without trying to set a timezone"
  [_ _ connection query]
  (run-query query connection))

(defmethod driver/execute-query :crossdata
  [driver {:keys [database settings], query :native, :as outer-query}]

  (log/debug "query:" query " outer-query:" outer-query)
  (let [query (-> (assoc query
                         :remark (qputil/query->remark outer-query)
                         :query  (if (seq (:params query))
                                   (unprepare/unprepare driver (cons (:query query) (:params query)))
                                   (:query query))
                         :max-rows (mbql.u/query->max-rows-limit outer-query))
                  (dissoc :params))]
    (sql-jdbc.execute/do-with-try-catch
     (fn []
       (let [db-connection (sql-jdbc.conn/db->pooled-connection-spec database)]
         (run-query-without-timezone driver settings db-connection query)))))
  )

(defmethod driver/supports? [:crossdata :basic-aggregations]              [_ _] true)
(defmethod driver/supports? [:crossdata :binning]                         [_ _] true)
(defmethod driver/supports? [:crossdata :expression-aggregations]         [_ _] true)
(defmethod driver/supports? [:crossdata :expressions]                     [_ _] true)
(defmethod driver/supports? [:crossdata :native-parameters]               [_ _] true)
(defmethod driver/supports? [:crossdata :nested-queries]                  [_ _] true)
(defmethod driver/supports? [:crossdata :standard-deviation-aggregations] [_ _] true)

(defmethod driver/supports? [:crossdata :foreign-keys] [_ _] true)




(defmethod sql.qp/current-datetime-fn :crossdata [_] :%now)

(defmethod sql.qp/unix-timestamp->timestamp [:crossdata :seconds] [_ _ expr]
  (hx/->timestamp (hsql/call :from_unixtime expr)))

(defn- date-format [format-str expr]
  (hsql/call :date_format expr (hx/literal format-str)))

(defn- str-to-date [format-str expr]
  (hx/->timestamp
   (hsql/call :from_unixtime
              (hsql/call :unix_timestamp
                         expr (hx/literal format-str)))))

(defmethod driver/date-add :crossdata [_ dt amount unit]
  (hx/+ (hx/->timestamp dt) (hsql/raw (format "(INTERVAL '%d' %s)" (int amount) (name unit)))))


(defn- trunc-with-format [format-str expr]
  (str-to-date format-str (date-format format-str expr)))
(defmethod sql.qp/quote-style :crossdata [_] :mysql)
(defmethod sql.qp/date [:crossdata :day]             [_ _ expr] (trunc-with-format "yyyy-MM-dd" (hx/->timestamp expr)))
(defmethod sql.qp/date [:crossdata :minute]          [_ _ expr] (trunc-with-format "yyyy-MM-dd HH:mm" (hx/->timestamp expr)))
(defmethod sql.qp/date [:crossdata :minute-of-hour]  [_ _ expr] (hsql/call :minute (hx/->timestamp expr)))
(defmethod sql.qp/date [:crossdata :hour]            [_ _ expr] (trunc-with-format "yyyy-MM-dd HH" (hx/->timestamp expr)))
(defmethod sql.qp/date [:crossdata :hour-of-day]     [_ _ expr] (hsql/call :hour (hx/->timestamp expr)))
(defmethod sql.qp/date [:crossdata :day]             [_ _ expr] (trunc-with-format "yyyy-MM-dd" (hx/->timestamp expr)))
(defmethod sql.qp/date [:crossdata :day-of-month]    [_ _ expr] (hsql/call :dayofmonth (hx/->timestamp expr)))
(defmethod sql.qp/date [:crossdata :day-of-year]     [_ _ expr] (hx/->integer (date-format "D" (hx/->timestamp expr))))
(defmethod sql.qp/date [:crossdata :week-of-year]    [_ _ expr] (hsql/call :weekofyear (hx/->timestamp expr)))
(defmethod sql.qp/date [:crossdata :month]           [_ _ expr] (hsql/call :trunc (hx/->timestamp expr) (hx/literal :MM)))
(defmethod sql.qp/date [:crossdata :month-of-year]   [_ _ expr] (hsql/call :month (hx/->timestamp expr)))
(defmethod sql.qp/date [:crossdata :quarter-of-year] [_ _ expr] (hsql/call :quarter (hx/->timestamp expr)))
(defmethod sql.qp/date [:crossdata :year]            [_ _ expr] (hsql/call :trunc (hx/->timestamp expr) (hx/literal :year)))

(defmethod sql.qp/date [:crossdata :day-of-week] [_ _ expr]
  (hx/->integer (date-format "u"
                             (hx/+ (hx/->timestamp expr)
                                   (hsql/raw "interval '1' day")))))

(defmethod sql.qp/date [:crossdata :week] [_ _ expr]
  (hsql/call :date_sub
             (hx/+ (hx/->timestamp expr)
                   (hsql/raw "interval '1' day"))
             (date-format "u"
                          (hx/+ (hx/->timestamp expr)
                                (hsql/raw "interval '1' day")))))

(defmethod sql.qp/date [:crossdata :quarter] [_ _ expr]
  (hsql/call :add_months
             (hsql/call :trunc (hx/->timestamp expr) (hx/literal :year))
             (hx/* (hx/- (hsql/call :quarter (hx/->timestamp expr))
                         1)
                   3)))


(defmethod unprepare/unprepare-value [:crossdata Date] [_ value]
  (hformat/to-sql
   (hsql/call :from_unixtime
              (hsql/call :unix_timestamp
                         (hx/literal (du/date->iso-8601 value))
                         (hx/literal "yyyy-MM-dd\\\\'T\\\\'HH:mm:ss.SSS\\\\'Z\\\\'")))))

(prefer-method unprepare/unprepare-value [:sql Time] [:crossdata Date])
