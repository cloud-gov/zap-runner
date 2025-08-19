---

## Daily ZAP scans - every 24 hours

The child pipeline `ci/child-pipelines/zap-dast.yml` includes a `time` resource with `interval: 24h` and scans the following contexts in parallel:

- `internal` (OpsUAA owner-password flow via UAAC)
- `external` (no auth)
- `cloud-gov-pages` (CF UAA user/pass -> `cf oauth-token`)
- `api` (static bearer header)
- `unauthenticated` (no auth)

Tune or add contexts under `ci/scan-contexts/`. Put URLs in `urls.txt` and settings in `config.yml`. A `test-template.yml` is included to show supported knobs.

## Authentication

We rely on Concourse + CredHub to inject secrets as vars. The pipeline **does not** call `credhub` directly.

- **CF UAA username/password → Bearer token**: the `acquire-auth` task runs `cf oauth-token`, which prints a bearer token that we pass to ZAP as an `Authorization` header. (See CF CLI help for `oauth-token`.)  
- **OpsUAA owner-password (UAAC)**: the `acquire-auth` task runs `uaac token owner get <client> <user> --secret <client_secret> --password <user_password>` to obtain a Bearer token (RFC 6749 “owner password” grant) and injects it as an `Authorization` header.

### Example variables (CredHub-backed)
See `ci/vars/zap-dast.yml`. Populate via your Concourse var store (CredHub):

```yaml
zap:
  auth_source:
    internal: opsuaa
    cloud-gov-pages: cf
  cf:
    cloud-gov-pages:
      api:  https://api.fr.cloud.gov
      user: zap-scan-user
      pass: ((/concourse/main/zap-scanner/zap-scan-password-production))
  opsuaa:
    host: opslogin.fr.cloud.gov
    client_id: zap_scan_client
    client_secret: ((/concourse/main/zap-scanner/zap_scan_client_secret-opsuaa))
    user: zap-scan-user
    pass: ((/concourse/main/zap-scanner/zap-scan-password-opsuaa))
````

## DefectDojo

Per-URL XML reports are generated (`zap-<host>.xml`) and pushed with **reimport-scan** (dedupes and updates findings). If reimport is not applicable, we fall back to a normal import.

---

## Notes & references

- ZAP AF traditional XML & site placeholders are supported by ZAP reporting; the pipeline emits one XML per host.
- DefectDojo supports import and **reimport** of ZAP scans via API v2; our task uses `reimport-scan` first, then falls back to `import-scan`.
- UAA bearer tokens are retrieved via owner-password or client credentials; UAAC’s owner-password is used for OpsUAA in our pipeline.
