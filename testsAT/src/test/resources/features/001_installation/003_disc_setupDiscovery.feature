Feature: Setup Discovery

  @skipOnEnv(SKIP_SETUP_HOSTS)
  Scenario: Configure /etc/hosts
    Given I run 'cp /etc/hosts /etc/hosts.bak' locally
    Given I run 'echo "${PUBLIC_NODE_IP} ${DISCOVERY_SERVICE_VHOST:-discovery.labs.stratio.com}" >> /etc/hosts' locally

  @web
  @runOnEnv(DISC_VERSION=0.32.0)
  Scenario: Setup discovery
    Given My app is running in '${DISCOVERY_SERVICE_VHOST:-discovery.labs.stratio.com}:443'
    When I securely browse to '${DISCOVERY_DISCOVERY_PATH:-/discovery}'
    And I wait '10' seconds
    And '1' elements exists with 'xpath://button'
    And I click on the element on index '0'
    And '1' elements exists with 'xpath://input[@name='first_name']'
    And I type '${USERNAME:-demo}' on the element on index '0'
    And '1' elements exists with 'xpath://input[@name='last_name']'
    And I type 'Stratio' on the element on index '0'
    And '1' elements exists with 'xpath://input[@name='email']'
    And I type '${USER:-demo@stratio.com}' on the element on index '0'
    And '1' elements exists with 'xpath://input[@name='password']'
    And I type '${PASSWORD:-123456}' on the element on index '0'
    And '1' elements exists with 'xpath://input[@name='password_confirm']'
    And I type '${PASSWORD:-123456}' on the element on index '0'
    And '1' elements exists with 'xpath://input[@name='site_name']'
    And I type 'QA' on the element on index '0'
    And I wait '2' seconds
    And '1' elements exists with 'xpath://button'
    And I click on the element on index '0'
    And I wait '2' seconds
    And '1' elements exists with 'xpath://section//a[@class='link']'
    And I click on the element on index '0'
    And I wait '2' seconds
    And '1' elements exists with 'xpath://button'
    And I click on the element on index '0'
    And I wait '2' seconds

  @skipOnEnv(SKIP_SETUP_HOSTS)
  Scenario: Configure /etc/hosts
    Given I run 'cp /etc/hosts.bak /etc/hosts' locally
