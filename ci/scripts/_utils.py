"""Shared utilities for ZAP pipeline scripts.

Note: PyYAML (yaml) is a required dependency, installed in the Docker
image as python3-yaml. This is a documented exception to the "stdlib
only" rule in CODING_STANDARDS.md — YAML parsing is fundamental to
the pipeline's target inventory system.
"""

import copy


def deep_merge(base, override):
    """Recursively merge override into base, returning a new dict.

    Values in override take precedence. Dicts are merged recursively;
    all other types are replaced wholesale.

    Args:
        base: Base dictionary (not modified).
        override: Override dictionary (not modified).

    Returns:
        New merged dictionary.
    """
    if isinstance(base, dict) and isinstance(override, dict):
        merged = copy.deepcopy(base)
        for key, value in override.items():
            merged[key] = deep_merge(merged[key], value) if key in merged else copy.deepcopy(value)
        return merged
    return copy.deepcopy(override)
