#!/usr/bin/env python3
"""Extract auth profiles from an external zap-runner config.yml.

Reads auth_profiles_json from a config.yml and outputs it in our
zap-runner format with provider annotations.

Usage:
    python3 extract-auth-profiles.py <source-config.yml> [--sanitize]

Options:
    --sanitize    Replace real CF API URLs with placeholders

Exit codes:
    0  Success
    1  Missing arguments or parse error
"""

import json
import sys

import yaml


def sanitize_cf_api(url):
    """Replace real CF API URLs with generic placeholders."""
    if "dev" in url.lower():
        return "https://api.dev.example.com"
    elif "stage" in url.lower() or "staging" in url.lower():
        return "https://api.staging.example.com"
    elif "prod" in url.lower() or "fr.cloud" in url.lower():
        return "https://api.production.example.com"
    return "https://api.example.com"


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <source-config.yml> [--sanitize]", file=sys.stderr)
        sys.exit(1)

    source_path = sys.argv[1]
    sanitize = "--sanitize" in sys.argv

    with open(source_path, encoding="utf-8") as f:
        config = yaml.safe_load(f) or {}

    # Extract auth_profiles_json (may be a string or already parsed)
    profiles_raw = config.get("auth_profiles_json", "{}")
    profiles = json.loads(profiles_raw) if isinstance(profiles_raw, str) else profiles_raw

    if not profiles:
        print("No auth profiles found in config", file=sys.stderr)
        sys.exit(0)

    # Convert to our format with provider annotations
    converted = {}
    for name, profile in profiles.items():
        entry = {"provider": "cf-uaa"}

        cf_api = profile.get("cf_api", "")
        if sanitize:
            cf_api = sanitize_cf_api(cf_api)
        entry["cf_api"] = cf_api

        # Keep CredHub references as-is (they're placeholders, not real values)
        entry["username"] = profile.get("username", "")
        entry["password"] = profile.get("password", "")

        converted[name] = entry

    print("# Auth profiles extracted — add to ci/config.yml auth_profiles_json")
    print("# Each profile uses the cf-uaa provider (CF UAA bearer token)")
    print("#")
    print("# To use with zap-runner, paste this into config.yml:")
    print("# auth_profiles_json: |")
    print(f"#   {json.dumps(converted, indent=2).replace(chr(10), chr(10) + '#   ')}")
    print()
    print("# Raw JSON:")
    print(json.dumps(converted, indent=2))

    print(f"\nExtracted {len(converted)} profile(s)", file=sys.stderr)


if __name__ == "__main__":
    main()
