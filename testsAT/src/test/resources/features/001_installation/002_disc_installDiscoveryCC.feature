@rest
Feature: [QATM-1866][Installation Discovery Command Center] Discovery install with command center

  Scenario:[QATM-1866][01][Setup] Check Postgres is installed
    Given I authenticate to DCOS cluster '${DCOS_IP}' using email '${DCOS_USER:-admin}' with user '${REMOTE_USER:-operador}' and pem file '${BOOTSTRAP_PEM:-src/test/resources/credentials/key.pem}'
    And I securely send requests to '${CLUSTER_ID}.${CLUSTER_DOMAIN:-labs.stratio.com}:443'
    Then in less than '100' seconds, checking each '10' seconds, I send a 'GET' request to '/service/deploy-api/deploy/status/all' so that the response contains '${DISC_POSTGRES_FRAMEWORK_ID_TLS:-postgrestls}'
    And in less than '100' seconds, checking each '10' seconds, I send a 'GET' request to '/service/deploy-api/deploy/status/service?service=/${DISC_POSTGRES_FRAMEWORK_ID_TLS:-postgrestls}' so that the response contains '"healthy":1'
    Then in less than '100' seconds, checking each '5' seconds, I send a 'GET' request to '/service/${DISC_POSTGRES_FRAMEWORK_ID_TLS:-postgrestls}/v1/service/status' so that the response contains '"pg-0001","role":"master","status":"RUNNING"'
    And in less than '100' seconds, checking each '5' seconds, I send a 'GET' request to '/service/${DISC_POSTGRES_FRAMEWORK_ID_TLS:-postgrestls}/v1/service/status' so that the response contains '"pg-0002","role":"sync_slave","status":"RUNNING"'
    And in less than '100' seconds, checking each '5' seconds, I send a 'GET' request to '/service/${DISC_POSTGRES_FRAMEWORK_ID_TLS:-postgrestls}/v1/service/status' so that the response contains '"pg-0003","role":"async_slave","status":"RUNNING"'

  Scenario:[QATM-2100][02][Setup] Create policy file for user Crossdata-1 in XD
    Given I create file 'xd_xd.json' based on 'schemas/xd_policy.json' as 'json' with:
      | $.id       | UPDATE | ${DISCOVERY_XD_POLICY_ID:-discovery_xd}         | n/a |
      | $.name     | UPDATE | ${DISCOVERY_XD_POLICY_NAME:-discovery_xd}       | n/a |
      | $.users[0] | UPDATE | ${DISCOVERY_XD_POLICY_USER:-crossdata-1}        | n/a |

  @runOnEnv(STRATIO_GOSEC_MANAGEMENT_VERSION=1.0.0||STRATIO_GOSEC_MANAGEMENT_VERSION>1.0.0)
  Scenario:[QATM-2100][02b]][Setup] Add version to policy file for user Crossdata-1 in XD
    Given I run 'dcos marathon task list | grep ${CROSSDATA_ID:-crossdata-1} | awk '{print $4}' | tail -1' in the ssh connection and save the value in environment variable 'crossdata1-IP'
    Then I open a ssh connection to '!{crossdata1-IP}' with user 'root' and password 'stratio'
    And I run 'docker ps | grep crossdata | awk '{print $1}'' in the ssh connection and save the value in environment variable 'crossdataDocker'
    And I run 'docker exec -t !{crossdataDocker} ls -l /opt/sds/crossdata/plugins | awk '{print $9}' | grep ${CROSSDATA_GOSEC_VERSION:-0.15} | sed 's/.*crossdata-//g' | sed 's/.jar//g'' in the ssh connection and save the value in environment variable 'xd-plugin-version'
    Given I create file 'xd_xd.json' based on 'xd_xd.json' as 'json' with:
      | $.services[0].version | ADD | !{xd-plugin-version} | string |

  Scenario:[QATM-2100][03][Setup] Create policy for user Crossdata-1 in XD
    Given I set sso token using host '${CLUSTER_ID}.${CLUSTER_DOMAIN:-labs.stratio.com}' with user '${DCOS_USER:-admin}' and password '${DCOS_PASSWORD:-1234}' and tenant 'NONE'
    And I securely send requests to '${CLUSTER_ID}.${CLUSTER_DOMAIN:-labs.stratio.com}:443'
    When I send a 'POST' request to '${BASE_END_POINT:-/service/gosecmanagement}/api/policy' based on 'xd_xd.json' as 'json' with:
      | $.id       | UPDATE | ${DISCOVERY_XD_POLICY_ID:-discovery_xd}         | n/a |
      | $.name     | UPDATE | ${DISCOVERY_XD_POLICY_NAME:-discovery_xd}       | n/a |
      | $.users[0] | UPDATE | ${DISCOVERY_XD_POLICY_USER:-crossdata-1}        | n/a |
    Then the service response status must be '201'
    And the service response must contain the text '"id":"${DISCOVERY_XD_POLICY_ID:-discovery_xd}"'
    Then I wait '5' seconds
    When I send a 'GET' request to '${BASE_END_POINT:-/service/gosecmanagement}/api/policy/${DISCOVERY_XD_POLICY_ID:-discovery_xd}'
    Then the service response status must be '200'
    And I wait '70' seconds

  @skipOnEnv(SKIP_DATABASE_CREATION)
  Scenario:[QATM-1866][04] Create database for Discovery on Postgres
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
    When I run 'docker exec -t !{postgresDocker} psql -p !{pgPortCalico} -U postgres -c "CREATE DATABASE ${DISCOVERY_DATASTORE_DB:-discovery}"' in the ssh connection
    Then the command output contains 'CREATE DATABASE'

  @skipOnEnv(SKIP_POLICY)
  Scenario:[QATM-1866][05] Creation policy for user crossdata-1
    # Generate token to connect to gosec
    Given I set sso token using host '${GOSECMANAGEMENT_HOST}' with user 'admin' and password '1234' and tenant 'NONE'
    And I securely send requests to '${GOSECMANAGEMENT_HOST}:443'
    # Obtain postgres plugin version
    When I send a 'GET' request to '${BASE_END_POINT:-/service/gosecmanagement}/api/service'
    Then the service response status must be '200'
    And I save element '$.[?(@.type == "communitypostgres")].pluginList[*]' in environment variable 'POSTGRES_PLUGINS'
    And I run 'echo '!{POSTGRES_PLUGINS}' | jq '.[] | select (.instanceList[].name == "${POSTGRES_FRAMEWORK_ID_TLS:-postgrestls}").version'' locally and save the value in environment variable 'POSTGRES_PLUGIN_VERSION'
    # Create policy
    When I send a 'POST' request to '${BASE_END_POINT:-/service/gosecmanagement}/api/policy' based on 'schemas/pg_policy.conf' as 'json' with:
      | $.id                                            | UPDATE  | ${DISCOVERY_PG_POLICY_ID:-discovery_pg}         | string |
      | $.name                                          | UPDATE  | ${DISCOVERY_PG_POLICY_NAME:-discovery_pg}       | string |
      | $.users                                         | REPLACE | [crossdata-1]                                   | array  |
      | $.services[0].instancesAcl[0].instances[0].name | UPDATE  | ${POSTGRES_FRAMEWORK_ID_TLS:-postgrestls}       | string |
      | $.services[0].version                           | UPDATE  | !{POSTGRES_PLUGIN_VERSION}                      | string |
    Then the service response status must be '201' and its response must contain the text '"id":"${DISCOVERY_PG_POLICY_ID:-discovery_pg}"'
    And I wait '70' seconds

  Scenario:[QATM-1866][06] Basic install
    Given I authenticate to DCOS cluster '${DCOS_IP}' using email '${DCOS_USER:-admin}' with user '${REMOTE_USER:-operador}' and pem file '${BOOTSTRAP_PEM:-src/test/resources/credentials/key.pem}'
    And I securely send requests to '${CLUSTER_ID}.${CLUSTER_DOMAIN:-labs.stratio.com}:443'
    # Obtain schema
    When I send a 'GET' request to '/service/deploy-api/deploy/discovery/${DISC_FLAVOUR:-hydra}/schema?level=1'
    Then I save element '$' in environment variable 'discovery-json-schema'
    And I run 'echo !{discovery-json-schema}' locally
    # Convert to jsonSchema
    And I convert jsonSchema '!{discovery-json-schema}' to json and save it in variable 'discovery-basic.json'
    And I run 'echo '!{discovery-basic.json}' > target/test-classes/schemas/discovery-basic.json' locally
    # Launch basic install
    When I send a 'POST' request to '/service/deploy-api/deploy/discovery/${DISC_FLAVOUR:-hydra}/schema' based on 'schemas/discovery-basic.json' as 'json' with:
      | $.general.serviceId                         | REPLACE | ${SERVICE_ID:-/discovery/discovery}                         | string |
      | $.general.marathonlb.haproxyhost            | REPLACE | ${DISCOVERY_SERVICE_VHOST:-discovery.labs.stratio.com}      | string |
      | $.general.marathonlb.haproxypath            | REPLACE | ${MARATHONLB_HA_PROXY_PATH:-/discovery}                     | string |
      | $.general.datastore.metadataDbInstanceName  | REPLACE | ${DISC_POSTGRES_FRAMEWORK_ID_TLS:-postgrestls}              | string |
      | $.general.datastore.metadataDbName          | REPLACE | ${DISCOVERY_METADATA_DB_NAME:-discovery}                    | string |
      | $.general.datastore.tenantName              | REPLACE | ${DISCOVERY_TENANT_NAME:-crossdata-1}                       | string |
      | $.general.datastore.metadataDbHost          | REPLACE | ${DISCOVERY_METADATA_DB_HOST:-pg-0001.postgrestls.mesos}    | string |
      | $.general.calico.networkName                | REPLACE | ${DISCOVERY_NETWORK_NAME:-stratio}                          | string |
      | $.general.resources.instances               | REPLACE | ${DISCOVERY_SERVICE_INSTANCES:-1}                           | number |
      | $.general.resources.cpus                    | REPLACE | ${DISCOVERY_SERVICE_CPUS:-1}                                | number |
      | $.general.resources.mem                     | REPLACE | ${DISCOVERY_SERVICE_MEM:-2048}                              | number |
      | $.general.identity.approlename              | REPLACE | ${APPROLENAME:-open}                                        | string |
# Comentamos variables ya que no disponemos de valores válidos
#       | $.settings.Login                            | ADD     | {}                                            | object  |
#       | $.settings.Login.mb-user-header             | ADD     | ${MB_USER_HEADER:- "fdsa"}                    | string  |
#       | $.settings.Login.mb-admin-group-header      | ADD     | ${MB_ADMIN_GROUP_HEADER:-"4e32" }             | string  |
#       | $.settings.Login.mb-group-header            | ADD     | ${MB_GROUP_HEADER:-"433" }                    | string  |
#       | $.general.identity.approlename              | UPDATE  | ${DISCOVERY_SECURITY_INSTANCE_APP_ROLE:-open} | n/a     |
    Then the service response status must be '202'
    And I run 'rm -f target/test-classes/schemas/discovery-basic.json' locally

  Scenario:[QATM-1866][07] Check status
    Given I authenticate to DCOS cluster '${DCOS_IP}' using email '${DCOS_USER:-admin}' with user '${REMOTE_USER:-operador}' and pem file '${BOOTSTRAP_PEM:-src/test/resources/credentials/key.pem}'
    And I securely send requests to '${CLUSTER_ID}.${CLUSTER_DOMAIN:-labs.stratio.com}:443'
    # Check Application in API
    Then in less than '200' seconds, checking each '10' seconds, I send a 'GET' request to '/service/deploy-api/deploy/status/all' so that the response contains '${SERVICE_ID:-/discovery/discovery}'
    # Check status in API
    And in less than '200' seconds, checking each '10' seconds, I send a 'GET' request to '/service/deploy-api/deploy/status/service?service=${SERVICE_ID:-/discovery/discovery}' so that the response contains '"healthy":1'
    # Check status in DCOS
    # Checking if service_ID contains "/" character or subdirectories. Ex: /discovery/discovery
    When I open a ssh connection to '${DCOS_CLI_HOST}' with user 'root' and password 'stratio'
    Then I run 'echo ${SERVICE_ID:-/discovery/discovery} | sed 's/\//./g' |  sed 's/^\.\(.*\)/\1/'' locally and save the value in environment variable 'serviceIDDcosTaskPath'
    And in less than '500' seconds, checking each '20' seconds, the command output 'dcos task | grep !{serviceIDDcosTaskPath} | grep R | wc -l' contains '1'
    When I run 'dcos task |  awk '{print $5}' | grep !{serviceIDDcosTaskPath}' in the ssh connection and save the value in environment variable 'dicoveryTaskId'
    Then in less than '10' seconds, checking each '10' seconds, the command output 'dcos marathon task show !{dicoveryTaskId} | grep TASK_RUNNING |wc -l' contains '1'
    And in less than '10' seconds, checking each '10' seconds, the command output 'dcos marathon task show !{dicoveryTaskId} | grep '"alive": true |wc -l' contains '1'

  Scenario:[QATM-1866][08] Check Discovery frontend
    Given I securely send requests to '${DISCOVERY_SERVICE_VHOST:-discovery.labs.stratio.com}'
    And in less than '600' seconds, checking each '100' seconds, I send a 'GET' request to '${DISCOVERY_DISCOVERY_PATH:-/discovery}' so that the response contains 'Metabase'
    Then the service response status must be '200'

#  @web
#  Scenario:[QATM-1866][09] Check Discovery frontend
#    Given My app is running in '${DISCOVERY_SERVICE_VHOST:-discovery.labs.stratio.com}:443'
#    When I securely browse to '${DISCOVERY_DISCOVERY_PATH:-/discovery}'
#    And in less than '300' seconds, checking each '10' seconds, '1' elements exists with 'xpath://input[@name="username"]'
#    And in less than '300' seconds, checking each '10' seconds, '1' elements exists with 'xpath://input[@name="password"]'
