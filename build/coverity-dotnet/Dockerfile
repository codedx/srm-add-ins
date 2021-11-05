# Dockerfile for codedx-coverityrunnerbase-dotnet

ARG BASE=codedx-coverityrunnerbase:v1.0

FROM $BASE as builder

USER root

RUN apt-get update && \
	apt-get install wget -y

# Install .NET Core SDK 2.1
RUN wget -q https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb && \
	dpkg -i packages-microsoft-prod.deb && \
	apt-get update && \
	apt-get install -y apt-transport-https && \
	apt-get update && \
	apt-get install -y dotnet-sdk-2.1 && \
	rm packages-microsoft-prod.deb

# Install .NET Core SDK 3.1
RUN apt-get install -y dotnet-sdk-3.1

# Install .NET Core SDK 5.0
RUN apt-get install -y dotnet-sdk-5.0

USER coverity
