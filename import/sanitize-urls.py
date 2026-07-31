#!/usr/bin/env python3
"""Sanitize a targets.yml by replacing real URLs with generic placeholders.

Useful for publishing configuration examples without exposing real endpoints.

Usage:
    python3 sanitize-urls.py <targets.yml> > sanitized-targets.yml

Replaces:
    - Real hostnames → app-name.apps.example.com
    - CF API URLs → api.{env}.example.com
    - CredHub refs preserved as-is (already placeholders)
    - Include/exclude path regexes updated to match new hostnames

Exit codes:
    0  Success
    1  Missing arguments
"""

import re
import sys
from urllib.parse import urlparse

import yaml


def sanitize_host(url):
    """Replace a real URL with a generic placeholder."""
    parsed = urlparse(url)
    host = parsed.hostname or ""
    path = parsed.path or ""

    parts = host.split(".")
    app_name = parts[0] if parts else "app"

    # Detect environment from hostname patterns
    env = "production"
    if "dev" in host.lower():
        env = "dev"
    elif "stage" in host.lower() or "staging" in host.lower():
        env = "staging"

    return f"https://{app_name}.{env}.example.com{path}"


def sanitize_regex(pattern, url_map):
    """Update a regex include/exclude path to match sanitized URLs."""
    for original_host, new_host in url_map.items():
        escaped_orig = re.escape(original_host).replace(r"\.", r"\\.")
        escaped_new = re.escape(new_host).replace(r"\.", r"\\.")
        pattern = pattern.replace(escaped_orig, escaped_new)
        # Also handle non-escaped versions
        pattern = pattern.replace(original_host.replace(".", "\\."), new_host.replace(".", "\\."))
    return pattern


def sanitize_targets(data):
    """Walk the targets structure and sanitize all URLs."""
    url_map = {}  # original_host → sanitized_host

    for service in data.get("services", []):
        for target in service.get("targets", []):
            url = target.get("url", "")
            if url:
                original_host = urlparse(url).hostname or ""
                sanitized = sanitize_host(url)
                sanitized_host = urlparse(sanitized).hostname or ""
                url_map[original_host] = sanitized_host
                target["url"] = sanitized

                # Update include_paths
                if "include_paths" in target:
                    target["include_paths"] = [sanitize_regex(p, url_map) for p in target["include_paths"]]

    return data


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <targets.yml>", file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1], encoding="utf-8") as f:
        data = yaml.safe_load(f)

    sanitized = sanitize_targets(data)

    header = "---\n# Sanitized targets — real URLs replaced with example.com placeholders\n\n"
    print(header + yaml.dump(sanitized, default_flow_style=False, sort_keys=False))

    # Count targets
    count = sum(len(s.get("targets", [])) for s in data.get("services", []))
    print(f"Sanitized {count} target(s)", file=sys.stderr)


if __name__ == "__main__":
    main()
