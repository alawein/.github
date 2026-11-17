"""Language CI reusables expose an optional runner label input."""
from pathlib import Path
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1]

# Fork pull requests always fall back to the GitHub-hosted default so a caller's
# self-hosted label can never run fork code on the Railway pool.
FORK_GUARDED_RUNS_ON = (
    "${{ github.event.pull_request.head.repo.fork && 'ubuntu-24.04' || inputs.runner }}"
)


def workflow(name: str):
    return yaml.safe_load((ROOT / ".github/workflows" / name).read_text(encoding="utf-8"))


class RunnerInputTests(unittest.TestCase):
    def assert_runner_input(self, name: str):
        data = workflow(name)
        # PyYAML 1.1 loads the workflow `on:` key as True.
        self.assertEqual(
            data[True]["workflow_call"]["inputs"]["runner"]["default"],
            "ubuntu-24.04",
        )
        self.assertEqual(data["jobs"]["ci"]["runs-on"], FORK_GUARDED_RUNS_ON)

    def test_node_ci_default_runner_is_ubuntu_2404(self):
        self.assert_runner_input("node-ci.yml")

    def test_python_ci_default_runner_is_ubuntu_2404(self):
        self.assert_runner_input("python-ci.yml")

    def test_fork_fallback_matches_input_default(self):
        for name in ("node-ci.yml", "python-ci.yml"):
            default = workflow(name)[True]["workflow_call"]["inputs"]["runner"]["default"]
            self.assertIn(f"'{default}'", workflow(name)["jobs"]["ci"]["runs-on"], name)


class RailwayImageTests(unittest.TestCase):
    def test_image_installs_pinned_verified_powershell(self):
        text = (ROOT / "runners/github-actions-railway/Dockerfile").read_text(encoding="utf-8")
        self.assertRegex(text, r"ARG PWSH_VERSION=\d+\.\d+\.\d+\n")
        self.assertRegex(text, r"ARG PWSH_SHA256=[0-9a-f]{64}\n")
        self.assertIn("sha256sum -c", text)
        self.assertIn("ln -s /opt/microsoft/powershell/7/pwsh /usr/local/bin/pwsh", text)


class RailwayProbeTests(unittest.TestCase):
    def setUp(self):
        self.job = workflow("ci.yml")["jobs"]["metadata-tests-railway"]

    def test_probe_job_runs_on_railway(self):
        self.assertEqual(self.job["runs-on"], ["self-hosted", "railway", "ephemeral"])

    def test_probe_job_skips_forks(self):
        self.assertIn("github.event.pull_request.head.repo.fork != true", self.job["if"])

    def test_probe_job_is_not_required(self):
        self.assertIs(self.job["continue-on-error"], True)
        for ruleset in (ROOT / "rulesets").glob("*.json"):
            self.assertNotIn("metadata-tests-railway", ruleset.read_text(encoding="utf-8"), ruleset.name)


if __name__ == "__main__":
    unittest.main()
