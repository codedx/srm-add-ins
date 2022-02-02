FROM golang:1.17.6-buster as builder

WORKDIR /tmp/build
COPY go.mod .
COPY cmd/testconnect cmd/testconnect
COPY pkg pkg
WORKDIR /tmp/build/cmd/testconnect
RUN go mod tidy && go build -ldflags=-w

RUN apt update && apt install -y apt-transport-https ca-certificates wget dirmngr gnupg software-properties-common
RUN wget -qO - https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public | apt-key add -
RUN add-apt-repository --yes https://adoptopenjdk.jfrog.io/adoptopenjdk/deb/
RUN apt update && apt install -y adoptopenjdk-8-hotspot maven

WORKDIR /tmp/build/burpsuite
COPY build/burpsuite .
WORKDIR /tmp/build/burpsuite/extender
RUN mvn package

FROM mcr.microsoft.com/powershell:lts-debian-10-20211215

RUN apt update && mkdir -p /usr/share/man/man1 && apt install -y default-jre curl

WORKDIR /opt/codedx/burpsuite/work/config
WORKDIR /opt/codedx/burpsuite/work/output

WORKDIR /opt/codedx/burpsuite/bin
COPY build/burpsuite/BurpSuite.ps1 .
COPY build/common/add-in.ps1 .

# Install toml2json
RUN FILE=toml2json-linux-amd64.tar.gz && \
	curl -LO https://github.com/codedx/codedx-toml2json/releases/download/v1.0.0/$FILE && \
	DEST=/opt/codedx/burpsuite/bin && \
	mkdir -p $DEST && \
	tar -C $DEST -xzf $FILE  && \
	rm $FILE

COPY --from=builder /tmp/build/cmd/testconnect/testconnect .
COPY --from=builder /tmp/build/burpsuite/extender/target/generate-report-burp-extension-1.0.0.jar .

ENV PATH=/opt/codedx/burpsuite/bin:${PATH}

RUN useradd -m --shell /bin/sh burpsuite --uid 1000
RUN chown -R burpsuite:burpsuite /opt/codedx/burpsuite

USER 1000

CMD ["sh"]
