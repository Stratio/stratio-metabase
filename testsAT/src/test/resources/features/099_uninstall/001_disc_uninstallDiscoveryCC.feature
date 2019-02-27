@rest
Feature: [QATM-1866][Uninstallation Discovery Command Center] Discovery uninstall with command center

  Scenario:[QATM-1866][01] Uninstall Discovery
    Given I authenticate to DCOS cluster '${DCOS_IP}' using email '${DCOS_USER:-admin}' with user '${REMOTE_USER:-operador}' and pem file '${BOOTSTRAP_PEM:-src/test/resources/credentials/key.pem}'
    And I securely send requests to '${CLUSTER_ID}.${CLUSTER_DOMAIN:-labs.stratio.com}:443'
    And I open a ssh connection to '${DCOS_CLI_HOST}' with user 'root' and password 'stratio'
    # Check if service_ID contains "/" character or subdirectories. Ex: /discovery/discovery
    Then I run 'echo ${SERVICE_ID:-/discovery/discovery/} | sed 's/^\/\(.*\)/\1/'' in the ssh connection and save the value in environment variable 'serviceName'
    When I send a 'DELETE' request to '/service/deploy-api/deploy/uninstall?app=!{serviceName}'
    # Check Uninstall in DCOS
    Then in less than '600' seconds, checking each '10' seconds, the command output 'dcos task | grep !{serviceName} | wc -l' contains '0'
    # Check Uninstall in CCT-API
    And in less than '200' seconds, checking each '10' seconds, I send a 'GET' request to '/service/deploy-api/deploy/status/all' so that the response does not contains '!{serviceName}'

  @skipOnEnv(SKIP_DATABASE_DELETION)
  Scenario:[QATM-1866][02] Delete database for Discovery on Postgrestls
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
    When I run 'docker exec -t !{postgresDocker} psql -p !{pgPortCalico} -U postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${DISCOVERY_DATASTORE_DB:-discovery}'"' in the ssh connection
    When I run 'docker exec -t !{postgresDocker} psql -p !{pgPortCalico} -U postgres -c "DROP DATABASE ${DISCOVERY_DATASTORE_DB:-discovery}"' in the ssh connection
    Then the command output contains 'DROP DATABASE'

  @skipOnEnv(SKIP_POLICY)
  Scenario:[QATM-1866][03] Delete policy user crossdata-1 in PG
    # Generate token to connect to gosec
    Given I set sso token using host '${GOSECMANAGEMENT_HOST}' with user '${DCOS_USER:-admin}' and password '${DCOS_PASSWORD:-1234}' and tenant 'NONE'
    And I securely send requests to '${GOSECMANAGEMENT_HOST}:443'
    # Obtain postgres plugin version
    When I send a 'GET' request to '/service/gosecmanagement/api/service'
    Then the service response status must be '200'
    And I save element '$.[?(@.type == "communitypostgres")].pluginList[*]' in environment variable 'POSTGRES_PLUGINS'
    And I run 'echo '!{POSTGRES_PLUGINS}' | jq '.[] | select (.instanceList[].name == "${POSTGRES_FRAMEWORK_ID_TLS:-postgrestls}").version'' locally and save the value in environment variable 'POSTGRES_PLUGIN_VERSION'
    # Update policy with no users, to avoid orphan reosurces
    When I send a 'PUT' request to '${BASE_END_POINT:-/service/gosecmanagement}/api/policy/${DISCOVERY_PG_POLICY_ID:-discovery_pg}' based on 'schemas/pg_policy.conf' as 'json' with:
      | $.id                                            | UPDATE  | ${DISCOVERY_PG_POLICY_ID:-discovery_pg}      | string |
      | $.name                                          | UPDATE  | ${DISCOVERY_PG_POLICY_NAME:-discovery_pg}    | string |
      | $.users                                         | REPLACE | []                                           | array  |
      | $.services[0].instancesAcl[0].instances[0].name | UPDATE  | ${POSTGRES_FRAMEWORK_ID_TLS:-postgrestls}    | string |
      | $.services[0].version                           | UPDATE  | !{POSTGRES_PLUGIN_VERSION}                   | string |
    Then the service response status must be '200'
    And I wait '120' seconds
    # Send request
    When I send a 'DELETE' request to '/service/gosecmanagement/api/policy/${DISCOVERY_PG_POLICY_ID:-discovery_pg}'
    Then the service response status must be '200'

  Scenario:[QATM-2100][04] Delete policy for user Crossdata-1 in XD
    Given I set sso token using host '${CLUSTER_ID}.${CLUSTER_DOMAIN:-labs.stratio.com}' with user '${DCOS_USER:-admin}' and password '${DCOS_PASSWORD:-1234}' and tenant 'NONE'
    And I securely send requests to '${CLUSTER_ID}.${CLUSTER_DOMAIN:-labs.stratio.com}:443'
    When I send a 'DELETE' request to '/service/gosecmanagement/api/policy/${DISCOVERY_XD_POLICY_ID:-discovery_xd}'
    Then the service response status must be '200'