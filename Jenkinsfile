@Library('libpipelines@master') _

hose {
    EMAIL = 'discovery'
    MODULE = 'discovery'
    REPOSITORY = 'discovery'
    SLACKTEAM = 'discovery'
    BUILDTOOL = 'make'
    DEVTIMEOUT = 30
    RELEASETIMEOUT = 30

    ATTIMEOUT = 90
    INSTALLTIMEOUT = 90

    PKGMODULESNAMES = ['discovery']

    DEV = { config ->
            doDocker(conf: config, skipOnPR: false)
    }

    INSTALLSERVICES = [
            ['DCOSCLI':   ['image': 'stratio/dcos-cli:0.4.15',
                           'volumes': ['stratio/paasintegrationpem:0.1.0'],
                           'env':     ['DCOS_IP=10.200.0.205',
                                      'SSL=true',
                                      'SSH=true',
                                      'TOKEN_AUTHENTICATION=true',
                                      'DCOS_USER=admin@demo.stratio.com',
                                      'DCOS_PASSWORD=1234',
                                      'BOOTSTRAP_USER=operador',
                                      'PEM_FILE_PATH=/paascerts/PaasIntegration.pem'],
                           'sleep':  10]]
        ]

    INSTALLPARAMETERS = """
        | -DDCOS_CLI_HOST=%%DCOSCLI#0
        | -DDCOS_CLI_USER=root
        | -DDCOS_CLI_PASSWORD=stratio
        | -DDCOS_IP=10.200.0.156
        | -DBOOTSTRAP_IP=10.200.0.155
        | -DREMOTE_USER=operador
        | -DSTRATIO_POSTGRES_COMM_VERSION=0.20.0-SNAPSHOT
        | -DSTRATIO_POSTGRES_FW_VERSION=1.1.0-SNAPSHOT
        | -DPOSTGRES_ID_DISC=/postgresdisc
        | -DPOSTGRES_TENANT_NAME=postgresdisc
        | -DPOSTGRES_DCOS_SERV_NAME=postgresdisc
        | -DPOSTGRES_DCOS_PACKAGE_FW_NAME=postgres
        | -DPOSTGRES_FRAMEWORK_ID_DISC=postgresdisc
        | -DSTRATIO_DISCOVERY_VERSION=0.28.9
        | -DDISCOVERY_NAME_DB=discovery
        | """.stripMargin().stripIndent()

    INSTALL = { config ->
        if (config.INSTALLPARAMETERS.contains('GROUPS_DISCOVERY')) {
            config.INSTALLPARAMETERS = "${config.INSTALLPARAMETERS}".replaceAll('-DGROUPS_DISCOVERY', '-Dgroups')
            doAT(conf: config)
        } else {
            doAT(conf: config, groups: ['nightly'])
        }
    }
}
