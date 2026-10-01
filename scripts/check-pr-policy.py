#!/usr/bin/env python3
"""Validate caller PR metadata without fetching or executing caller code."""
import argparse
import json
import os
from pathlib import Path
import re

BRANCH = re.compile(r"(?:feat|fix|docs|chore|refactor|test)/[a-z0-9]+(?:-[a-z0-9]+)*\Z")
DATE = re.compile(r"(?:\d{4}-\d{2}-\d{2}|\d{2}-\d{2}-\d{4}|(?:19|20)\d{6})")
ISSUE = re.compile(r"(?<![\w/])(?:[\w.-]+/[\w.-]+)?#[1-9]\d*(?![\w])|"
                   r"https://github\.com/[\w.-]+/[\w.-]+/issues/[1-9]\d*(?![\w/])")
PLACEHOLDERS = {"n/a", "na", "none", "todo", "tbd", "reason", "specific reason", "no issue"}


def prose(body):
    """Remove Markdown examples and comments before examining actual prose."""
    body = re.sub(r"<!--.*?(?:-->|\Z)", "", body, flags=re.S)
    body = re.sub(r"<(pre|code)\b[^>]*>.*?(?:</\1\s*>|\Z)", "", body, flags=re.S | re.I)
    lines, fence = [], None
    for line in body.splitlines():
        content = re.sub(r"^(?: {0,3}>[ \t]?)*(?: {0,3}(?:[-+*]|\d+[.)])[ \t]+)?", "", line)
        match = re.match(r"^ {0,3}(`{3,}|~{3,})(.*)$", content)
        if fence:
            if (match and match[1][0] == fence[0] and len(match[1]) >= len(fence)
                    and not match[2].strip()):
                fence = None
            continue
        if match:
            fence = match[1]
        elif not re.match(r"^(?: {4}|\t)", line):
            lines.append(line)
    return re.sub(r"(?<!`)(`+)(?!`).*?(?<!`)\1(?!`)", "", "\n".join(lines), flags=re.S)


def linked(body):
    text = prose(body)
    if ISSUE.search(text):
        return True
    for match in re.finditer(r"^\s*No-issue:[ \t]*([^\n]*)$", text, flags=re.M | re.I):
        reason = match[1].strip()
        if (len(reason) >= 15 and len(reason.split()) >= 3
                and reason.lower().rstrip(".") not in PLACEHOLDERS
                and not re.search(r"[<>{}\[\]]|\b(?:todo|tbd|placeholder)\b", reason, re.I)):
            return True
    return False


def check(event: dict) -> list[str]:
    """Return violations; only a validated PR or explicit push can succeed."""
    if not isinstance(event, dict):
        return ["Event must be an object."]
    name = event.get("_event_name")
    if name == "push":
        if isinstance(event.get("ref"), str) and event["ref"].startswith("refs/") and "pull_request" not in event:
            return []
        return ["Malformed push event."]
    if name not in (None, "pull_request"):
        return ["Unsupported policy event."]
    pr = event.get("pull_request")
    if not isinstance(pr, dict):
        return ["Missing pull_request metadata."]
    user, head = pr.get("user"), pr.get("head")
    valid = (isinstance(user, dict) and isinstance(user.get("login"), str) and bool(user["login"])
             and user.get("type") in ("User", "Bot") and isinstance(head, dict)
             and isinstance(head.get("ref"), str) and bool(head["ref"])
             and type(pr.get("draft")) is bool and type(pr.get("number")) is int and pr["number"] > 0
             and type(event.get("number")) is int and event["number"] == pr["number"] and "body" in pr
             and (pr["body"] is None or isinstance(pr["body"], str))
             and event.get("action") in ("opened", "edited", "synchronize", "reopened",
                                          "ready_for_review", "converted_to_draft"))
    if not valid:
        return ["Malformed pull_request metadata."]
    branch = head["ref"]
    if user["login"] == "dependabot[bot]" and user["type"] == "Bot" and branch.startswith("dependabot/") and len(branch) > 11:
        return []
    errors = []
    if not BRANCH.fullmatch(branch) or DATE.search(branch):
        errors.append("Branch must use a house type and a lowercase hyphenated topic without dates.")
    if not pr["draft"] and not linked(pr["body"] or ""):
        errors.append("Ready PR needs an issue reference or No-issue: followed by a specific reason.")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--event", required=True, type=Path)
    args = parser.parse_args()
    try:
        event = json.loads(args.event.read_text(encoding="utf-8"))
        if isinstance(event, dict) and os.environ.get("GITHUB_EVENT_NAME"):
            event["_event_name"] = os.environ["GITHUB_EVENT_NAME"]
        errors = check(event)
    except (OSError, ValueError) as error:
        errors = [f"Cannot read event: {error.__class__.__name__}."]
    for error in errors:
        print(error)
    if not errors:
        print("PR policy compliant (or explicit non-PR push).")
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
