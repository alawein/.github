"""Pure path → heavy branching for metadata-tests (frozen regex)."""
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

from metadata_suite_paths import (  # noqa: E402
    METADATA_HEAVY_PATH_GREP,
    paths_require_heavy_metadata_suite,
)


class MetadataSuitePathTests(unittest.TestCase):
    def test_fixture_matrix(self):
        cases = (
            (["docs/ci.md"], False),
            (["README.md"], False),
            (["scripts/tests/test_pr_policy.py"], False),
            (["scripts/new-repo.ps1"], True),
            (["scripts/check-pr-policy.py"], True),
            (["scripts/lib/check-policy.ps1"], True),
            (["default.json"], True),
            (["renovate.json"], True),
            (["rulesets/checks.json"], True),
            (["templates/workflows/docs.yml"], True),
            (["tests/test_check_list.py"], True),
            ([".github/workflows/ci.yml"], True),
            (["docs/ci.md", "templates/workflows/docs.yml"], True),
        )
        for paths, heavy in cases:
            with self.subTest(paths=paths):
                self.assertEqual(paths_require_heavy_metadata_suite(paths), heavy)

    def test_grep_pattern_is_frozen(self):
        self.assertEqual(
            METADATA_HEAVY_PATH_GREP,
            r"^(scripts/[^/]+$|scripts/lib/|templates/|tests/|\.github/workflows/|default\.json|renovate\.json|rulesets/)",
        )


if __name__ == "__main__":
    unittest.main()