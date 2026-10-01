"""Exercise the workflow's shell guards, including foreign caller trust and gates."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
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
        for workflow in ("pr-policy.yml", "hygiene.yml"):
            code, output = self.run_guard(workflow, "")
            self.assertEqual(code, 0)
            self.assertEqual(output.strip(), "kit-ref=" + "a" * 40)

    def test_foreign_caller_must_supply_full_immutable_ref(self):
        for workflow in ("pr-policy.yml", "hygiene.yml"):
            code, output = self.run_guard(workflow, "b" * 40, "owner/consumer")
            self.assertEqual(code, 0)
            self.assertEqual(output.strip(), "kit-ref=" + "b" * 40)
            for ref in ("", "main", "v1.2.0", "a" * 39, "$(echo bad)", "a" * 40 + "\n"):
                with self.subTest(workflow=workflow, ref=ref):
                    code, output = self.run_guard(workflow, ref, "owner/consumer")
                    self.assertNotEqual(code, 0)
                    self.assertEqual(output, "")

    def test_policy_gate_rejects_unsuccessful_producer_or_tests(self):
        script = self.shell_step("ci.yml", "Require policy and metadata tests")
        for result, tests, expected in (("success", "success", 0), ("cancelled", "success", 1),
                                       ("failure", "success", 1), ("skipped", "success", 1),
                                       ("success", "failure", 1), ("success", "cancelled", 1)):
            code = subprocess.run([BASH, "-c", script], env={**os.environ, "RESULT": result, "TESTS": tests}).returncode
            self.assertEqual(code, expected)


if __name__ == "__main__":
    unittest.main()
