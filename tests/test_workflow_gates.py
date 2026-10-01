"""Exercise the commands embedded in the reusable workflow files."""

import json
import os
import platform
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[1]
NODE_DIR = os.environ.get("NODE22_DIR")
LEGACY_SHA = "6f6dbe7f3a23ab830a32007bb52b83fd1bb40563"
RELEASE_SHA = "b5f8bc3a916b41e22e5e09ec72f34c01428c2933"
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


class DistributedGateTests(unittest.TestCase):
    def assert_paired_workflows(self, directory, code=False):
        ci = yaml.safe_load((directory / "ci.yml").read_text(encoding="utf-8"))
        links = ci["jobs"]["run-link-check"]
        self.assertIs(links["with"]["offline"], True)
        nightly = yaml.safe_load((directory / "check-links-nightly.yml").read_text(encoding="utf-8"))
        self.assertIn("schedule", nightly[True])
        self.assertIn("workflow_dispatch", nightly[True])
        external = nightly["jobs"]["run-link-check"]
        self.assertIs(external["with"]["offline"], False)
        self.assertEqual(links["uses"], external["uses"])
        if code:
            self.assertIs(ci["jobs"]["run-node-ci"]["with"]["require-test"], True)
            self.assertIs(ci["jobs"]["run-node-ci"]["with"]["run-test"], True)

    def test_distributed_stubs_pair_offline_and_external_checks(self):
        for stub in ["docs", "node", "python", "site"]:
            with self.subTest(stub=stub):
                with tempfile.TemporaryDirectory() as temporary:
                    directory = Path(temporary)
                    (directory / "ci.yml").write_bytes((ROOT / "templates/workflows" / f"{stub}.yml").read_bytes())
                    (directory / "check-links-nightly.yml").write_bytes((ROOT / "templates/workflows/check-links-nightly.yml").read_bytes())
                    self.assert_paired_workflows(directory, code=stub in ["node", "site"])

    def test_actual_generated_starters_receive_complete_check_pairs(self):
        variants = [("contract-docs", "docs", "typescript"), ("alawein", "profile", "typescript"),
                    ("contract-node", "tool", "typescript"), ("contract-python", "tool", "python"),
                    ("contract-site", "site", "typescript"), ("contract-lab", "lab", "typescript")]
        for name, repo_class, language in variants:
            with self.subTest(repo_class=repo_class, language=language):
                with tempfile.TemporaryDirectory() as temporary:
                    generated = subprocess.run(["pwsh", "-NoProfile", "-File", str(ROOT / "scripts/new-repo.ps1"),
                                                "-Name", name, "-Class", repo_class, "-Language", language,
                                                "-Path", temporary, "-Create"], capture_output=True, text=True)
                    self.assertEqual(generated.returncode, 0, generated.stderr)
                    self.assert_paired_workflows(Path(temporary) / name / ".github/workflows",
                                                 code=repo_class == "site" or (repo_class == "tool" and language == "typescript"))
                    directory = Path(temporary) / name / ".github/workflows"
                    ci = yaml.safe_load((directory / "ci.yml").read_text(encoding="utf-8"))
                    gates = {"markdown-lint", "link-check", "actionlint", "pr-title"}
                    if repo_class == "site" or (repo_class == "tool" and language == "typescript"):
                        gates.add("node-ci")
                    if repo_class == "lab" or (repo_class == "tool" and language == "python"):
                        gates.add("python-ci")
                    self.assertEqual(set(ci["jobs"]), gates | {"run-" + gate for gate in gates})
                    for job in ci["jobs"].values():
                        if "uses" in job:
                            self.assertTrue(job["uses"].endswith("@" + LEGACY_SHA))
                    self.assertEqual({path.name for path in directory.iterdir()}, {"ci.yml", "check-links-nightly.yml"})

    def test_manual_opt_in_assembles_generated_consumers_without_replacing_jobs(self):
        actionlint = os.environ.get("ACTIONLINT") or shutil.which("actionlint")
        self.assertTrue(actionlint, "actionlint is required for assembled consumer verification")
        fragment = yaml.safe_load((ROOT / "templates/workflows/pr-policy.jobs.yml").read_text(encoding="utf-8"))
        self.assertEqual(set(fragment), {"run-pr-policy", "pr-policy"}, "fragment must be merged under jobs")
        for repo_class, language, language_gate in (("docs", "typescript", None), ("tool", "typescript", "node-ci"), ("tool", "python", "python-ci")):
            with self.subTest(repo_class=repo_class, language=language), tempfile.TemporaryDirectory() as temporary:
                name = "contract-optin-docs" if repo_class == "docs" else "contract-optin"
                generated = subprocess.run(["pwsh", "-NoProfile", "-File", str(ROOT / "scripts/new-repo.ps1"),
                                            "-Name", name, "-Class", repo_class, "-Language", language,
                                            "-Path", temporary, "-Create"], capture_output=True, text=True)
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                directory = Path(temporary) / name / ".github/workflows"
                ci_path = directory / "ci.yml"
                ci = yaml.safe_load(ci_path.read_text(encoding="utf-8"))
                original_jobs = dict(ci["jobs"])
                ci["jobs"].update(fragment)
                ci[True]["pull_request"]["types"] += ["ready_for_review", "converted_to_draft"]
                # PyYAML 1.1 reads 'on' as true; restore the workflow key when emitting YAML.
                ci["on"] = ci.pop(True)
                ci_path.write_text(yaml.safe_dump(ci, sort_keys=False), encoding="utf-8")
                hygiene = yaml.safe_load((ROOT / "templates/workflows/hygiene-weekly.yml").read_text(encoding="utf-8"))
                checks = "markdown-lint,link-check,actionlint,pr-title"
                if language_gate:
                    checks += "," + language_gate
                hygiene["jobs"]["hygiene"]["with"]["expected-required-checks"] = checks
                hygiene["on"] = hygiene.pop(True)
                (directory / "hygiene-weekly.yml").write_text(yaml.safe_dump(hygiene, sort_keys=False), encoding="utf-8")
                for name, job in original_jobs.items():
                    self.assertEqual(ci["jobs"][name], job)
                self.assertEqual(ci["jobs"]["run-pr-policy"]["with"]["kit-ref"], RELEASE_SHA)
                self.assertEqual(ci["jobs"]["pr-policy"]["permissions"], {})
                self.assertEqual(ci["permissions"], {"contents": "read"})
                self.assertEqual(hygiene["jobs"]["hygiene"]["with"], {"expected-required-checks": checks})
                lint = subprocess.run([actionlint, "-shellcheck=", "-pyflakes=", *map(str, sorted(directory.glob("*.yml")))],
                                      capture_output=True, text=True)
                self.assertEqual(lint.returncode, 0, lint.stdout + lint.stderr)


if __name__ == "__main__":
    unittest.main()
