###################
# STAGE 1: builder
###################

# < STRATIO - recicly the jdk and clojure installation between builder and light builder
# FROM node:22-bullseye AS builder
FROM node:22-bullseye AS base
# STRATIO >

ARG MB_EDITION=oss
ARG VERSION

ENV NODE_OPTIONS="--max-old-space-size=4096"

WORKDIR /home/node

RUN apt-get update && apt-get upgrade -y && apt-get install wget apt-transport-https gpg curl git -y \
    && wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor | tee /etc/apt/trusted.gpg.d/adoptium.gpg > /dev/null \
    && echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | tee /etc/apt/sources.list.d/adoptium.list \
    && apt-get update \
    && apt install temurin-21-jdk -y \
    && curl -O https://download.clojure.org/install/linux-install-1.12.0.1488.sh \
    && chmod +x linux-install-1.12.0.1488.sh \
    && ./linux-install-1.12.0.1488.sh \
    # < STRATIO
    && apt-get clean
    # STRATIO >

# < STRATIO - recicly the jdk and clojure installation between builder and light builder
FROM base as builder
# STRATIO >

COPY . .

# version is pulled from git, but git doesn't trust the directory due to different owners
RUN git config --global --add safe.directory /home/node

# install frontend dependencies
RUN yarn --frozen-lockfile

# < STRATIO - we need the "v" before the version since metabase expects it that
# way but our Jenkins pass it without the v
RUN INTERACTIVE=false CI=true MB_EDITION=$MB_EDITION bin/build.sh :version v${VERSION}
# STRATIO >

# < STRATIO - light builder

# ######################################
# # STAGE 2: light builder
# ######################################
FROM base as lightbuilder

# Starting from version 0.43.x it is not required to add metabase java source code /home/node/java
# because drivers build scripts now do not seem to need it

# Copy metabase build and start scripts
COPY --from=builder /home/node/bin  /home/node/bin

# Copy metabase source code
COPY --from=builder /home/node/src       /home/node/src
COPY --from=builder /home/node/deps.edn  /home/node/deps.edn

# add metabase uberjar and needed drivers
COPY --from=builder /home/node/modules/drivers/hive-like /home/node/modules/drivers/hive-like
COPY --from=builder /home/node/modules/drivers/sparksql /home/node/modules/drivers/sparksql
COPY --from=builder /home/node/target/uberjar/metabase.jar /home/node/target/uberjar/metabase.jar

# STRATIO />
