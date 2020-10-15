@mandatory @vars(BOOTSTRAP_IP,REMOTE_USER,PEM_FILE_PATH,DCOS_PASSWORD,DCOS_TENANT1,UNIVERSE_VERSION,DCOS_TENANT1_OWNER_USER,DCOS_TENANT,DCOS_TENANT1_OWNER_PASSWORD)
@rest @dcos

Feature: Discovery install with command center

  @skipOnEnv(DISCOVERY_PUBLIC_AGENT_FQDN)
  @include(feature:../templates/Discovery_Templates_Compatible.feature,scenario:Take publicAgentFQDN)
  Scenario: [QATM-1863][01] Get publicAgentFQDN

  @runOnEnv(DISCOVERY_PUBLIC_AGENT_FQDN)
  Scenario: [QATM-1863][02] Use Marathon-lb-sec node FQDN provided
    Then I save '${DISCOVERY_PUBLIC_AGENT_FQDN}' in variable 'publicAgentFQDN'

  Scenario:[QATM-1866][06] Discovery installation
    Then I set sso token using host '!{EOS_ACCESS_POINT}' with user '${DCOS_USER}' and password '${DCOS_PASSWORD}' and tenant '${DCOS_TENANT}'
    And I securely send requests to '!{EOS_ACCESS_POINT}:443'
    When I get schema from service 'discovery' with model '${DISCOVERY_FLAVOUR:-pegaso}' and version '${UNIVERSE_VERSION}' and save it in file 'discovery-descriptor.json'
    And I create file 'discovery_descriptor.json' based on 'discovery-descriptor.json' as 'json' with:
      | $.general.serviceId                        | REPLACE | /${DISCOVERY_ID:-discovery-qa}                | string |
      | $.general.dcosServiceName                  | REPLACE | ${DISCOVERY_ID:-discovery-qa}                                                | string |
      | $.general.discoveryInstanceName            | REPLACE | ${DISCOVERY_ID:-discovery-qa}                                | string |
      | $.general.marathonlb.haproxyhost           | REPLACE | !{publicAgentFQDN}                                                           | string |
      | $.general.marathonlb.haproxypath           | REPLACE | /${DISCOVERY_ID:-discovery-qa}                                               | string |
      | $.general.datastore.metadataDbInstanceName | REPLACE | ${DISCOVERY_POSTGRES_NAME:-postgrestls}                | string |
      | $.general.datastore.postgresService        | REPLACE | /${DISCOVERY_POSTGRES_NAME:-postgrestls}               | string |
      | $.general.datastore.metadataDbName         | REPLACE | ${DISCOVERY_METADATA_DB_NAME:-discovery}                                     | string |
      | $.general.calico.networkName               | REPLACE | stratio                                                        | string |
      | $.general.resources.instances              | REPLACE | ${DISCOVERY_SERVICE_INSTANCES:-1}                                            | number |
      | $.general.resources.cpus                   | REPLACE | ${DISCOVERY_SERVICE_CPUS:-1}                                                 | number |
      | $.general.resources.mem                    | REPLACE | ${DISCOVERY_SERVICE_MEM:-2048}                                               | number |
      | $.general.identity.approlename             | REPLACE | open                                                      | string |
      | $.general.datastore.metadataDbIUrl1        | DELETE  |                                                                              | n/a    |
      | $.general.datastore.metadataDbIUrl2        | REPLACE | ${DISCOVERY_PGBOUNCER_NAME:-poolpostgrestls} | string |

    And I install service 'discovery' with model '${DISCOVERY_FLAVOUR:-pegaso}' and version '${UNIVERSE_VERSION}' and instance name '${DISCOVERY_ID:-discovery-qa}' in tenant '${DCOS_TENANT}' using json 'discovery_descriptor.json'
    And I run 'rm -f target/test-classes/discovery-descriptor.json' locally

  Scenario: Check command output with correct expresion and exist status=0
    Given I set sso token using host '!{EOS_ACCESS_POINT}' with user '${DCOS_USER}' and password '${DCOS_PASSWORD}' and tenant '${DCOS_TENANT}'
    Then in less than '1200' seconds, checking each '5' seconds, service with id '/${DISCOVERY_ID:-discovery-qa}' has '1' task in 'running' state in Marathon
    Then in less than '2200' seconds, checking each '5' seconds, service with id '/${DISCOVERY_ID:-discovery-qa}' has '1' 'healthy' task in Marathon
    When I wait '${DISCOVERY_WAIT:-60}' seconds

  @runOnEnv(DISCOVERY_WEB_VALIDATION)
  @web
  Scenario:[QATM-1866][09] Check Discovery frontend
    Given I set sso discovery token using host '!{DISCOVERY_HOST}/${DISCOVERY_ID:-discovery-qa}/auth' with user '${DCOS_USER}' and password '${DCOS_PASSWORD}' and tenant '${DCOS_TENANT}' without host name verification with cookie name '${DISCOVERY_ID:-discovery-qa}-auth-cookie'
    Given My app is running in '!{DISCOVERY_HOST}:443'
    When I securely browse to '${DISCOVERY_DISCOVERY_PATH:-/discovery}'
    And in less than '300' seconds, checking each '10' seconds, '1' elements exists with 'xpath://input[@name="username"]'
    And in less than '300' seconds, checking each '10' seconds, '1' elements exists with 'xpath://input[@name="password"]'
