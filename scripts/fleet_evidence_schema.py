#!/usr/bin/env python3
"""Fleet Control Center evidence schema constants and validators.

`rulesets/checks.json` remains the only required-check authority. This module
validates snapshot envelopes; it does not define required-check names.
"""
from __future__ import annotations

from typing import Any

SCHEMA_VERSION = "1.0.0"
ARTIFACT = "github-fleet-control-center"
STATUSES = frozenset({"PASS", "WARN", "FAIL", "UNKNOWN", "LIMITED", "STALE"})
REQUIRED_TOP = (
    "schema_version",
    "artifact",
    "observed_at",
    "freshness",
    "provenance",
    "status_legend",
    "fleet_overview",
    "workflow_registry",
    "ci_reliability",
    "pull_requests",
    "governance",
    "security",
    "automation",
    "drift",
    "recommendations",
    "maios_export",
)


def validate_snapshot(data: dict[str, Any]) -> list[str]:
    """Return human-readable errors; empty list means envelope is valid."""
    errors: list[str] = []
    if not isinstance(data, dict):
        return ["snapshot must be an object"]

    for key in REQUIRED_TOP:
        if key not in data:
            errors.append(f"missing top-level field: {key}")

    if data.get("artifact") != ARTIFACT:
        errors.append(f"artifact must be {ARTIFACT!r}")

    version = data.get("schema_version")
    if not isinstance(version, str) or not version.startswith("1."):
        errors.append("schema_version must be a 1.x semver string")

    legend = data.get("status_legend")
    if not isinstance(legend, list) or set(legend) != set(STATUSES):
        errors.append("status_legend must list exactly PASS|WARN|FAIL|UNKNOWN|LIMITED|STALE")

    freshness = data.get("freshness")
    if isinstance(freshness, dict):
        status = freshness.get("status")
        if status not in STATUSES:
            errors.append("freshness.status must be a known status")
        if not isinstance(freshness.get("max_age_seconds"), int):
            errors.append("freshness.max_age_seconds must be an int")
    else:
        errors.append("freshness must be an object")

    provenance = data.get("provenance")
    if isinstance(provenance, dict):
        if provenance.get("scope") not in STATUSES:
            errors.append("provenance.scope must be a known status")
        if not isinstance(provenance.get("sources"), list):
            errors.append("provenance.sources must be a list")
    else:
        errors.append("provenance must be an object")

    export = data.get("maios_export")
    if isinstance(export, dict):
        if export.get("read_only") is not True:
            errors.append("maios_export.read_only must be true")
    else:
        errors.append("maios_export must be an object")

    overview = data.get("fleet_overview")
    if isinstance(overview, dict):
        if overview.get("status") not in STATUSES:
            errors.append("fleet_overview.status must be a known status")
        repos = overview.get("repositories")
        if not isinstance(repos, list):
            errors.append("fleet_overview.repositories must be a list")
        else:
            for index, row in enumerate(repos):
                if not isinstance(row, dict) or "name" not in row:
                    errors.append(f"fleet_overview.repositories[{index}] needs name")
                    continue
                if row.get("status") not in STATUSES:
                    errors.append(f"fleet_overview.repositories[{index}].status invalid")
    else:
        errors.append("fleet_overview must be an object")

    return errors


def assert_valid(data: dict[str, Any]) -> None:
    errors = validate_snapshot(data)
    if errors:
        raise ValueError("; ".join(errors))
