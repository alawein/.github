"""Language CI reusables expose an optional runner label input."""
from pathlib import Path
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1]


def workflow(name: str):
    return yaml.safe_load((ROOT / ".github/workflows" / name).read_text(encoding="utf-8"))


class RunnerInputTests(unittest.TestCase):
    def test_node_ci_default_runner_is_ubuntu_2404(self):
        data = workflow("node-ci.yml")
        # PyYAML 1.1 loads the workflow `on:` key as True.
        self.assertEqual(
            data[True]["workflow_call"]["inputs"]["runner"]["default"],
            "ubuntu-24.04",
        )
        self.assertEqual(data["jobs"]["ci"]["runs-on"], "${{ inputs.runner }}")

    def test_python_ci_default_runner_is_ubuntu_2404(self):
        data = workflow("python-ci.yml")
        self.assertEqual(
            data[True]["workflow_call"]["inputs"]["runner"]["default"],
            "ubuntu-24.04",
        )
        self.assertEqual(data["jobs"]["ci"]["runs-on"], "${{ inputs.runner }}")


if __name__ == "__main__":
    unittest.main()
