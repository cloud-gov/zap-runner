# syntax=docker/dockerfile:1.4
ARG base_image

################################################################################
# STAGE 1 — ZAP BUILDER: pull official ZAP bits (JDK & scripts bundled upstream)
################################################################################
FROM zaproxy/zap-stable:latest AS zap-builder

USER root
ARG ENABLE_ADDON_UPDATE="false"
WORKDIR /zap

# Sanity-check baseline script
RUN test -x /zap/zap-baseline.py

# Optional add-on update
RUN if [ "${ENABLE_ADDON_UPDATE}" = "true" ]; then \
    /zap/zap.sh -cmd -silent -addonupdate; \
    else \
    echo "Skipping ZAP add-on update"; \
    fi

################################################################################
# STAGE 2 — FINAL IMAGE: your hardened Ubuntu base with Java 21 LTS
################################################################################
FROM ${base_image}

# Use root for installation
USER root
ARG DEBIAN_FRONTEND=noninteractive
WORKDIR /zap

# Copy ZAP installation from builder stage
COPY --from=zap-builder /zap /zap

# Install Java 21 LTS and necessary tooling, then harden under /zap
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    openjdk-21-jre-headless \
    curl \
    jq \
    python3-pip && \
    python-is-python3 && \
    pip3 install --no-cache-dir zaproxy && \
    find /zap -xdev -perm /6000 -type f -exec chmod a-s {} + && \
    apt-get purge -y python3-pip && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man

# Create non-root zap user and set permissions
RUN useradd -u 1000 -m -s /bin/bash zap && \
    chown -R zap:zap /zap

# Switch to non-root for runtime
USER zap

# Configure environment for ZAP
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 \
    PATH=${JAVA_HOME}/bin:/zap:${PATH} \
    ZAP_PORT=8080 \
    IS_CONTAINERIZED=true

# Embed metadata via OCI labels
LABEL org.opencontainers.image.title="zap-runner" \
    org.opencontainers.image.description="Containerized OWASP ZAP baseline scanner" \
    org.opencontainers.image.version="2.16.0" \
    org.opencontainers.image.created="2025-07-11T00:00:00Z" \
    org.opencontainers.image.source="https://github.com/cloud-gov/zap-runner" \
    org.opencontainers.image.licenses="CC0-1.0" \
    org.opencontainers.image.authors="Cloud.gov Office of Cybersecurity"

# Healthcheck for ZAP daemon
HEALTHCHECK --interval=30s --timeout=5s \
    CMD curl -fs http://localhost:${ZAP_PORT}/ || exit 1

# Default entrypoint and command
ENTRYPOINT ["zap-baseline.py"]
CMD ["-daemon", "-r", "/zap/wrk/report.html", "-J", "/zap/wrk/report.json"]
