import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
POINTER = "docs/system/repos.md#stack-conventions"


class StarterGovernanceTests(unittest.TestCase):
    def test_generated_tools_point_to_stack_conventions(self):
        shell = shutil.which("pwsh")
        if shell is None:
            self.skipTest("PowerShell is required for the real starter generator")
        for language in ["python", "typescript"]:
            with self.subTest(language=language), tempfile.TemporaryDirectory() as temporary:
                name = f"scope-{language}"
                result = subprocess.run(
                    [shell, "-NoProfile", "-File", str(ROOT / "scripts/new-repo.ps1"),
                     "-Name", name, "-Class", "tool", "-Language", language,
                     "-Description", "Inspect supplied records.",
                     "-Path", temporary, "-Create"],
                    cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                    errors="replace", check=False, timeout=30,
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                output = Path(temporary) / name
                guide = (output / "AGENTS.md").read_text(encoding="utf-8")
                self.assertIn(POINTER, guide)
                self.assertNotIn("C:/Users/", guide)
                self.assertFalse((output / ".git").exists())
                self.assertFalse((output / ".husky").exists())
                if language == "python":
                    self.assertTrue((output / "src/scope_python/__init__.py").exists())
                else:
                    self.assertTrue((output / "src/index.ts").exists())
                    self.assertTrue((output / "eslint.config.js").exists())

    def test_all_starter_instruction_files_point_to_the_same_owner(self):
        paths = [ROOT / "templates/agent/AGENTS.template.md"]
        paths.extend(
            ROOT / "templates/starters" / kind / "AGENTS.md"
            for kind in ["docs", "typescript", "python", "site", "lab"]
        )
        for path in paths:
            with self.subTest(path=path):
                text = path.read_text(encoding="utf-8")
                self.assertEqual(text.count(POINTER), 1)
