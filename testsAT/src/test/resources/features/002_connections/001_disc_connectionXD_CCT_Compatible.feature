@rest @dcos
Feature: Crossdata Conexion with Discovery

  @include(feature:../templates/Discovery_Templates_Compatible.feature,scenario: Get Discovery URL)
  Scenario: Get Discovery URL

  Scenario: [01] Add Crossdata Policy

    And I securely send requests to '!{EOS_ACCESS_POINT}:443'
    Given I get version of service 'crossdata' with id '\/${DISCOVERY_XD_SERVICE_NAME:-crossdata-1}' in tenant '${DCOS_TENANT}' with tenant user and tenant password '${DCOS_USER}:${DCOS_PASSWORD}' and save it in environment variable 'crossdata_plugin_version'
    And I run 'echo crossdata plugin !{crossdata_plugin_version}' locally
    Given I create 'policy' '${DISCOVERY_XD_SERVICE_NAME:-crossdata-1}-${DISCOVERY_ID:-discovery-qa}' in tenant ${DCOS_TENANT}' if it does not exist based on 'schemas/crossdata_policy_compatible.json' as 'json' with:
      | $.id                                 | UPDATE  | ${DISCOVERY_XD_SERVICE_NAME:-crossdata-1}-${DISCOVERY_ID:-discovery-qa}    | string  |
      | $.name                                 | UPDATE  | ${DISCOVERY_XD_SERVICE_NAME:-crossdata-1}-${DISCOVERY_ID:-discovery-qa}    | string  |
      | $.users                                | REPLACE | [${DISCOVERY_XD_SERVICE_NAME:-crossdata-1}]       | array   |
      | $.services[0].instancesAcl[0].instances[0].name | UPDATE  | ${DISCOVERY_XD_SERVICE_NAME:-crossdata-1} | n/a     |

  Scenario: [02] Create Crossdata Database Connection for Discovery
    # Register Crossdata database
    Given I set sso discovery token using host '!{DISCOVERY_HOST}/${DISCOVERY_ID:-discovery-qa}/auth' with user '${DCOS_USER}' and password '${DCOS_PASSWORD}' and tenant '${DCOS_TENANT}' without host name verification with cookie name '${DISCOVERY_ID:-discovery-qa}-auth-cookie'
    Given I obtain metabase id for user '${USER:-demo@stratio.com}' and password '${PASSWORD:-123456}' in endpoint 'https://!{DISCOVERY_HOST}/${DISCOVERY_ID:-discovery-qa}${DISCOVERY_SESSION:-/api/session}' and save in context cookies
    When I securely send requests to '!{DISCOVERY_HOST}:443'
    When I send a 'POST' request to '/${DISCOVERY_ID:-discovery-qa}/api/database' based on 'schemas/registerdatabase_crossdata.json' as 'json' with:
      | $.engine                     | UPDATE  | ${DISCOVERY_ENGINE_XD:-crossdata}                                           | string |
      | $.name                       | UPDATE  | ${DISCOVERY_DATABASE_XD_CONNECTION_NAME:-crossdata}                         | string |
      | $.details.host               | UPDATE  | ${DISCOVERY_XD_SERVICE_NAME:-crossdata-1}.marathon.mesos | string |
      | $.details.port               | REPLACE | ${DISCOVERY_XD_PORT:-8000}                                                  | number |
      | $.details.dbname             | UPDATE  | crossdatabla                                                                | string |
      | $.details.user               | UPDATE  | ${DISCOVERY_XD_SERVICE_NAME:-crossdata-1}                                | string |
      | $.details.additional-options | DELETE  |                                                                             | string |
      | $.details.tunnel-port        | DELETE  |                                                                             | string |
    Then the service response status must be '200'
    #Get Crossdata Database ID
    When I securely send requests to '!{DISCOVERY_HOST}:443'
    When I send a 'GET' request to '/${DISCOVERY_ID:-discovery-qa}/api/database'
    And I save element '$' in environment variable 'answer'
    And I run 'echo '!{answer}' | jq '.[] | select(.name=="${DISCOVERY_DATABASE_XD_CONNECTION_NAME:-crossdata}") | .id'' locally and save the value in environment variable 'crossdatadatabaseId'
    #Create tables for Crossdata-Database with Discovery
    When I securely send requests to '!{DISCOVERY_HOST}:443'
    When I send a 'POST' request to '/${DISCOVERY_ID:-discovery-qa}/api/dataset' based on 'schemas/query.json' as 'json' with:
      | $.native.query | UPDATE  | CREATE TABLE IF NOT EXISTS discovery_crossdata_table(id INT, name STRING) | string |
      | $.database     | REPLACE | !{crossdatadatabaseId}                                                    | number |

    Then the service response status must be '200'
    When I send a 'POST' request to '/${DISCOVERY_ID:-discovery-qa}/api/dataset' based on 'schemas/query.json' as 'json' with:
      | $.native.query | UPDATE  | INSERT INTO discovery_crossdata_table VALUES(1, 'test1') | string |
      | $.database     | REPLACE | !{crossdatadatabaseId}                                   | number |

    When I send a 'POST' request to '/${DISCOVERY_ID:-discovery-qa}/api/dataset' based on 'schemas/query.json' as 'json' with:
      | $.native.query | UPDATE  | select count(*) from discovery_crossdata_table | string |
      | $.database     | REPLACE | !{crossdatadatabaseId}                         | number |
    Then the service response status must be '200'
    And the service response must contain the text '"rows":[[1]]'

  @skipOnEnv(DISCOVERY_SKIP_UNINSTALL=yes)
  Scenario: [03] Delete Crossdata Conexion with Discovery
     #It's necessary wait to reconect and to avoid error "Too many attempts! You must wait 30 seconds before trying again."}}
    And I wait '${DISCOVERY_WAIT_FOR_RECONNECT:-30}' seconds
    Given I set sso discovery token using host '!{DISCOVERY_HOST}/${DISCOVERY_ID:-discovery-qa}/auth' with user '${DCOS_USER}' and password '${DCOS_PASSWORD}' and tenant '${DCOS_TENANT}' without host name verification with cookie name '${DISCOVERY_ID:-discovery-qa}-auth-cookie'
    Given I obtain metabase id for user '${USER:-demo@stratio.com}' and password '${PASSWORD:-123456}' in endpoint 'https://!{DISCOVERY_HOST}/${DISCOVERY_ID:-discovery-qa}${DISCOVERY_SESSION:-/api/session}' and save in context cookies
    When I securely send requests to '!{DISCOVERY_HOST}:443'
    When I send a 'POST' request to '/${DISCOVERY_ID:-discovery-qa}/api/dataset' based on 'schemas/query.json' as 'json' with:
      | $.native.query | UPDATE  | drop table discovery_crossdata_table | string |
      | $.database     | REPLACE | !{crossdatadatabaseId}               | number |
    Then the service response status must be '200'
    When I securely send requests to '!{DISCOVERY_HOST}:443'
    And I send a 'DELETE' request to '/${DISCOVERY_ID:-discovery-qa}/api/database/!{crossdatadatabaseId}'
    Then the service response status must be '204'

  @skipOnEnv(DISCOVERY_SKIP_UNINSTALL=yes)
  Scenario: [04] Delete Rocket policy
    Given I delete 'policy' '${DISCOVERY_XD_SERVICE_NAME:-crossdata-1}-${DISCOVERY_ID:-discovery-qa}' from tenant '${DCOS_TENANT}' with tenant user and tenant password '${DCOS_USER}:${DCOS_PASSWORD}' if it exists

