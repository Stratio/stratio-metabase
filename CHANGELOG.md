# Changelog

## 0.39.3 (upcoming)

* [ROCK-3900] Make nginx timeout for discovery-cicd configurable

## 0.39.2 (November 20, 2020)
* [ROCK-3110] Limit download records via variable
* Bump import/export artifact version to 1.3.0-5ad831f (add timeout configuration and clean empty string descriptions in cards)


## 0.39.1 (November 04, 2020)

* Restoring impersonation in queries related to Crossdata databases and tables
* Bump import/export artifact version to 1.2.1-1570d16 (fix parentId query param)
* Fix vulnerabilities

## 0.39.0 (September 23, 2020)

* Make proxies timeout configurable
* Bump import/export artifact version to 1.2.0-e81eb29
* Improve fault tolerance on Crossdata driver describe-table
* Add custom postgres driver to set variable in query with the current logged user
* Bump nippy dependency version to 3.0.0

## 0.38.0-04ad956 (Built: May 28, 2020 | Released: May 28, 2020)

* Import/Export for collections
* Prometheus metrics
* Change HealthCheck path to /api/health

## 0.37.0-518ff9f (Built: April 06, 2020 | Released: April 07, 2020)

* Allow Pgbouncer connection
* Integrate with SSO Login

* Fix postgres connection through crossdata

## 0.36.0 (March 05, 2020)

* Fix vulnerabilities

## 0.35.1 (February 27, 2020)

* Fix use of variables in native questions

## 0.35.0 (February 19, 2020)

* Update Crossdata JDBC driver to 2.17.0-07b9b70 version
* [ROCK-345] Dashboard nested filters
* Logs in Datacentric standard format
* Avoid Discovery checks Crossdata connection each 3 mins
* [ROCK-459] Maintaining the compatibility with Datio descriptor in Stratio scripts about service
  instance (DISCOVERY_INSTANCE_NAME)
* Upgrade to Metabase 0.33.2
* New Crossdata driver as a plugin
* [ROCK-629] Add JWT authentication
* Fix: Revert too strict site-url validation
* [ROCK-1220] Audit log activity events

## 0.34.0-7f4b16c (Built: September 19, 2019 | Released: September 20, 2019)

* [ROCK-459] Fix error with Decimal types in Crossdata2 driver
* [ROCK-475] Fix "Discovery goes down while testing stability"
* [ROCK-475] Fix when Discovery showed only tables from default database.
* [ROCK-148] Multitenant
* Fix deleting databases connections using ELIMINAR word in spanish language
* [SS-5301] Personalize queries with filter returned error. Fixed in the Crossdata2 driver.
* Upgrade XD jdbc from 2.14.3 to 2.14.4
* [ROCK-37] Fix prepareThreshold=0 directly in code spec.clj

## 0.33.0-510a4de (Built: April 10, 2019 | Released: April 12, 2019)

* [ROCK-32] Upgrade XD library to 2.14.3
* [ROCK-30] Impersonation refactor

## 0.32.0-c757db3 (Built: January 14, 2019 | Released: January 16, 2019)

* [DGPB-1653] Crossdata queries impersonation
* [DGPB-1617] Upgrade XD library to 2.13.4

## 0.31.1 (November 13, 2018)

* [DGPB-1583] Fix init login function

## 0.31.0-ccddeec (Built: October 08, 2018 | Released: October 30, 2018)

* [DGPB-1426] Fix: Date aggregation query
* [DGPB-1357] Upgrade to metabase 0.30.1
* [DGPB-1345] Add more metadata refresh options

## 0.30.0-78eb83f (Built: June 27, 2018 | Released: July 13, 2018)

* [DGPB-1119] Upgrade to metabase 0.29.4

## 0.29.0-d524010 (Built: May 24, 2018 | Released: June 04, 2018)

* [DGPB-1171] Add Armadillo admin logic for User auto-creation
* [DGPB-1130] Versioning improvement
* [DGPB-1029] Crossdata driver upgrade: 2.8.0 ? 2.11.1
* [DGPB-1028] Automatic login for existing Armadillo group id
* [DGPB-999] Discovery: connect with Postgres TLS
* [DGPB-983] Add Discovery in PaaS Universe
* [DGPB-868] Securize Stratio Discovery with Dynamic Authentication
* [DGPB-867] Virtual networks with Calico
* [DGPB-865] Integration with Jenkins
* [DGPB-864] Metabase version upgrade: 0.24.0 ? 0.27.2
* Armadillo integration for user login
