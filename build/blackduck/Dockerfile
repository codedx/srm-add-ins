ARG BASE=codedx/codedx-blackduckrunnerbase:v2025.6.2
FROM $BASE AS blackduckrunnerbase

USER root

# Install PowerShell Core
ENV DEBIAN_FRONTEND=noninteractive \
	TZ=Etc/UTC
RUN apt-get update && apt-get install -y wget apt-transport-https software-properties-common curl && \
	wget -q "https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/powershell_7.4.6-1.deb_amd64.deb" && \
	dpkg -i powershell_7.4.6-1.deb_amd64.deb && \
	apt-get install -f && \
	rm powershell_7.4.6-1.deb_amd64.deb && \
	pwsh -version

WORKDIR /opt/codedx/blackduck/work/config
WORKDIR /opt/codedx/blackduck/work/output
WORKDIR /opt/codedx/blackduck/work/contents

WORKDIR /opt/codedx/blackduck/bin
COPY build/blackduck/BlackDuck.ps1 .
COPY build/common/add-in.ps1 .

# Install toml2json
RUN FILE=toml2json-linux-amd64.tar.gz && \
	curl -LO https://github.com/codedx/codedx-toml2json/releases/download/v1.1.0/$FILE && \
	DEST=/opt/codedx/blackduck/bin && \
	mkdir -p $DEST && \
	tar -C $DEST -xzf $FILE  && \
	chmod +x $DEST/toml2json && \
	rm $FILE

ENV PATH=/opt/codedx/blackduck/bin:${PATH}

RUN chown -R blackduck:blackduck /opt/codedx/blackduck

# Allow add-ins to store certificates in Java cacerts
RUN chown root:blackduck /etc/ssl/certs/java/cacerts && \
	chmod 464 /etc/ssl/certs/java/cacerts

### Start Detector Configuration ###

# Install git
RUN apt-get install -y git

# Install Maven
ARG MAVEN_VERSION=3.9.10
RUN curl -LO https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz && \
    tar -C /opt -xvf apache-maven-${MAVEN_VERSION}-bin.tar.gz && \
    rm apache-maven-${MAVEN_VERSION}-bin.tar.gz
ENV PATH="$PATH:/opt/apache-maven-3.9.1/bin"

# Install npm (latest LTS is node 18.15.0, includes npm 9.5.0)
ARG NODE_VERSION=v18.15.0
RUN apt-get install -y xz-utils && \
    curl -LO https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-x64.tar.xz && \
    mkdir -p /usr/local/lib/nodejs && \
    tar xvf node-${NODE_VERSION}-linux-x64.tar.xz -C /usr/local/lib/nodejs
ENV PATH="$PATH:/usr/local/lib/nodejs/node-${NODE_VERSION}-linux-x64/bin"

# Install pip and pipenv (python3 included in base)
RUN apt-get install -y python3-pip && \
	apt-get install -y python-is-python3 && \
	apt install -y pipenv

# Install SBT and plugin required by SBT detector
ARG SBT_VERSION=1.7.1
ARG JDK_VERSION=11 # required for SBT
RUN apt-get install -y openjdk-${JDK_VERSION}-jdk && \
    echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" | tee /etc/apt/sources.list.d/sbt.list && \
	echo "deb https://repo.scala-sbt.org/scalasbt/debian /" | tee /etc/apt/sources.list.d/sbt_old.list && \
	curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | apt-key add && \
	apt-get update && \
	apt-get install -y sbt
COPY --chown=1001:1001 build/blackduck/plugins.sbt /home/blackduck/.sbt/1.0/plugins/plugins.sbt
COPY --chown=1001:1001 build/blackduck/plugins.sbt /home/blackduck/.sbt/0.13/plugins/plugins.sbt

# Install Go
ARG GOVERSION=1.23.1
RUN cd && \
	curl -LO "https://go.dev/dl/go$GOVERSION.linux-amd64.tar.gz" && \
	tar -C /usr/local -xzf "go$GOVERSION.linux-amd64.tar.gz" && \
	rm "go$GOVERSION.linux-amd64.tar.gz"
ENV PATH="$PATH:/usr/local/go/bin"

### End Detector Configuration ###

WORKDIR /opt/codedx/blackduck/bin

USER 1001
