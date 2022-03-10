ARG BASE=codedx/codedx-blackduckrunner:v1.20.0

FROM $BASE
USER root

# SBT versions to pre-cache
ARG SBT_VERSION=0.13.18

# Install SBT
RUN mkdir -p "/usr/local/sbt" && \
    mkdir /tmp/sbt && \
    cd /tmp/sbt && \
    curl -LO https://github.com/sbt/sbt/releases/download/v1.5.5/sbt-1.5.5.tgz && \
    tar xvf sbt-1.5.5.tgz && \
    mv sbt/* /usr/local/sbt && \
    rm -Rf /tmp/sbt

ENV PATH="/usr/local/sbt/bin:$PATH"

# Install JDK 8 by first removing JRE 11
RUN apk update && \
	apk del openjdk11-jre && \
	apk add openjdk8 && \
	apk add openjdk11-jre

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
WORKDIR /home/blackduck/.sbt/0.13/plugins
COPY build/blackduck-sbt/plugins.sbt .
WORKDIR /home/blackduck/.sbt/1.0/plugins
COPY build/blackduck-sbt/plugins.sbt .

WORKDIR /opt/codedx/blackduck/bin
