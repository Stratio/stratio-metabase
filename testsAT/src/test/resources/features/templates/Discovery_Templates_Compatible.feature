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
    Then in less than '600' seconds, checking each '20' seconds, I send a 'GET' request to '/exhibitor/exhibitor/v1/explorer/node-data?key=%2Fdatastore%2Fcommunity%2F${DISCOVERY_POSTGRES_NAME:-postgrestls}%2Fplan-v2-json&_=' so that the response contains 'str'
    When I securely send requests to '!{EOS_ACCESS_POINT}:443'
    When I get internal host ip for task 'pg-0001' in service with id '/${DISCOVERY_POSTGRES_NAME:-postgrestls}' from CCT and save the value in environment variable 'pgIPCalico'
    Then I send a 'GET' request to '/exhibitor/exhibitor/v1/explorer/node-data?key=%2Fdatastore%2Fcommunity%2F${DISCOVERY_POSTGRES_NAME:-postgrestls}%2Fplan-v2-json&_='
    And I save element '$.str' in environment variable 'exhibitor_answer'
    And I save '!{exhibitor_answer}' in variable 'parsed_answer'
    Given I run 'echo '!{parsed_answer}' | jq '.phases[] | .[] | .steps[] | .[] | select((.status=="RUNNING") and (.role=="master") and (.name=="pg-0001")).agent_hostname' | sed 's/^.\|.$//g'' locally with exit status '0' and save the value in environment variable 'pgIP'
    Given I open a ssh connection to '!{pgIP}' with user '!{CLUSTER_SSH_USER}' using pem file '!{CLUSTER_SSH_PEM_PATH}'
    Then I run 'sudo docker ps -q | xargs -n 1 sudo docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}} {{ .Name }}' | sed 's/ \// /'| grep !{pgIPCalico} | awk '{print $2}'' in the ssh connection and save the value in environment variable 'pgContainerName'
    And I run 'echo 'POSTGRES CONTAINER: !{pgContainerName}'' locally

  Scenario: Get Discovery URL
    Given I set sso token using host '!{EOS_ACCESS_POINT}' with user '${DCOS_USER}' and password '${DCOS_PASSWORD}' and tenant 'NONE'
    Then I get environment variable 'HIDDEN_HA_HOST' for service with id '${DISCOVERY_ID:-discovery-qa}' and save the value in environment variable 'DISCOVERY_HOST'

  Scenario: Selenium - Discovery Login
    Given My app is running in '!{DISCOVERY_HOST}/${DISCOVERY_ID:-discovery-qa}:443'
    When I securely browse to '/${DISCOVERY_ID:-discovery-qa}'
    And '1' elements exists with 'xpath://*[@id="fm1"]/section[3]/span'
    And I click on the element on index '0'
    And I wait '1' seconds
    And '1' elements exists with 'xpath://*[@id="tenant"]'
    And I type '${DCOS_TENANT}' on the element on index '0'
    And '1' elements exists with 'xpath://*[@id="username"]'
    And I type '${DCOS_USER}' on the element on index '0'
    And '1' elements exists with 'xpath://*[@id="password"]'
    And I type '${DCOS_PASSWORD}' on the element on index '0'
    And '1' elements exists with 'xpath://*[@id="fm1"]/input[5]'
    And I click on the element on index '0'
    And I wait '1' seconds
    Then I save selenium cookies in context
