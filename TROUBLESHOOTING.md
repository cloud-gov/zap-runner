# ZAP Scanner Troubleshooting Guide

## Common Issues

### 1. UAA Authentication Failures

**Symptom**: Scans fail with 401/403 errors

**Solutions**:

- Verify client credentials in CredHub
- Check token endpoint URL
- Ensure client has correct scopes
- Check UAA logs: `cf logs uaa --recent`

```bash
# Test UAA credentials manually
curl -X POST "https://uaa.fr.cloud.gov/oauth/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=YOUR_CLIENT_ID" \
  -d "client_secret=YOUR_CLIENT_SECRET"
```
