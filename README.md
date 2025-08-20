# ZAP Runner — Automated Security Scanning Platform

[![ZAP Version](https://img.shields.io/badge/ZAP-2.14%2B-blue)](https://www.zaproxy.org/)
[![License](https://img.shields.io/badge/License-CC0--1.0-green)](LICENSE.md)

ZAP Runner is a containerized **OWASP ZAP** automation framework for **Cloud.gov infrastructure**, providing **continuous Dynamic Application Security Testing (DAST)**. It integrates directly with **DefectDojo** for vulnerability management and is fully deployable in **Concourse pipelines**.

---

## Overview

ZAP Runner streamlines recurring DAST scans by:

- Running **scheduled scans** across authenticated and unauthenticated contexts
- Integrating with **DefectDojo** for deduplicated vulnerability tracking
- Exporting findings in multiple machine-readable formats for downstream use
- Supporting **CF UAA**, **OpsUAA**, **Bearer Token**, and **No Auth** modes
- Enabling security visibility via **Grafana dashboards**, **Prometheus metrics**, and **Slack alerting**

This supports **DevSecOps pipelines** by embedding automated, repeatable application security checks.

---

## Quick Start

```bash
# Build the Docker image
docker build -t zap-runner .

# Run a local scan
docker run -v $(pwd)/ci/scan-contexts:/zap/wrk zap-runner \
  python3 /zap/zap-baseline.py -c config.yml

# Generate an automation plan
python3 ci/scripts/generate-af-plan.py --context internal --dry-run

# Run validation tests
cd tests && ./final-validation.sh
```

---

## Features

- ✅ **Daily Automated Scans** — Scheduled DAST at 1 AM ET
- 🔑 **Authentication Options** — CF UAA, OpsUAA, Bearer tokens, or unauthenticated
- ⚡ **Parallel Context Execution** — Scan multiple targets simultaneously
- 📊 **Multi-Format Reporting** — HTML, JSON, XML, SARIF
- 🔗 **DefectDojo Integration** — Auto import with deduplication
- 🧩 **ZAP Automation Framework** — Full AF compliance and best practices
- 🧪 **Validation Suite** — 40+ preconfigured checks
- 📈 **Metrics & Dashboards** — Grafana, Prometheus, and Slack alerts

---

## Architecture

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────┐
│   Concourse    │────▶│  ZAP Runner  │────▶│  DefectDojo │
│    Pipeline    │     │   Container  │    │  Import     │
└─────────────────┘     └──────────────┘     └─────────────┘
         │                      │                     │
         ▼                      ▼                     ▼
   [Time Trigger]         [Auth + Scan]          [Reports]
    (Daily 1AM)          (Multi-Context)        (XML/JSON)
```

---

## Authentication

| Method           | Use Case           | Configuration                   |
| ---------------- | ------------------ | ------------------------------- |
| **CF UAA**       | Cloud Foundry apps | Username/password → OAuth token |
| **OpsUAA**       | Internal ops apps  | UAAC owner-password flow        |
| **Bearer Token** | APIs               | Static token injection          |
| **None**         | Public sites       | No authentication               |

Example (CredHub-backed):

```yaml
cf:
  cloud-gov-pages:
    api: https://api.fr.cloud.gov
    user: zap-scan-user
    pass: ((zap-scan-password))
```

---

## Scan Contexts

| Context           | Auth Type | Target Count  |
| ----------------- | --------- | ------------- |
| `internal`        | OpsUAA    | Daily 1 AM ET |
| `external`        | None      | Daily 1 AM ET |
| `cloud-gov-pages` | CF UAA    | Daily 1 AM ET |
| `api`             | Bearer    | Daily 1 AM ET |
| `unauthenticated` | None      | Daily 1 AM ET |

---

## Reporting

Reports are exported per hostname in:

- **HTML** — Human-readable summary
- **JSON** — For downstream CI/CD processing
- **XML** — For DefectDojo imports
- **SARIF** — GitHub/IDE integration

Filters configured in `ci/common/reporting.yml`:

```yaml
filters:
  risks: [high, medium, low]
  confidences: [confirmed, high]
```

---

## Testing & Validation

```bash
# Run all 40+ checks
cd tests
./final-validation.sh
```

Validation includes:

- ✅ Configuration correctness
- ✅ Documented command coverage
- ✅ Structure verification
- ✅ Context validation

---

## Deployment (Concourse)

```bash
# Set the pipeline
fly -t main set-pipeline \
  -p zap-scanner \
  -c ci/pipeline.yml \
  -l ci/config.yml \
  -l ci/vars/zap-dast.yml
```

---

## Security Considerations

- All secrets managed in **CredHub**
- **Never commit secrets** to repo
- Require **GPG-signed commits**
- Follow **Cloud.gov FedRAMP Moderate** security requirements

---

## Documentation & References

- [ZAP_BEST_PRACTICES.md](./docs/ZAP_BEST_PRACTICES.md) — AF best practices
- [COMPLIANCE.md](COMPLIANCE.md) — FedRAMP/NIST control mappings
- [tests/README.md](tests/README.md) — Test suite docs
- [SECURITY.md](SECURITY.md) — Security policy

---

## License

This project is public domain in the U.S., waived under [CC0 1.0 Universal](LICENSE.md).

---

## References

- [OWASP ZAP](https://www.zaproxy.org/)
- [ZAP Automation Framework](https://www.zaproxy.org/docs/automate/automation-framework/)
- [DefectDojo](https://www.defectdojo.org/)
- [Cloud.gov](https://cloud.gov/)

---

_Maintained by the Cloud.gov Security Team_
