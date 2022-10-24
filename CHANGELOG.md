# Changelog

## 0.43.4-0.1.1 (2022-10-24)

* [ROCK-8674] Sync correctly Administrators group

## 0.43.4-0.1.0 (2022-10-07)

* [ROCK-7390] Update metabase to 0.43
* [ROCK-6310] Forbid first_name editing but allow superusers to edit user details
* [ROCK-8431] [ROCK-8438] Fix security vulnerabilities of H2 embedded database (CVE-2022-23221)
* Fix: Resolve org.yaml:snakeyaml security vulnerabilities (GHSA-3mc7-4q67-w48m)

## 0.42.2-0.1.0 (2022-03-21)

* [ROCK-6000] Update metabase to 0.42
* Add admin group to whitelist

## Previous development

### Branched to branch-0.40.7-0.1 (2021-12-14)

* [ROCK-5578] Upgrade metabase to 0.40.7

### Branched to branch-0.40.5-0.1 (2021-11-22)

* [ROCK-5548] Upgrade metabase to 0.40.5

### Branched to branch-0.40.2-0.1 (2021-08-27)

* [ROCK-4939] Upgrade metabase to 0.40.2

### Branched to branch-0.38.1-0.2 (2021-07-09)

* [ROCK-NA] Fix: Do not try to auto-login in public api endpoints

### Branched to branch-0.38.1-0.2 (2021-06-15)

* [ROCK-4767] Fix: Allow emails as values of user header in auto-login
* [ROCK-4767] Fix: Automatic auto-login with expired sessions

### Branched to branch-0.38.1-0.2 (2021-05-13)

* [ROCK-4533] Dynamic var telling if request is for DB syncing.

### Branched to branch-0.38.1-0.1 (2021-04-28)

* Fix: autologin for uppercase usernames
* Fix: delete invalid session cookie with 401s

### Branched to branch-0.38.1-0.1 (2021-04-12)

* Fork based on Metabase 0.38.1
* Integration with Stratio Jenkins
* Auto-login via HTTP headers
* Handle empyt ResultSetMetadata
* Set response HTTP header with metabase username for external access log
* Remove vulnerabilities
