#!/usr/bin/env python3
"""Parse targets.yml and emit matching targets as JSONL.

Usage:
    python3 parse-targets.py <targets.yml> <context> <scan_variant>

Reads the target inventory YAML, applies deep-merge of defaults → service → target,
filters by context and scan_variant, and prints one JSON object per line to stdout.

Exit codes:
    0  Success (even if zero targets match)
    1  Missing arguments or file not found
"""

import json
import os
import sys

# Add script directory to path for _utils import
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import yaml
from _utils import deep_merge


def main():
    """Parse targets.yml and print matching targets as JSONL to stdout."""
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <targets.yml> <context> <scan_variant>", file=sys.stderr)
        sys.exit(1)

    path, wanted_context, wanted_variant = sys.argv[1], sys.argv[2], sys.argv[3]

    with open(path, encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}

    global_defaults = data.get("defaults", {})
    scan_profiles = global_defaults.get("scan_profiles", {})

    for service in data.get("services", []):
        service_meta = {k: v for k, v in service.items() if k != "targets"}
        service_defaults = deep_merge(global_defaults, service_meta)
        for raw_target in service.get("targets", []):
            target = deep_merge(service_defaults, raw_target)
            if not target.get("enabled", True):
                continue
            if target.get("context") != wanted_context:
                continue
            if target.get("scan_variant", "unauthenticated") != wanted_variant:
                continue

            # Resolve scan_profile — profile overrides inherited defaults,
            # then any explicit per-target scan settings override the profile
            profile_name = target.get("scan_profile")
            if profile_name and profile_name in scan_profiles:
                profile_scan = scan_profiles[profile_name]
                # Start with profile, overlay any target-specific scan overrides
                # (raw_target.scan has only explicit per-target overrides, not inherited defaults)
                target_scan_overrides = raw_target.get("scan", {})
                target["scan"] = deep_merge(profile_scan, target_scan_overrides)

            print(json.dumps(target, separators=(",", ":")))


if __name__ == "__main__":
    main()
