# Example Team Configuration

This is an example of how to add a new team's scan configuration.

1. Rename this directory to your team name
2. Update `config.yml` with your settings
3. Add your URLs to `urls.txt`
4. Add credentials to CredHub
5. Redeploy the pipeline

## Example CredHub commands:

```bash
# For OAuth2 authentication
credhub set -n /concourse/main/zap-scanner/example-team-client-id -t value -v "your-client-id"
credhub set -n /concourse/main/zap-scanner/example-team-client-secret -t value -v "your-secret"
credhub set -n /concourse/main/zap-scanner/example-team-token-uri -t value -v "https://your-uaa.cloud.gov/oauth/token"

# For API key authentication
credhub set -n /concourse/main/zap-scanner/example-team-token -t value -v "your-api-token"
```
