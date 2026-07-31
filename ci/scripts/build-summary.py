#!/usr/bin/env python3
"""Build a context summary JSON from scan metadata files.

Usage:
    python3 build-summary.py <work_root> <output_path> <context> <scan_variant> <scan_key>

Walks the work_root directory, collects scan-metadata.json from each
target subdirectory, and writes a context-summary.json with all targets.

Exit codes:
    0  Summary written successfully
    1  Missing arguments
"""

import json
import os
import sys


def main():
    """Collect scan metadata and write context summary."""
    if len(sys.argv) != 6:
        print(f"Usage: {sys.argv[0]} <work_root> <output_path> <context> <variant> <scan_key>", file=sys.stderr)
        sys.exit(1)

    work_root, summary_path, context, scan_variant, scan_key = sys.argv[1:6]
    targets = []

    for entry in sorted(os.listdir(work_root)):
        metadata_path = os.path.join(work_root, entry, "scan-metadata.json")
        if os.path.isfile(metadata_path):
            with open(metadata_path, encoding="utf-8") as f:
                targets.append(json.load(f))

    with open(summary_path, "w", encoding="utf-8") as f:
        json.dump(
            {
                "context": context,
                "scan_variant": scan_variant,
                "scan_key": scan_key,
                "targets": targets,
            },
            f,
            indent=2,
        )

    print(f"Summary: {len(targets)} target(s) written to {summary_path}")


if __name__ == "__main__":
    main()
