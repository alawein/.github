"""Kit CI path-filters the heavy metadata suite while keeping the job name."""
from pathlib import Path
import sys
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from metadata_suite_paths import METADATA_HEAVY_PATH_GREP, paths_require_heavy_metadata_suite  # noqa: E402


def ci_jobs():
    return yaml.safe_load((ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8"))["jobs"]


class MetadataPathFilterTests(unittest.TestCase):
    def test_metadata_tests_job_name_unchanged(self):
        self.assertIn("metadata-tests", ci_jobs())

    def test_workflow_regex_matches_frozen_helper(self):
        detect = next(
            s
            for s in ci_jobs()["metadata-tests"]["steps"]
            if s.get("name") == "Detect generator paths"
        )
        self.assertIn(f"grep -E '{METADATA_HEAVY_PATH_GREP}'", detect["run"])

    def test_paths_require_heavy_metadata_suite_fixtures(self):
        self.assertFalse(paths_require_heavy_metadata_suite(["docs/ci.md"]))
        self.assertFalse(paths_require_heavy_metadata_suite(["scripts/tests/test_pr_policy.py"]))
        self.assertTrue(paths_require_heavy_metadata_suite([".github/workflows/ci.yml"]))
        self.assertTrue(paths_require_heavy_metadata_suite(["default.json"]))
        self.assertTrue(paths_require_heavy_metadata_suite(["renovate.json"]))
        self.assertTrue(paths_require_heavy_metadata_suite(["rulesets/checks.json"]))
        self.assertTrue(paths_require_heavy_metadata_suite(["scripts/check-pr-policy.py"]))

    def test_detects_generator_paths_and_splits_suites(self):
        steps = ci_jobs()["metadata-tests"]["steps"]
        detect = next(s for s in steps if s.get("name") == "Detect generator paths")
        self.assertEqual(detect["id"], "gen")
        self.assertIn("scripts/[^/]+$", detect["run"])
        self.assertIn("default\\.json", detect["run"])
        self.assertIn("renovate\\.json", detect["run"])
        self.assertIn("rulesets/", detect["run"])
        self.assertIn("templates/", detect["run"])
        self.assertIn("heavy=", detect["run"])

        scripts_suite = next(s for s in steps if s.get("name") == "Metadata scripts suite")
        self.assertNotIn("if", scripts_suite)
        self.assertIn("discover -s scripts/tests", scripts_suite["run"])
        suite_steps = [s for s in steps if "discover -s scripts/tests" in s.get("run", "")]
        self.assertEqual(len(suite_steps), 1, suite_steps)
        self.assertEqual(suite_steps[0]["name"], "Metadata scripts suite")

        heavy_guards = [
            s for s in steps
            if s.get("if") == "steps.gen.outputs.heavy == 'true'"
        ]
        self.assertGreaterEqual(len(heavy_guards), 3)
        heavy_runs = "\n".join(s.get("run", "") for s in heavy_guards)
        self.assertIn("discover -s tests", heavy_runs)
        self.assertIn("--require-hashes", heavy_runs)
        self.assertIn("renovate-config-validator", heavy_runs)
        self.assertIn("test-update-policy-events.mjs", heavy_runs)

        install = next(s for s in steps if s.get("name", "").startswith("Install actionlint"))
        self.assertEqual(install["if"], "steps.gen.outputs.heavy == 'true'")
        env = install["env"]
        self.assertEqual(env["ACTIONLINT_SHA256"], "8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8")
        self.assertEqual(env["JUST_SHA256"], "409044617b6f06517c1035e55ca38c8c856ff8b650e41bc2aa1ef82d5903a23e")
        self.assertEqual(env["LYCHEE_SHA256"], "73657a111819a30c47c08352896796f23d64e4eb2b3ed39b6d32149241566fc5")


if __name__ == "__main__":
    unittest.main()