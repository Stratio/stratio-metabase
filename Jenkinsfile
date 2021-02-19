@Library('libpipelines@master') _

hose {
    EMAIL = 'rocket'
    MODULE = 'discovery'
    REPOSITORY = 'discovery'
    BUILDTOOL = 'make'
    DEVTIMEOUT = 120
    RELEASETIMEOUT = 80
    BUILDTOOLVERSION = '3.5.0'
    NEW_VERSIONING = 'true'
    ATTIMEOUT = 90
    INSTALLTIMEOUT = 90
    ANCHORE_TEST = false
    ANCHORE_POLICY = 'discovery'
    PKGMODULESNAMES = ['discovery']
    FREESTYLE_BRANCHING = true

    DEV = { config ->
        doDockers(
            conf : config,
            dockerImages :[
                [
                    image : "stratio-metabase-builder",
                    dockerfile : "stratio/Dockerfile",
                    conf : config
                ]
            ]
        )
    }
}
