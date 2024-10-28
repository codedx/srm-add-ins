# Dockerfile for codedx-staticcheckrunner

ARG BASE=golang:1.23.2-bullseye
FROM $BASE as builder

# Create a directory to store tool findings
WORKDIR /opt/codedx/staticcheck/work/output

# Create a directory to store scan request file in JSON format
WORKDIR /opt/codedx/staticcheck/work/config

# Create a directory to store the PowerShell Core scripts
WORKDIR /opt/codedx/staticcheck/script

COPY build/staticcheck/StaticCheck.ps1 .
COPY build/common/add-in.ps1 .

# Install PowerShell Core
RUN wget https://packages.microsoft.com/config/debian/11/packages-microsoft-prod.deb && \
	dpkg -i packages-microsoft-prod.deb && \
	apt-get update && \
	apt-get install -y powershell && \
	rm packages-microsoft-prod.deb

# Install toml2json
RUN FILE=toml2json-linux-amd64.tar.gz && \
	curl -LO https://github.com/codedx/codedx-toml2json/releases/download/v1.1.0/$FILE && \
	DEST=/opt/codedx/staticcheck/tools/toml2json && \
	mkdir -p $DEST && \
	tar -C $DEST -xzf $FILE  && \
	chmod +x $DEST/toml2json && \
	rm $FILE

# Install staticcheck
RUN FILE=staticcheck_linux_amd64.tar.gz && \
	curl -LO https://github.com/dominikh/go-tools/releases/download/2024.1.1/$FILE && \
	DEST=/opt/codedx/staticcheck/tools/staticcheck && \
	mkdir -p $DEST && \
	tar -C $DEST --strip-components=1 -xzf $FILE && \
	rm $FILE

ENV PATH=/opt/codedx/staticcheck/tools/toml2json:/opt/codedx/staticcheck/tools/staticcheck:${PATH}

# Create a new user and grant the user permissions to the /opt/codedx/staticcheck directory content
RUN useradd -m --shell /bin/sh staticcheck --uid 1000
RUN chown -R staticcheck:staticcheck /opt/codedx/staticcheck

USER 1000

# Configure containers to run sh by default
CMD ["sh"]

