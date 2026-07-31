#!/usr/bin/env python3
"""Fetch a bearer token using a pluggable auth provider.

Reads an auth profile from AUTH_PROFILES_JSON and fetches a bearer token
using the specified provider. Prints the raw token to stdout.

Supported providers:
  cf-uaa                  Cloud Foundry UAA (cf auth → cf oauth-token)
  oidc-client-credentials OIDC client_credentials grant (Authentik, Keycloak, etc.)
  static                  Passthrough — returns the token value directly

Usage:
    # Fetch token for a profile
    export AUTH_PROFILES_JSON='{"dev": {"provider": "cf-uaa", ...}}'
    python3 fetch-bearer-token.py dev

    # Override provider via CLI
    python3 fetch-bearer-token.py dev --provider static

Environment variables:
    AUTH_PROFILES_JSON   JSON object mapping profile names to provider configs

Exit codes:
    0  Token acquired — printed to stdout
    1  Error (missing config, auth failure, etc.)

Security:
    - Secrets passed via env vars, never CLI args
    - Token printed to stdout only (diagnostics to stderr)
    - No file-based caching — tokens stay in memory
    - CF_HOME uses a private temp dir (0700) cleaned up on exit
"""

import json
import os
import shutil
import ssl
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request


def log(msg):
    """Print diagnostic message to stderr."""
    print(f"[fetch-token] {msg}", file=sys.stderr)


def fetch_cf_uaa(profile):
    """Fetch bearer token via Cloud Foundry UAA (cf auth → cf oauth-token)."""
    cf_api = profile.get("cf_api")
    username = profile.get("username")
    password = profile.get("password")

    if not cf_api or not username or not password:
        log("ERROR: cf-uaa provider requires cf_api, username, password")
        sys.exit(1)

    # Use isolated CF_HOME to avoid contaminating other sessions
    cf_home = tempfile.mkdtemp(prefix="zap-cf-")
    os.chmod(cf_home, 0o700)
    env = {**os.environ, "CF_HOME": cf_home}

    skip_ssl = profile.get("skip_ssl_validation", False)

    try:
        cf_api_cmd = ["cf", "api", cf_api]
        if skip_ssl:
            cf_api_cmd.append("--skip-ssl-validation")
        subprocess.run(
            cf_api_cmd,
            env=env,
            capture_output=True,
            check=True,
            timeout=30,
        )
        subprocess.run(
            ["cf", "auth", username, password],
            env=env,
            capture_output=True,
            check=True,
            timeout=30,
        )
        result = subprocess.run(
            ["cf", "oauth-token"],
            env=env,
            capture_output=True,
            check=True,
            timeout=30,
            text=True,
        )
        token = result.stdout.strip()
        # Strip "bearer " / "Bearer " prefix
        for prefix in ("bearer ", "Bearer "):
            if token.startswith(prefix):
                token = token[len(prefix) :]
                break

        if not token:
            log("ERROR: cf oauth-token returned empty")
            sys.exit(1)

        log(f"CF UAA token acquired from {cf_api}")
        return token
    except subprocess.CalledProcessError as e:
        stderr = e.stderr.decode("utf-8", errors="replace") if isinstance(e.stderr, bytes) else str(e.stderr)
        log(f"ERROR: cf command failed: {stderr}")
        sys.exit(1)
    except subprocess.TimeoutExpired:
        log("ERROR: cf command timed out")
        sys.exit(1)
    finally:
        shutil.rmtree(cf_home, ignore_errors=True)


def fetch_oidc_client_credentials(profile):
    """Fetch bearer token via OIDC client_credentials grant."""
    token_url = profile.get("token_url")
    client_id = profile.get("client_id")
    client_secret = profile.get("client_secret")
    scope = profile.get("scope", "openid")

    if not token_url or not client_id or not client_secret:
        log("ERROR: oidc-client-credentials requires token_url, client_id, client_secret")
        sys.exit(1)

    verify_ssl = profile.get("verify_ssl", True)
    ssl_context = None
    if not verify_ssl:
        ssl_context = ssl.create_default_context()
        ssl_context.check_hostname = False
        ssl_context.verify_mode = ssl.CERT_NONE

    data = urllib.parse.urlencode(
        {
            "grant_type": "client_credentials",
            "client_id": client_id,
            "client_secret": client_secret,
            "scope": scope,
        }
    ).encode("utf-8")

    req = urllib.request.Request(
        token_url,
        data=data,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, context=ssl_context, timeout=30) as resp:
            body = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8", errors="replace")
        log(f"ERROR: Token endpoint returned HTTP {e.code}: {error_body}")
        sys.exit(1)
    except urllib.error.URLError as e:
        log(f"ERROR: Failed to reach token endpoint: {e.reason}")
        sys.exit(1)

    token = body.get("access_token")
    if not token:
        log("ERROR: Response missing access_token")
        sys.exit(1)

    expires_in = body.get("expires_in", "unknown")
    log(f"OIDC token acquired from {token_url} (expires_in={expires_in}s)")
    return token


def fetch_static(profile):
    """Return a static/pre-configured token."""
    token = profile.get("token")
    if not token:
        log("ERROR: static provider requires 'token' field")
        sys.exit(1)
    log("Static token loaded")
    return token


# Provider registry
PROVIDERS = {
    "cf-uaa": fetch_cf_uaa,
    "oidc-client-credentials": fetch_oidc_client_credentials,
    "static": fetch_static,
}


def main():
    if len(sys.argv) < 2:
        log(f"Usage: {sys.argv[0]} <profile_name> [--provider <type>]")
        log(f"Providers: {', '.join(PROVIDERS.keys())}")
        sys.exit(1)

    profile_name = sys.argv[1]
    provider_override = None
    if "--provider" in sys.argv:
        idx = sys.argv.index("--provider")
        if idx + 1 < len(sys.argv):
            provider_override = sys.argv[idx + 1]

    profiles_json = os.environ.get("AUTH_PROFILES_JSON")
    if not profiles_json:
        log("ERROR: AUTH_PROFILES_JSON environment variable not set")
        sys.exit(1)

    try:
        profiles = json.loads(profiles_json)
    except json.JSONDecodeError as e:
        log(f"ERROR: Invalid AUTH_PROFILES_JSON: {e}")
        sys.exit(1)

    if profile_name not in profiles:
        log(f"ERROR: Profile '{profile_name}' not found in AUTH_PROFILES_JSON")
        log(f"Available profiles: {', '.join(profiles.keys())}")
        sys.exit(1)

    profile = profiles[profile_name]

    # Determine provider: CLI override > profile config > default (cf-uaa)
    provider_name = provider_override or profile.get("provider", "cf-uaa")
    if provider_name not in PROVIDERS:
        log(f"ERROR: Unknown provider '{provider_name}'")
        log(f"Available: {', '.join(PROVIDERS.keys())}")
        sys.exit(1)

    log(f"Fetching token for profile '{profile_name}' via {provider_name}")
    token = PROVIDERS[provider_name](profile)

    # Output token to stdout (no newline for easy capture)
    sys.stdout.write(token)


if __name__ == "__main__":
    main()
