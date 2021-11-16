@Library('libpipelines') _

hose {
    EMAIL = 'rocket'
    BUILDTOOL = 'docker'
    DEVTIMEOUT = 120
    RELEASETIMEOUT = 80
    ATTIMEOUT = 90
    INSTALLTIMEOUT = 90
    FREESTYLE_BRANCHING = true
    UPSTREAM_VERSION = '0.40.2'

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
