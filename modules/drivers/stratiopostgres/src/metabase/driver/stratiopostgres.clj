(ns metabase.driver.stratiopostgres
  "Postgres driver that also sets a custom variable with the name or email of the current user"
  (:require [clojure
             [string :as str]]
            [clojure.java.jdbc :as jdbc]
            [clojure.tools.logging :as log]
            [metabase.api
             [common :as api]
             [session :refer [dummy-email-domain]]]
            [metabase.driver :as driver]
            [metabase.driver.sql-jdbc
             [connection :as sql-jdbc.conn]
             [execute :as sql-jdbc.execute]]
            [metabase.mbql.util :as mbql.u]
            [metabase.query-processor
             [interface :as qp.i]
             [store :as qp.store]
             [util :as qputil]]
            [metabase.util :as u]
            [metabase.util
             [i18n :refer [tru]]]
            [clojure.set :as set])
  (:import
   [java.sql PreparedStatement SQLException Time]
   [java.util Calendar Date TimeZone UUID]))

(driver/register! :stratiopostgres, :parent :postgres)

(defmethod driver/display-name :stratio-postgres [_] "Stratio PostgreSQL")



;; In ordedr to access the jdbc connection and set the variable with the user, we need
;; to tweak some functions in the sql-jdbc driver. Since the needed functions are private
;; we need to copy them here (and their dependencies) and just tweak them,
;; so the code below is basically a copy paste of that of the sql-jdbc.execute
;; namespace with minor changes

;; TODO - this should be a multimethod like `read-column`. Perhaps named `set-parameter`
(defn- set-parameters-with-timezone
  "Returns a function that will set date/timestamp PreparedStatement
  parameters with the correct timezone"
  [^TimeZone tz]
  (fn [^PreparedStatement stmt params]
    (mapv (fn [^Integer i value]
            (cond

              (and tz (instance? java.sql.Time value))
              (.setTime stmt i value (Calendar/getInstance tz))

              (and tz (instance? java.sql.Timestamp value))
              (.setTimestamp stmt i value (Calendar/getInstance tz))

              (and tz (instance? java.util.Date value))
              (.setDate stmt i value (Calendar/getInstance tz))

              :else
              (jdbc/set-parameter value stmt i)))
          (rest (range)) params)))

;;; +----------------------------------------------------------------------------------------------------------------+
;;; |                                                Running Queries                                                 |
;;; +----------------------------------------------------------------------------------------------------------------+

;; TODO - this is pretty similar to what `jdbc/with-db-connection` does, but not exactly the same. See if we can
;; switch to using that instead?
(defn- do-with-ensured-connection [db f]
  (if-let [conn (jdbc/db-find-connection db)]
    (f conn)
    (with-open [conn (jdbc/get-connection db)]
      (f conn))))

(defmacro ^:private with-ensured-connection
  "In many of the clojure.java.jdbc functions, it checks to see if there's already a connection open before opening a
  new one. This macro checks to see if one is open, or will open a new one. Will bind the connection to `conn-sym`."
  {:style/indent 1}
  [[conn-binding db] & body]
  `(do-with-ensured-connection ~db (fn [~conn-binding] ~@body)))

(defn- cancelable-run-query
  "Runs JDBC query, canceling it if an InterruptedException is caught (e.g. if there query is canceled before
  finishing)."
  [db sql params opts]
  (with-ensured-connection [conn db]
    ;; This is normally done for us by java.jdbc as a result of our `jdbc/query` call
    (with-open [^PreparedStatement stmt (jdbc/prepare-statement conn sql opts)]
      ;; specifiy that we'd like this statement to close once its dependent result sets are closed
      ;; (Not all drivers support this so ignore Exceptions if they don't)
      (u/ignore-exceptions
        (.closeOnCompletion stmt))
      (try
        (jdbc/query conn (into [stmt] params) opts)
        (catch InterruptedException e
          (try
            (log/warn (tru "Client closed connection, canceling query"))
            ;; This is what does the real work of canceling the query. We aren't checking the result of
            ;; `query-future` but this will cause an exception to be thrown, saying the query has been cancelled.
            (.cancel stmt)
            (finally
              (throw e))))))))

(defn- run-query
  "Run the query itself."
  [driver {sql :query, :keys [params remark max-rows]}, ^TimeZone timezone, connection]
  (let [--sql              (str "-- " remark "\n" sql)
        [columns & rows] (cancelable-run-query
                          connection sql params
                          {:identifiers    identity
                           :as-arrays?     true
                           :read-columns   (sql-jdbc.execute/read-columns driver (some-> timezone Calendar/getInstance))
                           :set-parameters (set-parameters-with-timezone timezone)
                           :max-rows       max-rows})]
    {:rows    (or rows [])
     :columns (map u/qualified-name columns)}))

;;; -------------------------- Running queries: exception handling & disabling auto-commit ---------------------------

(defn- exception->nice-error-message ^String [^SQLException e]
  ;; error message comes back like 'Column "ZID" not found; SQL statement: ... [error-code]' sometimes
  ;; the user already knows the SQL, and error code is meaningless
  ;; so just return the part of the exception that is relevant
  (->> (.getMessage e)
       (re-find #"^(.*);")
       second))

(defn do-with-try-catch
  "Tries to run the function `f`, catching and printing exception chains if SQLException is thrown,
  and rethrowing the exception as an Exception with a nicely formatted error message."
  {:style/indent 0}
  [f]
  (try
    (f)
    (catch SQLException e
      (log/error (jdbc/print-sql-exception-chain e))
      (throw
       (if-let [nice-error-message (exception->nice-error-message e)]
         (Exception. nice-error-message e)
         e)))))

(defn- do-with-auto-commit-disabled
  "Disable auto-commit for this transaction, and make the transaction `rollback-only`, which means when the
  transaction finishes `.rollback` will be called instead of `.commit`. Furthermore, execute F in a try-finally block;
  in the `finally`, manually call `.rollback` just to be extra-double-sure JDBC any changes made by the transaction
  aren't committed."
  {:style/indent 1}
  [conn f]
  (jdbc/db-set-rollback-only! conn)
  (.setAutoCommit (jdbc/get-connection conn) false)
  ;; TODO - it would be nice if we could also `.setReadOnly` on the transaction as well, but that breaks setting the
  ;; timezone. Is there some way we can have our cake and eat it too?
  (try
    (f)
    (finally (.rollback (jdbc/get-connection conn)))))

(defn- do-in-transaction [connection f]
  (jdbc/with-db-transaction [transaction-connection connection]
    (do-with-auto-commit-disabled transaction-connection (partial f transaction-connection))))

;;; ---------------------------------------------- Running w/ Timezone -----------------------------------------------

(defn- set-timezone!
  "Set the timezone for the current connection."
  {:arglists '([driver settings connection])}
  [driver {:keys [report-timezone]} connection]
  (let [timezone      (u/prog1 report-timezone
                        (assert (re-matches #"[A-Za-z\/_]+" <>)))
        format-string (sql-jdbc.execute/set-timezone-sql driver)
        sql           (format format-string (str \' timezone \'))]
    (log/debug (u/format-color 'green (tru "Setting timezone with statement: {0}" sql)))
    (jdbc/db-do-prepared connection [sql])))

;; < STRATIO
;; helper funcions for the modification of the functions below
(defn- user-var-name []
  (let [details       (:details (qp.store/database))
        add-user-var? (:add-user-var details)
        var-name      (:user-var-name details)]
    (and add-user-var? var-name)))

(defn- current-user-name []
  (-> @api/*current-user*
      (get :email "")
      (str/replace (re-pattern (str dummy-email-domain "$")) "")
      not-empty))

(defn- set-user-var!
  "Set a custom varible in the connection with the current user executing the query"
  {:arglists '([connection])}
  [connection]
  (let [user     (current-user-name)
        var-name (user-var-name)
        sql      (str "SET " var-name "=" \' user \' ";")]
    (when (and user var-name)
      (log/debug (u/format-color 'green (tru "Setting variable containing current user with statement: {0}" sql)))
      (jdbc/db-do-prepared connection [sql]))))

;; These two funcions below are the only things in the copy/pasted code from sql-jdbc.execute that we change.
;; Basically we just add the set-user-var! call in the transaction
(defn- run-query-without-timezone [driver _ connection query]
  (log/debug "stratiopostgres.clj->run-query-without-timezone query:" query)
  (do-in-transaction connection (fn [transaction-connection]
                                  (set-user-var! transaction-connection)
                                  (run-query driver
                                             query
                                             nil
                                             transaction-connection))))

(defn- run-query-with-timezone [driver {:keys [^String report-timezone] :as settings} connection query]
  (try
    (do-in-transaction connection (fn [transaction-connection]
                                    (set-timezone! driver transaction-connection)
                                    (set-user-var! transaction-connection)
                                    (run-query driver
                                               query
                                               (some-> report-timezone TimeZone/getTimeZone)
                                               transaction-connection)))
    (catch SQLException e
      (log/error (tru "Failed to set timezone:") "\n" (with-out-str (jdbc/print-sql-exception-chain e)))
      (run-query-without-timezone driver settings connection query))
    (catch Throwable e
      (log/error (tru "Failed to set timezone:") "\n" (.getMessage e))
      (run-query-without-timezone driver settings connection query))))
;; STRATIO />

;;; ------------------------------------------------- execute-query --------------------------------------------------

(defn execute-query
  "Process and run a native (raw SQL) QUERY."
  [driver {settings :settings, query :native, :as outer-query}]

  (log/debug "stratiopostgres.clj->execute-query:" settings query outer-query)

  (let [query (assoc query
                :remark   (qputil/query->remark outer-query)
                :max-rows (or (mbql.u/query->max-rows-limit outer-query) qp.i/absolute-max-results))]
    (do-with-try-catch
     (fn []
       (let [db-connection (sql-jdbc.conn/db->pooled-connection-spec (qp.store/database))]
         ((if (seq (:report-timezone settings))
            run-query-with-timezone
            run-query-without-timezone) driver settings db-connection query))))))

;; finally we implement the execute-query method for our driver
(defmethod driver/execute-query :stratiopostgres [driver query]
  (execute-query driver query))
