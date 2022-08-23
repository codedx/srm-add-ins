ARG BASE=codedx/codedx-blackduckrunner:v1.0

FROM $BASE
USER root

# SBT versions to pre-cache
ARG SBT_VERSION=1.7.1

# Install SBT
RUN mkdir -p "/usr/local/sbt" && \
    mkdir /tmp/sbt && \
    cd /tmp/sbt && \
    curl -LO https://github.com/sbt/sbt/releases/download/v${SBT_VERSION}/sbt-${SBT_VERSION}.tgz && \
    tar xvf sbt-${SBT_VERSION}.tgz && \
    mv sbt/* /usr/local/sbt && \
    rm -Rf /tmp/sbt

ENV PATH="/usr/local/sbt/bin:$PATH"

# Install JDK 11
RUN apk add openjdk11

# Allow add-ins to store certificates in Java cacerts
RUN chown root:blackduck /etc/ssl/certs/java/cacerts && \
	chmod 464 /etc/ssl/certs/java/cacerts

# Install git
RUN apk add git

# Install grunt-cli
RUN npm install -g grunt-cli

USER blackduck

# cache SBT version as user blackduck
RUN mkdir /tmp/sbt && \
	cd /tmp/sbt && \
	sbt -Dsbt.version=$SBT_VERSION about && \
	rm -Rf /tmp/sbt

# add SBT dependency graph plugin required by Detect
WORKDIR /home/blackduck/.sbt/1.0/plugins
COPY build/blackduck-sbt-java11/plugins-1.0.sbt ./plugins.sbt

WORKDIR /opt/codedx/blackduck/bin
