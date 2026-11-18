"""Runs the PowerShell policy cases (fake gh, no network) when pwsh exists."""
from pathlib import Path
import shutil
import subprocess
import unittest

TESTS = Path(__file__).resolve().parent / "check-policy.Tests.ps1"


@unittest.skipUnless(shutil.which("pwsh"), "pwsh is required")
class CheckPolicyTests(unittest.TestCase):
    def test_policy_cases_pass(self):
        result = subprocess.run(
            ["pwsh", "-NoProfile", "-File", str(TESTS)],
            capture_output=True, text=True, timeout=600,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("PASS: fake gh script policy cases and mutation refusal", result.stdout)


if __name__ == "__main__":
    unittest.main()
