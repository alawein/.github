"""Offline publication-contract regression for ready-to-copy kit distribution."""

from __future__ import annotations

import re
import subprocess
import sys
import unittest
from pathlib import Path

TESTS = Path(__file__).resolve().parent
ROOT = TESTS.parent

import importlib.util

_SPEC = importlib.util.spec_from_file_location(
    "check_publication_contract",
    ROOT / "scripts" / "check-publication-contract.py",
)
pub = importlib.util.module_from_spec(_SPEC)
assert _SPEC.loader is not None
_SPEC.loader.exec_module(pub)

KIT_SHA = "cc3b595f8e9e92a9ed6fc63b3be177cc8a571965"


class PublicationContractTests(unittest.TestCase):
    def test_offline_publication_contract_passes(self):
        code = pub.run(remote=False)
        self.assertEqual(code, 0)

    def test_ready_to_copy_excludes_withheld_claude_template(self):
        names = {path.name for path in pub.ready_to_copy_yamls()}
        self.assertNotIn("claude-review.yml", names)
        self.assertTrue(
            (ROOT / "templates/workflows/claude-review.WITHHELD.md").exists()
        )
        self.assertFalse((ROOT / "templates/workflows/claude-review.yml").exists())

    def test_freeze_targets_exist_locally(self):
        problems: list[str] = []
        pub.check_target_existence(problems)
        self.assertEqual(problems, [])

    def test_uses_and_kit_ref_lockstep(self):
        problems: list[str] = []
        pub.check_uses_kit_ref_lockstep(problems)
        self.assertEqual(problems, [])
        fragment = (ROOT / "templates/workflows/pr-policy.jobs.yml").read_text(
            encoding="utf-8"
        )
        self.assertIn(f"pr-policy.yml@{KIT_SHA}", fragment)
        self.assertRegex(fragment, rf"(?m)^    kit-ref: {KIT_SHA}$")

    def test_pr_policy_fragment_grants_pull_requests_read(self):
        fragment = pub.load_yaml(
            (ROOT / "templates/workflows/pr-policy.jobs.yml").read_text(encoding="utf-8")
        )
        perms = fragment["run-pr-policy"]["permissions"]
        self.assertEqual(
            perms, {"contents": "read", "pull-requests": "read"}
        )

    def test_caller_permissions_cover_pinned_callees(self):
        problems: list[str] = []
        pub.check_caller_permissions(problems)
        self.assertEqual(problems, [])

    def test_workflow_call_inputs_and_secrets_match_pinned_callees(self):
        problems: list[str] = []
        pub.check_workflow_call_inputs(problems)
        self.assertEqual(problems, [])

    def test_generated_starters_stay_on_freeze_lockstep(self):
        pins = set()
        for path in sorted(
            (ROOT / "templates/starters").glob("*/.github/workflows/*.yml")
        ):
            text = path.read_text(encoding="utf-8")
            pins.update(sha for _wf, sha, _c in pub.collect_calls(text))
            pins.update(pub.KIT_REF_RE.findall(text))
        self.assertEqual(pins, {KIT_SHA})

    def test_docs_pins_and_renovate_extend_match_freeze(self):
        self.assertEqual(pub.documented_freeze_sha(), KIT_SHA)
        renovate = (ROOT / "renovate.json").read_text(encoding="utf-8")
        self.assertIn(f"github>alawein/.github#{KIT_SHA}", renovate)
        ci = (ROOT / "docs/ci.md").read_text(encoding="utf-8")
        self.assertIn(KIT_SHA, ci)
        self.assertIn("# quality gates", ci)

    def test_cli_offline_exit_zero(self):
        result = subprocess.run(
            [sys.executable, str(ROOT / "scripts/check-publication-contract.py")],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("publication-contract PASS (offline)", result.stdout)
        self.assertNotIn("--remote", result.args[1:])

    def test_missing_target_is_detected(self):
        # Sanity: the withheld case that used to ship would fail existence.
        self.assertFalse(
            pub.git_path_exists(KIT_SHA, ".github/workflows/claude-review.yml")
        )
        self.assertTrue(
            pub.git_path_exists(KIT_SHA, ".github/workflows/pr-policy.yml")
        )


class PublicationContractScriptSurfaceTests(unittest.TestCase):
    def test_remote_flag_is_opt_in_only(self):
        source = (ROOT / "scripts/check-publication-contract.py").read_text(
            encoding="utf-8"
        )
        self.assertIn('"--remote"', source)
        self.assertIn("off by default", source)
        self.assertRegex(
            source,
            re.compile(r"remote preflight", re.I),
        )


if __name__ == "__main__":
    unittest.main()
