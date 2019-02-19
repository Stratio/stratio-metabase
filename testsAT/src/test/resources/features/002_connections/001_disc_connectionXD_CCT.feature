@rest
Feature: Connection on XData

  Background: Initial setup
    Given I authenticate to DCOS cluster '${DCOS_IP}' using email '${DCOS_USER:-admin}' with user '${REMOTE_USER:-operador}' and pem file 'src/test/resources/credentials/${PEM_FILE:-key.pem}'
    And I open a ssh connection to '${DCOS_CLI_HOST}' with user '${CLI_USER:-root}' and password '${CLI_PASSWORD:-stratio}'
    And I securely send requests to '${DCOS_IP}:443'

  Scenario: [Connection XData] Create table in Crossdata using shell
    # Obtain agent where crossdata is running
    Given I open a ssh connection to '${DCOS_CLI_HOST}' with user '${CLI_USER:-root}' and password '${CLI_PASSWORD:-stratio}'
    Then I run 'dcos task | grep ${XD_ID:-crossdata-1} | grep root | awk '{print $2}'' in the ssh connection and save the value in environment variable 'xdHost'
    # Obtain docker where crossdata is running
    Given I open a ssh connection to '!{xdHost}' with user '${REMOTE_USER:-operador}' using pem file 'src/test/resources/credentials/${PEM_FILE:-key.pem}'
    Then I run 'sudo docker ps | grep crossdata-scala | awk '{print $1}'' in the ssh connection and save the value in environment variable 'xdDocker'
    And I run 'echo "CREATE TABLE testxd(id INT, name STRING);" > /tmp/queries.txt' in the ssh connection
#    And I run 'echo "INSERT INTO testxd VALUES(1, 'test1');" >> /tmp/queries.txt' in the ssh connection
#    And I run 'echo "INSERT INTO testxd VALUES(2, 'test2');" >> /tmp/queries.txt' in the ssh connection
    And I run 'sudo docker cp /tmp/queries.txt !{xdDocker}:/tmp/' in the ssh connection
    And I run 'sudo docker exec -it !{xdDocker} sh -c "cd /opt/sds/crossdata/bin && ./crossdata-shell --user ${XD_USER:-crossdata-1} --queries-file /tmp/queries.txt"' in the ssh connection

  Scenario: [Connection XData] Check Crossdata connection
    # Register Crossdata database
    Given I obtain metabase id for user '${USER:-demo@stratio.com}' and password '${PASSWORD:-123456}' in endpoint 'https://${DISCOVERY_SERVICE_VHOST:-discovery.labs.stratio.com}${DISCOVERY_DISCOVERY_PATH:-/discovery}${DISCOVERY_SESSION:-/api/session}' and save in context cookies
    When I securely send requests to '${DISCOVERY_SERVICE_VHOST:-discovery.labs.stratio.com}:443'
    Then in less than '5' seconds, checking each '1' seconds, I send a 'POST' request to '${DISCOVERY_DISCOVERY_PATH:-/discovery}${DISCOVERY_DATABASES:-/api/database}' so that the response contains '"name":"${DISCOVERY_DATABASE_CONNECTION_NAME:-crossdata}",' based on 'schemas/registerdatabase.json' as 'json' with:
      | $.engine                                        | UPDATE  | ${DISCOVERY_ENGINE_XD:-crossdata2}                  | string |
      | $.name                                          | UPDATE  | ${DISCOVERY_DATABASE_XD_CONNECTION_NAME:-crossdata} | string |
      | $.details.host                                  | UPDATE  | ${DISCOVERY_XD_HOST:-crossdata-1.marathon.mesos}    | string |
      | $.details.port                                  | REPLACE | ${DISCOVERY_XD_PORT:-8000}                          | number |
      | $.details.dbname                                | UPDATE  | true                                                | string |
      | $.details.user                                  | UPDATE  | ${DISCOVERY_TENANT_NAME:-crossdata-1}               | string |
      | $.details.additional-options                    | DELETE  |                                                     | string |
      | $.details.tunnel-port                           | DELETE  |                                                     | string |

    # Get xdata database id
    When I securely send requests to '${DISCOVERY_SERVICE_VHOST:-discovery.labs.stratio.com}:443'
    Then in less than '300' seconds, checking each '10' seconds, I send a 'GET' request to '${DISCOVERY_DISCOVERY_PATH:-/discovery}${DISCOVERY_DATABASES:-/api/database}' so that the response contains '"engine":"crossdata2"'
    Then the service response status must be '200'
    And I save element '$' in environment variable 'exhibitor_answer'
    And I save ''!{exhibitor_answer}'' in variable 'parsed_answer'
    And I run 'echo !{parsed_answer} | jq '.[] | select(.engine=="crossdata2") | .id'' locally and save the value in environment variable 'xddatabaseId'

    # Get xdata table id
    When I securely send requests to '${DISCOVERY_SERVICE_VHOST:-discovery.labs.stratio.com}:443'
    Then in less than '300' seconds, checking each '10' seconds, I send a 'GET' request to '${DISCOVERY_DISCOVERY_PATH:-/discovery}${DISCOVERY_DATABASES:-/api/table}' so that the response contains '"engine":"crossdata2"'
    Then the service response status must be '200'
    And I save element '$' in environment variable 'tables_answer'
    And I save ''!{tables_answer}'' in variable 'parsed_answer'
    And I run 'echo !{parsed_answer} | jq '.[] | select(.name=="testxd") | .id'' locally and save the value in environment variable 'xdtableId'

    # Check query xdata database
    When I securely send requests to '${DISCOVERY_SERVICE_VHOST:-discovery.labs.stratio.com}:443'
    Then in less than '5' seconds, checking each '1' seconds, I send a 'POST' request to '${DISCOVERY_DISCOVERY_PATH:-/discovery}${DISCOVERY_DATASET:-/api/dataset}' so that the response contains '200' based on 'schemas/dataset.json' as 'json' with:
      | $.database                 | REPLACE | !{xddatabaseId}                      | number |
      | $.type                     | REPLACE | ${DISCOVERY_TYPE_DATASET:-query}     | string |
      | $.query.source_table       | REPLACE | !{xdtableId}                         | number |
    And I wait '3' seconds
    And the service response must contain the text '"row_count":0,'
#    And the service response must contain the text '"row_count":2,'

  Scenario: [Connection XData] Drop table in Crossdata using shell
    # Obtain agent where crossdata is running
    Given I open a ssh connection to '${DCOS_CLI_HOST}' with user '${CLI_USER:-root}' and password '${CLI_PASSWORD:-stratio}'
    Then I run 'dcos task | grep ${XD_ID:-crossdata-1} | grep root | awk '{print $2}'' in the ssh connection and save the value in environment variable 'xdHost'
    # Obtain docker where crossdata is running
    Given I open a ssh connection to '!{xdHost}' with user '${REMOTE_USER:-operador}' using pem file 'src/test/resources/credentials/${PEM_FILE:-key.pem}'
    Then I run 'sudo docker ps | grep crossdata-scala | awk '{print $1}'' in the ssh connection and save the value in environment variable 'xdDocker'
    And I run 'echo "DROP TABLE testxd;" > /tmp/queries.txt' in the ssh connection
    And I run 'sudo docker cp /tmp/queries.txt !{xdDocker}:/tmp/' in the ssh connection
    And I run 'sudo docker exec -it !{xdDocker} sh -c "cd /opt/sds/crossdata/bin && ./crossdata-shell --user ${XD_USER:-crossdata-1} --queries-file /tmp/queries.txt"' in the ssh connection

