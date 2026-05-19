@Library('libpipelines') _

hose {
    EMAIL = 'rocket'
    BUILDTOOL = 'docker'
    DEVTIMEOUT = 120
    RELEASETIMEOUT = 80
    ATTIMEOUT = 90
    INSTALLTIMEOUT = 90
    VERSIONING_TYPE = "stratioVersion-3-3"
    UPSTREAM_VERSION = '0.56.4'
    BUILDTOOL_MEMORY_LIMIT = '8Gi'
    BUILDTOOL_MEMORY_REQUEST = '4Gi'

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
