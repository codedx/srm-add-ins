FROM golang:1.17.5-alpine3.14 as builder

WORKDIR /zap

RUN apk update && apk add --no-cache curl wget xmlstarlet unzip git

# Download and expand the latest weekly release
RUN curl -s https://raw.githubusercontent.com/zaproxy/zap-admin/master/ZapVersions.xml | xmlstarlet sel -t -v //url | grep -i WEEKLY | wget --content-disposition -i - && \
	archive=$(ls) && \
	unzip $archive -d ZAP && \
	rm $archive && \
	mv ZAP/*/* . &&  \
	rm -R ZAP

# Remove large, unwanted plugins
RUN rm -f /zap/plugin/jxbrowser*.zap

# Fetch policies files from latest develop branch (note that there's a chance for a mismatch)
WORKDIR /tmp/zap-develop
RUN git clone https://github.com/zaproxy/zaproxy -b develop /tmp/zap-develop
 
WORKDIR /opt/codedx/zap/src
COPY go.mod .
COPY cmd/zap cmd/zap
COPY pkg pkg
WORKDIR /opt/codedx/zap/src/cmd/zap
RUN go mod tidy && go build -ldflags=-w

FROM openjdk:17-jdk-alpine3.14

WORKDIR /zap
COPY --from=builder /zap .
WORKDIR /root/.ZAP/policies
COPY --from=builder /tmp/zap-develop/docker/policies .

RUN apk update && apk add --no-cache libxslt ca-certificates bash netcat-openbsd firefox-esr
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

USER zap

CMD ["sh"]





