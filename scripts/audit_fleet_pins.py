#!/usr/bin/env python3
"""Print consumer workflow pins for alawein/.github reusables.

Read-only. Uses the GitHub code search API via `gh`, then fetches each matching
workflow file and extracts `uses: alawein/.github/...@<sha>` pins.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
import time
from collections import defaultdict
from urllib.parse import quote

PIN_RE = re.compile(
    r"alawein/\.github/\.github/workflows/[\w.-]+@([0-9a-f]{40}|[^\s#\"']+)"
)
SEARCH_QUERY = "org:alawein uses: alawein/.github path:.github/workflows"


def gh_api(path: str) -> dict | list:
    """GET a GitHub API path with light retry on search rate limits."""
    cmd = ["gh", "api", path]
    delay = 5
    for attempt in range(6):
        try:
            out = subprocess.check_output(cmd, text=True, stderr=subprocess.PIPE)
            return json.loads(out)
        except subprocess.CalledProcessError as error:
            err = (error.stderr or "") + (error.output or "")
            if attempt < 5 and ("403" in err or "429" in err or "rate limit" in err.lower()):
                time.sleep(delay)
                delay = min(delay * 2, 60)
                continue
            raise SystemExit(f"gh api failed for {path}: {err.strip() or error}") from error
    raise SystemExit(f"gh api retries exhausted for {path}")


def search_items() -> list[dict]:
    items: list[dict] = []
    page = 1
    while True:
        q = quote(SEARCH_QUERY)
        data = gh_api(f"search/code?q={q}&per_page=50&page={page}")
        assert isinstance(data, dict)
        batch = data.get("items") or []
        items.extend(batch)
        if len(batch) < 50 or page >= 10:
            break
        page += 1
        time.sleep(1)
    return items


def fetch_file(full_name: str, path: str) -> str:
    # Contents API returns base64; use raw via gh api with Accept header.
    encoded = quote(path, safe="/")
    cmd = [
        "gh",
        "api",
        f"repos/{full_name}/contents/{encoded}",
        "-H",
        "Accept: application/vnd.github.raw",
    ]
    try:
        return subprocess.check_output(cmd, text=True, stderr=subprocess.PIPE)
    except subprocess.CalledProcessError as error:
        err = (error.stderr or "").strip()
        return f"# ERROR fetching {full_name}/{path}: {err}"


def main() -> int:
    print(f"# Fleet pin audit for `{SEARCH_QUERY}`\n", flush=True)
    try:
        items = search_items()
    except SystemExit as error:
        print(str(error), file=sys.stderr)
        return 2

    if not items:
        print("No code-search hits (empty result or insufficient search scope).")
        return 0

    by_repo: dict[str, list[tuple[str, list[str]]]] = defaultdict(list)
    pin_counts: dict[str, int] = defaultdict(int)

    for item in items:
        repo = item["repository"]["full_name"]
        path = item["path"]
        body = fetch_file(repo, path)
        pins = PIN_RE.findall(body)
        unique = sorted(set(pins))
        for pin in pins:
            pin_counts[pin] += 1
        by_repo[repo].append((path, unique, len(pins)))
        time.sleep(0.2)

    print("| Repository | Path | Distinct pins | Call count |")
    print("| --- | --- | --- | ---: |")
    for repo in sorted(by_repo):
        for path, pins, count in sorted(by_repo[repo], key=lambda row: row[0]):
            shown = ", ".join(pins) if pins else "(no sha pin matched)"
            print(f"| {repo} | `{path}` | `{shown}` | {count} |")

    print("\n## Pin frequency\n")
    print("| Pin | Occurrences |")
    print("| --- | ---: |")
    for pin, count in sorted(pin_counts.items(), key=lambda kv: (-kv[1], kv[0])):
        print(f"| `{pin}` | {count} |")

    print("\n## Notes\n")
    print("- Kit templates currently freeze to reviewed main; consumers may still lag.")
    print("- ARCHIVE-* doctrine callers should fail closed via the archive guard step.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
