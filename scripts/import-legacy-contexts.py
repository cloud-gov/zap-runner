#!/usr/bin/env python3
"""
Convert legacy OWASP ZAP .context XML files into a service-centric targets.yml
skeleton for review.

This is intentionally conservative:
- it preserves source metadata
- it infers context/auth_profile from filenames and hostnames
- it splits multiple include regex hostnames into one target per hostname
- it is meant to generate a draft, not silently replace the curated targets.yml
"""

from __future__ import annotations

import copy
import re
import sys
import urllib.parse
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path

import yaml


COMMON_EXCLUDES = [
    r"mozilla\.com",
    r"mozilla\.net",
    r"mozilla\.org",
    r"firefox\.com",
    r"getpocket\.com",
    r"cloudflare-dns\.com",
    r"digitalgov\.gov",
    r"elastic\.co",
    r"grafana\.com",
    r"jsdelivr\.net",
    r"secureauth\.gsa\.gov",
    r".*logout.*",
    r".*signout.*",
]


def infer_auth_profile(source_name: str, url: str) -> str:
    lowered = source_name.lower()
    if "development" in lowered or ".dev." in url or "-dev." in url:
        return "development"
    if "staging" in lowered or "fr-stage" in url:
        return "staging"
    return "production"


def infer_context(source_name: str, url: str) -> str:
    lowered = source_name.lower()
    if "internal" in lowered:
        return "internal"
    if "pages" in lowered or "pages" in url:
        return "pages"
    return "external"


def normalize_service_name(source_name: str, context_name: str) -> str:
    lowered = source_name.lower()
    if "billing" in lowered:
        return "billing-api"
    if "pages editor" in lowered:
        return "pages-editor"
    if "csb" in lowered:
        return "csb"
    if "conmon-external" in lowered:
        return "conmon-external"
    if "conmon-internal" in lowered:
        return "conmon-internal"
    if "conmon-pages" in lowered:
        return "conmon-pages"

    base = context_name.strip().lower()
    base = re.sub(r"[^a-z0-9]+", "-", base).strip("-")
    return base or "unnamed-service"


def product_name_for_service(service_name: str) -> str:
    mapping = {
        "billing-api": "billing-api",
        "pages-editor": "pages-editor",
        "csb": "csb",
        "conmon-external": "cloud.gov conmon external",
        "conmon-internal": "cloud.gov conmon internal",
        "conmon-pages": "cloud.gov pages",
    }
    return mapping.get(service_name, service_name)


def engagement_name_for_profile(profile: str) -> str:
    return {
        "development": "Recurring ZAP - Development",
        "staging": "Recurring ZAP - Staging",
        "production": "Recurring ZAP - Production",
    }[profile]


def hostname_from_regex(value: str) -> str | None:
    match = re.match(r"^https://([^.*?/]+(?:\.[^.*?/]+)+)", value)
    if match:
        return match.group(1)
    try:
        parsed = urllib.parse.urlparse(value)
        if parsed.hostname:
            return parsed.hostname
    except ValueError:
        return None
    return None


def target_name_from_hostname(hostname: str, profile: str) -> str:
    stem = hostname.replace(".", "-")
    if stem.endswith("-cloud-gov") or stem.endswith("-gov"):
        return f"{stem}-{profile}"
    return f"{stem}-{profile}"


def include_path_for_hostname(hostname: str) -> str:
    escaped = re.escape(hostname)
    return rf"^https://{escaped}/.*"


def parse_context_file(path: Path) -> dict:
    tree = ET.parse(path)
    root = tree.getroot()
    context = root.find("./context")
    if context is None:
        raise ValueError(f"missing <context> in {path}")

    context_name = (context.findtext("name") or "").strip()
    inscope = (context.findtext("inscope") or "true").strip().lower() == "true"

    include_regexes = [e.text.strip() for e in context.findall("incregexes") if e.text]
    exclude_regexes = [e.text.strip() for e in context.findall("excregexes") if e.text]

    return {
        "source_file": path.name,
        "legacy_context_name": context_name,
        "legacy_inscope": inscope,
        "include_regexes": include_regexes,
        "exclude_regexes": exclude_regexes,
    }


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {Path(sys.argv[0]).name} <legacy-context-dir>", file=sys.stderr)
        return 2

    src_dir = Path(sys.argv[1]).expanduser().resolve()
    if not src_dir.is_dir():
        print(f"not a directory: {src_dir}", file=sys.stderr)
        return 2

    services_map: dict[str, dict] = {}

    for path in sorted(src_dir.glob("*.context")):
        parsed = parse_context_file(path)
        service_name = normalize_service_name(path.name, parsed["legacy_context_name"])
        service = services_map.setdefault(
            service_name,
            {
                "service_name": service_name,
                "context": infer_context(path.name, ""),
                "defectdojo": {
                    "product_name": product_name_for_service(service_name),
                },
                "targets": [],
            },
        )

        discovered = set()
        for include_value in parsed["include_regexes"]:
            hostname = hostname_from_regex(include_value)
            if not hostname or hostname in discovered:
                continue
            discovered.add(hostname)

            auth_profile = infer_auth_profile(path.name, include_value)
            service["context"] = infer_context(path.name, include_value)

            target = {
                "name": target_name_from_hostname(hostname, auth_profile),
                "url": f"https://{hostname}",
                "auth_profile": auth_profile,
                "include_paths": [include_path_for_hostname(hostname)],
                "defectdojo": {
                    "engagement_name": engagement_name_for_profile(auth_profile),
                    "test_title": hostname,
                },
                "legacy": {
                    "source_file": parsed["source_file"],
                    "legacy_context_name": parsed["legacy_context_name"],
                    "legacy_inscope": parsed["legacy_inscope"],
                },
            }

            if not parsed["legacy_inscope"]:
                target["enabled"] = False

            service["targets"].append(target)

    data = {
        "defaults": {
            "enabled": True,
            "auth_mode": "bearer",
            "report_to_defectdojo": True,
            "exclude_paths": copy.deepcopy(COMMON_EXCLUDES),
            "scan": {
                "minutes": 20,
                "max_depth": 5,
                "thread_count": 2,
                "passive_wait_minutes": 10,
                "fail_warn_level": "Medium",
                "fail_error_level": "High",
            },
            "defectdojo": {
                "product_type_name": "Web Application",
                "tags": ["zap", "concourse", "automated"],
            },
        },
        "services": list(services_map.values()),
    }

    yaml.safe_dump(data, sys.stdout, sort_keys=False)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())