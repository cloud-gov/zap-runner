---
title: Cloud-Gov Profile
description: Sanitized reference targets and auth profiles from cloud-gov/zap-runner
type: reference
status: canonical
---

# Cloud-Gov Profile

Ready-to-use configuration for scanning cloud-gov infrastructure using `zap-runner`.

## What's Included

| File | Description |
|------|-------------|
| `config.yml` | Pipeline variables (scan defaults, auth profiles, DefectDojo settings) |
| `targets.yml` | Sanitized scan targets (25 targets, URLs replaced with example.com) |
| `auth-profiles.json` | Auth profile reference with provider annotations |

## Setup

```bash
# 1. Copy targets and config to the pipeline
cp import/profiles/cloud-gov/targets.yml ci/zap-config/targets.yml
cp import/profiles/cloud-gov/config.yml ci/config.yml

# 2. Replace placeholder URLs with real endpoints
#    Edit ci/zap-config/targets.yml — replace example.com URLs
#    Edit ci/config.yml — replace ((var)) with your CredHub paths

# 3. Store credentials in CredHub
credhub set -n /concourse/main/zap-scanner/cf_api_dev -t value -v "https://api.dev.YOUR_DOMAIN"
credhub set -n /concourse/main/zap-scanner/cf_username_dev -t value -v "zap-scan-user"
credhub set -n /concourse/main/zap-scanner/cf_password_dev -t password -w "PASSWORD"
# Repeat for staging and production

# 4. Deploy the pipeline
fly -t your-target set-pipeline -p zap-scanner \
  -c ci/pipeline.yml \
  -l ci/config.yml

# 5. Verify targets
python3 ci/scripts/list-contexts.py ci/zap-config/targets.yml
```

## Improvements Over cloud-gov/zap-runner

| Feature | Previous Version | This Version |
|---------|----------------------|----------------------|
| Auth providers | CF UAA only | CF UAA + OIDC + static (modular) |
| Target onboarding | YAML only | CSV or YAML |
| Token security | Tokens visible in logs | Bearer tokens scrubbed from output |
| Finding filters | None | Risk + confidence level filtering |
| Report validation | File size only | JSON/SARIF structure + alert count assertions |
| CI linting | None | yamllint, hadolint, shellcheck, Python lint |
| Script testing | None | Unit tests for all 8 scripts |
| Context taxonomy | internal/external/pages | internal/external/public/static |

## Regenerating

To re-extract from the source repo:

```bash
# Extract targets (sanitized — no real URLs)
python3 import/extract-targets.py /path/to/zap-runner/ci/zap-config/targets.yml \
  --sanitize > import/profiles/cloud-gov/targets.yml

# Extract auth profiles (sanitized)
python3 import/extract-auth-profiles.py /path/to/zap-runner/ci/config.yml \
  --sanitize > import/profiles/cloud-gov/auth-profiles.json

# Or extract as CSV for review
python3 import/extract-targets.py /path/to/zap-runner/ci/zap-config/targets.yml \
  --sanitize --csv > import/profiles/cloud-gov/targets.csv
```
