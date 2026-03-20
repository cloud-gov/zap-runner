---
title: Authentication Profiles
description: Auth provider reference for CF UAA, OIDC, and static token providers
type: reference
status: canonical
---

# Authentication Profiles

ZAP pipeline supports multiple auth providers for scanning protected targets. Auth profiles are defined in `AUTH_PROFILES_JSON` (a JSON object in `ci/config.yml`) and referenced by targets via `auth_profile`.

## Providers

### `cf-uaa` — Cloud Foundry UAA

Fetches a bearer token via `cf auth` → `cf oauth-token`.

```json
{
  "production": {
    "provider": "cf-uaa",
    "cf_api": "https://api.cf.example.com",
    "username": "((cf_username_prod))",
    "password": "((cf_password_prod))",
    "skip_ssl_validation": false
  }
}
```

**CredHub setup:**
```bash
credhub set -n /concourse/main/zap-scanner/cf_username_prod -t value -v "zap-scan-user"
credhub set -n /concourse/main/zap-scanner/cf_password_prod -t password -w "PASSWORD"
```

**Target config:**
```yaml
targets:
  - name: my-cf-app
    url: https://app.cf.example.com
    auth_mode: bearer
    auth_profile: production
```

### `oidc-client-credentials` — OIDC (Authentik, Keycloak, Auth0, Okta)

Fetches a bearer token via OAuth2 client_credentials grant.

```json
{
  "my-oidc": {
    "provider": "oidc-client-credentials",
    "token_url": "https://auth.example.com/application/o/token/",
    "client_id": "zap-scanner",
    "client_secret": "((zap_oidc_client_secret))",
    "scope": "openid",
    "verify_ssl": true
  }
}
```

**CredHub setup:**
```bash
credhub set -n /concourse/main/zap-scanner/zap_oidc_client_secret -t password -w "SECRET"
```

**Target config:**
```yaml
targets:
  - name: my-protected-app
    url: https://app.example.com
    auth_mode: bearer
    auth_profile: my-oidc
```

### `static` — Pre-configured Token

Returns a token value directly (from CredHub or environment variable).

```json
{
  "my-api-key": {
    "provider": "static",
    "token": "((my_api_token))"
  }
}
```

**CredHub setup:**
```bash
credhub set -n /concourse/main/zap-scanner/my_api_token -t value -v "TOKEN_VALUE"
```

## Multiple Profiles

You can define multiple profiles in a single `AUTH_PROFILES_JSON`:

```json
{
  "development": {
    "provider": "cf-uaa",
    "cf_api": "https://api.dev.example.com",
    "username": "((cf_user_dev))",
    "password": "((cf_pass_dev))"
  },
  "staging": {
    "provider": "cf-uaa",
    "cf_api": "https://api.staging.example.com",
    "username": "((cf_user_staging))",
    "password": "((cf_pass_staging))"
  },
  "monitoring": {
    "provider": "static",
    "token": "((monitoring_api_token))"
  }
}
```

Each target references its profile by name:
```yaml
- name: dev-app
  auth_profile: development
- name: staging-app
  auth_profile: staging
- name: prometheus
  auth_profile: monitoring
```

## Backwards Compatibility

Profiles without a `"provider"` key default to `cf-uaa`:

```json
{
  "legacy-profile": {
    "cf_api": "https://api.example.com",
    "username": "user",
    "password": "((password))"
  }
}
```

## Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `cf command timed out` | CF API unreachable | Check network/firewall, verify `cf_api` URL |
| `Token endpoint returned HTTP 401` | Wrong client_id/secret | Verify OIDC credentials in CredHub |
| `Missing required environment variable` | AUTH_PROFILES_JSON not set | Add to pipeline params in config.yml |
| `Profile 'x' not found` | Typo in `auth_profile` | Check target's auth_profile matches a key in AUTH_PROFILES_JSON |
| `SSL: CERTIFICATE_VERIFY_FAILED` | Self-signed cert | Set `skip_ssl_validation: true` (cf-uaa) or `verify_ssl: false` (OIDC) |

## Security

- Tokens are **never** written to files — passed via environment variables only
- ZAP output is scrubbed: `Bearer <token>` → `Bearer **REDACTED**` in CI logs
- CredHub references (`((var))`) are interpolated by Concourse at runtime
- CF_HOME uses a private temp directory (0700), cleaned up after token fetch
