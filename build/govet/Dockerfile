# Dockerfile for codedx-govetrunner

ARG BASE=golang:1.21.3-bullseye
FROM $BASE as builder

# Create a directory to store tool findings
WORKDIR /opt/codedx/govet/work/output

# Create a directory to store scan request file in JSON format
WORKDIR /opt/codedx/govet/work/config

# Create a directory to store the PowerShell Core scripts
WORKDIR /opt/codedx/govet/script

COPY build/govet/GoVet.ps1 .
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
	DEST=/opt/codedx/govet/tools/toml2json && \
	mkdir -p $DEST && \
	tar -C $DEST -xzf $FILE  && \
	rm $FILE

ENV PATH=/opt/codedx/govet/tools/toml2json:${PATH}

# Create a new user and grant the user permissions to the /opt/codedx/govet directory content
RUN useradd -m --shell /bin/sh govet --uid 1000
RUN chown -R govet:govet /opt/codedx/govet

USER 1000

# Configure containers to run sh by default
CMD ["sh"]

