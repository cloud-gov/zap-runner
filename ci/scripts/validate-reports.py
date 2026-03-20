#!/usr/bin/env python3
"""Validate ZAP scan reports for correctness and completeness.

Usage:
    python3 validate-reports.py <report_dir> [--expect-alerts] [--min-alerts N]

Validates:
  1. Expected report files exist and are non-empty
  2. JSON report has valid structure (site[], alerts)
  3. SARIF report has valid schema reference and results[]
  4. Optional: asserts minimum number of alerts found

Exit codes:
    0  All validations passed
    1  One or more validations failed
"""

import argparse
import json
import os
import sys

RISK_LEVELS = {"Informational": 0, "Low": 1, "Medium": 2, "High": 3}
CONFIDENCE_LEVELS = {"Low": 1, "Medium": 2, "High": 3, "Confirmed": 4}


def validate_json_report(path, min_risk="Informational", min_confidence="Low"):
    """Validate ZAP traditional-json report structure.

    Counts only alerts at or above the specified risk and confidence levels.
    """
    errors = []
    min_risk_val = RISK_LEVELS.get(min_risk, 0)
    min_conf_val = CONFIDENCE_LEVELS.get(min_confidence, 1)

    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)

        if not isinstance(data, dict):
            errors.append(f"  {os.path.basename(path)}: root is not an object")
            return errors, 0

        sites = data.get("site", [])
        if not isinstance(sites, list):
            errors.append(f"  {os.path.basename(path)}: 'site' is not an array")
            return errors, 0

        alert_count = 0
        for site in sites:
            alerts = site.get("alerts", [])
            for alert in alerts:
                risk = RISK_LEVELS.get(alert.get("riskdesc", "").split(" ")[0], 0)
                conf = CONFIDENCE_LEVELS.get(alert.get("confidence", ""), 1)
                if risk >= min_risk_val and conf >= min_conf_val:
                    alert_count += 1

        return errors, alert_count
    except json.JSONDecodeError as e:
        errors.append(f"  {os.path.basename(path)}: invalid JSON — {e}")
        return errors, 0


def validate_sarif_report(path):
    """Validate SARIF report structure."""
    errors = []
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)

        if "$schema" not in data and "version" not in data:
            errors.append(f"  {os.path.basename(path)}: missing $schema or version")

        runs = data.get("runs", [])
        if not isinstance(runs, list) or len(runs) == 0:
            errors.append(f"  {os.path.basename(path)}: 'runs' is empty or missing")
            return errors, 0

        result_count = len(runs[0].get("results", []))
        return errors, result_count
    except json.JSONDecodeError as e:
        errors.append(f"  {os.path.basename(path)}: invalid JSON — {e}")
        return errors, 0


def main():
    parser = argparse.ArgumentParser(description="Validate ZAP scan reports")
    parser.add_argument("report_dir", help="Directory containing report files")
    parser.add_argument("--expect-alerts", action="store_true", help="Assert that at least some alerts were found")
    parser.add_argument("--min-alerts", type=int, default=0, help="Minimum number of JSON alerts expected")
    parser.add_argument(
        "--min-risk",
        default="Informational",
        choices=["Informational", "Low", "Medium", "High"],
        help="Minimum risk level to count (default: Informational)",
    )
    parser.add_argument(
        "--min-confidence",
        default="Low",
        choices=["Low", "Medium", "High", "Confirmed"],
        help="Minimum confidence to count (default: Low)",
    )
    args = parser.parse_args()

    report_dir = args.report_dir
    if not os.path.isdir(report_dir):
        print(f"FAIL: report directory does not exist: {report_dir}")
        sys.exit(1)

    all_errors = []
    total_json_alerts = 0
    total_sarif_results = 0
    files_found = 0

    # Walk all target subdirectories
    for entry in sorted(os.listdir(report_dir)):
        entry_path = os.path.join(report_dir, entry)
        if not os.path.isdir(entry_path):
            continue

        print(f"Validating: {entry}/")

        # Check if directory has any report files at all
        report_files = [f for f in os.listdir(entry_path) if os.path.isfile(os.path.join(entry_path, f))]
        if not report_files:
            print("  WARNING: no report files generated (ZAP may have failed to connect)")
            continue

        # Check report files — JSON is required, others are optional
        for ext in ["html", "json", "xml", "sarif.json"]:
            fpath = os.path.join(entry_path, f"{entry}.{ext}")
            if not os.path.isfile(fpath):
                if ext == "json":
                    all_errors.append(f"  {entry}.{ext}: MISSING (required)")
                # Other formats are optional — skip silently
                continue
            size = os.path.getsize(fpath)
            if size == 0:
                all_errors.append(f"  {entry}.{ext}: EMPTY (0 bytes)")
                continue
            files_found += 1
            print(f"  {entry}.{ext}: {size:,} bytes OK")

            # Structural validation
            if ext == "json":
                errs, count = validate_json_report(fpath, args.min_risk, args.min_confidence)
                all_errors.extend(errs)
                total_json_alerts += count
                print(f"  JSON alerts: {count}")
            elif ext == "sarif.json":
                errs, count = validate_sarif_report(fpath)
                all_errors.extend(errs)
                total_sarif_results += count
                print(f"  SARIF results: {count}")
            elif ext == "xml":
                # Basic XML well-formedness check
                try:
                    import xml.etree.ElementTree as ET

                    ET.parse(fpath)
                    print("  XML: well-formed OK")
                except ET.ParseError as e:
                    all_errors.append(f"  {entry}.xml: malformed XML — {e}")

    # Summary
    print("\n=== Validation Summary ===")
    print(f"Files validated: {files_found}")
    print(f"JSON alerts total: {total_json_alerts}")
    print(f"SARIF results total: {total_sarif_results}")

    if args.expect_alerts and total_json_alerts == 0:
        all_errors.append("Expected at least some alerts but found 0")

    if args.min_alerts > 0 and total_json_alerts < args.min_alerts:
        all_errors.append(f"Expected >= {args.min_alerts} alerts but found {total_json_alerts}")

    if all_errors:
        print(f"\nFAILURES ({len(all_errors)}):")
        for err in all_errors:
            print(f"  - {err}")
        sys.exit(1)
    else:
        print("\nAll validations PASSED")
        sys.exit(0)


if __name__ == "__main__":
    main()
