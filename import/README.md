---
title: Import Tools
description: Convert external ZAP scanner configs to zap-runner format
type: tooling
status: canonical
---

# Import Tools

Convert external ZAP scanner configurations into `zap-runner` format.

## Quick Start

```bash
# 1. Extract targets from an existing zap-runner repo
python3 import/extract-targets.py /path/to/zap-runner/ci/zap-config/targets.yml \
  > ci/zap-config/targets.yml

# 2. Extract auth profiles from config.yml
python3 import/extract-auth-profiles.py /path/to/zap-runner/ci/config.yml

# 3. Review and customize
python3 ci/scripts/list-contexts.py ci/zap-config/targets.yml
```

## Scripts

| Script | Input | Output |
|--------|-------|--------|
| `extract-targets.py` | External targets.yml | Our targets.yml format |
| `extract-auth-profiles.py` | External config.yml | AUTH_PROFILES_JSON snippet |
| `sanitize-urls.py` | Any targets.yml | Targets with env-specific URLs replaced by placeholders |

## Supported Source Formats

- **cloud-gov/zap-runner** style targets.yml (deep-merge defaults → service → target)
- CSV (via `ci/scripts/csv-to-targets.py`)

## What Gets Converted

- Target URLs, names, contexts, scan variants
- Auth profiles (CF UAA credentials → our provider format)
- Scan settings (minutes, depth, threads, thresholds)
- DefectDojo metadata (product, engagement, test title)
- Include/exclude path patterns
