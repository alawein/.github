#!/usr/bin/env python3
"""Report repository hygiene using GET requests only; unavailable data is UNKNOWN."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess

REPOSITORY = re.compile(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\Z")
REQUIRED_CHECKS = ("markdown-lint", "link-check", "actionlint", "pr-title")
REQUIRED_RULES = {"deletion", "non_fast_forward", "required_signatures", "required_linear_history", "pull_request", "required_status_checks"}


def audit(fetch, repository: str, *, required_checks=REQUIRED_CHECKS, now=None) -> dict:
    """Collect bounded observations using a fixtureable callback returning GET JSON."""
    now = now or datetime.now(timezone.utc)
    result = {"repository": repository, "captured_at": now.isoformat(), "status": "UNKNOWN",
              "findings": [], "unknown": [], "observed": {}}
    observed, unknown, findings = result["observed"], result["unknown"], result["findings"]
    if (not isinstance(repository, str) or not REPOSITORY.fullmatch(repository)
            or any(part in (".", "..") for part in repository.split("/"))):
        unknown.append("Invalid repository; expected OWNER/REPO.")
        return result
    root = "repos/" + repository

    def get(path, expected):
        try:
            value = fetch(path)
            if not isinstance(value, expected):
                raise ValueError("invalid response shape")
            return value
        except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
            unknown.append(f"{path}: {error.__class__.__name__}")
            return None

    def pages(path):
        items = []
        separator = "&" if "?" in path else "?"
        for page in range(1, 1001):
            batch = get(f"{path}{separator}per_page=100&page={page}", list)
            if batch is None:
                return None
            if len(batch) > 100 or any(not isinstance(item, dict) for item in batch):
                unknown.append(f"{path}: invalid page")
                return None
            items.extend(batch)
            if len(batch) < 100:
                return items
        unknown.append(f"{path}: pagination limit reached")
        return None

    metadata = get(root, dict)
    observed["squash_only"] = None
    if metadata is not None:
        flags = ("allow_squash_merge", "allow_merge_commit", "allow_rebase_merge")
        if all(type(metadata.get(key)) is bool for key in flags):
            observed["squash_only"] = metadata[flags[0]] and not any(metadata[key] for key in flags[1:])
            if not observed["squash_only"]:
                findings.append("Merge settings are not squash only.")
        else:
            unknown.append("Repository merge flags missing or malformed.")
        if metadata.get("default_branch") != "main":
            if isinstance(metadata.get("default_branch"), str) and metadata["default_branch"]:
                findings.append("Default branch is not main; effective rules below cover main only.")
            else:
                unknown.append("Repository default branch missing or malformed.")

    rules = pages(root + "/rules/branches/main")
    observed["effective_rules"] = None
    observed["required_checks"] = None
    if rules is not None:
        try:
            types = {rule["type"] for rule in rules}
            if any(not isinstance(kind, str) for kind in types):
                raise ValueError("invalid rule type")
            checks = {check["context"] for rule in rules if rule["type"] == "required_status_checks"
                      for check in rule["parameters"]["required_status_checks"]}
            if any(not isinstance(context, str) or not context for context in checks):
                raise ValueError("invalid check context")
            observed["effective_rules"], observed["required_checks"] = sorted(types), sorted(checks)
            missing_rules = REQUIRED_RULES - types
            missing_checks = set(required_checks) - checks
            if missing_rules:
                findings.append("Missing effective main rules: " + ", ".join(sorted(missing_rules)))
            if missing_checks:
                findings.append("Missing required checks: " + ", ".join(sorted(missing_checks)))
        except (KeyError, TypeError, ValueError):
            unknown.append("Effective rules missing or malformed.")

    rulesets = pages(root + "/rulesets?includes_parents=true")
    observed["bypass_actors"] = None
    if rulesets is not None:
        actors, complete = [], True
        for ruleset in rulesets:
            if type(ruleset.get("id")) is not int or ruleset.get("enforcement") not in ("active", "evaluate", "disabled"):
                unknown.append("Ruleset identity or enforcement missing or malformed.")
                complete = False
                continue
            if ruleset["enforcement"] != "active":
                continue
            detail = get(root + f"/rulesets/{ruleset['id']}?includes_parents=true", dict)
            if detail is None:
                complete = False
            elif detail.get("enforcement") != "active" or not isinstance(detail.get("bypass_actors"), list):
                unknown.append("Active ruleset bypass details missing or changed during collection.")
                complete = False
            elif any(not isinstance(actor, dict) for actor in detail["bypass_actors"]):
                unknown.append("Malformed bypass actor.")
                complete = False
            else:
                actors.extend({"ruleset_id": ruleset["id"], **actor} for actor in detail["bypass_actors"])
        if complete:
            observed["bypass_actors"] = actors
        if actors:
            findings.append("Active repository or inherited rulesets contain bypass actors.")

    pulls = pages(root + "/pulls?state=open")
    observed["ready_prs"] = None
    open_heads = set()
    if pulls is not None:
        try:
            for pr in pulls:
                if type(pr["draft"]) is not bool or type(pr["number"]) is not int:
                    raise ValueError("invalid PR metadata")
                head = pr["head"]
                if not isinstance(head["ref"], str) or not head["ref"]:
                    raise ValueError("invalid PR head")
                # Deleted fork repositories may be null; their refs are not local branches.
                if head["repo"] is not None:
                    if not isinstance(head["repo"].get("full_name"), str):
                        raise ValueError("invalid PR repository")
                    if head["repo"]["full_name"] == repository:
                        open_heads.add(head["ref"])
            observed["ready_prs"] = sum(not pr["draft"] for pr in pulls)
            if observed["ready_prs"] > 3:
                findings.append("More than three ready PRs wait in this repository; global admission remains a human policy.")
        except (KeyError, TypeError, ValueError, AttributeError):
            unknown.append("Open PR metadata missing or malformed.")

    branches = pages(root + "/branches")
    observed["orphan_branches"] = None
    if branches is not None and observed["ready_prs"] is not None:
        orphans, complete = [], True
        for branch in branches:
            try:
                name = branch["name"]
                if not isinstance(name, str) or not name:
                    raise ValueError("invalid branch name")
                if name == "main" or name in open_heads:
                    continue
                sha = branch["commit"]["sha"]
                if not isinstance(sha, str) or not re.fullmatch(r"[0-9a-f]{40}", sha):
                    raise ValueError("invalid commit SHA")
                commit = get(root + "/commits/" + sha, dict)
                if commit is None:
                    complete = False
                    continue
                date = datetime.fromisoformat(commit["commit"]["committer"]["date"].replace("Z", "+00:00"))
                if date.tzinfo is None or date > now:
                    raise ValueError("invalid commit date")
                age = (now - date).days
                if age >= 30:
                    orphans.append({"branch": name, "last_commit": sha, "last_commit_age_days": age})
            except (KeyError, TypeError, ValueError, AttributeError):
                unknown.append("Branch or last-commit metadata missing or malformed.")
                complete = False
        if complete:
            observed["orphan_branches"] = orphans
        if orphans:
            findings.append("Branches without an open PR have last commits at least 30 days old; no cleanup performed.")
    result["status"] = "UNKNOWN" if unknown else "WARN" if findings else "PASS"
    return result


def gh_get(path):
    """Use the existing in-memory GH_TOKEN; no token or API error output is retained."""
    response = subprocess.run(["gh", "api", "--method", "GET", path,
                               "-H", "Accept: application/vnd.github+json",
                               "-H", "X-GitHub-Api-Version: 2022-11-28"],
                              capture_output=True, text=True, encoding="utf-8", timeout=60)
    if response.returncode:
        raise OSError("GET unavailable")
    return json.loads(response.stdout)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--required-checks", default=",".join(REQUIRED_CHECKS))
    args = parser.parse_args()
    checks = [context.strip() for context in args.required_checks.split(",") if context.strip()]
    if not checks:
        parser.error("--required-checks must contain at least one check")
    fetch = gh_get if os.environ.get("GH_TOKEN") else lambda path: (_ for _ in ()).throw(OSError("GH_TOKEN missing"))
    report = audit(fetch, args.repository, required_checks=checks)
    encoded = json.dumps(report, indent=2, ensure_ascii=True) + "\n"
    args.output.write_text(encoded, encoding="utf-8")
    print(encoded, end="")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as stream:
            stream.write(f"## Hygiene: {report['status']}\n\n")
            stream.write(f"Findings: {len(report['findings'])}; UNKNOWN entries: {len(report['unknown'])}.\n\n")
            stream.write("Report details are in the job log and local JSON output. No changes were made.\n")
    return 2 if report["unknown"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
