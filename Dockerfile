# syntax=docker/dockerfile:1.4
# ZAP Runner — Containerized OWASP ZAP automation runner
#
# Multi-stage build:
#   Stage 1: Copy ZAP from official image (optionally update addons)
#   Stage 2: Layer ZAP onto a base image with cf CLI + tools
#
# Build args:
#   base_image      - Injected by common-pipelines (ubuntu-hardened-stig from ECR)
#   ZAP_IMAGE       - ZAP source image (default: zaproxy/zap-stable:latest)
#   CF_CLI_VERSION  - cf CLI version to install

ARG base_image
ARG ZAP_IMAGE=zaproxy/zap-stable:latest
ARG CF_CLI_VERSION=8.18.0

################################################################################
# STAGE 1 — ZAP BUILDER (copy ZAP installation from official image)
################################################################################
FROM ${ZAP_IMAGE} AS zap-builder

USER root
ARG ENABLE_ADDON_UPDATE="false"
WORKDIR /zap

# Verify ZAP is present
RUN test -x /zap/zap.sh

# Optionally update ZAP addons (set ENABLE_ADDON_UPDATE=true to enable)
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

# Copy ZAP installation from builder stage
COPY --from=zap-builder /zap /zap

# Verify base image is Debian/Ubuntu compatible
RUN command -v apt-get >/dev/null 2>&1 || \
    (echo "base_image must be Debian/Ubuntu compatible and provide apt-get" >&2 && exit 1)

# Install runtime dependencies
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
      python3-yaml \
      python3-requests \
      python3-websocket && \
    # Install AWS CLI v2
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip && \
    unzip -q /tmp/awscliv2.zip -d /tmp && \
    /tmp/aws/install && \
    rm -rf /tmp/aws /tmp/awscliv2.zip && \
    # Install cf CLI (pinned version from GitHub releases)
    curl -fsSL -L "https://github.com/cloudfoundry/cli/releases/download/v${CF_CLI_VERSION}/cf8-cli_${CF_CLI_VERSION}_linux_x86-64.tgz" \
      -o /tmp/cf-cli.tgz && \
    tar -xzf /tmp/cf-cli.tgz -C /usr/local/bin && \
    chmod 0755 /usr/local/bin/cf /usr/local/bin/cf8 && \
    rm -f /tmp/cf-cli.tgz && \
    # Cleanup
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man

# Create non-root user for scanning (UID 1000 may already exist in base)
RUN id -u zap >/dev/null 2>&1 || useradd -m -s /bin/bash zap && \
    mkdir -p /zap/wrk /zap/plan /zap/hooks && \
    chown -R zap:zap /zap

USER zap

# Environment
ENV JAVA_HOME=/usr/lib/jvm/default-java
ENV PATH=${JAVA_HOME}/bin:/zap:/usr/local/bin:${PATH} \
    HOME=/home/zap \
    ZAP_PORT=8080 \
    IS_CONTAINERIZED=true \
    ZAP_JAVA_OPTS=-Xmx2048m

LABEL org.opencontainers.image.title="zap-runner" \
      org.opencontainers.image.description="Containerized OWASP ZAP automation runner for Concourse CI" \
      org.opencontainers.image.licenses="Apache-2.0"

ENTRYPOINT ["/bin/bash"]
CMD ["-lc", "echo zap-runner image ready"]
