"""python-ci can install uv via setup-uv or pip to avoid release CDN faults."""
from pathlib import Path
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1]


def python_ci():
    return yaml.safe_load((ROOT / ".github/workflows/python-ci.yml").read_text(encoding="utf-8"))


class UvInstallMethodTests(unittest.TestCase):
    def test_default_uv_install_method_is_setup_uv(self):
        data = python_ci()
        self.assertEqual(
            data[True]["workflow_call"]["inputs"]["uv-install-method"]["default"],
            "setup-uv",
        )

    def test_pip_method_steps_are_gated(self):
        steps = python_ci()["jobs"]["ci"]["steps"]
        by_name = {s.get("name"): s for s in steps if "name" in s}
        self.assertIn("Install uv via pip", by_name)
        self.assertEqual(
            by_name["Install uv via pip"]["if"],
            "inputs.installer == 'uv' && inputs.uv-install-method == 'pip'",
        )
        self.assertEqual(
            by_name["Install uv via pip"]["env"]["UV_VERSION"],
            "${{ inputs.uv-version }}",
        )
        self.assertIn("uv==${UV_VERSION}", by_name["Install uv via pip"]["run"])
        self.assertNotIn("${{ inputs.uv-version }}", by_name["Install uv via pip"]["run"])
        setup_uv = next(s for s in steps if s.get("uses", "").startswith("astral-sh/setup-uv@"))
        self.assertEqual(
            setup_uv["if"],
            "inputs.installer == 'uv' && inputs.uv-install-method == 'setup-uv'",
        )


if __name__ == "__main__":
    unittest.main()
