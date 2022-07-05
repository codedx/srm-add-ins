# Dockerfile for codedx-gosecrunner

ARG BASE=golang:1.18.3-buster
FROM $BASE as builder

# Create a directory to store tool findings
WORKDIR /opt/codedx/gosec/work/output

# Create a directory to store scan request file in JSON format
WORKDIR /opt/codedx/gosec/work/config

# Create a directory to store the PowerShell Core scripts
WORKDIR /opt/codedx/gosec/script

COPY build/gosec/GoSec.ps1 .
COPY build/common/add-in.ps1 .

# Install PowerShell Core
RUN wget https://packages.microsoft.com/config/debian/10/packages-microsoft-prod.deb && \
	dpkg -i packages-microsoft-prod.deb && \
	apt-get update && \
	apt-get install -y powershell && \
	rm packages-microsoft-prod.deb

# Install toml2json
RUN FILE=toml2json-linux-amd64.tar.gz && \
	curl -LO https://github.com/codedx/codedx-toml2json/releases/download/v1.0.0/$FILE && \
	DEST=/opt/codedx/gosec/tools/toml2json && \
	mkdir -p $DEST && \
	tar -C $DEST -xzf $FILE  && \
	rm $FILE

# Install gosec
ARG GOSEC_VERSION=2.11.0
RUN FILE=gosec_${GOSEC_VERSION}_linux_amd64.tar.gz && \
	curl -LO https://github.com/securego/gosec/releases/download/v${GOSEC_VERSION}/$FILE && \
	DEST=/opt/codedx/gosec/tools/gosec && \
	mkdir -p $DEST && \
	tar -C $DEST -xzf $FILE && \
	rm $FILE

ENV PATH=/opt/codedx/gosec/tools/toml2json:/opt/codedx/gosec/tools/gosec:${PATH}

# Create a new user and grant the user permissions to the /opt/codedx/gosec directory content
RUN useradd -m --shell /bin/sh gosec --uid 1000
RUN chown -R gosec:gosec /opt/codedx/gosec

USER 1000

# Configure containers to run sh by default
CMD ["sh"]

