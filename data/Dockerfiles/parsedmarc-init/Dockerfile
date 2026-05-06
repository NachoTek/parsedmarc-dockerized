FROM alpine:latest

ADD start.sh /start.sh
COPY dashboards/ /opt/dashboards/

RUN apk add --no-cache curl openssl jq bash \
    && chmod +x /start.sh

ENTRYPOINT [ "/start.sh" ]
