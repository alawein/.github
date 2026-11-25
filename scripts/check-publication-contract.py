#!/usr/bin/env python3
"""Offline publication-contract checks for distributed kit callers.

Default mode is local and deterministic: it reads the working tree and the
local git object store. Pass --remote only for an explicit hosted preflight
(requires network and gh); remote mode never runs unless requested.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover - CI installs hashed PyYAML for root tests
    yaml = None

ROOT = Path(__file__).resolve().parents[1]
FREEZE_RE = re.compile(
    r"alawein/\.github/\.github/workflows/([\w.-]+)@([0-9a-f]{40})"
    r"(?:[ \t]+#[ \t]*([^\r\n]*))?"
)
KIT_REF_RE = re.compile(r"(?m)^[ \t]*kit-ref:[ \t]*([0-9a-f]{40})\b")
SAME_REPO_USES_RE = re.compile(
    r"(?m)^[ \t]*uses:[ \t]*(?:\$|\.)/\.github/workflows/([\w.-]+)\s*$"
)
PERM_KEYS = ("contents", "actions", "checks", "deployments", "id-token",
             "issues", "discussions", "packages", "pages", "pull-requests",
             "repository-projects", "security-events", "statuses")


def ready_to_copy_yamls() -> list[Path]:
    paths: list[Path] = []
    workflows = ROOT / "templates" / "workflows"
    for path in sorted(workflows.glob("*.yml")):
        if path.name.upper().endswith(".WITHHELD.YML") or "WITHHELD" in path.name:
            continue
        paths.append(path)
    starters = ROOT / "templates" / "starters"
    paths.extend(sorted(starters.glob("*/.github/workflows/*.yml")))
    return paths


def git_path_exists(sha: str, relpath: str) -> bool:
    result = subprocess.run(
        ["git", "-C", str(ROOT), "cat-file", "-e", f"{sha}:{relpath}"],
        capture_output=True,
        text=True,
        check=False,
    )
    return result.returncode == 0


def git_show(sha: str, relpath: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(ROOT), "show", f"{sha}:{relpath}"],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise FileNotFoundError(f"{sha}:{relpath}")
    return result.stdout


def load_yaml(text: str):
    if yaml is None:
        raise RuntimeError("PyYAML is required; install tests/requirements.txt")
    return yaml.safe_load(text)


def top_level_permissions(doc: dict) -> dict[str, str]:
    perms = doc.get("permissions")
    if perms is None:
        return {}
    if perms == "read-all":
        return {key: "read" for key in PERM_KEYS}
    if perms == "write-all":
        return {key: "write" for key in PERM_KEYS}
    if not isinstance(perms, dict):
        return {}
    return {str(k): str(v) for k, v in perms.items()}


def job_permissions(job: dict) -> dict[str, str] | None:
    if "permissions" not in job:
        return None
    perms = job["permissions"]
    if perms == {}:
        return {}
    if not isinstance(perms, dict):
        return {}
    return {str(k): str(v) for k, v in perms.items()}


def permission_covers(granted: dict[str, str], needed: dict[str, str]) -> list[str]:
    rank = {"none": 0, "read": 1, "write": 2}
    missing = []
    for key, need in needed.items():
        have = granted.get(key, "none")
        if rank.get(have, 0) < rank.get(need, 0):
            missing.append(f"{key}:{need} (have {have})")
    return missing


def collect_calls(text: str) -> list[tuple[str, str, str]]:
    return [(m.group(1), m.group(2), (m.group(3) or "").strip()) for m in FREEZE_RE.finditer(text)]


def check_target_existence(problems: list[str]) -> set[str]:
    pins: set[str] = set()
    for path in ready_to_copy_yamls():
        text = path.read_text(encoding="utf-8")
        for workflow, sha, _comment in collect_calls(text):
            pins.add(sha)
            rel = f".github/workflows/{workflow}"
            if not git_path_exists(sha, rel):
                problems.append(
                    f"{path.relative_to(ROOT)}: missing {rel} at pin {sha}"
                )
    return pins


def check_uses_kit_ref_lockstep(problems: list[str]) -> None:
    for path in ready_to_copy_yamls():
        text = path.read_text(encoding="utf-8")
        calls = collect_calls(text)
        kit_refs = KIT_REF_RE.findall(text)
        if not kit_refs:
            continue
        call_shas = {sha for _wf, sha, _c in calls}
        for ref in kit_refs:
            if ref not in call_shas:
                problems.append(
                    f"{path.relative_to(ROOT)}: kit-ref {ref} has no matching uses: pin"
                )
        if path.name == "pr-policy.jobs.yml":
            if len(set(kit_refs)) != 1:
                problems.append(f"{path.relative_to(ROOT)}: multiple kit-ref values")
            for workflow, sha, _c in calls:
                if workflow == "pr-policy.yml" and sha != kit_refs[0]:
                    problems.append(
                        f"{path.relative_to(ROOT)}: uses/kit-ref lockstep broken "
                        f"({sha} vs {kit_refs[0]})"
                    )


def check_single_freeze(problems: list[str], expected: str | None) -> str | None:
    pins: set[str] = set()
    comments: set[str] = set()
    for path in ready_to_copy_yamls():
        text = path.read_text(encoding="utf-8")
        for _wf, sha, comment in collect_calls(text):
            pins.add(sha)
            if comment:
                comments.add(comment)
        pins.update(KIT_REF_RE.findall(text))
    if not pins:
        problems.append("no ready-to-copy kit pins found")
        return None
    if len(pins) != 1:
        problems.append(f"ready-to-copy pins are not lockstep: {sorted(pins)}")
    pin = next(iter(pins)) if len(pins) == 1 else None
    if expected and pin and pin != expected:
        problems.append(f"ready-to-copy pin {pin} != documented freeze {expected}")
    if comments and comments != {"quality gates"} and not all(
        c.startswith("v") for c in comments
    ):
        # Allow either the pre-tag freeze comment or release-tag comments, not a mix with other text.
        if "quality gates" in comments and any(c != "quality gates" for c in comments):
            problems.append(f"mixed pin comments: {sorted(comments)}")
    return pin


def check_caller_permissions(problems: list[str]) -> None:
    for path in ready_to_copy_yamls():
        text = path.read_text(encoding="utf-8")
        doc = load_yaml(text)
        if not isinstance(doc, dict):
            continue
        # Jobs fragment (pr-policy.jobs.yml) has jobs at the top level.
        if "jobs" in doc:
            jobs = doc["jobs"]
            workflow_perms = top_level_permissions(doc)
        else:
            jobs = {k: v for k, v in doc.items() if isinstance(v, dict) and "uses" in v}
            workflow_perms = {}
        if not isinstance(jobs, dict):
            continue
        for name, job in jobs.items():
            if not isinstance(job, dict) or "uses" not in job:
                continue
            uses = str(job["uses"])
            match = re.search(
                r"alawein/\.github/\.github/workflows/([\w.-]+)@([0-9a-f]{40})",
                uses,
            )
            if not match:
                continue
            workflow, sha = match.group(1), match.group(2)
            try:
                callee_text = git_show(sha, f".github/workflows/{workflow}")
            except FileNotFoundError:
                # Existence check already reported.
                continue
            callee = load_yaml(callee_text)
            needed = top_level_permissions(callee if isinstance(callee, dict) else {})
            granted = job_permissions(job)
            if granted is None:
                granted = workflow_perms
            missing = permission_covers(granted, needed)
            if missing:
                problems.append(
                    f"{path.relative_to(ROOT)} job {name}: caller permissions "
                    f"missing {', '.join(missing)} for {workflow}@{sha[:7]}"
                )


def check_workflow_call_inputs(problems: list[str]) -> None:
    for path in ready_to_copy_yamls():
        text = path.read_text(encoding="utf-8")
        doc = load_yaml(text)
        if not isinstance(doc, dict):
            continue
        jobs = doc.get("jobs", doc)
        if not isinstance(jobs, dict):
            continue
        for name, job in jobs.items():
            if not isinstance(job, dict) or "uses" not in job:
                continue
            uses = str(job["uses"])
            match = re.search(
                r"alawein/\.github/\.github/workflows/([\w.-]+)@([0-9a-f]{40})",
                uses,
            )
            if not match:
                continue
            workflow, sha = match.group(1), match.group(2)
            try:
                callee_text = git_show(sha, f".github/workflows/{workflow}")
            except FileNotFoundError:
                continue
            callee = load_yaml(callee_text)
            if not isinstance(callee, dict):
                continue
            on = callee.get(True, callee.get("on", {}))
            if not isinstance(on, dict) or "workflow_call" not in on:
                problems.append(
                    f"{path.relative_to(ROOT)} job {name}: {workflow}@{sha[:7]} "
                    "is not a workflow_call reusable"
                )
                continue
            # Empty `workflow_call:` loads as None; treat as no inputs/secrets.
            call = on.get("workflow_call") or {}
            if not isinstance(call, dict):
                problems.append(
                    f"{path.relative_to(ROOT)} job {name}: {workflow}@{sha[:7]} "
                    "has a malformed workflow_call block"
                )
                continue
            declared_inputs = set((call.get("inputs") or {}).keys())
            declared_secrets = set((call.get("secrets") or {}).keys())
            passed_inputs = set((job.get("with") or {}).keys())
            passed_secrets = set((job.get("secrets") or {}).keys())
            unknown_inputs = sorted(passed_inputs - declared_inputs)
            unknown_secrets = sorted(passed_secrets - declared_secrets)
            if unknown_inputs:
                problems.append(
                    f"{path.relative_to(ROOT)} job {name}: unknown inputs "
                    f"{unknown_inputs} for {workflow}@{sha[:7]}"
                )
            if unknown_secrets:
                problems.append(
                    f"{path.relative_to(ROOT)} job {name}: unknown secrets "
                    f"{unknown_secrets} for {workflow}@{sha[:7]}"
                )
            required_secrets = {
                key
                for key, meta in (call.get("secrets") or {}).items()
                if isinstance(meta, dict) and meta.get("required")
            }
            missing_secrets = sorted(required_secrets - passed_secrets)
            if missing_secrets:
                problems.append(
                    f"{path.relative_to(ROOT)} job {name}: missing required secrets "
                    f"{missing_secrets} for {workflow}@{sha[:7]}"
                )


def check_withheld_claude(problems: list[str]) -> None:
    broken = ROOT / "templates" / "workflows" / "claude-review.yml"
    note = ROOT / "templates" / "workflows" / "claude-review.WITHHELD.md"
    if broken.exists():
        text = broken.read_text(encoding="utf-8")
        for workflow, sha, _c in collect_calls(text):
            if workflow == "claude-review.yml" and not git_path_exists(
                sha, ".github/workflows/claude-review.yml"
            ):
                problems.append(
                    "templates/workflows/claude-review.yml pins a missing "
                    f"claude-review.yml at {sha}; withhold or advance freeze"
                )
    if not note.exists():
        problems.append("templates/workflows/claude-review.WITHHELD.md missing")


def documented_freeze_sha() -> str | None:
    pins = (ROOT / "docs" / "pins.md").read_text(encoding="utf-8")
    match = re.search(
        r"Distributed callers and starters freeze to reviewed `main` commit\n"
        r"`([0-9a-f]{40})`",
        pins,
    )
    return match.group(1) if match else None


def remote_preflight(problems: list[str], pin: str | None) -> None:
    if not pin:
        problems.append("remote preflight skipped: no single freeze pin")
        return
    result = subprocess.run(
        ["gh", "api", f"repos/alawein/.github/git/commits/{pin}", "--jq", ".sha"],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        problems.append(f"remote preflight: gh api failed for {pin}: {result.stderr.strip()}")
        return
    remote = result.stdout.strip()
    if remote != pin:
        problems.append(f"remote preflight: expected {pin}, got {remote}")
    # Confirm each ready-to-copy workflow path exists on the remote tree.
    for path in ready_to_copy_yamls():
        text = path.read_text(encoding="utf-8")
        for workflow, sha, _c in collect_calls(text):
            api = subprocess.run(
                [
                    "gh",
                    "api",
                    f"repos/alawein/.github/contents/.github/workflows/{workflow}?ref={sha}",
                    "--jq",
                    ".path",
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            if api.returncode != 0:
                problems.append(
                    f"remote preflight: {workflow} missing at {sha}: {api.stderr.strip()}"
                )


def run(remote: bool = False) -> int:
    problems: list[str] = []
    check_withheld_claude(problems)
    check_target_existence(problems)
    expected = documented_freeze_sha()
    if expected is None:
        problems.append("docs/pins.md missing distributed freeze SHA stanza")
    pin = check_single_freeze(problems, expected)
    check_uses_kit_ref_lockstep(problems)
    check_caller_permissions(problems)
    check_workflow_call_inputs(problems)
    if remote:
        remote_preflight(problems, pin or expected)
    if problems:
        print("publication-contract FAIL")
        for item in problems:
            print(f"- {item}")
        return 1
    mode = "remote+offline" if remote else "offline"
    print(f"publication-contract PASS ({mode}) freeze={pin or expected}")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--remote",
        action="store_true",
        help="Also hit GitHub via gh (explicit remote preflight; off by default).",
    )
    args = parser.parse_args(argv)
    try:
        return run(remote=args.remote)
    except RuntimeError as exc:
        print(f"publication-contract ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
