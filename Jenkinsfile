@Library('libpipelines@master') _

hose {
    EMAIL = 'rocket'
    MODULE = 'discovery'
    REPOSITORY = 'discovery'
    SLACKTEAM = 'data-governance'
    BUILDTOOL = 'make'
    DEVTIMEOUT = 120
    RELEASETIMEOUT = 80
    BUILDTOOLVERSION = '3.5.0'
    NEW_VERSIONING = 'true'
    ATTIMEOUT = 90
    INSTALLTIMEOUT = 90
    ANCHORE_POLICY = 'discovery'
    ANCHORE_TEST = false
    PKGMODULESNAMES = ['discovery']

    DEV = { config ->
        doDocker(conf: config, skipOnPR: false)
    }

    INSTALLSERVICES = [

  	    ['CHROME': ['image': 'selenium/node-chrome-debug:3.9.1',
            		'volumes': ['/dev/shm:/dev/shm'],
	                'env': ['HUB_HOST=selenium391.cd','HUB_PORT=4444','SE_OPTS="-browser browserName=chrome,version=64%%JUID "']
            	       ]],
    ]

    INSTALLPARAMETERS = """
        | -DREMOTE_USER=\$PEM_VMWARE_USER
        | -DSELENIUM_GRID=selenium391.cd:4444
        | -DFORCE_BROWSER=chrome_64%%JUID
        | """.stripMargin().stripIndent()

    ATCREDENTIALS = [[TYPE:'sshKey', ID:'PEM_VMWARE']]

    INSTALL = { config, params ->
        def ENVIRONMENTMAP = stringToMap(params.ENVIRONMENT)
        def pempathhetzner = ""
        pempathhetzner = """${params.ENVIRONMENT}
            |PEM_FILE_PATH=\$PEM_VMWARE_PATH
            |""".stripMargin().stripIndent()

        def PATHHETZNER = stringToMap(pempathhetzner)
        def PATHHETZNERINSTALL = doReplaceTokens(INSTALLPARAMETERS.replaceAll(/\n/, ''), PATHHETZNER)

        def pempathvmware = ""
        pempathvmware = """${params.ENVIRONMENT}
            |PEM_FILE_PATH=\$PEM_VMWARE_KEY
            |""".stripMargin().stripIndent()

        def PATHVMWARE = stringToMap(pempathvmware)
        def PATHVMWAREINSTALL = doReplaceTokens(INSTALLPARAMETERS.replaceAll(/\n/, ' '), PATHVMWARE)

        if (config.INSTALLPARAMETERS.contains('GROUPS_DISCOVERY')) {
          if (params.ENVIRONMENT.contains('HETZNER_CLUSTER')) {
            PATHHETZNERINSTALL = "${PATHHETZNERINSTALL}".replaceAll('-DGROUPS_DISCOVERY', '-Dgroups')
            doAT(conf: config, parameters: PATHHETZNERINSTALL, environmentAuth: ENVIRONMENTMAP['HETZNER_CLUSTER'])
          } else {
            PATHVMWAREINSTALL = "${PATHVMWAREINSTALL}".replaceAll('-DGROUPS_DISCOVERY', '-Dgroups')
            doAT(conf: config, parameters: PATHVMWAREINSTALL)
          }
        } else {
          if (params.ENVIRONMENT.contains('HETZNER_CLUSTER')) {
            doAT(conf: config, groups: ['nightly'], parameters: PATHHETZNERINSTALL, environmentAuth: ENVIRONMENTMAP['HETZNER_CLUSTER'])
          } else {
            doAT(conf: config, groups: ['nightly'], parameters: PATHVMWAREINSTALL)
          }
        }
    }

}
