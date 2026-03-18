#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 4:
        print(
            f"usage: {Path(sys.argv[0]).name} <work-root> <summary-path> <context>",
            file=sys.stderr,
        )
        return 2

    work_root = Path(sys.argv[1])
    summary_path = Path(sys.argv[2])
    context = sys.argv[3]

    targets = []

    if work_root.is_dir():
        for entry in sorted(os.listdir(work_root)):
            metadata_path = work_root / entry / "scan-metadata.json"
            if metadata_path.is_file():
                with metadata_path.open("r", encoding="utf-8") as f:
                    targets.append(json.load(f))

    summary_path.parent.mkdir(parents=True, exist_ok=True)
    with summary_path.open("w", encoding="utf-8") as f:
        json.dump({"context": context, "targets": targets}, f, indent=2)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())