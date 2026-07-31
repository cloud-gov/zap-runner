#!/usr/bin/env python3
"""List all context/variant combinations defined in targets.yml.

Usage:
    python3 list-contexts.py <targets.yml> [--json]

Reads the target inventory and reports which context + scan_variant
combinations have active (enabled) targets. Useful for:
  - Verifying pipeline `across` values match actual targets
  - Discovering what will be scanned
  - Detecting empty matrix cells

Exit codes:
    0  Success
    1  Missing arguments or file not found
"""

import json
import os
import sys
from collections import defaultdict

# Add script directory to path for _utils import
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import yaml
from _utils import deep_merge


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <targets.yml> [--json]", file=sys.stderr)
        sys.exit(1)

    path = sys.argv[1]
    output_json = "--json" in sys.argv

    with open(path, encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}

    global_defaults = data.get("defaults", {})
    contexts = set()
    variants = set()
    cells = defaultdict(list)

    for service in data.get("services", []):
        service_meta = {k: v for k, v in service.items() if k != "targets"}
        service_defaults = deep_merge(global_defaults, service_meta)
        for raw_target in service.get("targets", []):
            target = deep_merge(service_defaults, raw_target)
            if not target.get("enabled", True):
                continue
            ctx = target.get("context", "unknown")
            var = target.get("scan_variant", "unauthenticated")
            contexts.add(ctx)
            variants.add(var)
            cells[(ctx, var)].append(
                {
                    "name": target.get("name", "unnamed"),
                    "url": target.get("url", "no-url"),
                    "scan_type": target.get("scan_type", "web"),
                }
            )

    if output_json:
        result = {
            "contexts": sorted(contexts),
            "variants": sorted(variants),
            "cells": {f"{ctx}/{var}": targets for (ctx, var), targets in sorted(cells.items())},
            "total_targets": sum(len(v) for v in cells.values()),
        }
        print(json.dumps(result, indent=2))
    else:
        print(f"Contexts: {', '.join(sorted(contexts))}")
        print(f"Variants: {', '.join(sorted(variants))}")
        print(f"Matrix cells ({len(cells)} active):")
        for (ctx, var), targets in sorted(cells.items()):
            print(f"  {ctx}/{var}: {len(targets)} target(s)")
            for t in targets:
                scan_type = f" [{t['scan_type']}]" if t.get("scan_type", "web") != "web" else ""
                print(f"    - {t['name']}: {t['url']}{scan_type}")
        print(f"\nTotal: {sum(len(v) for v in cells.values())} target(s)")


if __name__ == "__main__":
    main()
