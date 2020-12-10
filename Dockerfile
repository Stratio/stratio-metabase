###################
# STAGE 1: builder
###################

# FROM openjdk:8-jdk-alpine as builder
FROM openjdk:8-jdk-alpine3.9 as builder

WORKDIR /app/source

ENV FC_LANG en-US
ENV LC_CTYPE en_US.UTF-8

# bash:    various shell scripts
# wget:    installing lein
# git:     ./bin/version
# yarn:  frontend building
# make:    backend building
# gettext: translations

RUN apk add --update bash git wget make gettext yarn coreutils

ADD . /app/source

# import Crossdata and defaultSecrets
RUN mkdir /root/.crossdata/ && \
    mkdir /root/defaultsecrets/ && \
    mv /app/source/resources/security/* /root/defaultsecrets/. && \
    mkdir /root/kms/ && \
    mv  /app/source/resources/kms/* /root/kms/.


# lein:    backend dependencies and building
ADD https://raw.github.com/technomancy/leiningen/stable/bin/lein /usr/local/bin/lein
RUN chmod 744 /usr/local/bin/lein
RUN lein upgrade

# install dependencies before adding the rest of the source to maximize caching

# backend dependencies
ADD project.clj .
RUN lein deps

# frontend dependencies
RUN yarn -version
ADD yarn.lock package.json .yarnrc ./
RUN yarn

# add the rest of the source
ADD . .

# build the app
RUN bin/build

# install updated cacerts to /etc/ssl/certs/java/cacerts
RUN apk add --update java-cacerts

# import AWS RDS cert into /etc/ssl/certs/java/cacerts
ADD https://s3.amazonaws.com/rds-downloads/rds-combined-ca-bundle.pem .
RUN keytool -noprompt -import -trustcacerts -alias aws-rds \
  -file rds-combined-ca-bundle.pem \
  -keystore /etc/ssl/certs/java/cacerts \
  -keypass changeit -storepass changeit


# ###################
# # STAGE 2: runner
# ###################

# FROM adoptopenjdk/openjdk11:alpine-jre as runner
FROM qa.int.stratio.com/stratio/oauth-base:0.1.0-ff962c7 as runner

WORKDIR /app

ENV FC_LANG en-US
ENV LC_CTYPE en_US.UTF-8

# dependencies
RUN apt-get update \
  &&  apt-get install -y ttf-dejavu fontconfig wget \
  && apt-get --only-upgrade install -y libfreetype6 libssl1.1 libssl1.0.0 openssl\
  && apt-get -qq clean \
  && rm -rf /var/lib/apt/lists/*

# RUN apk add --update bash ttf-dejavu fontconfig && \
#     apk add --update curl && \
#     apk add --update jq && \
#     apk add --update openssl && \
#     rm -rf /var/cache/apk/*

# ***************************************************************
#   Install JAVA - 1.8.0
# ***************************************************************
RUN wget http://tools.stratio.com/jdk/jdk-8u131-linux-x64.tar.gz \
  && tar zfx jdk-8u131-linux-x64.tar.gz -C /usr/local/ \
  && rm -rf $JAVA_HOME/man \
  && rm jdk-8u131-linux-x64.tar.gz
ENV JAVA_HOME=/usr/local/jdk1.8.0_131
ENV PATH=$JAVA_HOME/bin:$PATH

# add fixed cacerts
# COPY --from=builder /etc/ssl/certs/java/cacerts /usr/lib/jvm/default-jvm/jre/lib/security/cacerts
COPY --from=builder /etc/ssl/certs/java/cacerts /usr/local/jdk1.8.0_131/jre/lib/security/cacerts

# add Metabase script and uberjar
RUN mkdir -p bin target/uberjar && \
    mkdir -p bin /root/.crossdata/
COPY --from=builder /app/source/target/uberjar/metabase.jar /app/target/uberjar/
ENV DISCOVERY_CICD_VERSION=1.3.0-5ad831f
ADD http://niquel.stratio.com/repository/releases/com/stratio/discoverycicd/${DISCOVERY_CICD_VERSION}/discoverycicd-${DISCOVERY_CICD_VERSION}-uber.jar /app/target/uberjar/discovery-cicd.jar
COPY --from=builder /app/source/bin/prometheus/config.yaml /app/target/uberjar/
COPY --from=builder /app/source/bin/prometheus/jmx_prometheus_javaagent-0.12.0.jar_temp /app/target/uberjar/jmx_prometheus_javaagent-0.12.0.jar
COPY --from=builder /app/source/bin/start /app/bin/
COPY --from=builder /app/source/resources/log4j2.xml /app/target/log/
COPY --from=builder /root/defaultsecrets/* /root/defaultsecrets/
COPY --from=builder /root/kms/* /root/kms/

# create the plugins directory, with writable permissions
RUN mkdir -p /plugins
RUN chmod a+rwx /plugins

# add scripts and conf for oauth-base (proxy with sso authenticatin) integration
# Set up our "pre" rc.local to set some enviroment variables to the oauth-base rc.local
RUN  mv /etc/rc.local /etc/rc.local.base
COPY /oauth-proxy-integration/rc.local /etc/rc.local
COPY /oauth-proxy-integration/docker-entrypoint.sh /docker-entrypoint.sh
COPY /oauth-proxy-integration/metabase-service /etc/service/metabase
RUN chmod +x /etc/service/metabase/run /etc/rc.local
COPY /oauth-proxy-integration/nginx-confs/* /usr/local/openresty/nginx/conf/

# add scripts for discovery-cicd-integration
COPY /discovery-cicd-integration/discovery-cicd-service /etc/service/discovery-cicd
RUN chmod +x /etc/service/discovery-cicd/run

# run it
# ENTRYPOINT ["/app/bin/start"]
