@rest
Feature: [QATM-1866][Uninstallation Discovery Command Center] Discovery uninstall with command center

  Scenario: [QATM-1866][Uninstallation Discovery Command Center] - [1] - Uninstall Discovery

    Given I authenticate to DCOS cluster '${DCOS_IP}' using email '${DCOS_USER:-admin}' with user '${REMOTE_USER:-operador}' and pem file 'src/test/resources/credentials/${PEM_FILE:-key.pem}'
    And I securely send requests to '${CLUSTER_ID}.${CLUSTER_DOMAIN:-labs.stratio.com}:443'
    And I open a ssh connection to '${DCOS_CLI_HOST}' with user 'root' and password 'stratio'
    # Check if service_ID contains "/" character or subdirectories. Ex: /discovery/discovery
    Then I run 'echo ${SERVICE_ID:-/discovery/discovery/} | sed 's/^\/\(.*\)/\1/'' in the ssh connection and save the value in environment variable 'serviceName'
    When I send a 'DELETE' request to '/service/deploy-api/deploy/uninstall?app=!{serviceName}'
    # Check Uninstall in DCOS
    Then in less than '600' seconds, checking each '10' seconds, the command output 'dcos task | grep ${SERVICE:-discovery} | wc -l' contains '0'
    # Check Uninstall in CCT-API
    And in less than '200' seconds, checking each '10' seconds, I send a 'GET' request to '/service/deploy-api/deploy/status/all' so that the response does not contains '${SERVICE:-discovery}'
