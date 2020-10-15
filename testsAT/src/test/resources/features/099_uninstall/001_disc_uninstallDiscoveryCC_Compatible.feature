@rest @dcos
Feature: Discovery Unistall with command center

  @skipOnEnv(DISCOVERY_SKIP_UNINSTALL=yes)
  Scenario: Uninstall Discovery
    Given I set sso token using host '!{EOS_ACCESS_POINT}' with user '${DCOS_USER}' and password '${DCOS_PASSWORD}' and tenant '${DCOS_TENANT}'
    And I securely send requests to '!{EOS_ACCESS_POINT}:443'
    Then I uninstall service '${DISCOVERY_ID:-discovery-qa}' from tenant '${DCOS_TENANT}'

  @skipOnEnv(DISCOVERY_SKIP_UNINSTALL=yes)
  Scenario: [QATM-1863][03] Delete Discovery policy
    Given I delete 'policy' '${DISCOVERY_ID:-discovery-qa}' from tenant '${DCOS_TENANT}' with tenant user and tenant password '${DCOS_USER}:${DCOS_PASSWORD}' if it exists

