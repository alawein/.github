"""Every copy of a required-check list must match rulesets/checks.json, the one canonical list."""
import json
from pathlib import Path
import re
import sys
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1]
CHECKS = json.loads((ROOT / "rulesets/checks.json").read_text(encoding="utf-8"))
BASE = CHECKS["fleet_base"]

TESTS = Path(__file__).resolve().parent
if str(TESTS) not in sys.path:
    sys.path.insert(0, str(TESTS))

from workflow_gate_contract import KitSelfKind, classify_kit_self, slash_parts  # noqa: E402


def text(path):
    return (ROOT / path).read_text(encoding="utf-8")


def workflow(path):
    return yaml.safe_load(text(path))


def contexts(path):
    rules = json.loads(text(path))["rules"]
    return [check["context"] for rule in rules if rule["type"] == "required_status_checks"
            for check in rule["parameters"]["required_status_checks"]]


def powershell_list(path, pattern):
    match = re.search(pattern + r"\s*=\s*@\(([^)]*)\)", text(path))
    return re.findall(r"'([^']+)'", match[1])


class FleetBaseCopiesTests(unittest.TestCase):
    def test_every_fleet_copy_matches_checks_json(self):
        copies = {
            "scripts/audit-hygiene.py": list(re.search(r"REQUIRED_CHECKS = \(([^)]*)\)", text("scripts/audit-hygiene.py"))[1]
                                             .replace('"', "").replace(" ", "").split(",")),
            "hygiene.yml default": workflow(".github/workflows/hygiene.yml")[True]["workflow_call"]["inputs"]
                                   ["expected-required-checks"]["default"].split(","),
            "templates/workflows/hygiene-weekly.yml": workflow("templates/workflows/hygiene-weekly.yml")["jobs"]["hygiene"]
                                                      ["with"]["expected-required-checks"].split(","),
            "rulesets/main-public.json": contexts("rulesets/main-public.json"),
            "scripts/lib/check-policy.ps1": powershell_list("scripts/lib/check-policy.ps1", r"\$checks"),
            "scripts/verify-repo.ps1": powershell_list("scripts/verify-repo.ps1", r"\$BaseChecks"),
        }
        for name, listed in copies.items():
            with self.subTest(copy=name):
                self.assertEqual(listed, BASE)
        self.assertEqual(contexts("rulesets/main-site.json"), BASE + [CHECKS["language_extra"]["node"]])


class KitSelfCopiesTests(unittest.TestCase):
    def test_kit_contexts_and_hygiene_match_checks_json(self):
        # Kit CI requires reusable-workflow slash names (no thin always() lint gates).
        # Policy still uses bare always() gates for pr-title and pr-policy.
        ci = workflow(".github/workflows/ci.yml")["jobs"]
        policy = workflow(".github/workflows/policy.yml")["jobs"]
        kit_self = CHECKS["kit_self"]

        for ctx in kit_self:
            kind = classify_kit_self(ctx)
            with self.subTest(ctx=ctx, kind=kind.value):
                if kind is KitSelfKind.SLASH_PRODUCER:
                    caller, called = slash_parts(ctx)
                    self.assertIn(caller, ci)
                    self.assertIn("uses", ci[caller])
                    self.assertEqual(called, "lint")
                elif kind is KitSelfKind.PLAIN_JOB:
                    self.assertIn(ctx, ci)
                    self.assertNotEqual(ci[ctx].get("if"), "${{ always() }}")
                elif kind is KitSelfKind.ALWAYS_GATE:
                    self.assertIn(ctx, policy)
                    self.assertEqual(policy[ctx].get("if"), "${{ always() }}")
                    self.assertEqual(policy[ctx].get("permissions"), {})
                else:
                    raise AssertionError(f"unhandled kind: {kind!r}")

        ci_always = [
            name for name, job in ci.items()
            if job.get("if") == "${{ always() }}" and job.get("permissions") == {}
        ]
        self.assertEqual(ci_always, [])
        weekly = workflow(".github/workflows/hygiene-weekly.yml")["jobs"]["hygiene"]["with"][
            "expected-required-checks"
        ]
        self.assertEqual(sorted(weekly.split(",")), sorted(kit_self))


if __name__ == "__main__":
    unittest.main()
