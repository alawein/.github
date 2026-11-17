"""Kit CI path-filters the heavy metadata suite while keeping the job name."""
from pathlib import Path
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1]


def ci_jobs():
    return yaml.safe_load((ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8"))["jobs"]


class MetadataPathFilterTests(unittest.TestCase):
    def test_metadata_tests_job_name_unchanged(self):
        self.assertIn("metadata-tests", ci_jobs())

    def test_detects_generator_paths_and_splits_suites(self):
        steps = ci_jobs()["metadata-tests"]["steps"]
        detect = next(s for s in steps if s.get("name") == "Detect generator paths")
        self.assertEqual(detect["id"], "gen")
        self.assertIn("scripts/new-repo", detect["run"])
        self.assertIn("templates/", detect["run"])
        self.assertIn("heavy=", detect["run"])

        fast = next(s for s in steps if s.get("name") == "Fast path metadata suite")
        self.assertEqual(fast["if"], "steps.gen.outputs.heavy != 'true'")
        self.assertIn("discover -s scripts/tests", fast["run"])

        heavy_guards = [
            s for s in steps
            if s.get("if") == "steps.gen.outputs.heavy == 'true'"
        ]
        self.assertGreaterEqual(len(heavy_guards), 3)
        heavy_runs = "\n".join(s.get("run", "") for s in heavy_guards)
        self.assertIn("discover -s tests", heavy_runs)
        self.assertIn("--require-hashes", heavy_runs)


if __name__ == "__main__":
    unittest.main()
