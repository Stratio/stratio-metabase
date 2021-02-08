###################
# STAGE 1: builder
###################

# < STRATIO - changing base image to one found in our nexus
# # Build currently doesn't work on > Java 11 (i18n utils are busted) so build on 8 until we fix this
# FROM adoptopenjdk/openjdk8:alpine as builder
FROM openjdk:8-jdk-alpine3.9 as builder
# STRATIO />

WORKDIR /app/source

ENV FC_LANG en-US
ENV LC_CTYPE en_US.UTF-8

# bash:    various shell scripts
# wget:    installing lein (TODO -- is this actually needed? We don't use wget directly)
# curl:    needed by script that installs Clojure CLI
# git:     ./bin/version
# yarn:    frontend building
# make:    backend building (TODO -- huh? We don't use Make to build the backend)
# gettext: translations
# java-cacerts: installs updated cacerts to /etc/ssl/certs/java/cacerts

RUN apk add --update coreutils bash yarn git wget curl make gettext java-cacerts

# lein:    backend dependencies and building
ADD https://raw.github.com/technomancy/leiningen/stable/bin/lein /usr/local/bin/lein
RUN chmod 744 /usr/local/bin/lein
RUN lein upgrade

# Clojure CLI (needed for some build scripts)
ADD https://download.clojure.org/install/linux-install-1.10.1.708.sh /tmp/linux-install-1.10.1.708.sh
RUN chmod +x /tmp/linux-install-1.10.1.708.sh
RUN /tmp/linux-install-1.10.1.708.sh

# install dependencies before adding the rest of the source to maximize caching

# backend dependencies
ADD project.clj .
RUN lein deps

# frontend dependencies
ADD yarn.lock package.json .yarnrc ./
RUN yarn

# add the rest of the source
ADD . .

# build the app
RUN INTERACTIVE=false bin/build

# import AWS RDS cert into /etc/ssl/certs/java/cacerts
ADD https://s3.amazonaws.com/rds-downloads/rds-combined-ca-bundle.pem .
RUN keytool -noprompt -import -trustcacerts -alias aws-rds \
  -file rds-combined-ca-bundle.pem \
  -keystore /etc/ssl/certs/java/cacerts \
  -keypass changeit -storepass changeit





# < STRATIO - light builder

# ######################################
# # STAGE 2: light builder
# ######################################
FROM openjdk:8-jdk-alpine3.9 as lightbuilder

# bash:    various shell scripts
# curl:    needed by script that installs Clojure CLI
RUN apk add --update coreutils bash curl

# lein:    backend dependencies and building
ADD https://raw.github.com/technomancy/leiningen/stable/bin/lein /usr/local/bin/lein
RUN chmod 744 /usr/local/bin/lein
RUN lein upgrade

# Clojure CLI (needed for some build scripts)
ADD https://download.clojure.org/install/linux-install-1.10.1.708.sh /tmp/linux-install-1.10.1.708.sh
RUN chmod +x /tmp/linux-install-1.10.1.708.sh
RUN /tmp/linux-install-1.10.1.708.sh

# Copy local .m2 metabase-core to be able to build drivers
COPY --from=builder /root/.m2/repository/metabase-core /root/.m2/repository/metabase-core

# Copy metabase source files (needed to calculate checksum to skip rebuild of matabase-core and uberjar)
COPY --from=builder /app/source/project.clj             /app/source/project.clj
COPY --from=builder /app/source/src                     /app/source/src
COPY --from=builder /app/source/enterprise/backend/src  /app/source/enterprise/backend/src
COPY --from=builder /app/source/backend/mbql            /app/source/backend/mbql

# Copy lein command to strip and compress driver jars
COPY --from=builder /app/source/lein-commands           /app/source/lein-commands

# Copy metabase build and start scripts
COPY --from=builder /app/source/bin  /app/source/bin

# add metabase uberjar
COPY --from=builder /app/source/target/uberjar/metabase.jar /app/source/target/uberjar/metabase.jar

# add fixed cacerts
COPY --from=builder /etc/ssl/certs/java/cacerts /etc/ssl/certs/java/cacerts

# STRATIO />
