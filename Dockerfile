# syntax=docker/dockerfile:1.4
ARG base_image
ARG ZAP_VERSION=latest

################################################################################
# STAGE 1 — ZAP BUILDER: pull official ZAP bits (JDK & scripts bundled upstream)
################################################################################
FROM zaproxy/zap-stable:${ZAP_VERSION} AS zap-builder

USER root
ARG ENABLE_ADDON_UPDATE="false"
WORKDIR /zap

RUN test -x /zap/zap-baseline.py

# Install required add-ons at build time (best practice)
# Report Generation and OpenAPI add-ons are typically included by default,
# but we ensure they're installed/updated
RUN if [ "${ENABLE_ADDON_UPDATE}" = "true" ]; then \
  /zap/zap.sh -cmd -silent -addonupdate; \
  /zap/zap.sh -cmd -silent -addoninstall reportgenerator; \
  /zap/zap.sh -cmd -silent -addoninstall openapi; \
  else \
  echo "Skipping ZAP add-on update"; \
  # Still ensure critical add-ons are installed
  /zap/zap.sh -cmd -silent -addoninstall reportgenerator; \
  /zap/zap.sh -cmd -silent -addoninstall openapi; \
  fi

################################################################################
# STAGE 2 — FINAL IMAGE: hardened Ubuntu base (the image via ARG base_image)
################################################################################
FROM ${base_image}

USER root
ARG DEBIAN_FRONTEND=noninteractive
WORKDIR /zap

# Copy ZAP from builder
COPY --from=zap-builder /zap /zap

# Core tooling: Python, curl, jq, etc.
RUN apt-get update &&     apt-get install -y --no-install-recommends       ca-certificates curl gnupg       openjdk-21-jre-headless xvfb unzip jq git       python3-pip python-is-python3 python3-yaml python3-requests python3-websocket       build-essential ruby-full &&     pip3 install --no-cache-dir zaproxy PyYAML &&     rm -rf /var/lib/apt/lists/*

# --- Install Cloud Foundry CLI v8 (official apt repo) ---
# Ref: CF CLI v8 Debian/Ubuntu instructions
# Add key + repo, then install cf8-cli
RUN set -e;     apt-get update && apt-get install -y --no-install-recommends ca-certificates curl gnupg &&     install -d -m 0755 /usr/share/keyrings &&     curl -fsSL https://packages.cloudfoundry.org/debian/cli.cloudfoundry.org.key |       gpg --dearmor -o /usr/share/keyrings/cloudfoundry-keyring.gpg &&     echo "deb [signed-by=/usr/share/keyrings/cloudfoundry-keyring.gpg] https://packages.cloudfoundry.org/debian stable main"       > /etc/apt/sources.list.d/cloudfoundry-cli.list &&     apt-get update && apt-get install -y --no-install-recommends cf8-cli &&     rm -rf /var/lib/apt/lists/*

# --- Install UAAC (cf-uaac Ruby gem) ---
# Ref: UAAC docs: gem install cf-uaac
RUN gem install --no-document cf-uaac

# Create non-root user
RUN useradd -u 1000 -m -s /bin/bash zap && chown -R zap:zap /zap
USER zap

# Workspace & env
RUN mkdir -p /zap/wrk && chown -R zap:zap /zap/wrk
VOLUME ["/zap/wrk"]

ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64     PATH=${JAVA_HOME}/bin:/zap:${PATH}     ZAP_PORT=8080     IS_CONTAINERIZED=true

LABEL org.opencontainers.image.title="zap-runner"       org.opencontainers.image.description="Containerized OWASP ZAP AF runner with cf8 + UAAC"       org.opencontainers.image.source="https://github.com/cloud-gov/zap-runner"       org.opencontainers.image.licenses="CC0-1.0"

HEALTHCHECK --interval=30s --timeout=5s   CMD curl -fs http://localhost:${ZAP_PORT}/ || exit 1

ENTRYPOINT ["python3", "-u", "/zap/zap-baseline.py"]
CMD ["-daemon"]