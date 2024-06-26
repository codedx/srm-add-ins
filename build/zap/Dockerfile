FROM golang:1.22.3-alpine3.18 as builder

ARG ZAP_VERSION=2.14.0

WORKDIR /zap

RUN apk update && apk add --no-cache wget git

# Download and expand the release
RUN wget --content-disposition https://github.com/zaproxy/zaproxy/releases/download/v${ZAP_VERSION}/ZAP_${ZAP_VERSION}_Linux.tar.gz && \
	archive=$(ls) && \
	tar zxf $archive && \
	rm $archive && \
	mv ZAP*/* . &&  \
	rm -R ZAP*

# Remove large, unwanted plugins
RUN rm -f /zap/plugin/jxbrowser*.zap

WORKDIR /opt/codedx/zap/src
COPY go.mod .
COPY cmd/zap cmd/zap
COPY pkg pkg
WORKDIR /opt/codedx/zap/src/cmd/zap
RUN go mod tidy && go build -ldflags=-w

WORKDIR /zap-git
RUN git clone --depth 1 --branch v$ZAP_VERSION https://github.com/zaproxy/zaproxy.git

# java < 15 is required as zap-api-scan and various dependencies it uses require nashorn support
FROM eclipse-temurin:11.0.21_9-jdk-alpine

WORKDIR /zap
COPY --from=builder /zap .
COPY --from=builder /zap-git/zaproxy/docker/zap-api-scan.py .
COPY --from=builder /zap-git/zaproxy/docker/zap_common.py .
COPY --from=builder /zap-git/zaproxy/docker/policies/ /home/zap/.ZAP/policies/
COPY --from=builder /zap-git/zaproxy/docker/scripts/ /home/zap/.ZAP_D/scripts/

# zap-x and Xvfb is only needed for running the ajax spider, which zap-api-scan
# doesn't do, but it will only attempt to run zap-x.sh and not zap.sh
RUN cp zap.sh zap-x.sh

WORKDIR /zap/wrk
COPY cmd/zap/auth_script_hook.py .

RUN apk update && apk add --no-cache libxslt ca-certificates bash netcat-openbsd firefox-esr python3 py3-pip
RUN pip3 install --upgrade python-owasp-zap-v2.4 urllib3

# used by zap-api-scan to check if it's running in a container
ENV IS_CONTAINERIZED true

WORKDIR /opt/codedx/zap/logs
WORKDIR /opt/codedx/zap/work/output
WORKDIR /opt/codedx/zap/licenses
COPY cmd/zap/licenses .
WORKDIR /opt/codedx/zap/bin
COPY --from=builder /opt/codedx/zap/src/cmd/zap/zap .

ENV PATH $JAVA_HOME/bin:/zap/:$PATH

RUN adduser -h /home/zap -s /bin/sh -D zap
RUN chown -R zap:zap /opt/codedx/zap
RUN chown -R zap:zap /home/zap
RUN chown -R zap:zap /zap/wrk

USER zap

# Update add-ons
RUN /zap/zap-x.sh -cmd -addonupdate

CMD ["sh"]





