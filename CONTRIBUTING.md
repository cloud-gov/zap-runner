---
title: Contributing
description: How to add targets, auth providers, and contexts
type: development
status: canonical
---

# Contributing

## Adding a New Scan Target

**Option A: CSV (easiest)**
1. Edit `ci/zap-config/targets.example.csv` or create a new CSV
2. Run: `python3 ci/scripts/csv-to-targets.py targets.csv > ci/zap-config/targets.yml`
3. Verify: `python3 ci/scripts/list-contexts.py ci/zap-config/targets.yml`

**Option B: YAML (full control)**
1. Edit `ci/zap-config/targets.yml` — add your target under the appropriate service
2. Choose the right context: `internal`, `external`, `public`, or `static`
3. Choose the scan variant: `unauthenticated` or `authenticated`
4. Optionally set `scan_type: api` for API-focused scans
5. Verify: `python3 ci/scripts/list-contexts.py ci/zap-config/targets.yml`
6. Push and the pipeline will scan it automatically

## Adding a New Auth Provider

1. Add a function `fetch_<provider>(profile)` to `ci/scripts/fetch-bearer-token.py`
2. Register it in the `PROVIDERS` dict
3. The function receives the profile dict from `AUTH_PROFILES_JSON`
4. Return the bearer token as a string
5. Log diagnostics to stderr, never stdout
6. Add unit tests in both `.github/workflows/validate.yml` and `ci/example-test/pipeline.yml`

## Adding a New Context

1. Add targets in `ci/zap-config/targets.yml` with the new context name
2. Add the context to `across` blocks in:
   - `ci/pipeline.yml` (both `scan-all-targets` and `import-to-defectdojo`)
   - `ci/example-test/pipeline.yml` (`scan-all-contexts`)
3. Verify: `python3 ci/scripts/list-contexts.py ci/zap-config/targets.yml`

## Code Standards

See `CODING_STANDARDS.md` for full details. Key points:

- Python scripts: stdlib only (no pip dependencies beyond PyYAML)
- Bash: `set -ceu`, `set -o pipefail`, no unquoted variables
- YAML: validated by yamllint (relaxed profile, 200 char line limit)
- Secrets: CredHub `((var))` only, never in code or CLI args
- Tests: validate structure (JSON schema, alert counts), not just file existence

## Running Tests

```bash
# GitHub Actions (automatic on push/PR to main)

# Local script tests
python3 ci/scripts/list-contexts.py ci/zap-config/targets.yml
python3 ci/scripts/csv-to-targets.py ci/zap-config/targets.example.csv > /dev/null

# Concourse test pipeline (customize ci/example-test/ for your env)
fly -t <target> set-pipeline -p zap-scanner-test \
  -c ci/example-test/pipeline.yml --non-interactive
```

See `docs/AUTH_PROFILES.md` for auth provider setup.
