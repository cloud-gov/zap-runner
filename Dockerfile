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
# STAGE 2 — FINAL IMAGE: your hardened Ubuntu base (no STIG steps needed here)
################################################################################
FROM ${base_image}

USER root
WORKDIR /zap
ARG DEBIAN_FRONTEND=noninteractive

# Copy ZAP tree from builder
COPY --from=zap-builder /zap /zap

# Install only what we need at runtime (curl/jq for scripts, Python API client)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl jq python3-pip && \
    pip3 install --no-cache-dir zaproxy && \
    # Hardening: strip any remaining setuid/setgid bits
    find / -perm /6000 -type f -exec chmod a-s {} + && \
    apt-get purge -y curl jq && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man

# Create and switch to non-root user
RUN useradd -u 1000 -m -s /bin/bash zap && chown -R zap:zap /zap
USER zap

# Environment & health-check
ENV PATH="/usr/lib/jvm/java-17-openjdk-amd64/bin:/zap:$PATH" \
    ZAP_PORT=8080 \
    IS_CONTAINERIZED=true

HEALTHCHECK --interval=30s --timeout=5s \
    CMD curl -fs http://localhost:${ZAP_PORT}/ || exit 1

ENTRYPOINT ["zap-baseline.py"]
CMD ["-daemon", "-r", "/zap/wrk/report.html", "-J", "/zap/wrk/report.json"]