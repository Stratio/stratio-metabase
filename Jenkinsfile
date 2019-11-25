@Library('libpipelines@master') _

hose {
    EMAIL = 'rocket'
    MODULE = 'discovery'
    REPOSITORY = 'discovery'
    SLACKTEAM = 'data-governance'
    BUILDTOOL = 'make'
    DEVTIMEOUT = 60
    RELEASETIMEOUT = 40
    BUILDTOOLVERSION = '3.5.0'
    NEW_VERSIONING = 'true'
    ANCHORE_TEST = true
    ATTIMEOUT = 90
    INSTALLTIMEOUT = 90

    PKGMODULESNAMES = ['discovery']

    DEV = { config ->
            doDocker(conf: config, skipOnPR: false)
    }

    INSTALLSERVICES = [

  	    ['CHROME': ['image': 'selenium/node-chrome-debug:3.9.1',
            		'volumes': ['/dev/shm:/dev/shm'],
	                'env': ['HUB_HOST=selenium391.cd','HUB_PORT=4444','SE_OPTS="-browser browserName=chrome,version=64%%JUID "']
            	       ]],
            ['DCOSCLI': ['image': 'stratio/dcos-cli:0.4.15-SNAPSHOT',
                         'env': ['DCOS_IP=10.200.0.156',
                                 'SSL=true',
                                 'SSH=true',
                                 'TOKEN_AUTHENTICATION=true',
                                 'DCOS_USER=admin',
                                 'DCOS_PASSWORD=1234',
                                 'CLI_BOOTSTRAP_USER=root',
                        	 'CLI_BOOTSTRAP_PASSWORD=stratio'],
                         'sleep':  120,
                         'healthcheck': 5000]]
    ]

    INSTALLPARAMETERS = """
        | -DDCOS_CLI_HOST=%%DCOSCLI#0
        | -DCLUSTER_ID=nightly
        | -DDCOS_IP=10.200.0.156
        | -DBOOTSTRAP_IP=10.200.0.155
        | -DSELENIUM_GRID=selenium391.cd:4444
        | -DFORCE_BROWSER=chrome_64%%JUID
        | -DREMOTE_USER=operador
	| -DDISC_POSTGRES_FRAMEWORK_ID_TLS=postgrestls
	| -DDISC_FLAVOUR=hydra
	| -DGOSECMANAGEMENT_HOST=nightly.labs.stratio.com
	| -DDISCOVERY_SERVICE_VHOST=nightlypublic.labs.stratio.com
        | -Dquietasdefault=false
        | """.stripMargin().stripIndent()

    INSTALL = { config ->
        if (config.INSTALLPARAMETERS.contains('GROUPS_DISCOVERY')) {
            config.INSTALLPARAMETERS = "${config.INSTALLPARAMETERS}".replaceAll('-DGROUPS_DISCOVERY', '-Dgroups')
            doAT(conf: config)
        } else {
            doAT(conf: config, groups: ['CCTnightly'])
        }
    }
}
