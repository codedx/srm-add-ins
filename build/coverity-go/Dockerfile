# Dockerfile for codedx-coverityrunnerbase-go

ARG BASE=codedx-coverityrunnerbase:v1.0

FROM $BASE as builder

USER root

ARG GOPACKAGE=go1.17.6.linux-amd64.tar.gz
RUN apt-get update && \
	apt-get install curl -y && \
	curl -LO https://golang.org/dl/${GOPACKAGE} && \
	ls -la && \
	tar -C /usr/local -xzf ${GOPACKAGE} && \
	rm ${GOPACKAGE}

ENV PATH=/usr/local/go/bin:${PATH}

USER coverity
