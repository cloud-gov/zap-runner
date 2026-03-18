#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import yaml


def getenv_int(name: str, default: int) -> int:
    value = os.getenv(name, str(default))
    try:
        return int(value)
    except ValueError as exc:
        raise SystemExit(f"{name} must be an integer, got: {value}") from exc


def main() -> int:
    if len(sys.argv) != 3:
        print(
            f"usage: {Path(sys.argv[0]).name} <target-json> <plan-path>",
            file=sys.stderr,
        )
        return 2

    target = json.loads(sys.argv[1])
    plan_path = Path(sys.argv[2])

    name = target["name"]
    url = target["url"]
    include_paths = target.get("include_paths") or [f"^{url.rstrip('/')}/.*"]
    exclude_paths = target.get("exclude_paths") or []
    auth_mode = target.get("auth_mode", "unauthenticated")
    bearer_token = target.get("_runtime_bearer_token", "")

    report_dir = str(plan_path.parent)

    jobs: list[dict] = []

    if auth_mode == "bearer":
        jobs.append(
            {
                "type": "replacer",
                "parameters": {
                    "deleteAllRules": True,
                },
                "rules": [
                    {
                        "description": "Authorization header",
                        "enabled": True,
                        "matchType": "REQ_HEADER",
                        "matchRegex": False,
                        "matchString": "Authorization",
                        "replacement": f"Bearer {bearer_token}",
                        "initiators": [],
                        "url": "",
                    }
                ],
            }
        )

    jobs.extend(
        [
            {
                "type": "spider",
                "parameters": {
                    "context": name,
                    "user": "",
                    "maxDepth": getenv_int("ZAP_MAX_DEPTH", 5),
                    "threadCount": getenv_int("ZAP_THREAD_COUNT", 2),
                    "url": url,
                },
            },
            {
                "type": "passiveScan-config",
                "parameters": {
                    "maxAlertsPerRule": 10,
                    "scanOnlyInScope": True,
                },
            },
            {
                "type": "passiveScan-wait",
                "parameters": {
                    "maxDuration": getenv_int("ZAP_PASSIVE_WAIT_MINUTES", 10),
                },
            },
            {
                "type": "activeScan",
                "parameters": {
                    "context": name,
                    "user": "",
                    "policy": "Default Policy",
                    "maxRuleDurationInMins": 0,
                    "maxScanDurationInMins": getenv_int("ZAP_MINUTES", 20),
                    "addQueryParam": False,
                    "inScopeOnly": True,
                },
            },
            {
                "type": "report",
                "parameters": {
                    "template": "traditional-html",
                    "reportDir": report_dir,
                    "reportFile": f"{name}.html",
                    "displayReport": False,
                },
            },
            {
                "type": "report",
                "parameters": {
                    "template": "traditional-json",
                    "reportDir": report_dir,
                    "reportFile": f"{name}.json",
                    "displayReport": False,
                },
            },
            {
                "type": "report",
                "parameters": {
                    "template": "traditional-xml",
                    "reportDir": report_dir,
                    "reportFile": f"{name}.xml",
                    "displayReport": False,
                },
            },
            {
                "type": "report",
                "parameters": {
                    "template": "sarif-json",
                    "reportDir": report_dir,
                    "reportFile": f"{name}.sarif.json",
                    "displayReport": False,
                },
            },
            {
                "type": "exitStatus",
                "parameters": {
                    "warnLevel": os.getenv("ZAP_FAIL_WARN_LEVEL", "Medium"),
                    "errorLevel": os.getenv("ZAP_FAIL_ERROR_LEVEL", "High"),
                },
            },
        ]
    )

    plan = {
        "env": {
            "contexts": [
                {
                    "name": name,
                    "urls": [url],
                    "includePaths": include_paths,
                    "excludePaths": exclude_paths,
                }
            ]
        },
        "jobs": jobs,
    }

    plan_path.parent.mkdir(parents=True, exist_ok=True)
    with plan_path.open("w", encoding="utf-8") as f:
        yaml.safe_dump(plan, f, sort_keys=False)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())