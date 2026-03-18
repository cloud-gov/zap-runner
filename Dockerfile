# syntax=docker/dockerfile:1.4
ARG base_image
ARG ZAP_IMAGE=zaproxy/zap-stable:latest
ARG CF_CLI_VERSION=8.13.0

################################################################################
# STAGE 1 — ZAP BUILDER
################################################################################
FROM ${ZAP_IMAGE} AS zap-builder

USER root
ARG ENABLE_ADDON_UPDATE="false"
WORKDIR /zap

RUN test -x /zap/zap.sh

RUN if [ "${ENABLE_ADDON_UPDATE}" = "true" ]; then \
    /zap/zap.sh -cmd -silent -addonupdate; \
    else \
    echo "Skipping ZAP add-on update"; \
    fi

################################################################################
# STAGE 2 — FINAL IMAGE
################################################################################
FROM ${base_image}

USER root
ARG DEBIAN_FRONTEND=noninteractive
ARG CF_CLI_VERSION
WORKDIR /zap

COPY --from=zap-builder /zap /zap

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    openjdk-21-jre-headless \
    xvfb \
    unzip \
    jq \
    git \
    curl \
    ca-certificates \
    python3 \
    python3-pip \
    python3-yaml \
    python3-requests \
    python3-websocket \
    awscli && \
    mkdir -p /tmp/cf-cli && \
    curl -fsSL "https://github.com/cloudfoundry/cli/releases/download/v${CF_CLI_VERSION}/cf8-cli_${CF_CLI_VERSION}_linux_x86-64.tgz" \
    -o /tmp/cf-cli.tgz && \
    tar -xzf /tmp/cf-cli.tgz -C /tmp/cf-cli && \
    install -m 0755 /tmp/cf-cli/cf8 /usr/local/bin/cf8 && \
    ln -sf /usr/local/bin/cf8 /usr/local/bin/cf && \
    rm -rf /tmp/cf-cli /tmp/cf-cli.tgz && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man

RUN useradd -u 1000 -m -s /bin/bash zap && \
    mkdir -p /zap/wrk /zap/plan /zap/hooks && \
    chown -R zap:zap /zap

USER zap

ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 \
    PATH=${JAVA_HOME}/bin:/zap:/usr/local/bin:${PATH} \
    HOME=/home/zap \
    ZAP_PORT=8080 \
    IS_CONTAINERIZED=true \
    ZAP_JAVA_OPTS=-Xmx2048m

LABEL org.opencontainers.image.title="zap-runner" \
    org.opencontainers.image.description="Containerized OWASP ZAP automation runner" \
    org.opencontainers.image.source="https://github.com/cloud-gov/zap-runner" \
    org.opencontainers.image.licenses="CC0-1.0" \
    org.opencontainers.image.authors="Cloud.gov Office of Cybersecurity"

ENTRYPOINT ["/bin/bash"]
CMD ["-lc", "echo zap-runner image ready"]