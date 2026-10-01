"""Behavior fixtures for metadata admitted by the shared PR gate."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "check-pr-policy.py"


def load():
    spec = importlib.util.spec_from_file_location("pr_policy", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.check


def event(branch="feat/policy-hygiene", body="Closes #12", draft=False):
    return {"_event_name": "pull_request", "action": "opened", "number": 12,
            "pull_request": {"number": 12, "draft": draft, "body": body,
                             "user": {"login": "contributor", "type": "User"},
                             "head": {"ref": branch}}}


class PolicyTests(unittest.TestCase):
    def setUp(self):
        self.check = load()

    def test_six_house_branch_types(self):
        for kind in ("feat", "fix", "docs", "chore", "refactor", "test"):
            with self.subTest(kind=kind):
                self.assertEqual(self.check(event(kind + "/policy-hygiene")), [])

    def test_disallowed_human_branches(self):
        for branch in ("codex/task", "feat/2026-10-01-topic", "feat/Bad", "feat/a--b",
                       "feat/topic-2026-10-01", "feat/20261001", "feat/a-", "feat/-a",
                       "feat/a/b", "feat/topic-10-01-2026", "dependabot/npm/x"):
            with self.subTest(branch=branch):
                self.assertTrue(self.check(event(branch)))

    def test_bot_exemption_requires_all_three_identity_fields(self):
        bot = event("dependabot/npm/x", "")
        bot["pull_request"]["user"] = {"login": "dependabot[bot]", "type": "Bot"}
        self.assertEqual(self.check(bot), [])
        for key, value in (("login", "dependabot"), ("type", "User")):
            forged = copy.deepcopy(bot)
            forged["pull_request"]["user"][key] = value
            self.assertTrue(self.check(forged))
        bot["pull_request"]["head"]["ref"] = "codex/task"
        self.assertTrue(self.check(bot))

    def test_draft_may_defer_linkage_but_not_branch_rules(self):
        self.assertEqual(self.check(event(body="", draft=True)), [])
        self.assertTrue(self.check(event("codex/task", "", draft=True)))
        ready = event(body="")
        ready["action"] = "ready_for_review"
        self.assertTrue(self.check(ready))
        ready["action"] = "edited"
        self.assertTrue(self.check(ready))
        ready["action"] = "converted_to_draft"
        ready["pull_request"]["draft"] = True
        self.assertEqual(self.check(ready), [])

    def test_linkage_ignores_examples_and_comments(self):
        for body in ("<!-- Closes #12 -->", "`Closes #12`", "```md\nCloses #12\n```",
                     "~~~\nCloses #12\n~~~", "    Closes #12", "<!-- No-issue: specific reason -->",
                     "> ```md\n> Closes #12\n> ```", "> ~~~\n> Closes #12\n> ~~~",
                     "- ```md\n  Closes #12\n  ```", "- ~~~\n  Closes #12\n  ~~~",
                     "```md\n``` not a closing fence\nCloses #12\n```",
                     "<pre>Closes #12</pre>", "<code>Closes #12</code>",
                     "```\nNo-issue: this change updates shared workflows\n```", "Closes #0",
                     "Closes #12abc", "https://github.com/owner/repo/pull/12"):
            with self.subTest(body=body):
                self.assertTrue(self.check(event(body=body)))

    def test_real_linkage_and_specific_exception(self):
        for body in ("Closes #12", "Fixes owner/repo#23", "Refs #123",
                     "https://github.com/owner/repo/issues/12",
                     "No-issue: shared workflow policy has no existing tracking issue"):
            with self.subTest(body=body):
                self.assertEqual(self.check(event(body=body)), [])

    def test_container_code_cannot_supply_linkage_or_exception(self):
        for text in ("Closes #12", "No-issue: shared workflow policy has no existing tracking issue"):
            for body in (">     " + text, "-     " + text,
                         "> - - ~~~\n>     " + text + "\n>     ~~~",
                         "- - ```\n    " + text + "\n    ```",
                         "~~~\n> ~~~\n" + text + "\n~~~",
                         "- ~~~\n  - ~~~\n  " + text + "\n  ~~~"):
                with self.subTest(body=body):
                    self.assertTrue(self.check(event(body=body)))

    def test_container_prose_and_prose_after_code_remain_linkage(self):
        reason = "No-issue: shared workflow policy has no existing tracking issue"
        for body in ("> Closes #12", "- Closes #12", "> - - Closes #12",
                     "> " + reason, "- " + reason, "> - - " + reason,
                     "> - - ~~~\n>     Closes #99\n>     ~~~\n\nCloses #12",
                     "- ~~~\n  - ~~~\n  Closes #99\n  ~~~\n\n" + reason):
            with self.subTest(body=body):
                self.assertEqual(self.check(event(body=body)), [])

    def test_blank_template_reasons_do_not_pass(self):
        for body in (None, "", "No-issue: n/a", "No-issue: TODO", "No-issue: reason",
                     "No-issue: <specific reason>", "No-issue: {{REASON}}", "No-issue: none",
                     "No-issue: \nCloses nothing", "No-issue: `specific reason here`"):
            with self.subTest(body=body):
                self.assertTrue(self.check(event(body=body)))

    def test_malformed_or_missing_pr_event_fails_closed(self):
        for malformed in ({}, [], {"_event_name": "pull_request"}, {"pull_request": None},
                          {"_event_name": "pull_request", "ref": "refs/heads/main"}):
            self.assertTrue(self.check(malformed))
        for field in ("user", "head", "draft", "number", "body"):
            malformed = event()
            del malformed["pull_request"][field]
            self.assertTrue(self.check(malformed), field)
        malformed = event()
        malformed["pull_request"]["number"] = 1
        malformed["number"] = True
        self.assertTrue(self.check(malformed), "boolean event number")
        for field, value in (("draft", "false"), ("number", True), ("body", []),
                             ("user", {"login": "", "type": "User"}), ("head", {"ref": None})):
            malformed = event()
            malformed["pull_request"][field] = value
            self.assertTrue(self.check(malformed), field)

    def test_only_explicit_push_non_pr_event_passes(self):
        self.assertEqual(self.check({"_event_name": "push", "ref": "refs/heads/main"}), [])
        self.assertTrue(self.check({"_event_name": "workflow_dispatch"}))
        self.assertTrue(self.check({"_event_name": "push"}))

    def test_cli_reports_bad_json_and_missing_pr_without_traceback(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "event.json"
            for content in ("{", json.dumps({"ref": "refs/heads/main"})):
                path.write_text(content, encoding="utf-8")
                result = subprocess.run([sys.executable, str(SCRIPT), "--event", str(path)],
                                        env={**os.environ, "GITHUB_EVENT_NAME": "pull_request"},
                                        capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("Traceback", result.stderr)


if __name__ == "__main__":
    unittest.main()
