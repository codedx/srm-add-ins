# Includes PowerShell Core
FROM mcr.microsoft.com/dotnet/sdk:8.0

WORKDIR /tmp

# Create a directory to store tool findings
WORKDIR /opt/codedx/securitycodescan/work/output

# Create a directory to store scan request file in JSON format
WORKDIR /opt/codedx/securitycodescan/work/config

# Create a directory to store the PowerShell Core scripts
WORKDIR /opt/codedx/securitycodescan/script

# Copy SecurityCodeScan.ps1 to the script directory
COPY build/securitycodescan/SecurityCodeScan.ps1 .
COPY build/common/add-in.ps1 .

# Install toml2json
RUN FILE=toml2json-linux-amd64.tar.gz && \
	curl -LO https://github.com/codedx/codedx-toml2json/releases/download/v1.1.0/$FILE && \
	DEST=/opt/codedx/securitycodescan/script && \
	mkdir -p $DEST && \
	tar -C $DEST -xzf $FILE  && \
	chmod +x $DEST/toml2json && \
	rm $FILE

ENV PATH=/opt/codedx/securitycodescan/script:${PATH}

# Create a new user and grant the user permissions to the /opt/codedx/securitycodescan directory content
RUN useradd -m --shell /bin/sh securitycodescan --uid 1000
RUN chown -R securitycodescan:securitycodescan /opt/codedx/securitycodescan

USER 1000

# Configure containers to run sh by default
CMD ["sh"]
