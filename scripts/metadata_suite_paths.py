"""Frozen path set for metadata-tests fast vs heavy branching (see docs/ci.md)."""
from __future__ import annotations

import re
from collections.abc import Iterable

# Must match `grep -E` in `.github/workflows/ci.yml` job `metadata-tests`, step `Detect generator paths`.
# Top-level scripts/* and scripts/lib/ trip heavy; scripts/tests/ stays on the fast path
# (scripts/tests always runs). default.json, renovate.json, and rulesets/ trip the
# Renovate validator / root suite that the previous filter skipped.
METADATA_HEAVY_PATH_GREP = (
    r"^(scripts/[^/]+$|scripts/lib/|templates/|tests/|\.github/workflows/|default\.json|renovate\.json|rulesets/)"
)
METADATA_HEAVY_PATH_RE = re.compile(METADATA_HEAVY_PATH_GREP)


def paths_require_heavy_metadata_suite(changed_paths: Iterable[str]) -> bool:
    """Return True when any changed path triggers the heavy metadata suite."""
    return any(METADATA_HEAVY_PATH_RE.match(path) for path in changed_paths)