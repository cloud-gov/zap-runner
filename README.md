---
title: zap-runner
description: Cloud-Gov DAST scanning pipeline for Concourse CI using OWASP ZAP
type: operational
status: canonical
---

# zap-runner

Cloud-Gov DAST scanning pipeline using OWASP ZAP for Concourse CI.

This is a **self-contained, ready-to-deploy** Concourse pipeline for OWASP ZAP security scanning of Cloud Foundry applications.

## Quick Start

```bash
# 1. Clone this repo
git clone git@github.com:cloud-gov/zap-runner.git
cd zap-runner

# 2. Verify CredHub secrets exist (these should already be set)
#    Run from the CredHub production standalone jumpbox:
credhub find -n zap
# Expected:
#   /concourse/main/zap-scanner/zap-scan-password-development
#   /concourse/main/zap-scanner/zap-scan-password-staging
#   /concourse/main/zap-scanner/zap-scan-password-production
#   /concourse/main/zap-scanner/zap_scan_client_secret-opsuaa
#   /concourse/main/zap-scanner/zap-scan-password-opsuaa

# If any are missing, set them:
#   credhub set -n /concourse/main/zap-scanner/zap-scan-password-development -t password -w "PASSWORD"

# Set pipeline repo URI:
credhub set -n /concourse/main/zap-scanner/pipeline_repo_uri \
  -t value -v "git@github.com:cloud-gov/zap-runner.git"

# Create S3 bucket for ZAP reports (one-time):
cf target -o YOUR_ORG -s YOUR_SPACE
cf create-service s3 basic zap-reports
cf create-service-key zap-reports zap-reports-key
cf service-key zap-reports zap-reports-key    # → copy bucket name
credhub set -n /concourse/main/zap-scanner/zap_reports_bucket -t value -v "BUCKET_NAME"

# DefectDojo — reuse existing deploy-defectdojo creds if available:
#   credhub get -n /concourse/main/defectdojo_production_import_url
#   credhub get -n /concourse/main/defectdojo_production_auth_token
# Or set new ones:
#   credhub set -n /concourse/main/zap-scanner/defectdojo_url -t value -v "URL/api/v2/reimport-scan/"
#   credhub set -n /concourse/main/zap-scanner/defectdojo_api_key -t password -w "TOKEN"
#
# Shared cloud-gov secrets (should already exist — used by all pipelines):
#   ecr_aws_key, ecr_aws_secret, cloud-gov-pgp-keys

# 3. Verify auth works (from any Concourse task or jumpbox)
export USER_ID="zap-scan-user"
export USER_PASSWORD=$(credhub get -n "/concourse/main/zap-scanner/zap-scan-password-development" -q)
cf api api.dev.us-gov-west-1.aws-us-gov.cloud.gov
cf auth $USER_ID $USER_PASSWORD
cf oauth-token    # Should emit a bearer token

# 4. Deploy the pipeline
fly -t your-target set-pipeline -p zap-scanner \
  -c ci/pipeline.yml -l ci/config.yml

# 5. Unpause and go
fly -t your-target unpause-pipeline -p zap-scanner
```

## What's Included

```
ci/
  pipeline.yml            # Concourse pipeline (self-setting, matrix scan, S3, DefectDojo)
  config.yml              # All configuration (scan defaults, auth profiles, thresholds)
  zap-config/
    targets.yml           # 25 scan targets across 8 services (3 environments)
    targets.example.csv   # CSV template for adding new targets
  scripts/                # 8 Python scripts (target parsing, plan building, validation, auth)
  tasks/                  # Concourse task definitions (scan, upload, DefectDojo import)
  example-test/           # Example test pipeline (customize for your CI environment)
Dockerfile                # ZAP scanner image (Ubuntu 24.04 + ZAP + CF CLI + tools)
docs/
  AUTH_PROFILES.md        # Auth provider reference (CF UAA, OIDC, static tokens)
import/                   # Tools for extracting/converting targets from other formats
```

## Scan Matrix

The pipeline scans across **contexts × variants**:

| Context | Description | Targets |
|---------|-------------|---------|
| internal | Internal monitoring/tools | alertmanager, ci, grafana, logs-platform, prometheus, ... |
| external | External CF apps (authenticated) | billing-api, csb, cg-ui, dashboard, api, ... |
| pages | Cloud.gov Pages | pages-staging, pages-production, admin panels |
| development | Dev environment apps | billing-api-dev, pages-editor-dev |

## Auth Flow

```
CredHub ((password)) → cf auth → cf oauth-token → Bearer token → ZAP replacer → All requests
```

Each environment (development/staging/production) has its own CF UAA auth profile. Tokens are:
- Fetched per scan via `ci/scripts/fetch-bearer-token.py`
- Injected into ZAP requests via the Automation Framework replacer job
- Scrubbed from CI logs (`Bearer <token>` → `Bearer **REDACTED**`)

## Improvements Over cloud-gov/zap-runner

| Feature | Original | This Pipeline |
|---------|----------|--------------|
| Auth providers | CF UAA only (inline bash) | Modular: CF UAA + OIDC + static (Python) |
| Target onboarding | YAML only | CSV or YAML |
| Token security | Tokens visible in logs | Bearer tokens scrubbed |
| Finding filters | None | Risk + confidence level filtering |
| Report validation | File size only | JSON/SARIF schema + alert count assertions |
| CI linting | None | yamllint, hadolint, Python lint |
| Script testing | None | Unit tests for all 8 scripts |
| Report formats | HTML, JSON, XML, SARIF | Same + configurable per-scan |

## Adding New Targets

```bash
# Option A: Edit the CSV
vim ci/zap-config/targets.example.csv
python3 ci/scripts/csv-to-targets.py ci/zap-config/targets.example.csv > ci/zap-config/targets.yml

# Option B: Edit YAML directly
vim ci/zap-config/targets.yml

# Verify
python3 ci/scripts/list-contexts.py ci/zap-config/targets.yml
```

## Documentation

- [AUTH_PROFILES.md](docs/AUTH_PROFILES.md) — Auth provider setup (CF UAA, OIDC, static)
- [CODING_STANDARDS.md](CODING_STANDARDS.md) — Pipeline development standards
- [CONTRIBUTING.md](CONTRIBUTING.md) — How to add targets, providers, contexts
