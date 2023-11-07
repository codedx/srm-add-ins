# Dockerfile for codedx-golangci-lintrunner

ARG BASE=golang:1.21.3-bullseye
FROM $BASE as builder

# Create a directory to store tool findings
WORKDIR /opt/codedx/golangci-lint/work/output

# Create a directory to store scan request file in JSON format
WORKDIR /opt/codedx/golangci-lint/work/config

# Create a directory to store the PowerShell Core scripts
WORKDIR /opt/codedx/golangci-lint/script

COPY build/golangci-lint/GoLangLint.ps1 .
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
	DEST=/opt/codedx/golangci-lint/tools/toml2json && \
	mkdir -p $DEST && \
	tar -C $DEST -xzf $FILE  && \
	rm $FILE

# Install golangci-lint
RUN FILE=golangci-lint-1.42.1-linux-amd64.tar.gz && \
	curl -LO https://github.com/golangci/golangci-lint/releases/download/v1.42.1/$FILE && \
	DEST=/opt/codedx/golangci-lint/tools/golangci-lint && \
	mkdir -p $DEST && \
	tar -C $DEST --strip-components=1 -xzf $FILE && \
	rm $FILE

ENV PATH=/opt/codedx/golangci-lint/tools/toml2json:/opt/codedx/golangci-lint/tools/golangci-lint:${PATH}

# Create a new user and grant the user permissions to the /opt/codedx/golangci-lint directory content
RUN useradd -m --shell /bin/sh golangci-lint --uid 1000
RUN chown -R golangci-lint:golangci-lint /opt/codedx/golangci-lint

USER 1000

# Configure containers to run sh by default
CMD ["sh"]

