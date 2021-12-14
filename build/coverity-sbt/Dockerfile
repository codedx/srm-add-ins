# Dockerfile for codedx-coverityrunnerbase-sbt

ARG BASE=codedx-coverityrunnerbase:v1.0

FROM $BASE as builder

USER root

# SBT versions to pre-cache
ARG SBT_VERSION=0.13.18
ARG NODE_VERSION=12.x

RUN apt-get update && \
	apt-get install -y curl gnupg-agent

# Install SBT, nodesj, and grunt-cli
RUN echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" | tee /etc/apt/sources.list.d/sbt.list && \
	echo "deb https://repo.scala-sbt.org/scalasbt/debian /" | tee /etc/apt/sources.list.d/sbt_old.list && \
	curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | apt-key add && \
	curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}" | bash - && \
	apt-get update && \
	apt-get install -y sbt nodejs && \
	npm install -g grunt-cli && \
	apt-get clean

# Install Java
RUN curl -LO https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u302-b08/OpenJDK8U-jdk_x64_linux_hotspot_8u302b08.tar.gz && \
	tar xvf OpenJDK8U-jdk_x64_linux_hotspot_8u302b08.tar.gz -C /opt && \
	rm OpenJDK8U-jdk_x64_linux_hotspot_8u302b08.tar.gz
ENV PATH=/opt/jdk8u302-b08/bin:$PATH

USER coverity

# cache SBT version as user coverity
RUN mkdir /tmp/sbt && \
	cd /tmp/sbt && \
	sbt -Dsbt.version=$SBT_VERSION about && \
	rm -Rf /tmp/sbt
