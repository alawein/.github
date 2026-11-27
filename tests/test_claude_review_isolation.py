"""The Claude review job must scrub secrets from the subprocesses its tools start."""

import unittest
from pathlib import Path

import yaml

WORKFLOW = Path(__file__).resolve().parents[1] / ".github/workflows/claude-review.yml"


def claude_step(doc: dict) -> dict:
    for job in doc["jobs"].values():
        for step in job.get("steps", []):
            if str(step.get("uses", "")).startswith("anthropics/claude-code-action@"):
                return step
    raise AssertionError("no claude-code-action step")


class ClaudeReviewIsolation(unittest.TestCase):
    def test_subprocess_env_scrub_is_on(self):
        step = claude_step(yaml.safe_load(WORKFLOW.read_text(encoding="utf-8")))
        self.assertEqual(str(step.get("env", {}).get("CLAUDE_CODE_SUBPROCESS_ENV_SCRUB")), "1")

    def test_bad_change_is_caught(self):
        doc = yaml.safe_load(WORKFLOW.read_text(encoding="utf-8"))
        claude_step(doc).pop("env", None)
        with self.assertRaises(AssertionError):
            self.assertEqual(str(claude_step(doc).get("env", {}).get("CLAUDE_CODE_SUBPROCESS_ENV_SCRUB")), "1")


if __name__ == "__main__":
    unittest.main()
