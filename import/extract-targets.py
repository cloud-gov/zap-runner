#!/usr/bin/env python3
"""Extract and convert targets from an external zap-runner targets.yml.

Reads a targets.yml in the cloud-gov/zap-runner format (deep-merge
defaults → service → target) and outputs our zap-runner
targets.yml format.

Usage:
    python3 extract-targets.py <source-targets.yml> [--sanitize] [--context <ctx>]

Options:
    --sanitize    Replace real URLs with placeholder patterns
    --context     Only extract targets for a specific context
    --csv         Output as CSV instead of YAML

Exit codes:
    0  Success
    1  Missing arguments or parse error
"""

import copy
import csv
import io
import sys

import yaml


def deep_merge(base, override):
    """Recursively merge override into base."""
    if isinstance(base, dict) and isinstance(override, dict):
        merged = copy.deepcopy(base)
        for key, value in override.items():
            merged[key] = deep_merge(merged[key], value) if key in merged else copy.deepcopy(value)
        return merged
    return copy.deepcopy(override)


def sanitize_url(url):
    """Replace environment-specific URLs with generic placeholders."""
    # Strip protocol
    from urllib.parse import urlparse

    parsed = urlparse(url)
    host = parsed.hostname or ""
    # Replace with generic pattern
    parts = host.split(".")
    if len(parts) >= 3:
        app_name = parts[0]
        return f"https://{app_name}.apps.example.com"
    return f"https://{host.replace('.', '-')}.example.com"


def extract_targets(source_path, sanitize=False, context_filter=None):
    """Parse source targets.yml and extract all targets."""
    with open(source_path, encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}

    global_defaults = data.get("defaults", {})
    results = []

    for service in data.get("services", []):
        service_meta = {k: v for k, v in service.items() if k != "targets"}
        service_defaults = deep_merge(global_defaults, service_meta)

        for raw_target in service.get("targets", []):
            target = deep_merge(service_defaults, raw_target)

            if not target.get("enabled", True):
                continue

            if context_filter and target.get("context") != context_filter:
                continue

            url = target.get("url", "")
            if sanitize:
                url = sanitize_url(url)

            auth_mode = target.get("auth_mode", "unauthenticated")
            results.append(
                {
                    "name": target.get("name", "unnamed"),
                    "url": url,
                    "service_name": target.get("service_name", "unknown"),
                    "context": target.get("context", "external"),
                    "scan_variant": target.get(
                        "scan_variant", "authenticated" if auth_mode != "unauthenticated" else "unauthenticated"
                    ),
                    "auth_mode": auth_mode,
                    "auth_profile": target.get("auth_profile", ""),
                    "include_paths": target.get("include_paths", []),
                    "exclude_paths": target.get("exclude_paths", []),
                    "scan": target.get("scan", {}),
                    "defectdojo": target.get("defectdojo", {}),
                    "report_to_defectdojo": target.get("report_to_defectdojo", True),
                }
            )

    return results, global_defaults


def targets_to_yaml(targets, defaults):
    """Convert extracted targets to our targets.yml format."""
    # Group by service_name + context + variant
    services = {}
    for t in targets:
        key = f"{t['service_name']}-{t['context']}-{t['scan_variant']}"
        if key not in services:
            services[key] = {
                "service_name": t["service_name"],
                "context": t["context"],
                "scan_variant": t["scan_variant"],
                "auth_mode": t["auth_mode"],
                "targets": [],
            }
            if t.get("auth_profile"):
                services[key]["auth_profile"] = t["auth_profile"]
            if t.get("defectdojo", {}).get("product_name"):
                services[key]["defectdojo"] = {"product_name": t["defectdojo"]["product_name"]}

        entry = {
            "name": t["name"],
            "url": t["url"],
        }
        if t.get("include_paths"):
            entry["include_paths"] = t["include_paths"]
        if t.get("scan"):
            # Only include non-default scan settings
            entry["scan"] = {k: v for k, v in t["scan"].items() if k in ("minutes", "max_depth", "thread_count")}
        if t.get("defectdojo", {}).get("engagement_name"):
            entry["defectdojo"] = {
                "engagement_name": t["defectdojo"].get("engagement_name", ""),
                "test_title": t["defectdojo"].get("test_title", ""),
            }

        services[key]["targets"].append(entry)

    # Build final structure
    result = {
        "defaults": {
            "enabled": True,
            "scan_variant": defaults.get("scan_variant", "unauthenticated"),
            "auth_mode": defaults.get("auth_mode", "unauthenticated"),
            "report_to_defectdojo": defaults.get("report_to_defectdojo", True),
            "exclude_paths": defaults.get("exclude_paths", []),
            "scan": defaults.get("scan", {}),
            "defectdojo": defaults.get("defectdojo", {}),
        },
        "services": list(services.values()),
    }
    return result


def targets_to_csv(targets):
    """Convert extracted targets to CSV format."""
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(
        ["name", "url", "context", "scan_variant", "auth_mode", "auth_profile", "scan_type", "include_paths"]
    )
    for t in targets:
        include = "|".join(t.get("include_paths", []))
        writer.writerow(
            [
                t["name"],
                t["url"],
                t["context"],
                t["scan_variant"],
                t["auth_mode"],
                t.get("auth_profile", ""),
                "web",
                include,
            ]
        )
    return output.getvalue()


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <source-targets.yml> [--sanitize] [--context <ctx>] [--csv]", file=sys.stderr)
        sys.exit(1)

    source_path = sys.argv[1]
    sanitize = "--sanitize" in sys.argv
    output_csv = "--csv" in sys.argv
    context_filter = None
    if "--context" in sys.argv:
        idx = sys.argv.index("--context")
        if idx + 1 < len(sys.argv):
            context_filter = sys.argv[idx + 1]

    targets, defaults = extract_targets(source_path, sanitize, context_filter)
    print(f"Extracted {len(targets)} target(s)", file=sys.stderr)

    if output_csv:
        print(targets_to_csv(targets))
    else:
        result = targets_to_yaml(targets, defaults)
        header = "---\n# Imported targets — review and customize before use\n"
        header += f"# Source: {source_path}\n"
        header += f"# Targets: {len(targets)}\n\n"
        print(header + yaml.dump(result, default_flow_style=False, sort_keys=False))


if __name__ == "__main__":
    main()
