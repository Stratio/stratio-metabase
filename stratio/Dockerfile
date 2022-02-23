###################
# STAGE 1: builder
###################

# < STRATIO - changing base image to one found in our nexus
FROM openjdk:11.0.12-jdk-slim as builder
# STRATIO />

WORKDIR /app/source

ENV DEBIAN_FRONTEND=noninteractive

# installing Clojure and Clojure CLI
RUN apt-get update && apt-get upgrade -y && apt-get install -y wget curl \
    && curl -O https://download.clojure.org/install/linux-install-1.10.3.1040.sh \
    && chmod +x linux-install-1.10.3.1040.sh \
    && ./linux-install-1.10.3.1040.sh \
    # install Node LTS and Yarn from their repos
    && curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && wget https://dl.yarnpkg.com/debian/pubkey.gpg && cat pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && apt-get update && apt-get install --no-install-recommends -y git nodejs yarn \
    && apt-get clean

# add the the source
COPY . .

# build the app
RUN INTERACTIVE=false bin/build


# < STRATIO - light builder

# ######################################
# # STAGE 2: light builder
# ######################################
FROM openjdk:11.0.12-jdk-slim as lightbuilder

# installing Clojure and Clojure CLI
RUN apt-get update && apt-get upgrade -y && apt-get install -y curl git \
    && curl -O https://download.clojure.org/install/linux-install-1.10.3.1040.sh \
    && chmod +x linux-install-1.10.3.1040.sh \
    && ./linux-install-1.10.3.1040.sh \
    && apt-get clean

# Copy metabase java source code to (drivers build scripts seem to need it)
COPY --from=builder /app/source/java /app/source/java

# Copy metabase build and start scripts
COPY --from=builder /app/source/bin  /app/source/bin

# add metabase uberjar
COPY --from=builder /app/source/target/uberjar/metabase.jar /app/source/target/uberjar/metabase.jar

# STRATIO />
