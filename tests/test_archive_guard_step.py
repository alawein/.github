"""Archive guard must be a first step, not a separate billed job."""
from pathlib import Path
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1]
REUSABLES = [
    "lint-markdown.yml",
    "check-links.yml",
    "lint-actions.yml",
    "lint-zizmor.yml",
    "pr-title.yml",
    "pr-policy.yml",
    "node-ci.yml",
    "python-ci.yml",
    "hygiene.yml",
]


class ArchiveGuardStepTests(unittest.TestCase):
    def test_no_separate_archive_guard_job(self):
        for name in REUSABLES:
            data = yaml.safe_load((ROOT / ".github/workflows" / name).read_text(encoding="utf-8"))
            self.assertNotIn("archive-guard", data.get("jobs", {}), name)

    def test_first_step_refuses_archive_prefix(self):
        for name in REUSABLES:
            text = (ROOT / ".github/workflows" / name).read_text(encoding="utf-8")
            self.assertIn("ARCHIVE-*", text, name)
            data = yaml.safe_load(text)
            jobs = data["jobs"]
            # Primary work job keeps historical id (lint / ci / check / audit).
            primary = next(iter(jobs.values()))
            first = primary["steps"][0]
            self.assertEqual(first.get("name"), "Refuse to run in an archive repo", name)
            self.assertIn("ARCHIVE-*", first.get("run", ""), name)


if __name__ == "__main__":
    unittest.main()
