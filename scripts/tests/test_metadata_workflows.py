"""Exercise the workflow's shell guards, including foreign caller trust and gates."""
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
AUDIT_SOURCE_SHA = "ce04a21e332e42c3137b26f3becb0de77086b6cb"
AUDIT_SOURCE_HASH = "444859e0388579527564800c508432a9c1f28a1ddaa076b23b6353e4dea4f374"
RELEASE_SHA = "b5f8bc3a916b41e22e5e09ec72f34c01428c2933"
BASH = (str(Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Git/bin/bash.exe")
        if os.name == "nt" else shutil.which("bash"))


class MetadataWorkflowTests(unittest.TestCase):
    def shell_step(self, workflow, name):
        path = ROOT / ".github/workflows" / workflow
        self.assertTrue(path.exists(), "metadata workflow missing")
        text = path.read_text(encoding="utf-8")
        match = re.search(r"      - name: " + re.escape(name) + r"\n(.*?)(?=\n      - |\n  [a-z]|\Z)", text, re.S)
        self.assertIsNotNone(match, "named guard missing")
        block = match[1]
        script = block.split("        run: |\n", 1)[1]
        return "\n".join(line[10:] for line in script.splitlines() if line.startswith("          "))

    def run_guard(self, workflow, ref, repository="alawein/.github", sha="a" * 40):
        script = self.shell_step(workflow, "Validate kit ref")
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "output"
            result = subprocess.run([BASH, "-c", script], capture_output=True, text=True,
                                    env={**os.environ, "KIT_REF": ref, "CALLER_REPOSITORY": repository,
                                         "CALLER_SHA": sha, "GITHUB_OUTPUT": output.as_posix()})
            return result.returncode, output.read_text() if output.exists() else ""

    def test_same_repo_can_default_to_current_sha(self):
        code, output = self.run_guard("pr-policy.yml", "")
        self.assertEqual(code, 0)
        self.assertEqual(output.strip(), "kit-ref=" + "a" * 40)

    def test_foreign_caller_must_supply_full_immutable_ref(self):
        code, output = self.run_guard("pr-policy.yml", "b" * 40, "owner/consumer")
        self.assertEqual(code, 0)
        self.assertEqual(output.strip(), "kit-ref=" + "b" * 40)
        for ref in ("", "main", "v1.2.0", "a" * 39, "$(echo bad)", "a" * 40 + "\n"):
            with self.subTest(ref=ref):
                code, output = self.run_guard("pr-policy.yml", ref, "owner/consumer")
                self.assertNotEqual(code, 0)
                self.assertEqual(output, "")

    def test_hygiene_executes_only_the_reviewed_literal_source(self):
        workflow = (ROOT / ".github/workflows/hygiene.yml").read_text(encoding="utf-8")
        self.assertNotIn("kit-ref:", workflow, "audit source must not be a caller input")
        checkouts = re.findall(r"      - name: .*?\n(.*?)(?=\n      - |\Z)", workflow, re.S)
        checkouts = [step for step in checkouts if "uses: actions/checkout@" in step]
        self.assertEqual(len(checkouts), 1, "every audit checkout needs review")
        checkout = checkouts[0]
        self.assertRegex(checkout, r"(?m)^          repository: alawein/\.github$")
        self.assertRegex(checkout, r"(?m)^          ref: " + AUDIT_SOURCE_SHA + r"$")
        self.assertIn("persist-credentials: false", checkout)

    def test_local_audit_source_matches_the_reviewed_pin(self):
        # Normalize platform checkout line endings; all other source bytes are bound.
        source = (ROOT / "scripts/audit-hygiene.py").read_text(encoding="utf-8").encode("utf-8")
        self.assertEqual(hashlib.sha256(source).hexdigest(), AUDIT_SOURCE_HASH,
                         "audit changes require reviewing and updating the source pin and hash together")

    def test_policy_gate_rejects_unsuccessful_producer_or_tests(self):
        script = self.shell_step("ci.yml", "Require policy and metadata tests")
        for result, tests, expected in (("success", "success", 0), ("cancelled", "success", 1),
                                       ("failure", "success", 1), ("skipped", "success", 1),
                                       ("success", "failure", 1), ("success", "cancelled", 1)):
            code = subprocess.run([BASH, "-c", script], env={**os.environ, "RESULT": result, "TESTS": tests}).returncode
            self.assertEqual(code, expected)

    def test_opt_in_consumer_gate_requires_success(self):
        fragment = (ROOT / "templates/workflows/pr-policy.jobs.yml").read_text(encoding="utf-8")
        script = re.search(r"      run: \|\n((?:        .*\n?)+)", fragment)[1]
        script = "\n".join(line[8:] for line in script.splitlines())
        for result in ("success", "failure", "cancelled", "skipped", ""):
            with self.subTest(result=result):
                code = subprocess.run([BASH, "-c", script], env={**os.environ, "RESULT": result}).returncode
                self.assertEqual(code, 0 if result == "success" else 1)

    def test_new_callers_bind_workflow_and_source_without_extra_credentials(self):
        policy = (ROOT / "templates/workflows/pr-policy.jobs.yml").read_text(encoding="utf-8")
        self.assertIn("pr-policy.yml@" + RELEASE_SHA + " # v1.3.0", policy)
        self.assertRegex(policy, r"(?m)^    kit-ref: " + RELEASE_SHA + "$")
        self.assertIn("needs: [run-pr-policy]", policy)
        self.assertIn("if: ${{ always() }}", policy)
        self.assertIn("permissions: {}", policy)
        self.assertNotIn("pull-requests:", policy)
        hygiene = (ROOT / "templates/workflows/hygiene-weekly.yml").read_text(encoding="utf-8")
        self.assertIn("hygiene.yml@" + RELEASE_SHA + " # v1.3.0", hygiene)
        self.assertNotIn("kit-ref:", hygiene)
        for caller in (policy, hygiene):
            self.assertNotIn("secrets:", caller)
            self.assertNotIn("write", caller)


if __name__ == "__main__":
    unittest.main()
