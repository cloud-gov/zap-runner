# ZAP Automation Framework Migration Guide

## What Changed

1. **New Directory Structure**
   - Context-based organization under `ci/scan-contexts/`
   - Separate auth scripts in `ci/scripts/auth-scripts/`
   - Main scan script at `ci/scripts/run-zap-scan.sh`

2. **Configuration Files**
   - Each context has its own `config.yml` and `urls.txt`
   - No more CSV files - URLs are in plain text files
   - Authentication is configured per context

3. **Pipeline Updates**
   - Dynamic job generation for each context
   - Scheduled and manual scan options
   - Better credential management with CredHub

## Next Steps

1. **Update Files with New Content**
   ```bash
   # Copy the new content into these files:
   ci/pipeline.yml
   ci/tasks/zap-scan.yml
   ci/scripts/run-zap-scan.sh
   ci/scripts/auth-scripts/uaa-oauth2.js
   ```

2. **Configure Each Context**
   - Edit `ci/scan-contexts/*/config.yml` files
   - Update `ci/scan-contexts/*/urls.txt` with your URLs

3. **Set Up CredHub Credentials**
   ```bash
   # For internal context (UAA OAuth2)
   credhub set -n /concourse/main/zap-scanner/internal-client-id -t value -v "YOUR_CLIENT_ID"
   credhub set -n /concourse/main/zap-scanner/internal-client-secret -t value -v "YOUR_CLIENT_SECRET"
   credhub set -n /concourse/main/zap-scanner/internal-token-uri -t value -v "https://uaa.fr.cloud.gov/oauth/token"

   # For cloud-gov-pages (Form auth)
   credhub set -n /concourse/main/zap-scanner/cloud-gov-pages-username -t value -v "YOUR_USERNAME"
   credhub set -n /concourse/main/zap-scanner/cloud-gov-pages-password -t password -w "YOUR_PASSWORD"

   # Add proxy settings if needed for internal scans
   credhub set -n /concourse/main/zap-scanner/internal-proxy-host -t value -v "proxy.internal.gov"
   credhub set -n /concourse/main/zap-scanner/internal-proxy-port -t value -v "8080"
   ```

4. **Deploy the Pipeline**
   ```bash
   fly -t cloud-gov set-pipeline -p zap-scanner -c ci/pipeline.yml
   ```

## Adding New Contexts

1. Create directory: `mkdir -p ci/scan-contexts/new-context`
2. Create `config.yml` and `urls.txt`
3. Add credentials to CredHub with pattern: `/concourse/main/zap-scanner/new-context-*`
4. Redeploy pipeline

## Authentication Types Supported

- **oauth2**: For UAA-based authentication (internal apps)
- **form**: For form-based login (Pages)
- **header**: For Bearer token auth (APIs)
- **api-key**: For API key header auth
- **none**: For public/unauthenticated scans
