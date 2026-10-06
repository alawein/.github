"""Runs the PowerShell repo-sweep tests (temp git repos, no network) when pwsh and git exist."""
from pathlib import Path
import shutil
import subprocess
import unittest

TESTS = Path(__file__).resolve().parent / "repo-sweep.Tests.ps1"


@unittest.skipUnless(shutil.which("pwsh") and shutil.which("git"), "pwsh and git are required")
class RepoSweepTests(unittest.TestCase):
    def test_status_and_clean_behave(self):
        result = subprocess.run(
            ["pwsh", "-NoProfile", "-File", str(TESTS)],
            capture_output=True, text=True, timeout=600,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("PASS: repo-sweep tests", result.stdout)


if __name__ == "__main__":
    unittest.main()
