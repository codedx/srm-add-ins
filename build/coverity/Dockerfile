# Dockerfile for codedx-coverityrunnerbase

FROM debian:buster-20230227

ARG COVERITY_HOME=/opt/sw/synopsys/coverity

RUN apt-get update && \
	apt-get install -y wget curl

# Install pwsh
RUN wget https://packages.microsoft.com/config/debian/10/packages-microsoft-prod.deb && \
	dpkg -i packages-microsoft-prod.deb && \
	apt-get update && \
	apt-get install -y powershell && \
	rm packages-microsoft-prod.deb && \
	pwsh -version

ENV VENDOR=Synopsys \
	COVERITY_HOME=$COVERITY_HOME

RUN mkdir -p "${COVERITY_HOME}/bin" && \
	useradd -ms /bin/bash -u 1001 coverity && \
	chown -R coverity:coverity "${COVERITY_HOME}"

ENV PATH=${COVERITY_HOME}/bin:${PATH}

COPY --chown=coverity:coverity build/coverity/LICENSE /home/coverity/LICENSE

# Install toml2json
RUN FILE=toml2json-linux-amd64.tar.gz && \
	curl -LO https://github.com/codedx/codedx-toml2json/releases/download/v1.0.0/$FILE && \
	DEST=/opt/codedx/coverity/script && \
	mkdir -p $DEST && \
	tar -C $DEST -xzf $FILE  && \
	rm $FILE

USER coverity

# Create a directory to store tool findings
WORKDIR /opt/codedx/coverity/work/output

# Create a directory to store scan request file in JSON format
WORKDIR /opt/codedx/coverity/work/config

# Create an intermediate directory
WORKDIR /opt/codedx/coverity/idir

# Create a directory to store the PowerShell Core scripts
WORKDIR /opt/codedx/coverity/script

# Copy Coverity.ps1 to the script directory
COPY --chown=coverity:coverity build/coverity/Coverity.ps1 .
COPY --chown=coverity:coverity build/common/add-in.ps1 .

ENV PATH=/opt/codedx/coverity/script:${PATH}

USER root
RUN chown -R coverity:coverity /opt/codedx
USER coverity

# Configure containers to run sh by default
CMD ["sh"]
