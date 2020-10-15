@rest
Feature: Discovery scenario templates

  Scenario: Take Marathon-lb IP
    Given I set sso token using host '!{EOS_ACCESS_POINT}' with user '${DCOS_USER}' and password '${DCOS_PASSWORD}' and tenant 'NONE'
    Then I get host ip for task '.*marathonlb.*' in service with id '/marathonlb' from CCT and save the value in environment variable 'marathonIP'

  Scenario: Take publicAgentFQDN
    Given I set sso token using host '!{EOS_ACCESS_POINT}' with user '${DCOS_USER}' and password '${DCOS_PASSWORD}' and tenant 'NONE'
    Then I get host ip for task '.*marathonlb.*' in service with id '/marathonlb' from CCT and save the value in environment variable 'publicAgentIP'
    Then I open a ssh connection to '!{publicAgentIP}' with user '!{CLUSTER_SSH_USER}' using pem file '!{CLUSTER_SSH_PEM_PATH}'
    And I run 'hostname -f' in the ssh connection with exit status '0' and save the value in environment variable 'publicAgentFQDN'

  Scenario: Get Postgres IP
    Given I set sso token using host '!{EOS_ACCESS_POINT}' with user '${DCOS_USER}' and password '${DCOS_PASSWORD}' and tenant 'NONE'
    When I get host ip for task 'pg-0001' in service with id '/${DCOS_TENANT1}/${DCOS_TENANT1}-${DISCOVERY_POSTGRES_NAME:-postgrestls}' from CCT and save the value in environment variable 'pgIP'
    And I run 'echo '!{pgIP}'' locally
    Then I get container name for task 'pg-0001' in service with id '/${DCOS_TENANT1}/${DCOS_TENANT1}-${DISCOVERY_POSTGRES_NAME:-postgrestls}' and save the value in environment variable 'pgContainerName'
    And I run 'echo '!{pgContainerName}'' locally

  Scenario: Get Discovery URL
    Given I set sso token using host '!{EOS_ACCESS_POINT}' with user '${DCOS_USER}' and password '${DCOS_PASSWORD}' and tenant 'NONE'
    Then I get environment variable 'HIDDEN_HA_HOST' for service with id '/${DCOS_TENANT1}/${DCOS_TENANT1}-${DISCOVERY_ID:-discovery-qa}' and save the value in environment variable 'DISCOVERY_HOST'

  Scenario: Selenium - Discovery Login
    Given My app is running in '!{DISCOVERY_HOST}/${DCOS_TENANT1}-${DISCOVERY_ID:-discovery-qa}:443'
    When I securely browse to '/${DCOS_TENANT1}-${DISCOVERY_ID:-discovery-qa}'
    And '1' elements exists with 'xpath://*[@id="fm1"]/section[3]/span'
    And I click on the element on index '0'
    And I wait '1' seconds
    And '1' elements exists with 'xpath://*[@id="tenant"]'
    And I type '${DCOS_TENANT1}' on the element on index '0'
    And '1' elements exists with 'xpath://*[@id="username"]'
    And I type '${DCOS_TENANT1_OWNER_USER}' on the element on index '0'
    And '1' elements exists with 'xpath://*[@id="password"]'
    And I type '${DCOS_TENANT1_OWNER_PASSWORD}' on the element on index '0'
    And '1' elements exists with 'xpath://*[@id="fm1"]/input[5]'
    And I click on the element on index '0'
    And I wait '1' seconds
    Then I save selenium cookies in context
