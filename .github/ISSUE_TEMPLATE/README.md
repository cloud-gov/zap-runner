# Example Team Configuration

This is an example of how to add a new team's scan configuration.

1. Rename this directory to the team name
2. Update `config.yml` with the right settings
3. Add the URLs to `urls.txt`
4. Add credentials to CredHub
5. Redeploy the pipeline

## Example CredHub commands:

```bash
# For OAuth2 authentication
credhub set -n /concourse/main/zap-scanner/example-team-client-id -t value -v "the-client-id"
credhub set -n /concourse/main/zap-scanner/example-team-client-secret -t value -v "the-secret"
credhub set -n /concourse/main/zap-scanner/example-team-token-uri -t value -v "https://the-uaa.cloud.gov/oauth/token"

# For API key authentication
credhub set -n /concourse/main/zap-scanner/example-team-token -t value -v "the-api-token"
```
