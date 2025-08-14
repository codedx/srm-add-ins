FROM golang:1.24.6-alpine3.21 AS builder

ARG ZAP_VERSION=2.16.0

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
FROM eclipse-temurin:17.0.16_8-jdk-alpine-3.21

WORKDIR /zap
COPY --from=builder /zap .
COPY --from=builder /zap-git/zaproxy/docker/zap-api-scan.py .
COPY --from=builder /zap-git/zaproxy/docker/zap_common.py .

# zap-x and Xvfb is only needed for running the ajax spider, which zap-api-scan
# doesn't do, but it will only attempt to run zap-x.sh and not zap.sh
RUN cp zap.sh zap-x.sh

WORKDIR /zap/wrk

# to support a read-only root filesystem, auth_script_hook.py starts in /zap-data and
# will be copied to /zap/wrk at runtime to support API scans. profile data will be
# copied to the profile of the user running the container, which may not be the "zap"
# user
WORKDIR /zap-data
COPY cmd/zap/auth_script_hook.py .
COPY --from=builder /zap-git/zaproxy/docker/policies/ /zap-data/profile/.ZAP/policies/
COPY --from=builder /zap-git/zaproxy/docker/scripts/  /zap-data/profile/.ZAP_D/scripts/

RUN apk update && apk add --no-cache libxslt ca-certificates bash netcat-openbsd firefox python3

# install urllib3, setuptools, and six package with apk instead of pip3
RUN apk add py3-urllib3 py3-setuptools py3-six

# create and use a virtual environment for python-owasp-zap-v2.4
WORKDIR /opt/python
RUN python3 -m venv --system-site-packages /opt/python
RUN /opt/python/bin/pip3 install --upgrade python-owasp-zap-v2.4

# used by zap-api-scan to check if it's running in a container
ENV IS_CONTAINERIZED=true

WORKDIR /opt/codedx/zap/logs
WORKDIR /opt/codedx/zap/work/output
WORKDIR /opt/codedx/zap/licenses
COPY cmd/zap/licenses .
WORKDIR /opt/codedx/zap/bin
COPY --from=builder /opt/codedx/zap/src/cmd/zap/zap .

ENV PATH=$JAVA_HOME/bin:/opt/python/bin:/zap/:$PATH

RUN adduser -h /home/zap -s /bin/sh -D zap
RUN chown -R zap:zap /opt/codedx/zap
RUN chown -R zap:zap /zap/wrk

# Ensure that a legacy TOML add-in file works with this container image
RUN cp -R /zap-data/profile/.ZAP   /home/zap && \
	cp -R /zap-data/profile/.ZAP_D /home/zap && \
	chown -R zap:zap /home/zap

# Add version file to track cmd/zap capability
RUN echo '1.1' > '/version'

USER zap

# Update add-ons
RUN /zap/zap-x.sh -cmd -addonupdate

CMD ["sh"]





