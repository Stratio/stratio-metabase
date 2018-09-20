Feature: Login with headers

  Background: Initial setup
    Given I open a ssh connection to '${BOOTSTRAP_IP}' with user '${REMOTE_USER:-operador}' using pem file 'src/test/resources/credentials/${PEM_FILE:-key.pem}'
    And I run 'grep -Po '"root_token":"(\d*?,|.*?[^\\]")' /stratio_volume/vault_response | awk -F":" '{print $2}' | sed -e 's/^"//' -e 's/"$//'' in the ssh connection and save the value in environment variable 'vaultToken'
    And I authenticate to DCOS cluster '${DCOS_IP}' using email '${DCOS_USER:-admin}' with user '${REMOTE_USER:-operador}' and pem file 'src/test/resources/credentials/${PEM_FILE:-key.pem}'
    And I open a ssh connection to '${DCOS_CLI_HOST:-dcos-cli.demo.stratio.com}' with user '${CLI_USER:-root}' and password '${CLI_PASSWORD:-stratio}'
    And I securely send requests to '${DCOS_IP}:443'

  @web
  @include(feature:001_disc_loginUserPassword.feature,scenario:DefaultLogin)
  @loop(GROUP_LIST,GROUP)
  Scenario: Create groups
    When '1' elements exists with 'xpath://div[@id='root']/div/div[1]/div[2]/div/div/div'
    Then I click on the element on index '0'
    When '1' elements exists with 'xpath://a[contains(@data-metabase-event,'Admin') and contains(@href,'admin')]'
    Then I click on the element on index '0'
    When '1' elements exists with 'xpath://a[contains(@href,'people') and contains(@data-metabase-event,'NavBar')]'
    Then I click on the element on index '0'
    When '1' elements exists with 'xpath://ul[contains(@class,'AdminList')]//a[contains(@href,'groups')]'
    Then I click on the element on index '0'
    When '1' elements exists with 'xpath://button'
    Then I click on the element on index '0'
    When '1' elements exists with 'xpath://input'
    Then I type '<GROUP>' on the element on index '0'
    When '1' elements exists with 'xpath://table//button'
    Then I click on the element on index '0'
    And I wait '5' seconds

  @rest
  Scenario: Modify discovery instance adding header environment variables
    Given I open a ssh connection to '${DCOS_CLI_HOST:-dcos-cli.demo.labs.stratio.com}' with user '${CLI_USER:-root}' and password '${CLI_PASSWORD:-stratio}'
    When I run 'echo "{\"env\":" > /tmp/discovery_config.json;dcos marathon app show ${DISCOVERY_SERVICE_FOLDER:-discovery}/${DISCOVERY_SERVICE_NAME:-discovery} | jq .env >> /tmp/discovery_config.json;echo "}" >> /tmp/discovery_config.json' in the ssh connection
    Then I inbound copy '/tmp/discovery_config.json' through a ssh connection to 'target/test-classes'
    And I create file 'discovery_header.json' based on 'discovery_config.json' as 'json' with:
      | $.env.MB-GROUP-HEADER                                             | ADD     | vnd.bbva.group-id                                  | string  |
      | $.env.MB-ADMIN-GROUP-HEADER                                       | ADD     | ${GROUP_ADMIN:-testadmin}                          | string  |
      | $.env.APPROLE                                                     | DELETE  | {}                                                 | object  |
    And I outbound copy 'target/test-classes/discovery_header.json' through a ssh connection to '/tmp'
    When I run 'dcos marathon app stop --force ${DISCOVERY_SERVICE_FOLDER:-discovery}/${DISCOVERY_SERVICE_NAME:-discovery}' in the ssh connection
    Then the command output contains 'Created deployment'
    When I run 'dcos marathon app update ${DISCOVERY_SERVICE_FOLDER:-discovery}/${DISCOVERY_SERVICE_NAME:-discovery} < /tmp/discovery_header.json' in the ssh connection
    Then the command output contains 'Created deployment'
    When I run 'dcos marathon app start --force ${DISCOVERY_SERVICE_FOLDER:-discovery}/${DISCOVERY_SERVICE_NAME:-discovery}' in the ssh connection
    Then the command output contains 'Created deployment'
    Given in less than '300' seconds, checking each '10' seconds, the command output 'dcos marathon task list ${DISCOVERY_SERVICE_FOLDER:-discovery}/${DISCOVERY_SERVICE_NAME:-discovery} | awk '{print $5}' | grep ${DISCOVERY_SERVICE_NAME:-discovery} | wc -l' contains '1'
    And I run 'dcos marathon task list ${DISCOVERY_SERVICE_FOLDER:-discovery}/${DISCOVERY_SERVICE_NAME:-discovery} | awk '{print $5}' | grep ${DISCOVERY_SERVICE_NAME:-discovery}' in the ssh connection and save the value in environment variable 'discoveryTaskId'
    Then in less than '300' seconds, checking each '10' seconds, the command output 'dcos marathon task show !{discoveryTaskId} | grep TASK_RUNNING | wc -l' contains '1'
    Then in less than '300' seconds, checking each '10' seconds, the command output 'dcos marathon task show !{discoveryTaskId} | grep healthCheckResults | wc -l' contains '1'
    Then in less than '300' seconds, checking each '10' seconds, the command output 'dcos marathon task show !{discoveryTaskId} | grep "alive": true | wc -l' contains '1'
    And I run 'rm -rf /tmp/discovery_config.json /tmp/discovery_header.json' in the ssh connection
    Given I securely send requests to '${DISCOVERY_SERVICE_VHOST:-nightlypublic.labs.stratio.com}'
    And in less than '600' seconds, checking each '10' seconds, I send a 'GET' request to '${DISCOVERY_DISCOVERY_PATH:-/discovery}' so that the response contains 'Metabase'
    Then the service response status must be '200'

  Scenario: Set PROXY_HEADERS variable to non-existing user without group (user: notexists)
    When We update system property 'PROXY_HEADERS' to value 'vnd.bbva.user-id:notexists'

  @web
  Scenario: Login through headers - User and group don't exist --> NO LOGIN
    Given My app is running in '${DISCOVERY_SERVICE_VHOST:-nightlypublic.labs.stratio.com}:443'
    When I securely browse to '${DISCOVERY_DISCOVERY_PATH:-/discovery}'
    And I wait '10' seconds
    And '1' elements exists with 'xpath://input[@name="username"]'
    And '0' elements exists with 'xpath://h2[contains(.,'notexists')]'

  Scenario: Set PROXY_HEADERS variable to non-existing user and group (user: notexists, group: notexists)
    When We update system property 'PROXY_HEADERS' to value 'vnd.bbva.user-id:notexists,vnd.bbva.group-id:notexists'

  @web
  Scenario: Login through headers - User and group don't exist --> NO LOGIN
    Given My app is running in '${DISCOVERY_SERVICE_VHOST:-nightlypublic.labs.stratio.com}:443'
    When I securely browse to '${DISCOVERY_DISCOVERY_PATH:-/discovery}'
    And I wait '10' seconds
    And '1' elements exists with 'xpath://input[@name="username"]'
    And '0' elements exists with 'xpath://h2[contains(.,'notexists')]'

  Scenario: Set PROXY_HEADERS variable to existing user and non-existing group (user: demo (or USERNAME variable), group: notexists)
    When We update system property 'PROXY_HEADERS' to value 'vnd.bbva.user-id:${USERNAME:-demo},vnd.bbva.group-id:test'

  @web
  Scenario: Login through headers - User exists --> AUTOMATIC LOGIN
    Given My app is running in '${DISCOVERY_SERVICE_VHOST:-nightlypublic.labs.stratio.com}:443'
    When I securely browse to '${DISCOVERY_DISCOVERY_PATH:-/discovery}'
    And I wait '10' seconds
    And '0' elements exists with 'xpath://input[@name="username"]'
    And '1' elements exists with 'xpath://h2[contains(.,'${USERNAME:-demo}')]'

  Scenario: Set PROXY_HEADERS variable to non-existing user and existing group (user: newuser, group: test (or GROUP variable))
    When We update system property 'PROXY_HEADERS' to value 'vnd.bbva.user-id:newuser,vnd.bbva.group-id:${GROUP:-test}'

  @web
  Scenario: Login through headers - User doesn't exist and group exists --> AUTOMATIC LOGIN
    Given My app is running in '${DISCOVERY_SERVICE_VHOST:-nightlypublic.labs.stratio.com}:443'
    When I securely browse to '${DISCOVERY_DISCOVERY_PATH:-/discovery}'
    And I wait '10' seconds
    And '0' elements exists with 'xpath://input[@name="username"]'
    And '1' elements exists with 'xpath://h2[contains(.,'newuser')]'

  Scenario: Set PROXY_HEADERS variable to non-existing user and existing group. GROUP-ADMIN header contains this group (user: newuser, group: testadmin (or GROUP_ADMIN variable))
    When We update system property 'PROXY_HEADERS' to value 'vnd.bbva.user-id:newadminuser,vnd.bbva.group-id:${GROUP_ADMIN:-testadmin} '

  @web
  Scenario: Login through headers - User doesn't exist and group exists --> AUTOMATIC LOGIN and user is admin
    Given My app is running in '${DISCOVERY_SERVICE_VHOST:-nightlypublic.labs.stratio.com}:443'
    When I securely browse to '${DISCOVERY_DISCOVERY_PATH:-/discovery}'
    And I wait '10' seconds
    And '0' elements exists with 'xpath://input[@name="username"]'
    And '1' elements exists with 'xpath://h2[contains(.,'newadminuser')]'