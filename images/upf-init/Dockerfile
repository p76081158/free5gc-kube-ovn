FROM alpine:3.14

LABEL description="Initial container for free5gc-upf"

RUN apk update && \
    apk add iptables && \
    rm -rf /var/cache/apk/*