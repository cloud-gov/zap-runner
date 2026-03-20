#!/usr/bin/env python3
"""Build a ZAP Automation Framework plan YAML from a target JSON object.

Environment variables (required):
    TARGET_JSON              JSON string of the target object
    PLAN_PATH                Output path for the plan YAML
    REPORT_DIR               Directory for report output

Environment variables (with defaults from target.scan{}):
    ZAP_MINUTES              Active scan duration (default: 10)
    ZAP_MAX_DEPTH            Spider max depth (default: 5)
    ZAP_THREAD_COUNT         Spider thread count (default: 2)
    ZAP_PASSIVE_WAIT_MINUTES Passive scan wait (default: 5)
    ZAP_FAIL_WARN_LEVEL      Exit warn level (default: Medium)
    ZAP_FAIL_ERROR_LEVEL     Exit error level (default: High)

Optional environment variables:
    ZAP_SKIP_ACTIVE_SCAN     Set to "true" to skip active scan (faster for CI tests)
    ZAP_REPORT_FORMATS       Comma-separated list of formats (default: html,json,xml,sarif)
    ZAP_MIN_RISK_LEVEL       Minimum risk to report: Informational|Low|Medium|High (default: Low)
    ZAP_MIN_CONFIDENCE       Minimum confidence to report: Low|Medium|High|Confirmed (default: Medium)

Exit codes:
    0  Plan written successfully
    1  Missing required environment variable or invalid input
"""

import json
import os
import sys

import yaml


def get_env(name, default=None):
    """Get environment variable, exit if required and missing."""
    val = os.environ.get(name, default)
    if val is None:
        print(f"Missing required environment variable: {name}", file=sys.stderr)
        sys.exit(1)
    return val


def main():
    target = json.loads(get_env("TARGET_JSON"))
    plan_path = get_env("PLAN_PATH")
    report_dir = get_env("REPORT_DIR")

    name = target["name"]
    url = target["url"]
    include_paths = target.get("include_paths") or [f"^{url.rstrip('/')}/.*"]
    exclude_paths = target.get("exclude_paths") or []
    auth_mode = target.get("auth_mode", "unauthenticated")
    scan = target.get("scan", {})
    bearer_token = target.get("_runtime_bearer_token", "")
    headers = target.get("headers", {})

    scan_type = target.get("scan_type", "web")
    is_api_scan = scan_type == "api"
    passive_only = scan.get("passive_only", False)
    skip_active = passive_only or os.environ.get("ZAP_SKIP_ACTIVE_SCAN", "false") == "true"
    report_formats = os.environ.get("ZAP_REPORT_FORMATS", "html,json,xml,sarif").split(",")

    jobs = []

    # Auth configuration — ZAP replacer job injects headers into all requests
    # Ref: https://www.zaproxy.org/docs/desktop/addons/replacer/automation/
    if auth_mode == "bearer":
        jobs.append(
            {
                "type": "replacer",
                "parameters": {"deleteAllRules": True},
                "rules": [
                    {
                        "description": "Authorization header",
                        "matchType": "req_header",
                        "matchRegex": False,
                        "matchString": "Authorization",
                        "replacementString": f"Bearer {bearer_token}",
                        "tokenProcessing": False,
                        "url": "",
                    }
                ],
            }
        )
    elif auth_mode == "header":
        rules = [
            {
                "description": f"{k} header",
                "matchType": "req_header",
                "matchRegex": False,
                "matchString": k,
                "replacementString": v,
                "tokenProcessing": False,
                "url": "",
            }
            for k, v in headers.items()
        ]
        if rules:
            jobs.append({"type": "replacer", "parameters": {"deleteAllRules": True}, "rules": rules})
    elif auth_mode != "unauthenticated":
        raise SystemExit(f"Unsupported auth_mode: {auth_mode}")

    # Spider — API scans use shallow depth (1) to hit API endpoints without deep crawling
    spider_depth = 1 if is_api_scan else int(scan.get("max_depth", get_env("ZAP_MAX_DEPTH", "5")))
    jobs.append(
        {
            "type": "spider",
            "parameters": {
                "context": name,
                "user": "",
                "maxDepth": spider_depth,
                "threadCount": int(scan.get("thread_count", get_env("ZAP_THREAD_COUNT", "2"))),
                "url": url,
            },
        }
    )

    # Passive scan
    jobs.append({"type": "passiveScan-config", "parameters": {"maxAlertsPerRule": 10, "scanOnlyInScope": True}})
    jobs.append(
        {
            "type": "passiveScan-wait",
            "parameters": {
                "maxDuration": int(scan.get("passive_wait_minutes", get_env("ZAP_PASSIVE_WAIT_MINUTES", "5")))
            },
        }
    )

    # Active scan (optional — skipped in CI test mode; API scans use default policy)
    if not skip_active:
        jobs.append(
            {
                "type": "activeScan",
                "parameters": {
                    "context": name,
                    "user": "",
                    "policy": "Default Policy",
                    "maxRuleDurationInMins": 0,
                    "maxScanDurationInMins": int(scan.get("minutes", get_env("ZAP_MINUTES", "10"))),
                    "addQueryParam": False,
                    "inScopeOnly": True,
                },
            }
        )

    # Note: ZAP_MIN_RISK_LEVEL and ZAP_MIN_CONFIDENCE are applied at the
    # validation/consumption level (validate-reports.py --min-risk), not in the
    # ZAP plan. ZAP's alertFilter job type only supports per-ruleId filtering,
    # not broad risk/confidence-level exclusion. Reports contain all findings;
    # the exitStatus job uses warnLevel/errorLevel for pipeline pass/fail.

    # Reports
    format_map = {
        "html": "traditional-html",
        "json": "traditional-json",
        "xml": "traditional-xml",
        "sarif": "sarif-json",
    }
    for fmt in report_formats:
        fmt = fmt.strip()
        if fmt in format_map:
            ext = f"{name}.sarif.json" if fmt == "sarif" else f"{name}.{fmt}"
            jobs.append(
                {
                    "type": "report",
                    "parameters": {
                        "template": format_map[fmt],
                        "reportDir": report_dir,
                        "reportFile": ext,
                        "displayReport": False,
                    },
                }
            )

    # Exit status
    jobs.append(
        {
            "type": "exitStatus",
            "parameters": {
                "warnLevel": scan.get("fail_warn_level", get_env("ZAP_FAIL_WARN_LEVEL", "Medium")),
                "errorLevel": scan.get("fail_error_level", get_env("ZAP_FAIL_ERROR_LEVEL", "High")),
            },
        }
    )

    # Assemble plan
    plan = {
        "env": {
            "contexts": [{"name": name, "urls": [url], "includePaths": include_paths, "excludePaths": exclude_paths}]
        },
        "jobs": jobs,
    }

    with open(plan_path, "w", encoding="utf-8") as f:
        yaml.safe_dump(plan, f, sort_keys=False)


if __name__ == "__main__":
    main()
