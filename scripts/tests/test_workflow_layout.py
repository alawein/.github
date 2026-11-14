"""Run the actual PowerShell readiness function without GitHub access."""
from pathlib import Path
import shutil
import subprocess
import unittest


@unittest.skipUnless(shutil.which("pwsh"), "PowerShell is required")
class WorkflowLayoutTests(unittest.TestCase):
    def test_split_layout_and_invalid_metadata(self):
        script = Path(__file__).with_name("workflow-layout.Tests.ps1")
        result = subprocess.run(["pwsh", "-NoProfile", "-File", str(script)],
                                capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("PASS: split and legacy", result.stdout)
