@mandatory @vars(BOOTSTRAP_IP,REMOTE_USER,PEM_FILE_PATH,DCOS_PASSWORD,UNIVERSE_VERSION,DCOS_TENANT)
@rest @dcos
Feature: Postgres Conexion with Discovery

  @include(feature:../templates/Discovery_Templates_Compatible.feature,scenario: Get Discovery URL)
  Scenario: Get Discovery URL

  @include(feature:../templates/Discovery_Templates_Compatible.feature,scenario: Get Postgres IP)
  Scenario: Get Postgres IP

  @skipOnEnv(SKIP_DISCOVERY_DATASET_CREATION)
  Scenario: Create data for Discovery on Postgres
    Given I open a ssh connection to '!{pgIP}' with user '!{CLUSTER_SSH_USER}' using pem file '!{CLUSTER_SSH_PEM_PATH}'
    And I outbound copy 'src/test/resources/schemas/createPGContent.sql' through a ssh connection to '/tmp'
    When I run 'sudo docker cp /tmp/createPGContent.sql !{pgContainerName}:/tmp/ ; sudo docker exec -t !{pgContainerName} psql -p 5432 -U "${DISCOVERY_ID:-discovery-qa}" -d ${DISCOVERY_METADATA_DB_NAME:-discovery} -c "CREATE SCHEMA IF NOT EXISTS \"discoveryqa\";"' in the ssh connection
    And I run 'sudo docker cp /tmp/createPGContent.sql !{pgContainerName}:/tmp/ ; sudo docker exec -t !{pgContainerName} psql -p 5432 -U "${DISCOVERY_ID:-discovery-qa}" -d ${DISCOVERY_METADATA_DB_NAME:-discovery} -f /tmp/createPGContent.sql | grep "INSERT 0 1" | wc -l' in the ssh connection
    Then the command output contains '254'

  Scenario: Create Postgres database connection and check datas
    Given I set sso discovery token using host '!{DISCOVERY_HOST}/${DISCOVERY_ID:-discovery-qa}/auth' with user '${DCOS_USER}' and password '${DCOS_PASSWORD}' and tenant '${DCOS_TENANT}' without host name verification with cookie name '${DISCOVERY_ID:-discovery-qa}-auth-cookie'
    Given I obtain metabase id for user '${USER:-demo@stratio.com}' and password '${PASSWORD:-123456}' in endpoint 'https://!{DISCOVERY_HOST}/${DISCOVERY_ID:-discovery-qa}${DISCOVERY_SESSION:-/api/session}' and save in context cookies
    And I securely send requests to '!{DISCOVERY_HOST}:443'
    Then in less than '200' seconds, checking each '5' seconds, I send a 'POST' request to '/${DISCOVERY_ID:-discovery-qa}${DISCOVERY_DATABASES:-/api/database}' so that the response contains '"name":"${DISCOVERY_DATABASE_PG_CONNECTION_NAME:-discovery}",' based on 'schemas/registerdatabase.json' as 'json' with:
      | $.engine                                        | UPDATE  | ${DISCOVERY_ENGINE_PG:-postgres}                                                                                                                                                        | string |
      | $.name                                          | UPDATE  | ${DISCOVERY_DATABASE_PG_CONNECTION_NAME:-discovery}                                                                                                                                     | string |
      | $.details.host                                  | UPDATE  | pg-0001.${DISCOVERY_POSTGRES_NAME:-postgrestls}.mesos                                                                                                                                                                  | string |
      | $.details.port                                  | REPLACE | ${DISCOVERY_POSTGRES_PORT:-5432}                                                                                                                                                                    | number |
      | $.details.dbname                                | UPDATE  | ${DISCOVERY_METADATA_DB_NAME:-discovery}                                                                                                                                                   | string |
      | $.details.user                                  | UPDATE  | ${DISCOVERY_ID:-discovery-qa}                                                                                                                                                   | string |
      | $.details.additional-options                    | UPDATE  | ssl=true&sslmode=verify-full&sslcert=/root/kms/${DISCOVERY_ID:-discovery-qa}.pem&sslkey=/root/kms/${DISCOVERY_ID:-discovery-qa}.pk8&sslrootcert=/root/kms/root.pem      | string |
    Then the service response status must be '200'
#     Get postgres database id
    When I securely send requests to '!{DISCOVERY_HOST}:443'
    When I send a 'GET' request to '/${DISCOVERY_ID:-discovery-qa}/api/database'
    Then the service response status must be '200'
    And I save element '$' in environment variable 'answer'
    And I run 'echo '!{answer}' | jq '.[] | select(.name=="${DISCOVERY_DATABASE_PG_CONNECTION_NAME:-discovery}") | .id'' locally and save the value in environment variable 'pgdatabaseId'
    When I securely send requests to '!{DISCOVERY_HOST}:443'
    Then in less than '300' seconds, checking each '10' seconds, I send a 'GET' request to '/${DISCOVERY_ID:-discovery-qa}/api/table' so that the response contains '"name":"table_test_plan"'
    Then the service response status must be '200'
    And I save element '$' in environment variable 'tables_answer'
    And I save ''!{tables_answer}'' in variable 'parsed_answer'
    And I run 'echo !{parsed_answer} | jq '.[] | select(.name=="table_test_plan") | .id'' locally and save the value in environment variable 'pgtableId'

    # Check query postgres database
    When I securely send requests to '!{DISCOVERY_HOST}:443'
    Then in less than '5' seconds, checking each '1' seconds, I send a 'POST' request to '/${DISCOVERY_ID:-discovery-qa}/api/dataset' so that the response contains '200' based on 'schemas/dataset.json' as 'json' with:
      | $.database                 | REPLACE | !{pgdatabaseId}                         | number |
      | $.type                     | UPDATE  | ${DISCOVERY_TYPE_DATASET:-query}        | string |
      | $.query.source_table       | REPLACE | !{pgtableId}                            | number |
#    And I wait '3' seconds
    And the service response must contain the text '"row_count":254,'

  @skipOnEnv(DISCOVERY_SKIP_UNINSTALL=yes)
  Scenario: Delete postgres Conexion with Discovery
     #It's necessary wait to reconect and to avoid error "Too many attempts! You must wait 30 seconds before trying again."}}
    And I wait '${DISCOVERY_WAIT_FOR_RECONNECT:-30}' seconds
    Given I set sso discovery token using host '!{DISCOVERY_HOST}/${DISCOVERY_ID:-discovery-qa}/auth' with user '${DCOS_USER}' and password '${DCOS_PASSWORD}' and tenant '${DCOS_TENANT}' without host name verification with cookie name '${DISCOVERY_ID:-discovery-qa}-auth-cookie'
    Given I obtain metabase id for user '${USER:-demo@stratio.com}' and password '${PASSWORD:-123456}' in endpoint 'https://!{DISCOVERY_HOST}/${DISCOVERY_ID:-discovery-qa}${DISCOVERY_SESSION:-/api/session}' and save in context cookies
    When I securely send requests to '!{DISCOVERY_HOST}:443'
    And I send a 'DELETE' request to '/${DISCOVERY_ID:-discovery-qa}/api/database/!{pgdatabaseId}'
    Then the service response status must be '204'

  @skipOnEnv(DISCOVERY_SKIP_UNINSTALL=yes)
  Scenario: Delete database for Discovery on Postgrestls
    Given I open a ssh connection to '!{pgIP}' with user '!{CLUSTER_SSH_USER}' using pem file '!{CLUSTER_SSH_PEM_PATH}'
    When I run 'sudo docker exec -t !{pgContainerName} psql -p 5432 -U "${DISCOVERY_ID:-discovery-qa}" -d ${DISCOVERY_METADATA_DB_NAME:-discovery} -c "DROP SCHEMA \"discoveryqa\" CASCADE;"' in the ssh connection
    Then the command output contains 'DROP SCHEMA'

