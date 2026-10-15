#!/usr/bin/env python3
"""Report repository hygiene using GET requests only; unavailable data is UNKNOWN.

With --token-limited, fields GitHub returns only to admin tokens are reported as
unverifiable (status LIMITED, exit 0) instead of UNKNOWN."""
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


class HttpError(OSError):
    """A failed GET with its HTTP status and GitHub message; no token or body is kept."""

    def __init__(self, status: int, message: str = ""):
        super().__init__(f"HTTP {status}")
        self.status, self.message = status, message


def audit(fetch, repository: str, *, required_checks=REQUIRED_CHECKS, now=None, token_limited=False) -> dict:
    """Collect bounded observations using a fixtureable callback returning GET JSON."""
    now = now or datetime.now(timezone.utc)
    result = {"repository": repository, "captured_at": now.isoformat(), "status": "UNKNOWN",
              "findings": [], "unknown": [], "unverifiable": [], "observed": {}}
    observed, unknown, findings = result["observed"], result["unknown"], result["findings"]
    unverifiable = result["unverifiable"]
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
        if token_limited and not any(key in metadata for key in flags):
            unverifiable.append("Repository merge flags need an admin token.")
        elif all(type(metadata.get(key)) is bool for key in flags):
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

    result["coverage"] = {
        "scope": "Configured main protection, not PR check execution or production acceptance.",
        "rulesets": {"endpoint": root + "/rules/branches/main", "status": "UNKNOWN"},
        "classic": {"endpoint": root + "/branches/main/protection", "status": "UNKNOWN"},
        "bypass_actors": "Active repository/inherited rulesets only; not classic bypass coverage."}
    for key in ("effective_rules", "required_checks", "ruleset_rules", "ruleset_required_checks",
                "classic_rules", "classic_required_checks", "classic_required_approvals", "classic_enforce_admins"):
        observed[key] = None
    observed["check_producers"] = []

    def producers(checks, source, identity):
        if not isinstance(checks, list):
            raise ValueError("invalid checks")
        records = []
        for check in checks:
            if not isinstance(check, dict) or not isinstance(check.get("context"), str) or not check["context"]:
                raise ValueError("invalid context")
            app = check.get(identity)
            if app is not None and (type(app) is not int or app < -1):
                raise ValueError("invalid producer")
            # Null/-1 identifies no bound app, not an independent trusted producer.
            records.append({"source": source, "context": check["context"], "app_id": app})
        return records

    rules = pages(root + "/rules/branches/main")
    if rules is not None:
        try:
            types = {rule["type"] for rule in rules}
            if any(not isinstance(kind, str) for kind in types):
                raise ValueError("invalid rule type")
            records = [record for rule in rules if rule["type"] == "required_status_checks"
                       for record in producers(rule["parameters"]["required_status_checks"], "rulesets", "integration_id")]
            observed["ruleset_rules"] = sorted(types)
            observed["ruleset_required_checks"] = sorted({record["context"] for record in records})
            observed["check_producers"].extend(records)
            result["coverage"]["rulesets"]["status"] = "OBSERVED"
        except (KeyError, TypeError, ValueError):
            unknown.append("Ruleset branch rules missing or malformed.")

    classic_path = root + "/branches/main/protection"
    try:
        classic = fetch(classic_path)
        if not isinstance(classic, dict):
            raise ValueError("invalid response shape")
    except HttpError as error:
        classic = None
        if error.status == 404 and error.message == "Branch not protected":
            observed["classic_rules"], observed["classic_required_checks"] = [], []
            result["coverage"]["classic"]["status"] = "OBSERVED"
        elif token_limited and error.status in (403, 404):
            unverifiable.append("Classic main protection needs an admin token.")
            result["coverage"]["classic"]["status"] = "UNVERIFIABLE"
        else:
            unknown.append(f"{classic_path}: HttpError")
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        classic = None
        unknown.append(f"{classic_path}: {error.__class__.__name__}")
    if classic is not None:
        try:
            types = set()
            for field, rule, enabled in (("allow_deletions", "deletion", False),
                                         ("allow_force_pushes", "non_fast_forward", False),
                                         ("required_signatures", "required_signatures", True),
                                         ("required_linear_history", "required_linear_history", True)):
                value = classic[field]["enabled"]
                if type(value) is not bool:
                    raise ValueError("invalid classic flag")
                if value is enabled:
                    types.add(rule)
            admins = classic["enforce_admins"]["enabled"]
            if type(admins) is not bool:
                raise ValueError("invalid admin flag")
            review = classic["required_pull_request_reviews"]
            approvals = None
            if review is not None:
                approvals = review["required_approving_review_count"]
                if type(approvals) is not int or not 0 <= approvals <= 6:
                    raise ValueError("invalid approval count")
                types.add("pull_request")
            status = classic["required_status_checks"]
            contexts, records = [], []
            if status is not None:
                contexts = status["contexts"]
                if not isinstance(contexts, list) or any(not isinstance(c, str) or not c for c in contexts):
                    raise ValueError("invalid classic contexts")
                records = producers(status.get("checks", []), "classic", "app_id")
                bound = {record["context"] for record in records}
                records.extend({"source": "classic", "context": c, "app_id": None} for c in contexts if c not in bound)
                contexts = sorted(set(contexts) | bound)
                types.add("required_status_checks")
            observed["classic_rules"], observed["classic_required_checks"] = sorted(types), contexts
            observed["classic_required_approvals"], observed["classic_enforce_admins"] = approvals, admins
            observed["check_producers"].extend(records)
            result["coverage"]["classic"]["status"] = "OBSERVED"
        except (KeyError, TypeError, ValueError):
            unknown.append("Classic main protection missing or malformed.")

    # Partial coverage can establish a positive source observation, never absence.
    if observed["ruleset_rules"] is not None and observed["classic_rules"] is not None:
        types = set(observed["ruleset_rules"]) | set(observed["classic_rules"])
        checks = set(observed["ruleset_required_checks"]) | set(observed["classic_required_checks"])
        observed["effective_rules"], observed["required_checks"] = sorted(types), sorted(checks)
        missing_rules, missing_checks = REQUIRED_RULES - types, set(required_checks) - checks
        if missing_rules:
            findings.append("Missing effective main rules: " + ", ".join(sorted(missing_rules)))
        if missing_checks:
            findings.append("Missing required checks: " + ", ".join(sorted(missing_checks)))
    elif observed["ruleset_rules"] is not None and result["coverage"]["classic"]["status"] == "UNVERIFIABLE":
        # Rulesets alone can prove a control present, never absent.
        gaps = (sorted(REQUIRED_RULES - set(observed["ruleset_rules"]))
                + sorted(set(required_checks) - set(observed["ruleset_required_checks"])))
        if gaps:
            unverifiable.append("Not in rulesets; classic protection unverifiable: " + ", ".join(gaps))

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
            elif token_limited and detail.get("enforcement") == "active" and "bypass_actors" not in detail:
                if "Ruleset bypass actors need an admin token." not in unverifiable:
                    unverifiable.append("Ruleset bypass actors need an admin token.")
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
    result["status"] = ("UNKNOWN" if unknown else "WARN" if findings
                        else "LIMITED" if unverifiable else "PASS")
    return result


def gh_get(path):
    """Use the existing in-memory GH_TOKEN; no token or API error output is retained."""
    response = subprocess.run(["gh", "api", "--method", "GET", path,
                               "-H", "Accept: application/vnd.github+json",
                               "-H", "X-GitHub-Api-Version: 2022-11-28"],
                              capture_output=True, text=True, encoding="utf-8", timeout=60)
    if response.returncode:
        match = re.search(r"\(HTTP (\d{3})\)", response.stderr or "")
        try:
            message = json.loads(response.stdout).get("message", "")
        except (ValueError, AttributeError):
            message = ""
        if match:
            raise HttpError(int(match[1]), message if isinstance(message, str) else "")
        raise OSError("GET unavailable")
    return json.loads(response.stdout)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--required-checks", default=",".join(REQUIRED_CHECKS))
    parser.add_argument("--token-limited", action="store_true",
                        help="Report admin-only fields as unverifiable instead of UNKNOWN.")
    args = parser.parse_args()
    checks = [context.strip() for context in args.required_checks.split(",") if context.strip()]
    if not checks:
        parser.error("--required-checks must contain at least one check")
    fetch = gh_get if os.environ.get("GH_TOKEN") else lambda path: (_ for _ in ()).throw(OSError("GH_TOKEN missing"))
    report = audit(fetch, args.repository, required_checks=checks, token_limited=args.token_limited)
    encoded = json.dumps(report, indent=2, ensure_ascii=True) + "\n"
    args.output.write_text(encoded, encoding="utf-8")
    print(encoded, end="")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as stream:
            stream.write(f"## Hygiene: {report['status']}\n\n")
            stream.write(f"Findings: {len(report['findings'])}; UNKNOWN entries: {len(report['unknown'])}; "
                         f"unverifiable with this token: {len(report['unverifiable'])}.\n\n")
            stream.write("Report details are in the job log and local JSON output. No changes were made.\n")
    return 2 if report["unknown"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
