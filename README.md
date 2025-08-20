# ZAP Runner - Automated Security Scanning Platform

[![ZAP Version](https://img.shields.io/badge/ZAP-2.14%2B-blue)](https://www.zaproxy.org/)
[![License](https://img.shields.io/badge/License-CC0--1.0-green)](LICENSE.md)
[![Status](https://img.shields.io/badge/Status-Production%20Ready-success)](PROJECT_STATUS.md)

Automated OWASP ZAP security scanning platform for cloud.gov infrastructure, providing continuous DAST (Dynamic Application Security Testing) with DefectDojo integration.

## 🚀 Quick Start

```bash
# Build the Docker image
docker build -t zap-runner .

# Run a local scan (example)
docker run -v $(pwd)/ci/scan-contexts:/zap/wrk zap-runner \
  python3 /zap/zap-baseline.py -c config.yml

# Generate an automation plan
python3 ci/scripts/generate-af-plan.py --context internal --dry-run

# Run validation tests
cd tests && ./final-validation.sh
```

## 📋 Features

- **Daily Automated Scans**: Scheduled DAST scans at 1 AM ET
- **Multiple Authentication Methods**: CF UAA, OpsUAA, Bearer tokens, Unauthenticated
- **Parallel Context Execution**: Scan multiple targets simultaneously  
- **Multi-Format Reporting**: HTML, JSON, XML, SARIF
- **DefectDojo Integration**: Automatic vulnerability management with deduplication
- **ZAP Automation Framework**: Full AF support with best practices
- **Comprehensive Testing**: 40+ validation checks
- **Grafana Dashboard**: Real-time security metrics visualization
- **Enhanced Slack Alerts**: Configurable thresholds with detailed notifications
- **Prometheus Metrics**: Export scan results for monitoring

## 🏗️ Architecture

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────┐
│   Concourse     │────▶│  ZAP Runner  │────▶│  DefectDojo │
│    Pipeline     │     │   Container  │     │   Import    │
└─────────────────┘     └──────────────┘     └─────────────┘
         │                      │                     │
         ▼                      ▼                     ▼
   [Time Trigger]         [Auth + Scan]          [Reports]
    (Daily 1AM)          (Multi-Context)        (XML/JSON)
```

## 📁 Project Structure

```
zap-runner/
├── ci/
│   ├── common/              # Central configuration
│   │   ├── user-agent.txt   # Custom user agent
│   │   ├── global-exclusions.txt # URL exclusions
│   │   └── reporting.yml    # Report templates
│   ├── scan-contexts/       # Scan targets
│   │   ├── internal/        # Internal apps (OpsUAA auth)
│   │   ├── external/        # External sites (no auth)
│   │   ├── api/            # API scanning (OpenAPI specs)
│   │   ├── cloud-gov-pages/ # CF UAA authenticated
│   │   └── unauthenticated/ # Basic scans
│   ├── tasks/              # Concourse tasks
│   │   ├── acquire-auth.yml
│   │   ├── zap-af.yml
│   │   └── push-defectdojo.yml
│   └── pipeline.yml        # Main pipeline
├── tests/                  # Validation suite
├── Dockerfile             # Multi-stage build
└── docs/                  # Documentation
```

## 🔐 Authentication

The platform supports multiple authentication methods:

| Method | Use Case | Configuration |
|--------|----------|--------------|
| **CF UAA** | Cloud Foundry apps | Username/password → OAuth token |
| **OpsUAA** | Internal operations | UAAC owner-password flow |
| **Bearer Token** | API endpoints | Static token injection |
| **None** | Public sites | No authentication |

### Example Configuration (CredHub-backed)

```yaml
zap:
  auth_source:
    internal: opsuaa
    cloud-gov-pages: cf
  cf:
    cloud-gov-pages:
      api: https://api.fr.cloud.gov
      user: zap-scan-user
      pass: ((zap-scan-password))
  opsuaa:
    host: opslogin.fr.cloud.gov
    client_id: zap_scan_client
    client_secret: ((zap_scan_client_secret))
```

## 📊 Scan Contexts

| Context | Auth Type | Target Count | Schedule |
|---------|-----------|--------------|----------|
| `internal` | OpsUAA | 5 URLs | Daily 1 AM ET |
| `external` | None | 2 URLs | Daily 1 AM ET |
| `cloud-gov-pages` | CF UAA | 2 URLs | Daily 1 AM ET |
| `api` | Bearer | 3 APIs | Daily 1 AM ET |
| `unauthenticated` | None | 2 URLs | Daily 1 AM ET |

## 🔧 Configuration

### Adding a New Scan Context

1. Create directory: `ci/scan-contexts/your-context/`
2. Add target URLs: `urls.txt` (one per line)
3. Configure settings: `config.yml` (optional)
4. Update pipeline: Add to `across` values in `ci/child-pipelines/zap-dast.yml`
5. Set authentication: Configure in `ci/vars/zap-dast.yml`

### Context Configuration Options

```yaml
# ci/scan-contexts/your-context/config.yml
AUTH_TYPE: oauth2           # oauth2, header, form, none
SCAN_TYPE: full             # full, api, baseline
SPIDER_MAX_DEPTH: 10        # Spider depth
MAX_SCAN_DURATION: 120      # Minutes
ALERT_THRESHOLD: MEDIUM     # LOW, MEDIUM, HIGH
```

## 📈 Reporting

Reports are generated in multiple formats per hostname:

- **HTML**: Human-readable findings report
- **JSON**: Machine-parseable results
- **XML**: DefectDojo integration format
- **SARIF**: GitHub/IDE integration format

### Report Filtering

Configure risk and confidence levels in `ci/common/reporting.yml`:

```yaml
filters:
  risks: [high, medium, low]
  confidences: [confirmed, high]
```

## 🧪 Testing & Validation

Comprehensive test suite available in `tests/` directory:

```bash
# Complete validation (40+ checks)
cd tests
./final-validation.sh

# Individual test suites
./test-zap-config.sh          # Configuration tests
./test-documented-commands.sh # Command validation
./verify-project-structure.sh # Structure verification
./validate-scan-contexts.sh   # Context validation
```

## 🚀 Deployment

### Concourse Pipeline

```bash
# Set the pipeline
fly -t main set-pipeline \
  -p zap-scanner \
  -c ci/pipeline.yml \
  -l ci/config.yml \
  -l ci/vars/zap-dast.yml

# Trigger manually
fly -t main trigger-job -j zap-scanner/daily-dast

# Watch output
fly -t main watch -j zap-scanner/daily-dast
```

### Docker Build Options

```bash
# Standard build
docker build -t zap-runner .

# Custom base image
docker build --build-arg base_image=ubuntu:22.04 -t zap-runner .

# Enable add-on updates
docker build --build-arg ENABLE_ADDON_UPDATE=true -t zap-runner .

# Specific ZAP version
docker build --build-arg ZAP_VERSION=2.14.0 -t zap-runner .
```

## 📝 Documentation

- **[PROJECT_STATUS.md](PROJECT_STATUS.md)** - Current project status and roadmap
- **[ZAP_BEST_PRACTICES.md](ZAP_BEST_PRACTICES.md)** - ZAP AF best practices
- **[COMPLIANCE.md](COMPLIANCE.md)** - NIST 800-53 control mappings
- **[docs/GRAFANA_SETUP.md](docs/GRAFANA_SETUP.md)** - Grafana dashboard setup for cloud.gov
- **[tests/README.md](tests/README.md)** - Test suite documentation
- **[SECURITY.md](SECURITY.md)** - Security policies

## ⚠️ Important Notes

### ZAP Automation Framework
- **No deprecated features**: `addOns` job removed, add-ons installed at build time
- **Proper job order**: options → replacer → import/openapi → spider → activeScan → report → exitStatus
- **Exit codes**: 0=Success, 1=Errors, 2=Warnings

### Security Considerations
- All credentials managed via CredHub
- Never commit secrets to repository
- Use GPG signed commits
- Follow cloud.gov security requirements (FedRAMP, FISMA)

## 🐛 Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| Auth token failures | Check CredHub variables and service availability |
| Scan timeouts | Adjust `SPIDER_MAX_DEPTH` and `MAX_SCAN_DURATION` |
| Report generation errors | Verify `reporting.yml` syntax |
| Pipeline failures | Check Concourse logs and Docker build |

### Debug Commands

```bash
# Check ZAP version
docker run zap-runner zap.sh -version

# List installed add-ons
docker run zap-runner zap.sh -cmd -addonlist

# Validate automation plan
docker run -v $(pwd)/plan.yaml:/zap/plan.yaml zap-runner \
  zap.sh -cmd -autorun /zap/plan.yaml -autocheckplan

# Test authentication
docker run -e AUTH_SOURCE=cf -e CF_API=... zap-runner \
  bash -c 'source ci/tasks/acquire-auth.yml'
```

## 📊 Metrics & Monitoring

### Coverage Statistics
- **Daily Coverage**: 15+ URLs across 5 contexts
- **Parallel Execution**: All contexts simultaneously
- **Report Generation**: 4 formats per hostname
- **Success Rate**: 100% validation tests passing

### Grafana Dashboard
The project includes a comprehensive Grafana dashboard for real-time monitoring:

- **Vulnerability Trends**: Track high/medium/low risk findings over time
- **Security Score**: Overall security posture percentage
- **Scan Performance**: Duration and coverage metrics
- **Context Breakdown**: Per-context vulnerability distribution

See [docs/GRAFANA_SETUP.md](docs/GRAFANA_SETUP.md) for cloud.gov integration instructions.

### Slack Alerting
Enhanced alerting with configurable thresholds:

```yaml
# Configure in pipeline variables
alert_thresholds:
  high: 0      # Alert on any high-risk finding
  medium: 10   # Alert if medium-risk > 10
  low: 50      # Alert if low-risk > 50
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Run validation tests: `cd tests && ./final-validation.sh`
4. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

## 📄 License

This project is in the public domain within the United States, and copyright and related rights in the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](LICENSE.md).

## 🔗 References

- [OWASP ZAP](https://www.zaproxy.org/)
- [ZAP Automation Framework](https://www.zaproxy.org/docs/automate/automation-framework/)
- [DefectDojo](https://www.defectdojo.org/)
- [cloud.gov](https://cloud.gov/)

---

*Maintained by cloud.gov Security Team*