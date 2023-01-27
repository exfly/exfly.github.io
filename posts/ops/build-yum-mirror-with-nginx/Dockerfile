FROM ubuntu:20.04
RUN sed -E -i -e 's/(archive|ports).ubuntu.com/192.168.0.102:7000/g' -e '/security.ubuntu.com/d' /etc/apt/sources.list

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates && \
    rm -rf /var/lib/apt/lists/* && \
    update-ca-certificates
