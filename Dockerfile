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
    /zap/zap.sh -cmd -silent -addonupdate ; \
    else \
    echo "Skipping ZAP add-on update" ; \
    fi

################################################################################
# STAGE 2 — FINAL IMAGE: your hardened Ubuntu base with Java 21 LTS
################################################################################
FROM ${base_image}
USER root
WORKDIR /zap
ARG DEBIAN_FRONTEND=noninteractive

# Install Java 21 runtime, tools, and API client, then harden only under /zap
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    openjdk-21-jre-headless \  
    curl jq python3-pip && \
    pip3 install --no-cache-dir zaproxy && \
    # Harden: strip setuid/setgid binaries in /zap only
    find /zap -xdev -perm /6000 -type f -exec chmod a-s {} + 2>/dev/null && \
    # Clean up APT caches and unneeded packages
    apt-get purge -y curl jq && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man

# Set JAVA_HOME so ZAP scripts detect Java 21 correctly
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 \
    PATH="$JAVA_HOME/bin:$PATH:/zap" \
    ZAP_PORT=8080 \
    IS_CONTAINERIZED=true

HEALTHCHECK --interval=30s --timeout=5s \
    CMD curl -fs http://localhost:${ZAP_PORT}/ || exit 1

ENTRYPOINT ["zap-baseline.py"]
CMD ["-daemon", "-r", "/zap/wrk/report.html", "-J", "/zap/wrk/report.json"]