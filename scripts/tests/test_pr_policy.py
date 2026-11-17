"""Behavior fixtures for metadata admitted by the shared PR gate."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import re
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


def complete_body():
    return "\n\n".join([
        "## Context\nCloses #12\nPrevent incomplete release evidence.",
        "## Changes\nValidate the supplied manifest.",
        "## Testing Evidence\npytest: exit 0, all tests passed.",
        "## Screenshots/Logs\nNot applicable: this change has no visual output.",
        "## Rollback Plan\nRevert the change.",
    ])


class RequiredSectionTests(unittest.TestCase):
    def test_ready_pr_requires_meaningful_evidence_in_each_section(self):
        check = load()
        self.assertEqual(check(event(body=complete_body()), require_sections=True), [])
        for replacement in ("", "<!-- Fill this in -->", "TBD", "- [ ]"):
            with self.subTest(replacement=replacement):
                body = complete_body().replace("pytest: exit 0, all tests passed.", replacement)
                self.assertTrue(check(event(body=body), require_sections=True))

    def test_example_headings_do_not_satisfy_required_sections(self):
        for opening, closing in (("```markdown", "```"), ("<pre>", "</pre>"), ("<code>", "</code>")):
            with self.subTest(opening=opening):
                body = "Closes #12\n" + opening + "\n" + complete_body() + "\n" + closing
                self.assertTrue(load()(event(body=body), require_sections=True))

    def test_list_fenced_examples_cannot_satisfy_required_sections(self):
        for opening, closing, indent in (("- ```markdown", "  ```", 2), ("1. ~~~markdown", "   ~~~", 3)):
            with self.subTest(opening=opening):
                example = "\n".join(" " * indent + line for line in complete_body().splitlines())
                body = f"Closes #12\n{opening}\n{example}\n{closing}"
                errors = load()(event(body=body), require_sections=True)
                self.assertEqual(len(errors), 5, errors)

    def test_list_fence_headings_do_not_replace_real_empty_sections(self):
        empty = "\n".join("## " + name + "\nTBD" for name in (
            "Context", "Changes", "Testing Evidence", "Screenshots/Logs", "Rollback Plan"))
        example = "\n".join("  " + line for line in complete_body().splitlines())
        body = f"Closes #12\n{empty}\n- ```markdown\n{example}\n  ```"
        errors = load()(event(body=body), require_sections=True)
        self.assertEqual(len(errors), 4, errors)
        self.assertTrue(all("Rollback Plan" not in error for error in errors))

    def test_nested_fence_then_real_sections_and_fenced_evidence(self):
        example = "\n".join("  > " + line for line in complete_body().splitlines())
        evidence = "- ```text\n  pytest: 42 passed\n  ```"
        body = (f"- > ```markdown\n{example}\n  > ```\n\n" +
                complete_body().replace("pytest: exit 0, all tests passed.", evidence))
        self.assertEqual(load()(event(body=body), require_sections=True), [])

    def test_html_code_with_fence_like_text_does_not_hide_later_sections(self):
        for tag in ("pre", "code"):
            for opening in ("- ```", "1. ~~~"):
                with self.subTest(tag=tag, opening=opening):
                    body = f"Closes #12\n<{tag}>\n{opening}\n  </{tag}>\n" + complete_body()
                    self.assertEqual(load()(event(body=body), require_sections=True), [])

    def test_html_code_after_a_list_fence_scope_ends_keeps_real_sections(self):
        body = "Closes #12\n- ```\n  example\n<pre>\n- ```\n  </pre>\n" + complete_body()
        self.assertEqual(load()(event(body=body), require_sections=True), [])

    def test_unclosed_comment_in_code_does_not_hide_later_sections(self):
        for block in ("```html\n<!--\n```", "- ```html\n  <!--\n  ```", "<pre>\n<!--\n</pre>"):
            with self.subTest(block=block):
                body = "Closes #12\n" + block + "\n" + complete_body()
                self.assertEqual(load()(event(body=body), require_sections=True), [])

    def test_fence_in_closed_comment_does_not_hide_later_sections(self):
        body = "<!--\n```\n-->\n" + complete_body()
        self.assertEqual(load()(event(body=body), require_sections=True), [])

    def test_real_comment_or_fence_cannot_supply_section_headings(self):
        for block in ("<!--\n" + complete_body() + "\n-->",
                      "```html\n<!--\n" + complete_body() + "\n```"):
            with self.subTest(block=block):
                self.assertEqual(len(load()(event(body="Closes #12\n" + block), require_sections=True)), 5)

    def test_drafts_can_defer_sections(self):
        self.assertEqual(load()(event(body="", draft=True), require_sections=True), [])

    def test_fenced_and_inline_command_results_count_as_evidence(self):
        for evidence in ("```text\npytest tests/test_cli.py\n42 passed\n```", "`pytest`: 42 passed"):
            with self.subTest(evidence=evidence):
                body = complete_body().replace("pytest: exit 0, all tests passed.", evidence)
                self.assertEqual(load()(event(body=body), require_sections=True), [])

    def test_undone_tasks_markup_and_multiline_placeholders_do_not_count(self):
        for evidence in ("- [ ] Run the checks", "TBD\nTODO", "<br>", "**TODO**"):
            with self.subTest(evidence=evidence):
                body = complete_body().replace("pytest: exit 0, all tests passed.", evidence)
                self.assertTrue(load()(event(body=body), require_sections=True))


class PolicyTests(unittest.TestCase):
    def setUp(self):
        self.check = load()

    def test_six_house_branch_types(self):
        for kind in ("feat", "fix", "docs", "chore", "refactor", "test"):
            with self.subTest(kind=kind):
                self.assertEqual(self.check(event(kind + "/policy-hygiene")), [])

    def test_title_check_default_types_and_exp_pass(self):
        # Run 42973143206 rejected ci/add-zizmor-audit although pr-title accepts `ci`.
        for kind in ("style", "perf", "build", "ci", "revert", "exp"):
            with self.subTest(kind=kind):
                self.assertEqual(self.check(event(kind + "/add-zizmor-audit")), [])

    def test_cli_prints_each_violation_as_an_error_annotation(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "event.json"
            path.write_text(json.dumps(event("codex/task", "")), encoding="utf-8")
            # The script reads GITHUB_EVENT_NAME; pin it so a main-push runner does not turn this PR event into a push.
            result = subprocess.run([sys.executable, str(SCRIPT), "--event", str(path)], capture_output=True, text=True,
                                    env={**os.environ, "GITHUB_EVENT_NAME": "pull_request"})
        self.assertEqual(result.returncode, 1)
        lines = result.stdout.splitlines()
        self.assertEqual(len(lines), 2, result.stdout)
        for line in lines:
            self.assertRegex(line, r"^::error::\S")
        self.assertIn("::error::Branch must use a house type", result.stdout)

    def test_documented_release_branch_passes_ready_pr_policy(self):
        delivery = (SCRIPT.parents[1] / "docs/system/delivery.md").read_text(encoding="utf-8")
        branches = re.findall(r"`(chore/release-[^`]+)`", delivery)
        self.assertTrue(branches, "release routine must supply a branch example")
        for branch in branches:
            branch = branch.replace("X", "1").replace("Y", "3").replace("Z", "0")
            for body in ("Closes #12", "No-issue: this release has no existing tracking issue"):
                with self.subTest(branch=branch, body=body):
                    self.assertEqual(self.check(event(branch, body)), [])

    def test_disallowed_human_branches(self):
        for branch in ("codex/task", "feat/2026-10-01-topic", "feat/Bad", "feat/a--b",
                       "feat/topic-2026-10-01", "feat/20261001", "feat/a-", "feat/-a",
                       "feat/a/b", "feat/topic-10-01-2026", "dependabot/npm/x",
                       "chore/release-v1.3.0"):
            with self.subTest(branch=branch):
                self.assertTrue(self.check(event(branch)))

    def test_bot_branches_get_no_exemption(self):
        bot = event("dependabot/npm/x", "")
        bot["pull_request"]["user"] = {"login": "dependabot[bot]", "type": "Bot"}
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

    def test_unclosed_html_markers_inside_fences_do_not_hide_real_linkage(self):
        for marker in ("<pre>", "<code>", "<!--"):
            for opening, content, closing in (("```html", marker, "```"),
                                               ("- ```html", "  " + marker, "  ```")):
                with self.subTest(marker=marker, opening=opening):
                    body = f"{opening}\n{content}\n{closing}\nCloses #12"
                    self.assertEqual(self.check(event(body=body)), [])

    def test_html_and_fences_cannot_supply_linkage(self):
        for body in ("```html\n<pre>Closes #12\n```",
                     "```html\n<!-- Closes #12\n```",
                     "<pre>\n- ```\nCloses #12\n</pre>",
                     "<!--\n- ```\nCloses #12\n-->"):
            with self.subTest(body=body):
                self.assertTrue(self.check(event(body=body)))

    def test_inline_html_code_does_not_hide_surrounding_linkage(self):
        self.assertEqual(self.check(event(body="Notes <pre>example</pre> Closes #12")), [])

    def test_fence_or_html_in_closed_comment_does_not_hide_linkage(self):
        for comment in ("<!--\n```\n-->", "<!-- <pre> -->", "<!--\n<pre>\n-->"):
            with self.subTest(comment=comment):
                self.assertEqual(self.check(event(body=comment + "\nCloses #12")), [])

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

    def test_fence_scope_and_container_order_cannot_expose_code(self):
        for text in ("Closes #12", "No-issue: shared workflow policy has no existing tracking issue"):
            for body in ("> ~~~\n> example\n~~~\n" + text + "\n~~~",
                         "- ~~~\n  example\n~~~\n" + text + "\n~~~",
                         "- > ~~~\n  >     ~~~\n  > " + text + "\n  > ~~~",
                         "- ~~~\n\n  " + text + "\n  ~~~"):
                with self.subTest(body=body):
                    self.assertTrue(self.check(event(body=body)))

    def test_fence_scope_exit_and_valid_closing_preserve_prose(self):
        for text in ("Closes #12", "No-issue: shared workflow policy has no existing tracking issue"):
            for body in ("> ~~~\n> example\n" + text,
                         "- ~~~\n  example\n" + text,
                         "- > ~~~\n  > example\n  > ~~~\n\n" + text,
                         "> - ~~~\n>   example\n>   ~~~\n\n" + text,
                         "- > ~~~\n  >     ~~~\n  > Closes #99\n  > ~~~\n\n" + text,
                         "~~~\n> ~~~\nCloses #99\n~~~\n\n" + text):
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

    def test_dependabot_style_fixture_passes_with_house_branch_and_sections(self):
        fixture = Path(__file__).resolve().parent / "fixtures" / "dependabot-pr-valid.json"
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--event", str(fixture)],
            env={**os.environ, "REQUIRE_SECTIONS": "true", "GITHUB_EVENT_NAME": "pull_request"},
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("PR policy compliant", result.stdout)


if __name__ == "__main__":
    unittest.main()
