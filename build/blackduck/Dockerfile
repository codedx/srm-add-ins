FROM codedx/codedx-blackduckrunnerbase:v2022.10.0
USER root

# Install .NET and powershell requirements
RUN apk add --no-cache \
    ca-certificates \
    less \
    ncurses-terminfo-base \
    krb5-libs \
    libgcc \
    libintl \
    libssl1.1 \
    libstdc++ \
    tzdata \
    userspace-rcu \
    zlib \
    icu-libs \
    zip && \
    apk -X https://dl-cdn.alpinelinux.org/alpine/edge/main add --no-cache lttng-ust

# Install powershell
RUN wget -O powershell.tar.gz https://github.com/PowerShell/PowerShell/releases/download/v7.2.1/powershell-7.2.1-linux-alpine-x64.tar.gz && \
	mkdir -p /opt/microsoft/powershell/7 && \
	tar zxf powershell.tar.gz -C /opt/microsoft/powershell/7 && \
	chmod +x /opt/microsoft/powershell/7/pwsh && \
	ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh && \
	export POWERSHELL_TELEMETRY_OPTOUT=1 && \
	rm powershell.tar.gz

# Install gradle
RUN wget -O gradle-bin.zip https://services.gradle.org/distributions/gradle-7.3.3-bin.zip && \
	unzip gradle-bin.zip && \
	mkdir -p /usr/share/gradle && \
	mv gradle-*/* /usr/share/gradle && \
	rm -r gradle-* && \
	ln -s /usr/share/gradle/bin/gradle /usr/local/bin/gradle

RUN apk add --no-cache npm

WORKDIR /opt/codedx/blackduck/work/config
WORKDIR /opt/codedx/blackduck/work/output
WORKDIR /opt/codedx/blackduck/work/contents

WORKDIR /opt/codedx/blackduck/bin
COPY build/blackduck/BlackDuck.ps1 .
COPY build/common/add-in.ps1 .

# Install toml2json
RUN FILE=toml2json-linux-alpine.tar.gz && \
	curl -LO https://github.com/codedx/codedx-toml2json/releases/download/v1.0.0/$FILE && \
	DEST=/opt/codedx/blackduck/bin && \
	mkdir -p $DEST && \
	tar -C $DEST -xzf $FILE  && \
	rm $FILE

ENV PATH=/opt/codedx/blackduck/bin:${PATH}

RUN chown -R blackduck:blackduck /opt/codedx/blackduck

# Allow add-ins to store certificates in Java cacerts
RUN chown root:blackduck /etc/ssl/certs/java/cacerts && \
	chmod 464 /etc/ssl/certs/java/cacerts

USER 1000
