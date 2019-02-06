# README

## ACCEPTANCE TESTS - MICROSTRATEGY GROUP

### How to execute the microstrategy query set

mvn clean verify -Dgroups=Microstrategy


## ACCEPTANCE TESTS

Cucumber automated and manual acceptance tests.
This module depends on a QA library (stratio-test-bdd), where common logic and steps are implemented.

## EXECUTION

These tests will be executed as part of the continuous integration flow as follows:

mvn verify [-D\<ENV_VAR>=\<VALUE>] [-Dit.test=\<TEST_TO_EXECUTE>|-Dgroups=\<GROUP_TO_EXECUTE>]

Example:

### Create policies in Gosec
mvn clean verify -Dgroups=create_policy -DBOOTSTRAP_IP=10.200.0.155 -DDCOS_IP=10.200.0.156 -DDCOS_CLI_HOST=dcos-cli-nightly.demo.stratio.com -DDISC_VERSION=0.31.0 -DREGISTERSERVICEOLD=true -DCLUSTER_ID=nightly -DDISCOVERY_POLICIES=true -DlogLevel=DEBUG -DPOSTGRES_VERSION=1.3.0

### Install Postgres dependencies
mvn clean verify -Dgroups=config_postgres -DBOOTSTRAP_IP=10.200.0.155 -DDCOS_IP=10.200.0.156 -DDCOS_CLI_HOST=dcos-cli-nightly.demo.stratio.com -DDISC_VERSION=0.31.0 -DCLUSTER_ID=nightly -DlogLevel=DEBUG

### Install Discovery
mvn clean verify -Dgroups=install_discovery -DBOOTSTRAP_IP=10.200.0.155 -DDCOS_IP=10.200.0.156 -DDCOS_CLI_HOST=dcos-cli-nightly.demo.stratio.com -DDISC_VERSION=0.31.0 -DDISCOVERY_SERVICE_VHOST=nightlypublic.labs.stratio.com -DlogLevel=DEBUG

### Install Discovery Command Center
-DDISC_FLAVOUR (mandatory): descriptor name value (Ex: hydra)
-DDISC_ADVANCED_INSTALL (optional):
    Without parameter: will be executed the Basic install
        - intbootstrap: mvn clean verify -Dgroups=install_discovery_cc -DBOOTSTRAP_IP=10.200.1.52 -DDCOS_IP=10.200.0.242 -DDCOS_CLI_HOST=172.17.0.3 -DCLUSTER_ID=intbootstrap -DlogLevel=DEBUG -DDISC_VERSION=0.31.1 -DDISC_POSTGRES_FRAMEWORK_ID_TLS=postgrestls -DDISC_FLAVOUR=hydra
        - nightly:      mvn clean verify -Dgroups=install_discovery_cc -DBOOTSTRAP_IP=10.200.0.155 -DDCOS_IP=10.200.0.156 -DDCOS_CLI_HOST=dcos-cli-nightly.demo.stratio.com -DCLUSTER_ID=nightly -DlogLevel=DEBUG -DDISC_VERSION=0.31.1 -DDISC_POSTGRES_FRAMEWORK_ID_TLS=postgrestls -DDISC_FLAVOUR=hydra
    With parameter: will be executed the Advance install
        - intbootstrap: mvn clean verify -Dgroups=install_discovery_cc -DBOOTSTRAP_IP=10.200.1.52 -DDCOS_IP=10.200.0.242 -DDCOS_CLI_HOST=172.17.0.3 -DCLUSTER_ID=intbootstrap -DlogLevel=DEBUG -DDISC_VERSION=0.31.1 -DDISC_POSTGRES_FRAMEWORK_ID_TLS=postgrestls -DDISC_FLAVOUR=hydra -DDISC_ADVANCED_INSTALL
        - nightly:      mvn clean verify -Dgroups=install_discovery_cc -DBOOTSTRAP_IP=10.200.0.155 -DDCOS_IP=10.200.0.156 -DDCOS_CLI_HOST=dcos-cli-nightly.demo.stratio.com -DCLUSTER_ID=nightly -DlogLevel=DEBUG -DDISC_VERSION=0.31.1 -DDISC_POSTGRES_FRAMEWORK_ID_TLS=postgrestls -DDISC_FLAVOUR=hydra -DDISC_ADVANCED_INSTALL

### Purge Discovery Command Center
-DDISC_FLAVOUR (mandatory): descriptor name value (Ex: hydra)
-DSERVICE_ID (optional). By default: /discovery/discovery
-DSERVICE (optional): "service value" located in .../deploy-api/deploy/status/all when the service has been deployed. By default: discovery
    - intbootstrap
    mvn clean verify -Dgroups=purge_discovery_cc -DBOOTSTRAP_IP=10.200.1.52 -DDCOS_IP=10.200.0.242 -DDCOS_CLI_HOST=172.17.0.3 -DlogLevel=DEBUG -DCLUSTER_ID=intbootstrap
    - huawei
    mvn clean verify -Dgroups=purge_discovery_cc -DBOOTSTRAP_IP=10.10.4.2 -DDCOS_IP=10.10.4.61 -DDCOS_CLI_HOST=172.17.0.4 -DlogLevel=DEBUG -DCLUSTER_ID=bootstrap
    - nightly
    mvn clean verify -Dgroups=purge_discovery_cc -DBOOTSTRAP_IP=10.200.0.155 -DDCOS_IP=10.200.0.156 -DDCOS_CLI_HOST=dcos-cli-nightly.demo.stratio.com -DlogLevel=DEBUG -DCLUSTER_ID=nightly


### Register Postgres database
mvn clean verify -Dgroups=connection_PG -DDCOS_IP=10.200.0.156 -DDCOS_CLI_HOST=dcos-cli-nightly -DDISCOVERY_SERVICE_VHOST=nightlypublic.labs.stratio.com -DDISC_VERSION=0.31.0 -DlogLevel=DEBUG -DSELENIUM_GRID=sl.demo.stratio.com:4444 -DFORCE_BROWSER=chrome_64datagov
## For launch this group it's necessary having deployed next component:
- docker run -d --name sl selenium/hub:3.9.1 && docker run -d -v /dev/shm:/dev/shm --name docker-selenium-chrome -e HUB_HOST=sl.demo.stratio.com -e HUB_PORT=4444 -e SE_OPTS="-browser browserName=chrome,version=64datagov " selenium/node-chrome-debug:3.9.1

### Register Crossdata database
mvn clean verify -Dgroups=connection_XD -DDCOS_IP=10.200.0.156 -DDCOS_CLI_HOST=dcos-cli-nightly -DDISCOVERY_SERVICE_VHOST=nightlypublic.labs.stratio.com -DDISC_VERSION=0.31.0 -DlogLevel=DEBUG -DSELENIUM_GRID=sl.demo.stratio.com:4444 -DFORCE_BROWSER=chrome_64datagov
## For launch this group it's necessary having deployed next component:
- docker run -d --name sl selenium/hub:3.9.1 && docker run -d -v /dev/shm:/dev/shm --name docker-selenium-chrome -e HUB_HOST=sl.demo.stratio.com -e HUB_PORT=4444 -e SE_OPTS="-browser browserName=chrome,version=64datagov " selenium/node-chrome-debug:3.9.1

### Login Tests
mvn clean verify -Dgroups=login -DBOOTSTRAP_IP=10.200.0.155 -DDCOS_IP=10.200.0.156 -DDCOS_CLI_HOST=dcos-cli-nightly -DDISC_VERSION=0.31.0 -DCLUSTER_ID=nightly -DlogLevel=DEBUG -DDISCOVERY_SERVICE_VHOST=nightlypublic.labs.stratio.com -DSELENIUM_GRID=sl.demo.stratio.com:4444 -DFORCE_BROWSER=chrome_64datagov -DMODHEADER_PLUGIN=src/test/resources/chromePlugins/ModHeader_v2.2.3.crx -DGROUP_LIST=testadmin,group1 -DUSERNAME=Demo -DGROUP=group1 -DADMIN_GROUP=testadmin
## For launch this group it's necessary having deployed next component:
- docker run -d --name sl selenium/hub:3.9.1 && docker run -d -v /dev/shm:/dev/shm --name docker-selenium-chrome -e HUB_HOST=sl.demo.stratio.com -e HUB_PORT=4444 -e SE_OPTS="-browser browserName=chrome,version=64datagov " selenium/node-chrome-debug:3.9.1

### Purge Discovery
mvn clean verify -Dgroups=purge_discovery -DBOOTSTRAP_IP=10.200.0.155 -DDCOS_IP=10.200.0.156 -DDCOS_CLI_HOST=dcos-cli-nightly.demo.stratio.com -DDISC_VERSION=0.31.0 -DlogLevel=DEBUG

### Delete changes in Postgres
mvn clean verify -Dgroups=purge_postgres -DBOOTSTRAP_IP=10.200.0.155 -DDCOS_IP=10.200.0.156 -DDCOS_CLI_HOST=dcos-cli-nightly.demo.stratio.com -DDISC_VERSION=0.31.0 -DCLUSTER_ID=nightly -DlogLevel=DEBUG

### Delete policies in Gosec
mvn clean verify -Dgroups=delete_policy -DBOOTSTRAP_IP=10.200.0.155 -DDCOS_IP=10.200.0.156 -DDCOS_CLI_HOST=dcos-cli-nightly.demo.stratio.com -DlogLevel=DEBUG -DDISC_VERSION=0.31.0 -DREGISTERSERVICEOLD=false -DCLUSTER_ID=nightly -DDISCOVERY_POLICIES=true -DPOSTGRES_VERSION=1.3.0

### Nightly
mvn clean verify -Dgroups=nightly -DBOOTSTRAP_IP=10.200.0.155 -DDCOS_IP=10.200.0.156 -DDCOS_CLI_HOST=dcos-cli-nightly.demo.stratio.com -DDISC_VERSION=0.31.0 -DREGISTERSERVICEOLD=false -DDISCOVERY_SERVICE_VHOST=nightlypublic.labs.stratio.com -DCLUSTER_ID=nightly -DDISCOVERY_POLICIES=true -DSELENIUM_GRID=sl.demo.stratio.com:4444 -DFORCE_BROWSER=chrome_64datagov -DlogLevel=DEBUG -DPOSTGRES_VERSION=1.3.0
## For launch this group it's necessary having deployed next component:
- docker run -d --name sl selenium/hub:3.9.1 && docker run -d -v /dev/shm:/dev/shm --name docker-selenium-chrome -e HUB_HOST=sl.demo.stratio.com -e HUB_PORT=4444 -e SE_OPTS="-browser browserName=chrome,version=64datagov " selenium/node-chrome-debug:3.9.1


## Tests Command Center

### installation:
mvn clean verify -Dgroups=install_discovery_cc -DDCOS_IP=10.200.0.156 -DDCOS_CLI_HOST=dcos-cli.demo.labs.stratio.com -DCLUSTER_ID=nightly -DDISC_POSTGRES_FRAMEWORK_ID_TLS=postgrestls -DDISC_FLAVOUR=hydra -DGOSECMANAGEMENT_HOST=nightly.labs.stratio.com -DSELENIUM_GRID=sl.demo.labs.stratio.com:4444 -DFORCE_BROWSER=chrome_64aalfonso -DDISCOVERY_SERVICE_VHOST=nightlypublic.labs.stratio.com

### uninstall:
mvn clean verify -Dgroups=purge_discovery_cc -DDCOS_IP=10.200.0.156 -DDCOS_CLI_HOST=dcos-cli.demo.labs.stratio.com -DCLUSTER_ID=nightly -DGOSECMANAGEMENT_HOST=nightly.labs.stratio.com

### connection Postgres:
mvn clean verify -Dgroups=connection_PG_CCT -DDCOS_IP=10.200.0.156 -DDCOS_CLI_HOST=dcos-cli.demo.labs.stratio.com -DCLUSTER_ID=nightly -DDISC_POSTGRES_FRAMEWORK_ID_TLS=postgrestls -DDISCOVERY_SERVICE_VHOST=nightlypublic.labs.stratio.com

### connection Crossdata:
mvn clean verify -Dgroups=connection_XD_CCT -DDCOS_IP=10.200.0.156 -DDCOS_CLI_HOST=dcos-cli.demo.labs.stratio.com -DDISCOVERY_SERVICE_VHOST=nightlypublic.labs.stratio.com

### nightly:
mvn clean verify -Dgroups=CCTnightly -DDCOS_IP=10.200.0.156 -DDCOS_CLI_HOST=dcos-cli.demo.labs.stratio.com -DCLUSTER_ID=nightly -DDISC_POSTGRES_FRAMEWORK_ID_TLS=postgrestls -DDISC_FLAVOUR=hydra -DGOSECMANAGEMENT_HOST=nightly.labs.stratio.com -DSELENIUM_GRID=sl.demo.labs.stratio.com:4444 -DFORCE_BROWSER=chrome_64aalfonso -DDISCOVERY_SERVICE_VHOST=nightlypublic.labs.stratio.com

By default, in jenkins we will execute the group basic, which should contain a subset of tests, that are key to the functioning of the module and the ones generated for the new feature.

All tests, that are not fully implemented, should belong to the group manual and be tagged with '@ignore @manual'
