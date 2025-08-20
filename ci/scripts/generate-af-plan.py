#!/usr/bin/env python3
"""
Generate ZAP Automation Framework plan for a given context.
This script can be used for local testing and debugging of AF plans.
"""

import argparse
import json
import os
import sys
import yaml
from pathlib import Path


def load_context_config(context_dir):
    """Load configuration for a specific scan context."""
    config_path = context_dir / "config.yml"
    urls_path = context_dir / "urls.txt"
    
    config = {}
    if config_path.exists():
        with open(config_path) as f:
            config = yaml.safe_load(f) or {}
    
    urls = []
    if urls_path.exists():
        with open(urls_path) as f:
            urls = [line.strip() for line in f if line.strip() and not line.startswith('#')]
    
    return config, urls


def load_reporting_config(reporting_path):
    """Load central reporting configuration."""
    with open(reporting_path) as f:
        return yaml.safe_load(f)


def generate_af_plan(context_name, base_dir, dry_run=False):
    """Generate a ZAP Automation Framework plan for the given context."""
    
    # Paths
    context_dir = base_dir / "scan-contexts" / context_name
    common_dir = base_dir / "common"
    
    if not context_dir.exists():
        print(f"Error: Context directory does not exist: {context_dir}")
        return None
    
    # Load configurations
    context_config, urls = load_context_config(context_dir)
    reporting_config = load_reporting_config(common_dir / "reporting.yml")
    
    # Load user agent
    user_agent = ""
    ua_file = common_dir / "user-agent.txt"
    if ua_file.exists():
        with open(ua_file) as f:
            user_agent = f.read().strip()
    
    # Load exclusions
    exclusions = []
    exc_file = common_dir / "global-exclusions.txt"
    if exc_file.exists():
        with open(exc_file) as f:
            exclusions = [line.strip() for line in f 
                         if line.strip() and not line.startswith('#')]
    
    # Build AF plan
    plan = {
        "env": {
            "contexts": []
        },
        "jobs": []
    }
    
    # 1. Options job
    options_job = {
        "type": "options",
        "parameters": {}
    }
    
    if user_agent:
        options_job["parameters"]["userAgent"] = user_agent
    
    if exclusions:
        options_job["parameters"]["excludePaths"] = exclusions
    
    plan["jobs"].append(options_job)
    
    # 2. Authentication (if needed)
    auth_type = context_config.get("AUTH_TYPE", "none")
    if auth_type != "none":
        # Add replacer job for authentication
        replacer_job = {
            "type": "replacer",
            "parameters": {
                "rules": [{
                    "description": "Authentication header",
                    "enabled": True,
                    "matchType": "REQ_HEADER",
                    "matchString": "Authorization",
                    "replacement": "Bearer <TOKEN>",
                    "matchRegex": False
                }]
            }
        }
        plan["jobs"].append(replacer_job)
    
    # 3. Import URLs or OpenAPI specs
    scan_type = context_config.get("SCAN_TYPE", "web")
    
    if scan_type == "api":
        # Look for OpenAPI specs
        openapi_files = list(context_dir.glob("openapi-*.json"))
        for spec_file in openapi_files:
            openapi_job = {
                "type": "openapi",
                "parameters": {
                    "apiFile": str(spec_file),
                    "targetUrl": urls[0] if urls else "https://api.example.com"
                }
            }
            plan["jobs"].append(openapi_job)
    else:
        # Regular URL import
        for url in urls:
            import_job = {
                "type": "import",
                "parameters": {
                    "type": "url",
                    "fileName": f"url-{url.replace('https://', '').replace('/', '_')}.txt"
                }
            }
            plan["jobs"].append(import_job)
    
    # 4. Spider job
    spider_depth = context_config.get("SPIDER_MAX_DEPTH", 5)
    spider_job = {
        "type": "spider",
        "parameters": {
            "maxDepth": spider_depth
        }
    }
    plan["jobs"].append(spider_job)
    
    # 5. Active scan job
    scan_duration = context_config.get("MAX_SCAN_DURATION", 0)
    active_scan_job = {
        "type": "activeScan",
        "parameters": {
            "policy": "Default Policy"
        }
    }
    if scan_duration > 0:
        active_scan_job["parameters"]["maxScanDurationInMins"] = scan_duration
    
    plan["jobs"].append(active_scan_job)
    
    # 6. Report jobs
    for template in reporting_config.get("templates", []):
        report_job = {
            "type": "report",
            "parameters": {
                "template": template["id"],
                "reportDir": "/zap/wrk/reports",
                "reportFile": f"zap-{context_name}.{template['extension']}",
                "displayReport": False,
                "reportTitle": f"ZAP Scan - {context_name}",
                "risks": reporting_config.get("filters", {}).get("risks", []),
                "confidences": reporting_config.get("filters", {}).get("confidences", [])
            }
        }
        plan["jobs"].append(report_job)
    
    # 7. Exit status job
    threshold = context_config.get("ALERT_THRESHOLD", "MEDIUM")
    exit_job = {
        "type": "exitStatus",
        "parameters": {
            "errorLevel": "HIGH" if threshold == "HIGH" else "HIGH",
            "warnLevel": threshold if threshold != "HIGH" else "MEDIUM"
        }
    }
    plan["jobs"].append(exit_job)
    
    return plan


def main():
    parser = argparse.ArgumentParser(
        description="Generate ZAP Automation Framework plan for a scan context"
    )
    parser.add_argument(
        "--context",
        required=True,
        help="Name of the scan context (e.g., internal, external, api)"
    )
    parser.add_argument(
        "--base-dir",
        default="ci",
        help="Base directory for CI configuration (default: ci)"
    )
    parser.add_argument(
        "--output",
        help="Output file path (default: stdout)"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Display the plan without writing to file"
    )
    
    args = parser.parse_args()
    
    base_dir = Path(args.base_dir)
    if not base_dir.exists():
        print(f"Error: Base directory does not exist: {base_dir}")
        sys.exit(1)
    
    # Generate the plan
    plan = generate_af_plan(args.context, base_dir, args.dry_run)
    
    if plan is None:
        sys.exit(1)
    
    # Output the plan
    plan_yaml = yaml.dump(plan, default_flow_style=False, sort_keys=False)
    
    if args.dry_run or not args.output:
        print(plan_yaml)
    else:
        with open(args.output, 'w') as f:
            f.write(plan_yaml)
        print(f"Plan written to: {args.output}")
    
    return 0


if __name__ == "__main__":
    sys.exit(main())