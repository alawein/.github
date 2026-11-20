"""Token/context efficiency evals for slim Start here and load contracts."""
from __future__ import annotations

import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests" / "fixtures" / "token_efficiency"


def estimate_tokens(text: str) -> int:
    return len(text.encode("utf-8")) // 4


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def load_json(name: str):
    return json.loads((FIXTURES / name).read_text(encoding="utf-8"))


class PromptContextEvals(unittest.TestCase):
    """Byte/token estimates of Start here LOAD stack and evidence fields."""

    def test_after_stack_smaller_than_before_fixture(self):
        before = load_json("load_stack_before.json")
        after_budget = load_json("load_stack_after.json")
        agents = read("docs/system/agents.md")
        m = re.search(r"(## Safety floor\n.*?)(?=\n## |\Z)", agents, re.S)
        self.assertIsNotNone(m)
        after_tok = estimate_tokens(read("AGENTS.md")) + estimate_tokens(m.group(1))
        self.assertLess(after_tok, before["forced_full_stack_tokens"])
        self.assertLessEqual(after_tok, after_budget["expected_max_always_tokens"])
        self.assertLessEqual(after_tok, before["forced_full_stack_tokens"] // 3)

    def test_evidence_routine_field_count(self):
        after = load_json("evidence_fields_after.json")
        text = read("templates/agent/evidence.template.md")
        required = after["routine_fields"]
        for field in required:
            self.assertIn(field, text)
        self.assertEqual(len(required), 8)
        self.assertIn("Optional (promotion only)", text)
        self.assertIn("merge permission", text.lower())

    def test_orchestrated_brief_cap_when_split(self):
        brief = ROOT / "templates/agent/orchestrated-improvement-brief.md"
        if not brief.exists():
            self.skipTest("orchestrated split not landed yet")
        self.assertLessEqual(estimate_tokens(brief.read_text(encoding="utf-8")), 800)


class AgentActionEvals(unittest.TestCase):
    """Scripted checklist contracts for scout vs PR-edit loads."""

    def test_scout_must_not_require_just_check_or_full_delivery(self):
        checklist = load_json("scout_checklist.json")
        combined = read("AGENTS.md") + "\n" + read("templates/agent/session-start-prompt.md")
        for forbidden in checklist["must_not"]:
            self.assertNotRegex(
                combined,
                forbidden["pattern"],
                msg=forbidden["reason"],
            )
        for required in checklist["must"]:
            self.assertRegex(combined, required["pattern"], msg=required["reason"])

    def test_pr_edit_must_load_delivery_merge_and_branches(self):
        checklist = load_json("pr_edit_checklist.json")
        combined = (
            read("AGENTS.md")
            + read("templates/agent/session-start-prompt.md")
            + read("docs/system/agents.md")
        )
        for required in checklist["must"]:
            self.assertRegex(combined, required["pattern"], msg=required["reason"])

    def test_safety_floor_and_rv001_still_reachable(self):
        agents_root = read("AGENTS.md")
        self.assertIn("agents.md#safety-floor", agents_root)
        self.assertIn("owner merge permission", agents_root)
        self.assertIn("reviewers.md", agents_root)
        self.assertIn("CodeRabbit", agents_root)
        self.assertIn("never authorize", agents_root)
        reviewers = read("docs/system/reviewers.md")
        self.assertIn("RV-001", reviewers)
        self.assertIn("CodeRabbit", reviewers)


if __name__ == "__main__":
    unittest.main()
