@rest
Feature: [QATM-1866][Installation Discovery Command Center] Discovery install with command center

  @skipOnEnv(ADVANCED_INSTALL)
  Scenario: [QATM-1866][Installation Discovery Command Center] - [1] - Basic install
    Given I authenticate to DCOS cluster '${DCOS_IP}' using email '${DCOS_USER:-admin}' with user '${REMOTE_USER:-operador}' and pem file 'src/test/resources/credentials/${PEM_FILE:-key.pem}'
    And I securely send requests to '${CLUSTER_ID}.${CLUSTER_DOMAIN:-labs.stratio.com}:443'
    # Obtain schema
    When I send a 'GET' request to '/service/deploy-api/deploy/discovery/${FLAVOUR}/schema?level=1'
    Then I save element '$' in environment variable 'discovery-json-schema'
    And I run 'echo !{discovery-json-schema}' locally
    # Convert to jsonSchema
    And I convert jsonSchema '!{discovery-json-schema}' to json and save it in variable 'discovery-basic.json'
    And I run 'echo '!{discovery-basic.json}' > target/test-classes/schemas/discovery-basic.json' locally

    # Launch basic install
    When I send a 'POST' request to '/service/deploy-api/deploy/discovery/${FLAVOUR}/schema' based on 'schemas/discovery-basic.json' as 'json' with:
       | $.general.datastore.metadataDbHost          |  UPDATE | ${DISCOVERY_METADATA_DB_HOST:-pg-0001.postgrestls.mesos}      | n/a     |
       | $.general.datastore.tenantName              |  UPDATE | ${DISCOVERY_TENANT_NAME:-crossdata-1}                         | n/a     |
       | $.general.calico.networkName                |  UPDATE | ${CALICO_NETWORK_NAME:-stratio}                               | n/a     |
       | $.settings.Login.mb-user-header             | DELETE  | {}              | string  |
       | $.settings.Login.mb-admin-group-header      | DELETE  | {}              | string  |
       | $.settings.Login.mb-group-header            | DELETE  | {}              | string  |

    Then the service response status must be '202'
    And I run 'rm -f target/test-classes/schemas/discovery-basic.json' locally


  @runOnEnv(ADVANCED_INSTALL)
  Scenario: [QATM-1866][Installation Discovery Command Center] - [1] - Advanced install
    Given I authenticate to DCOS cluster '${DCOS_IP}' using email '${DCOS_USER:-admin}' with user '${REMOTE_USER:-operador}' and pem file 'src/test/resources/credentials/${PEM_FILE:-key.pem}'
    And I securely send requests to '${CLUSTER_ID}.${CLUSTER_DOMAIN:-labs.stratio.com}:443'
    # Obtain schema
    When I send a 'GET' request to '/service/deploy-api/deploy/discovery/${FLAVOUR}/schema?level=1'
    Then I save element '$' in environment variable 'discovery-json-schema'
    And I run 'echo !{discovery-json-schema}' locally
    # Convert to jsonSchema
    And I convert jsonSchema '!{discovery-json-schema}' to json and save it in variable 'discovery-basic.json'
    And I run 'echo '!{discovery-basic.json}' > target/test-classes/schemas/discovery-basic.json' locally

    When I send a 'POST' request to '/service/deploy-api/deploy/discovery/${FLAVOUR}/schema' based on 'schemas/discovery-basic.json' as 'json' with:
      # Basic install
      | $.general.datastore.metadataDbHost          | UPDATE  | ${DISCOVERY_METADATA_DB_HOST:-pg-0001.postgrestls.mesos}         | n/a     |
      | $.general.datastore.tenantName              | UPDATE  | ${DISCOVERY_TENANT_NAME:-crossdata-1}         | n/a     |
      | $.general.calico.networkName                | UPDATE  | ${CALICO_NETWORK_NAME:-stratio}               | n/a     |
      | $.settings.Login.mb-user-header             | DELETE  | {}                                            | string  |
      | $.settings.Login.mb-admin-group-header      | DELETE  | {}                                            | string  |
      | $.settings.Login.mb-group-header            | DELETE  | {}                                            | string  |
      # Advance install
      | $.general.serviceId                         | UPDATE  | ${SERVICE_ID:-/discovery/discovery}           | n/a     |
      | $.general.marathonlb.haproxypath            | UPDATE  | ${MARATHONLB_HA_PROXY_PATH:-/discovery}       | n/a     |
      | $.general.marathonlb.haproxyhost            | UPDATE  | ${MARATHONLB_HA_PROXY_HOST:-discovery.labs.stratio.com}          | n/a     |
      | $.general.datastore.dbPort                  | REPLACE | ${DISCOVERY_DB_PORT:-5432}                    | number  |
      | $.general.datastore.metadataDbName          | UPDATE  | ${DISCOVERY_METADATA_DB_NAME:-discovery}      | n/a     |
      | $.general.resources.instances               | REPLACE | ${RESOURCES_INSTANCES:-1}                     | number  |
      | $.general.resources.cpus                    | REPLACE | ${RESOURCES_CPUS:-2}                          | number  |
      | $.general.resources.mem                     | REPLACE | ${RESOURCES_MEM:-4096}                        | number  |
      | $.general.indentity.approlename             | UPDATE  | ${IDENTITY_APP_ROLE_NAME:-open}               | n/a     |
      | $.settings.init.mb-init-admin-user          | UPDATE  | ${INIT_ADMIN_USER:-Demo}                      | n/a     |
      | $.settings.init.mb-init-admin-mail          | UPDATE  | ${INIT_ADMIN_MAIL:-demo@stratio.com}          | n/a     |
      | $.settings.init.mb-init-admin-password      | REPLACE | ${INIT_ADMIN_PASSWORD:-123456}                | number  |
      | $.settings.jdbcParameters                   | UPDATE  | ${JDBC_PARAMETERS:-prepareThreshold=0}        | n/a     |
      | $.settings.Login                            | ADD     | {}                                            | object  |

       # Comentamos variables ya que no disponemos de valores válidos
#      | $.settings.Login.mb-user-header             | ADD     | ${MB_USER_HEADER:- "fdsa"}                    | string  |
#      | $.settings.Login.mb-admin-group-header      | ADD     | ${MB_ADMIN_GROUP_HEADER:-"4e32" }             | string  |
#      | $.settings.Login.mb-group-header            | ADD     | ${MB_GROUP_HEADER:-"433" }                    | string  |
       | $.environment.VAULT_HOST                   | UPDATE  | ${VAULT_HOST:-vault.service.paas.labs.stratio.com}                | n/a     |
       | $.environment.VAULT_PORT                   | REPLACE | ${VAULT_PORT:-8200}                           | number  |

    Then the service response status must be '202'
    And I run 'rm -f target/test-classes/schemas/discovery-basic.json' locally

  Scenario: [QATM-1866][Installation Discovery Command Center] - [2] - Check status
    Given I authenticate to DCOS cluster '${DCOS_IP}' using email '${DCOS_USER:-admin}' with user '${REMOTE_USER:-operador}' and pem file 'src/test/resources/credentials/${PEM_FILE:-key.pem}'
    And I securely send requests to '${CLUSTER_ID}.${CLUSTER_DOMAIN:-labs.stratio.com}:443'
    # Check Application in API
    Then in less than '200' seconds, checking each '20' seconds, I send a 'GET' request to '/service/deploy-api/deploy/status/all' so that the response contains '${SERVICE_ID:-/discovery/discovery}'
    # Check status in API
    And in less than '500' seconds, checking each '20' seconds, I send a 'GET' request to '/service/deploy-api/deploy/status/service?service=${SERVICE_ID:-/discovery/discovery}' so that the response contains '"healthy":1'
    # Check status in DCOS
    # Checking if service_ID contains "/" character or subdirectories. Ex: /discovery/discovery
    When I open a ssh connection to '${DCOS_CLI_HOST}' with user 'root' and password 'stratio'
    Then I run 'echo ${SERVICE_ID:-/discovery/discovery} | sed 's/\//./g' |  sed 's/^\.\(.*\)/\1/'' in the ssh connection and save the value in environment variable 'serviceIDDcosTaskPath'
    And in less than '500' seconds, checking each '20' seconds, the command output 'dcos task | grep !{serviceIDDcosTaskPath} | grep R | wc -l' contains '1'
    When I run 'dcos task |  awk '{print $5}' | grep !{serviceIDDcosTaskPath}' in the ssh connection and save the value in environment variable 'dicoveryTaskId'
    Then in less than '1200' seconds, checking each '10' seconds, the command output 'dcos marathon task show !{dicoveryTaskId} | grep TASK_RUNNING' contains 'TASK_RUNNING'
    And in less than '1200' seconds, checking each '10' seconds, the command output 'dcos marathon task show !{dicoveryTaskId} | grep healthCheckResults' contains 'healthCheckResults'
    And in less than '1200' seconds, checking each '10' seconds, the command output 'dcos marathon task show !{dicoveryTaskId} | grep  '"alive": true'' contains '"alive": true'
