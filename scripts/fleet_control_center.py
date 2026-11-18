#!/usr/bin/env python3
"""Aggregate read-only GitHub fleet evidence into a Control Center snapshot.

Offline mode uses fixtures (CI-safe). Live mode uses `gh` GET APIs only.
Does not mutate rulesets, settings, or consumer pins.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from fleet_evidence_schema import ARTIFACT, SCHEMA_VERSION, STATUSES, assert_valid

KIT = "alawein/.github"
ROOT = Path(__file__).resolve().parents[1]


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def load_checks(kit_root: Path) -> dict[str, Any]:
    return json.loads((kit_root / "rulesets" / "checks.json").read_text(encoding="utf-8"))


def gh_api(path: str) -> Any:
    out = subprocess.check_output(["gh", "api", path], text=True, stderr=subprocess.PIPE)
    return json.loads(out)


def _gh_get(path: str) -> Any | None:
    """GET via gh api. Return None on failure (partial observation)."""
    try:
        return gh_api(path)
    except (subprocess.CalledProcessError, json.JSONDecodeError, TypeError, ValueError):
        return None


def load_pin_rows(path: Path | None) -> list[dict[str, Any]]:
    if path is None:
        return []
    data = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(data, dict) and "rows" in data:
        return list(data["rows"])
    if isinstance(data, list):
        return data
    raise SystemExit(f"unexpected pin fixture shape in {path}")


def kit_commit_live() -> str:
    try:
        data = gh_api(f"repos/{KIT}/commits/main")
        return str(data["sha"])
    except (subprocess.CalledProcessError, KeyError, TypeError):
        return "UNKNOWN"


def build_snapshot(
    *,
    kit_root: Path,
    pin_rows: list[dict[str, Any]],
    kit_commit: str,
    observed_at: str | None = None,
    scope: str = "LIMITED",
    sources: list[str] | None = None,
    live_kit: dict[str, Any] | None = None,
) -> dict[str, Any]:
    checks = load_checks(kit_root)
    kit_self = list(checks.get("kit_self") or [])
    fleet_base = list(checks.get("fleet_base") or [])
    stamp = observed_at or utc_now()
    src = sources or ["rulesets/checks.json", "pin fixture or audit"]

    live = live_kit or {}
    live_partial = bool(live.get("partial"))
    live_runs = list(live.get("recent_runs") or [])
    ci_status = live.get("ci_status", "UNKNOWN")
    if live_kit is not None and (live_partial or not live_runs):
        if ci_status == "PASS":
            ci_status = "LIMITED"
        if scope == "PASS":
            scope = "LIMITED"

    stale_pins: list[dict[str, Any]] = []
    for row in pin_rows:
        distinct = row.get("pins")
        if isinstance(distinct, list) and distinct:
            pin_list = list(dict.fromkeys(str(p) for p in distinct if p))
        else:
            single = row.get("pin")
            pin_list = [str(single)] if single else []
        for pin in pin_list:
            if not pin or pin == "UNKNOWN":
                continue
            vs = "PASS" if kit_commit != "UNKNOWN" and pin == kit_commit else "STALE"
            if kit_commit == "UNKNOWN":
                vs = "UNKNOWN"
            stale_pins.append(
                {
                    "repository": row["repository"],
                    "path": row.get("path", ""),
                    "pin": pin,
                    "vs_kit": vs,
                }
            )

    consumer_names = sorted({row["repository"] for row in pin_rows if row.get("repository") != KIT})
    repositories: list[dict[str, Any]] = [
        {
            "name": KIT,
            "visibility": (live_kit or {}).get("visibility", "UNKNOWN"),
            "class": "kit",
            "default_branch": (live_kit or {}).get("default_branch", "main"),
            "latest_verified_commit": kit_commit,
            "latest_ci_status": (live_kit or {}).get("latest_ci_status", "UNKNOWN"),
            "required_checks": kit_self,
            "open_pr_count": (live_kit or {}).get("open_pr_count"),
            "blocked_pr_count": (live_kit or {}).get("blocked_pr_count"),
            "active_workflows": (live_kit or {}).get("active_workflows", []),
            "governance_state": (live_kit or {}).get("governance_state", "UNKNOWN"),
            "status": (live_kit or {}).get("status", "LIMITED"),
            "last_observation": stamp,
            "notes": (live_kit or {}).get("notes", "Kit row"),
        }
    ]
    for name in consumer_names:
        repositories.append(
            {
                "name": name,
                "visibility": "UNKNOWN",
                "class": "consumer",
                "default_branch": "UNKNOWN",
                "latest_verified_commit": "UNKNOWN",
                "latest_ci_status": "UNKNOWN",
                "required_checks": fleet_base,
                "open_pr_count": None,
                "blocked_pr_count": None,
                "active_workflows": [],
                "governance_state": "LIMITED",
                "status": "LIMITED",
                "last_observation": stamp,
                "notes": "Observed as reusable-workflow consumer only",
            }
        )

    drift_findings = [
        {
            "repository": row["repository"],
            "expected": f"pin == {kit_commit}",
            "observed": row["pin"],
            "source": "pin inventory",
            "severity": "medium",
            "confidence": "high" if row["vs_kit"] == "STALE" else "low",
            "recommended_action": "Reviewed pin-bump PRs only; do not auto-upgrade",
        }
        for row in stale_pins
        if row["vs_kit"] == "STALE"
    ]

    snapshot: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "artifact": ARTIFACT,
        "observed_at": stamp,
        "freshness": {
            "status": "PASS",
            "max_age_seconds": 3600,
            "note": "fleet_control_center aggregator",
        },
        "provenance": {
            "collector": "fleet_control_center",
            "sources": src,
            "scope": scope if scope in STATUSES else "LIMITED",
            "scope_note": "Incomplete org listing stays LIMITED",
        },
        "status_legend": sorted(STATUSES),
        "fleet_overview": {
            "status": "WARN" if drift_findings or scope == "LIMITED" else "PASS",
            "repositories": repositories,
        },
        "workflow_registry": {
            "status": "WARN" if drift_findings else "PASS",
            "kit_commit": kit_commit,
            "consumer_pins": stale_pins,
            "outdated_pin_count": sum(1 for row in stale_pins if row["vs_kit"] == "STALE"),
            "note": "Do not auto-upgrade consumer pins.",
        },
        "ci_reliability": {
            "status": ci_status if live_kit is not None else "UNKNOWN",
            "repository": KIT,
            "recent_runs": live_runs,
            "failure_classification": live.get("failure_classification", []),
        },
        "pull_requests": {
            "status": "WARN" if (live_kit or {}).get("prs") else "UNKNOWN",
            "items": (live_kit or {}).get("prs", []),
        },
        "governance": {
            "status": (live_kit or {}).get("governance_status", "UNKNOWN"),
            "repository": KIT,
            "documented": {
                "required_checks_source": "rulesets/checks.json kit_self",
                "required_checks": kit_self,
            },
            "observed": (live_kit or {}).get("governance_observed", {}),
            "drift": (live_kit or {}).get("governance_drift", []),
            "unknown": (live_kit or {}).get("governance_unknown", []),
        },
        "security": {
            "status": "WARN" if drift_findings else "UNKNOWN",
            "findings": [
                {
                    "severity": "info",
                    "item": "actionlint + zizmor required on kit",
                    "status": "PASS",
                },
                {
                    "severity": "warn",
                    "item": "Consumer pins lag kit main",
                    "status": "WARN" if drift_findings else "PASS",
                    "action": "Reviewed pin bump via consumer PRs only",
                },
            ],
            "secrets_inspected": False,
        },
        "automation": {
            "status": "LIMITED",
            "workflows": (live_kit or {}).get("automation", []),
        },
        "drift": {
            "status": "WARN" if drift_findings else "PASS",
            "findings": drift_findings,
        },
        "recommendations": [
            {
                "priority": 1,
                "item": "Plan reviewed consumer pin bumps",
                "status": "open",
            }
            if drift_findings
            else {
                "priority": 3,
                "item": "Expand collector scope beyond LIMITED observations",
                "status": "open",
            }
        ],
        "maios_export": {
            "interface_version": "1.0.0",
            "read_only": True,
            "paths": {
                "snapshot": "internal/fleet-evidence/latest/fleet.json",
                "schema": "docs/fleet-evidence-schema.md",
            },
            "authoritative_elsewhere": ["rulesets/checks.json", "MAIOS operating topology"],
        },
    }
    assert_valid(snapshot)
    return snapshot


def write_snapshot(snapshot: dict[str, Any], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(snapshot, indent=2) + "\n", encoding="utf-8")
    stamp = output.parent / "observed_at.txt"
    stamp.write_text(snapshot["observed_at"] + "\n", encoding="utf-8")


def collect_live_kit() -> dict[str, Any]:
    repo = _gh_get(f"repos/{KIT}") or {}
    runs = _gh_get(f"repos/{KIT}/actions/runs?per_page=5")
    pulls = _gh_get(f"repos/{KIT}/pulls?state=open")
    rulesets = _gh_get(f"repos/{KIT}/rulesets")

    runs_missing = runs is None
    runs_payload = runs if isinstance(runs, dict) else {}
    recent = []
    for run in (runs_payload.get("workflow_runs") or [])[:5]:
        recent.append(
            {
                "name": run.get("name"),
                "conclusion": run.get("conclusion"),
                "branch": run.get("head_branch"),
                "created_at": run.get("created_at"),
                "url": run.get("html_url"),
            }
        )

    pulls_list = pulls if isinstance(pulls, list) else []
    prs = []
    for pull in pulls_list:
        prs.append(
            {
                "repository": KIT,
                "number": pull.get("number"),
                "title": pull.get("title"),
                "branch": (pull.get("head") or {}).get("ref"),
                "sha": (pull.get("head") or {}).get("sha"),
                "author": (pull.get("user") or {}).get("login"),
                "draft": pull.get("draft"),
                "ci_technical": "UNKNOWN",
                "independent_review": "UNKNOWN",
                "required_approval_state": "NOT_AUTHORIZED",
                "merge_conflicts": "UNKNOWN",
                "blocking_conditions": ["Owner merge authorization required"],
                "url": pull.get("html_url"),
            }
        )

    # Failed GET, other live gaps, or empty workflow_runs all count as partial.
    partial = bool(
        runs_missing
        or repo == {}
        or pulls is None
        or rulesets is None
        or not recent
    )

    if not recent:
        ci_status = "LIMITED"
    elif any(r.get("conclusion") == "failure" for r in recent):
        ci_status = "WARN"
    else:
        ci_status = "PASS"

    return {
        "visibility": (
            "private" if repo.get("private") else "public" if repo else "UNKNOWN"
        ),
        "default_branch": repo.get("default_branch", "main") if repo else "UNKNOWN",
        "latest_ci_status": "PASS"
        if recent and recent[0].get("conclusion") == "success"
        else "UNKNOWN",
        "open_pr_count": len(prs),
        "blocked_pr_count": len(prs),
        "active_workflows": sorted({str(r.get("name")) for r in recent if r.get("name")}),
        "governance_state": "PASS"
        if isinstance(rulesets, list) and rulesets
        else "UNKNOWN",
        "status": "LIMITED" if partial else ("WARN" if prs else "PASS"),
        "notes": "Live gh snapshot (partial)" if partial else "Live gh snapshot",
        "ci_status": ci_status,
        "recent_runs": recent,
        "prs": prs,
        "partial": partial,
        "governance_status": "PASS"
        if isinstance(rulesets, list) and rulesets
        else "UNKNOWN",
        "governance_observed": {
            "rulesets": [
                {
                    "id": r.get("id"),
                    "name": r.get("name"),
                    "enforcement": r.get("enforcement"),
                }
                for r in (rulesets if isinstance(rulesets, list) else [])
            ]
        },
        "governance_unknown": ["Bypass actors detail"],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--kit-root", type=Path, default=ROOT)
    parser.add_argument("--pins", type=Path, help="JSON pin fixture or auditor JSON export")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--kit-commit", default="UNKNOWN")
    parser.add_argument("--live", action="store_true", help="Enrich kit row via gh GET")
    parser.add_argument("--offline", action="store_true", help="Never call gh (default)")
    args = parser.parse_args(argv)

    pin_rows = load_pin_rows(args.pins)
    live_kit = None
    kit_commit = args.kit_commit
    sources = ["rulesets/checks.json"]
    if args.pins:
        sources.append(str(args.pins))
    scope = "LIMITED"

    if args.live and not args.offline:
        live_kit = collect_live_kit()
        if kit_commit == "UNKNOWN":
            kit_commit = kit_commit_live()
        sources.extend([f"gh api repos/{KIT}", f"gh api repos/{KIT}/actions/runs"])
        scope = "LIMITED"
        if live_kit.get("partial"):
            sources.append("partial: actions runs or related live GET missing")

    snapshot = build_snapshot(
        kit_root=args.kit_root,
        pin_rows=pin_rows,
        kit_commit=kit_commit,
        scope=scope,
        sources=sources,
        live_kit=live_kit,
    )
    write_snapshot(snapshot, args.output)
    print(f"wrote {args.output}", flush=True)
    return 0


if __name__ == "__main__":
    # Allow `python3 scripts/fleet_control_center.py` without installing a package.
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    raise SystemExit(main())
