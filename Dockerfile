FROM docker:dind

ENV TARGETARCH="linux-x64" \
    DOCKER_TLS_CERTDIR=""

WORKDIR /azp/

# Single COPY instruction for all scripts
COPY scripts/ .

# Single RUN layer for all setup
RUN chmod +x *.sh && \
    adduser -D agent && \
    addgroup agent docker && \
    chown -R agent:agent /azp

# Start as root
ENTRYPOINT ["/bin/sh", "/azp/wrapper.sh"]
