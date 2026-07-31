#!/usr/bin/env python3
"""Convert a CSV of scan targets into targets.yml format.

Usage:
    python3 csv-to-targets.py targets.csv > ci/zap-config/targets.yml
    python3 csv-to-targets.py targets.csv --merge ci/zap-config/targets.yml

CSV format (header row required):
    name,url,context,scan_variant,auth_mode,auth_profile,scan_type,include_paths

Minimal CSV (only name and url required, defaults applied):
    name,url
    my-app,https://app.example.com

Full CSV with all options:
    name,url,context,scan_variant,auth_mode,auth_profile,scan_type,include_paths
    my-app,https://app.example.com,public,unauthenticated,unauthenticated,,web,
    my-api,https://api.example.com,internal,unauthenticated,unauthenticated,,api,
    my-cf-app,https://cf.example.com,external,authenticated,bearer,production,web,

Exit codes:
    0  targets.yml written to stdout (or merged to file)
    1  Invalid CSV or missing required fields
"""

import csv
import io
import sys

import yaml

DEFAULTS = {
    "context": "public",
    "scan_variant": "unauthenticated",
    "auth_mode": "unauthenticated",
    "auth_profile": "",
    "scan_type": "web",
    "include_paths": "",
}

YAML_DEFAULTS = {
    "enabled": True,
    "scan_variant": "unauthenticated",
    "auth_mode": "unauthenticated",
    "report_to_defectdojo": True,
    "exclude_paths": [
        "mozilla\\.com",
        "mozilla\\.net",
        "mozilla\\.org",
        "google\\.com",
        "googleapis\\.com",
        "cloudflare\\.com",
        "jsdelivr\\.net",
        ".*logout.*",
        ".*signout.*",
    ],
    "scan": {
        "minutes": 10,
        "max_depth": 5,
        "thread_count": 2,
        "passive_wait_minutes": 5,
        "fail_warn_level": "Medium",
        "fail_error_level": "High",
    },
    "defectdojo": {
        "product_type_name": "Web Application",
        "tags": ["zap", "concourse", "automated"],
    },
}


def csv_to_services(csv_path):
    """Parse CSV and group targets by service (context + scan_variant)."""
    services = {}

    with open(csv_path, encoding="utf-8") as f:
        # Filter out comment lines before passing to DictReader
        lines = [line for line in f if not line.strip().startswith("#")]
        reader = csv.DictReader(io.StringIO("".join(lines)))

        for row_num, row in enumerate(reader, start=2):
            name = (row.get("name") or "").strip()
            url = (row.get("url") or "").strip()

            if not name or not url:
                print(f"WARNING: row {row_num} missing name or url, skipping", file=sys.stderr)
                continue

            ctx = row.get("context", "").strip() or DEFAULTS["context"]
            variant = row.get("scan_variant", "").strip() or DEFAULTS["scan_variant"]
            auth_mode = row.get("auth_mode", "").strip() or DEFAULTS["auth_mode"]
            auth_profile = row.get("auth_profile", "").strip() or ""
            scan_type = row.get("scan_type", "").strip() or DEFAULTS["scan_type"]
            include_paths_raw = row.get("include_paths", "").strip()

            # Auto-generate include_paths from URL if not provided
            from urllib.parse import urlparse

            parsed = urlparse(url)
            escaped_host = parsed.hostname.replace(".", "\\\\.")
            auto_include = f"^{parsed.scheme}://{escaped_host}/.*"
            include_paths = (
                [p.strip() for p in include_paths_raw.split("|") if p.strip()] if include_paths_raw else [auto_include]
            )

            # Group by service key
            service_key = f"{ctx}-{variant}-{auth_mode}"
            if service_key not in services:
                svc = {
                    "service_name": f"{ctx}-targets",
                    "context": ctx,
                    "scan_variant": variant,
                    "auth_mode": auth_mode,
                }
                if auth_profile:
                    svc["auth_profile"] = auth_profile
                services[service_key] = {"meta": svc, "targets": []}

            target = {
                "name": name,
                "url": url,
                "include_paths": include_paths,
            }
            if scan_type != "web":
                target["scan_type"] = scan_type

            services[service_key]["targets"].append(target)

    return services


def build_targets_yml(services):
    """Build the targets.yml structure."""
    result = {
        "defaults": YAML_DEFAULTS,
        "services": [],
    }

    for key in sorted(services.keys()):
        svc_data = services[key]
        service = dict(svc_data["meta"])
        service["targets"] = svc_data["targets"]
        result["services"].append(service)

    return result


def main():
    """Convert CSV to targets.yml and write to stdout."""
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <targets.csv> [--merge <targets.yml>]", file=sys.stderr)
        print(
            "\nCSV columns: name,url,context,scan_variant,auth_mode,auth_profile,scan_type,include_paths",
            file=sys.stderr,
        )
        print("Only name and url are required. Others have sensible defaults.", file=sys.stderr)
        sys.exit(1)

    csv_path = sys.argv[1]
    services = csv_to_services(csv_path)

    if not services:
        print("ERROR: no valid targets found in CSV", file=sys.stderr)
        sys.exit(1)

    targets_yml = build_targets_yml(services)

    # Header comment
    header = """---
# ZAP Scan Target Inventory
# Generated from CSV by csv-to-targets.py
#
# Context taxonomy:
#   internal  — internal APIs and services
#   external  — external apps requiring authentication
#   public    — public-facing apps, no authentication needed
#   static    — static sites, landing pages
#
# Edit this file directly or regenerate from CSV:
#   python3 ci/scripts/csv-to-targets.py ci/zap-config/targets.csv > ci/zap-config/targets.yml

"""
    output = header + yaml.dump(targets_yml, default_flow_style=False, sort_keys=False)
    sys.stdout.write(output)

    target_count = sum(len(s["targets"]) for s in services.values())
    print(f"Generated {target_count} target(s) in {len(services)} service(s)", file=sys.stderr)


if __name__ == "__main__":
    main()
