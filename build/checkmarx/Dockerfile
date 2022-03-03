FROM mcr.microsoft.com/powershell:7.2.1-alpine-3.13-20220223

WORKDIR /opt/codedx/checkmarx/work/config
WORKDIR /opt/codedx/checkmarx/work/output

WORKDIR /opt/codedx/checkmarx/bin
COPY build/checkmarx/Checkmarx.ps1 .
COPY build/common/add-in.ps1 .

RUN  apk update && apk add curl

RUN FILE=toml2json-linux-alpine.tar.gz && \
	curl -LO https://github.com/codedx/codedx-toml2json/releases/download/v1.0.0/$FILE && \
	DEST=/opt/codedx/checkmarx/bin && \
	mkdir -p $DEST && \
	tar -C $DEST -xzf $FILE  && \
	rm $FILE

ENV PATH=/opt/codedx/checkmarx/bin:${PATH}

RUN adduser -h /home/checkmarx -s /bin/sh -D checkmarx -u 1000
RUN chown -R checkmarx:checkmarx /opt/codedx/checkmarx

USER 1000

CMD ["sh"]
