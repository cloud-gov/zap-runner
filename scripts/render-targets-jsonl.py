#!/usr/bin/env python3
from __future__ import annotations

import copy
import json
import sys
from pathlib import Path

import yaml


def deep_merge(base, override):
    if isinstance(base, dict) and isinstance(override, dict):
        merged = copy.deepcopy(base)
        for key, value in override.items():
            if key in merged:
                merged[key] = deep_merge(merged[key], value)
            else:
                merged[key] = copy.deepcopy(value)
        return merged
    return copy.deepcopy(override)


def main() -> int:
    if len(sys.argv) != 3:
        print(
            f"usage: {Path(sys.argv[0]).name} <targets.yml> <context>",
            file=sys.stderr,
        )
        return 2

    targets_path = Path(sys.argv[1])
    wanted_context = sys.argv[2]

    if not targets_path.is_file():
        print(f"targets file not found: {targets_path}", file=sys.stderr)
        return 1

    with targets_path.open("r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}

    global_defaults = data.get("defaults", {})
    services = data.get("services", [])

    for service in services:
        service_meta = {k: v for k, v in service.items() if k != "targets"}
        service_defaults = deep_merge(global_defaults, service_meta)

        for raw_target in service.get("targets", []):
            target = deep_merge(service_defaults, raw_target)
            if not target.get("enabled", True):
                continue
            if target.get("context") != wanted_context:
                continue
            print(json.dumps(target, separators=(",", ":")))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())