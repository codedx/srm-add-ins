FROM mcr.microsoft.com/dotnet/sdk:7.0.403

WORKDIR /tmp

# Install PowerShell Core
RUN apt update && \
	apt install -y curl gnupg apt-transport-https && \
	curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
	sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-debian-bullseye-prod bullseye main" > /etc/apt/sources.list.d/microsoft.list' && \
	apt update && \
	apt install -y powershell

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
	curl -LO https://github.com/codedx/codedx-toml2json/releases/download/v1.0.0/$FILE && \
	DEST=/opt/codedx/securitycodescan/script && \
	mkdir -p $DEST && \
	tar -C $DEST -xzf $FILE  && \
	rm $FILE

ENV PATH=/opt/codedx/securitycodescan/script:${PATH}

# Create a new user and grant the user permissions to the /opt/codedx/securitycodescan directory content
RUN useradd -m --shell /bin/sh securitycodescan --uid 1000
RUN chown -R securitycodescan:securitycodescan /opt/codedx/securitycodescan

USER 1000

# Configure containers to run sh by default
CMD ["sh"]
