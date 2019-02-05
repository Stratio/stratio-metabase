@rest
Feature: Connection on Postgres

  Background: Initial setup
    Given I authenticate to DCOS cluster '${DCOS_IP}' using email '${DCOS_USER:-admin}' with user '${REMOTE_USER:-operador}' and pem file 'src/test/resources/credentials/${PEM_FILE:-key.pem}'
    And I open a ssh connection to '${DCOS_CLI_HOST}' with user '${CLI_USER:-root}' and password '${CLI_PASSWORD:-stratio}'
    And I securely send requests to '${DCOS_IP}:443'

  Scenario: [Connection Postgres][01] Obtain postgreSQL ip and port
    Given I send a 'GET' request to '/service/${POSTGRES_FRAMEWORK_ID_TLS:-postgrestls}/v1/service/status'
    Then the service response status must be '200'
    And I save element in position '0' in '$.status[?(@.role == "master")].dnsHostname' in environment variable 'postgresTLS_Host'
    And I save element in position '0' in '$.status[?(@.role == "master")].ports[0]' in environment variable 'postgresTLS_Port'
    And I wait '5' seconds

  @skipOnEnv(SKIP_DATABASE_CREATION)
  Scenario: [QATM-1866][Installation Discovery Command Center] Create database for Discovery on Postgres
    Given I set sso token using host '${CLUSTER_ID}.${CLUSTER_DOMAIN:-labs.stratio.com}' with user '${DCOS_USER:-admin}' and password '${DCOS_PASSWORD:-1234}' and tenant 'NONE'
    And I securely send requests to '${CLUSTER_ID}.${CLUSTER_DOMAIN:-labs.stratio.com}:443'
    Given I securely send requests to '${CLUSTER_ID}.${CLUSTER_DOMAIN:-labs.stratio.com}:443'
    When in less than '300' seconds, checking each '20' seconds, I send a 'GET' request to '/exhibitor/exhibitor/v1/explorer/node-data?key=%2Fdatastore%2Fcommunity%2F${POSTGRES_FRAMEWORK_ID_TLS:-postgrestls}%2Fplan-v2-json&_=' so that the response contains 'str'
    And the service response status must be '200'
    And I save element '$.str' in environment variable 'exhibitor_answer'
    And I save ''!{exhibitor_answer}'' in variable 'parsed_answer'
    And I run 'echo !{parsed_answer} | jq '.phases[0]' | jq '."0001".steps[0]'| jq '."0"'.agent_hostname | sed 's/^.\|.$//g'' locally with exit status '0' and save the value in environment variable 'pgIP'
    And I run 'echo !{pgIP}' locally
    Then I wait '10' seconds
    When in less than '300' seconds, checking each '20' seconds, I send a 'GET' request to '/service/${POSTGRES_FRAMEWORK_ID_TLS:-postgrestls}/v1/service/status' so that the response contains 'status'
    Then the service response status must be '200'
    And I save element in position '0' in '$.status[?(@.role == "master")].assignedHost' in environment variable 'pgIPCalico'
    And I save element in position '0' in '$.status[?(@.role == "master")].ports[0]' in environment variable 'pgPortCalico'
    Given I open a ssh connection to '!{pgIP}' with user '${CLI_USER:-root}' and password '${CLI_PASSWORD:-stratio}'
    When I run 'docker ps -q | xargs -n 1 docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}} {{ .Name }}' | sed 's/ \// /'| grep !{pgIPCalico} | awk '{print $2}'' in the ssh connection and save the value in environment variable 'postgresDocker'
    When I run 'docker exec -t !{postgresDocker} psql -p !{pgPortCalico} -U postgres -c "CREATE DATABASE ${DISCOVERY_DATA_DB:-pruebadiscovery}"' in the ssh connection
    Then the command output contains 'CREATE DATABASE'
    And I wait '60' seconds

  @skipOnEnv(SKIP_DATABASE_CREATION)
  Scenario: [QATM-1866][Installation Discovery Command Center] Create data for Discovery on Postgres
    Given I open a ssh connection to '!{pgIP}' with user '${CLI_USER:-root}' and password '${CLI_PASSWORD:-stratio}'
    And I outbound copy 'src/test/resources/schemas/createPGContent.sql' through a ssh connection to '/tmp'
    When I run 'docker cp /tmp/createPGContent.sql !{postgresDocker}:/tmp/ ; docker exec -t !{postgresDocker} psql -p !{pgPortCalico} -U "${DISCOVERY_TENANT_NAME:-crossdata-1}" -d ${DISCOVERY_DATA_DB:-pruebadiscovery} -f /tmp/createPGContent.sql | grep "INSERT 0 1" | wc -l' in the ssh connection
    Then the command output contains '254'

  @web
  Scenario: [Connection Postgres]Check Postgres database connection
    # Register postgres database
    Given My app is running in '${DISCOVERY_SERVICE_VHOST:-discovery.labs.stratio.com}:443'
    When I securely browse to '${DISCOVERY_DISCOVERY_PATH:-/discovery}'
    And I wait '3' seconds
    And '1' elements exists with 'xpath://input[@name="username"]'
    And I type '${USER:-demo@stratio.com}' on the element on index '0'
    And '1' elements exists with 'xpath://input[@name="password"]'
    And I type '${PASSWORD:-123456}' on the element on index '0'
    And '1' elements exists with 'xpath://*[@id="root"]/div/div/div/div[2]/form/div[4]/button'
    And I click on the element on index '0'
    And I wait '1' seconds
    Then I save selenium cookies in context
    When I securely send requests to '${DISCOVERY_SERVICE_VHOST:-discovery.labs.stratio.com}:443'
    Then in less than '5' seconds, checking each '1' seconds, I send a 'POST' request to '${DISCOVERY_DISCOVERY_PATH:-/discovery}${DISCOVERY_DATABASES:-/api/database}' so that the response contains '"name":"${DISCOVERY_DATABASE_PG_CONNECTION_NAME:-discovery}",' based on 'schemas/registerdatabase.json' as 'json' with:
      | $.engine                                        | UPDATE  | ${DISCOVERY_ENGINE_PG:-postgres}                                                                                                                                                        | string |
      | $.name                                          | UPDATE  | ${DISCOVERY_DATABASE_PG_CONNECTION_NAME:-discovery}                                                                                                                                     | string |
      | $.details.host                                  | UPDATE  | !{postgresTLS_Host}                                                                                                                                                                     | string |
      | $.details.port                                  | REPLACE | !{postgresTLS_Port}                                                                                                                                                                     | number |
      | $.details.dbname                                | UPDATE  | ${DISCOVERY_DATA_DB:-pruebadiscovery}                                                                                                                                                   | string |
      | $.details.user                                  | UPDATE  | ${DISCOVERY_TENANT_NAME:-crossdata-1}                                                                                                                                                   | string |
      | $.details.additional-options                    | UPDATE  | ssl=true&sslmode=verify-full&sslcert=/root/kms/${DISCOVERY_TENANT_NAME:-crossdata-1}.pem&sslkey=/root/kms/${DISCOVERY_TENANT_NAME:-crossdata-1}.pk8&sslrootcert=/root/kms/root.pem      | string |

    # Get postgres database id
    When I securely send requests to '${DISCOVERY_SERVICE_VHOST:-discovery.labs.stratio.com}:443'
    Then in less than '300' seconds, checking each '10' seconds, I send a 'GET' request to '${DISCOVERY_DISCOVERY_PATH:-/discovery}${DISCOVERY_DATABASES:-/api/database}' so that the response contains '"engine":"postgres"'
    Then the service response status must be '200'
    And I save element '$' in environment variable 'exhibitor_answer'
    And I save ''!{exhibitor_answer}'' in variable 'parsed_answer'
    And I run 'echo !{parsed_answer} | jq '.[] | select(.engine=="postgres") | .id'' locally and save the value in environment variable 'pgdatabaseId'
    When I securely send requests to '${DISCOVERY_SERVICE_VHOST:-discovery.labs.stratio.com}:443'
    Then in less than '300' seconds, checking each '10' seconds, I send a 'GET' request to '${DISCOVERY_DISCOVERY_PATH:-/discovery}${DISCOVERY_DATABASES:-/api/table}' so that the response contains '"engine":"postgres"'
    Then the service response status must be '200'
    And I save element '$' in environment variable 'tables_answer'
    And I save ''!{tables_answer}'' in variable 'parsed_answer'
    And I run 'echo !{parsed_answer} | jq '.[] | select(.name=="table_test_plan") | .id'' locally and save the value in environment variable 'pgtableId'

    # Check query postgres database
    When I securely send requests to '${DISCOVERY_SERVICE_VHOST:-discovery.labs.stratio.com}:443'
    Then in less than '5' seconds, checking each '1' seconds, I send a 'POST' request to '${DISCOVERY_DISCOVERY_PATH:-/discovery}${DISCOVERY_DATASET:-/api/dataset}' so that the response contains '200' based on 'schemas/dataset.json' as 'json' with:
      | $.database                 | REPLACE | !{pgdatabaseId}                         | number |
      | $.type                     | UPDATE  | ${DISCOVERY_TYPE_DATASET:-query}        | string |
      | $.query.source_table       | REPLACE | !{pgtableId}                            | number |
    And I wait '3' seconds
    And the service response must contain the text '"row_count":254,'

  Scenario: [QATM-1866][Uninstallation Discovery Command Center] Delete database for Discovery on Postgrestls
    Given I set sso token using host '${CLUSTER_ID:-nightly}.labs.stratio.com' with user '${DCOS_USER:-admin}' and password '${DCOS_PASSWORD:-1234}' and tenant 'NONE'
    And I securely send requests to '${CLUSTER_ID:-nightly}.labs.stratio.com:443'
    When in less than '300' seconds, checking each '20' seconds, I send a 'GET' request to '/exhibitor/exhibitor/v1/explorer/node-data?key=%2Fdatastore%2Fcommunity%2F${POSTGRES_FRAMEWORK_ID_TLS:-postgrestls}%2Fplan-v2-json&_=' so that the response contains 'str'
    And the service response status must be '200'
    And I save element '$.str' in environment variable 'exhibitor_answer'
    And I save ''!{exhibitor_answer}'' in variable 'parsed_answer'
    And I run 'echo !{parsed_answer} | jq '.phases[0]' | jq '."0001".steps[0]'| jq '."0"'.agent_hostname | sed 's/^.\|.$//g'' locally with exit status '0' and save the value in environment variable 'pgIP'
    And I run 'echo !{pgIP}' locally
    Then I wait '10' seconds
    When in less than '300' seconds, checking each '20' seconds, I send a 'GET' request to '/service/${POSTGRES_FRAMEWORK_ID_TLS:-postgrestls}/v1/service/status' so that the response contains 'status'
    Then the service response status must be '200'
    And I save element in position '0' in '$.status[?(@.role == "master")].assignedHost' in environment variable 'pgIPCalico'
    And I save element in position '0' in '$.status[?(@.role == "master")].ports[0]' in environment variable 'pgPortCalico'
    Given I open a ssh connection to '!{pgIP}' with user '${CLI_USER:-root}' and password '${CLI_PASSWORD:-stratio}'
    When I run 'docker ps -q | xargs -n 1 docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}} {{ .Name }}' | sed 's/ \// /'| grep !{pgIPCalico} | awk '{print $2}'' in the ssh connection and save the value in environment variable 'postgresDocker'
    When I run 'docker exec -t !{postgresDocker} psql -p !{pgPortCalico} -U postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${DISCOVERY_DATA_DB:-pruebadiscovery}'"' in the ssh connection
    When I run 'docker exec -t !{postgresDocker} psql -p !{pgPortCalico} -U postgres -c "DROP DATABASE ${DISCOVERY_DATA_DB:-pruebadiscovery}"' in the ssh connection
    Then the command output contains 'DROP DATABASE'
