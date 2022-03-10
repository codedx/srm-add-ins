ARG BASE=codedx/codedx-blackduckrunner:v1.20.0

FROM $BASE
USER root

# Install .NET Core SDKs (required for NuGet analysis)
RUN cd /tmp && \
    curl -LO https://dot.net/v1/dotnet-install.sh && \
    chmod +x dotnet-install.sh && \
    ./dotnet-install.sh --install-dir /usr/share/dotnet -c 2.1 && \
    ./dotnet-install.sh --install-dir /usr/share/dotnet -c 3.1 && \
    ./dotnet-install.sh --install-dir /usr/share/dotnet -c 5.0 && \
    rm /tmp/dotnet-install.sh && \
    ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet

USER blackduck
