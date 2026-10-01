"""Exercise the commands embedded in the reusable workflow files."""

import json
import os
import platform
import subprocess
import tempfile
import unittest
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[1]
NODE_DIR = os.environ.get("NODE22_DIR")
BASH = Path(r"C:\Program Files\Git\bin\bash.exe") if platform.system() == "Windows" else Path("/bin/bash")


def workflow(name):
    return yaml.safe_load((ROOT / ".github" / "workflows" / name).read_text(encoding="utf-8"))


def step(name):
    return next((s for s in workflow("node-ci.yml")["jobs"]["ci"]["steps"] if s.get("name") == name), None)


class NodeGateTests(unittest.TestCase):
    def run_step(self, manifest, run_test="true", name="Require a runnable test script"):
        self.assertIsNotNone(step(name), f"missing {name} step")
        with tempfile.TemporaryDirectory() as directory:
            Path(directory, "package.json").write_text(manifest, encoding="utf-8")
            env = {**os.environ, "RUN_TEST": run_test}
            if NODE_DIR:
                env["PATH"] = NODE_DIR + os.pathsep + env["PATH"]
            return subprocess.run([str(BASH), "-c", step(name)["run"]], cwd=directory, env=env, capture_output=True, text=True)

    def test_required_test_explains_missing_and_blank_scripts(self):
        for manifest in ['{"scripts":{}}', '{"scripts":{"test":""}}', '{"scripts":{"test":"  "}}']:
            with self.subTest(manifest=manifest):
                result = self.run_step(manifest)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("::error::", result.stderr)
                for detail in ["package.json", "nonempty", "test"]:
                    self.assertIn(detail, result.stderr.lower())

    def test_required_test_explains_conflicting_execution_inputs(self):
        result = self.run_step('{"scripts":{"test":"node -e \'process.exit(0)\'"}}', "false")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("::error::", result.stderr)
        self.assertIn("require-test: true", result.stderr)
        self.assertIn("run-test: true", result.stderr)

    def test_required_test_accepts_runnable_script(self):
        result = self.run_step('{"scripts":{"test":"node -e \'process.exit(0)\'"}}')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_actual_test_step_propagates_failure_and_skips_only_when_optional(self):
        self.assertEqual(step("Test")["run"], "npm test --if-present")
        # The required branch must invoke npm test without --if-present.
        self.assertIsNotNone(step("Test (required)"))
        self.assertEqual(step("Test (required)")["run"], "npm test")
        manifest = json.dumps({"scripts": {"test": 'node -e "console.log(\'KIT_F3_TEST_EXECUTED\'); process.exit(7)"'}})
        result = self.run_step(manifest, name="Test (required)")
        self.assertIn("KIT_F3_TEST_EXECUTED", result.stdout)
        self.assertEqual(result.returncode, 7, f"stdout={result.stdout!r} stderr={result.stderr!r}")


class LinkGateTests(unittest.TestCase):
    def test_reusable_links_preserve_external_checks_by_default(self):
        links = workflow("check-links.yml")
        self.assertIs(links[True]["workflow_call"]["inputs"]["offline"]["default"], False)

    def test_nightly_links_check_external_sites(self):
        self.assertTrue((ROOT / ".github" / "workflows" / "check-links-nightly.yml").exists())
        nightly = workflow("check-links-nightly.yml")
        self.assertIn("schedule", nightly[True])
        self.assertIn("workflow_dispatch", nightly[True])
        call = nightly["jobs"]["run-link-check"]
        self.assertFalse(call["with"]["offline"])


if __name__ == "__main__":
    unittest.main()
