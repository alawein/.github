"""One inherited-repo inspection and the smallest safe repair."""

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SHELL = shutil.which("pwsh")
GIT = shutil.which("git")
SECRET = "TOKEN=do-not-print-9f3c"


def git(repo: Path, *args: str) -> None:
    subprocess.run(["git", *args], cwd=repo, check=True, capture_output=True, text=True)


def inspect(repo: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [SHELL, "-NoProfile", "-File", str(ROOT / "scripts/inspect-inherited.ps1"), "-Path", str(repo)],
        cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace", check=False, timeout=60,
    )


@unittest.skipUnless(SHELL and GIT, "pwsh and git are required")
class InheritedRepoTests(unittest.TestCase):
    def test_inspection_refuses_execution_and_repair_stays_local(self):
        with tempfile.TemporaryDirectory() as temporary:
            repo = Path(temporary) / "inherited-sample"
            repo.mkdir()
            (repo / "add.py").write_text("def add(left, right):\n    return left - right\n", encoding="utf-8")
            (repo / "test_add.py").write_text(
                "import unittest\nfrom add import add\n\n"
                "class AddTests(unittest.TestCase):\n"
                "    def test_add(self):\n"
                "        self.assertEqual(add(2, 3), 5)\n\n"
                "if __name__ == '__main__':\n    unittest.main()\n",
                encoding="utf-8",
            )
            (repo / "NOTES.md").write_text("keep-this-sentence\n", encoding="utf-8")
            (repo / "LICENSE").write_text("MIT\n", encoding="utf-8")
            (repo / ".env").write_text(SECRET + "\n", encoding="utf-8")
            (repo / "vercel.json").write_text("{}\n", encoding="utf-8")
            (repo / "package.json").write_text(
                '{"name":"inherited-sample","scripts":{"preinstall":"echo refused"}}\n',
                encoding="utf-8",
            )
            git(repo, "init")
            git(repo, "config", "user.email", "fixture@example.invalid")
            git(repo, "config", "user.name", "Fixture")
            git(repo, "add", "add.py", "test_add.py", "NOTES.md", "LICENSE", "package.json", "vercel.json")
            git(repo, "commit", "-m", "starting revision")
            starting = subprocess.run(["git", "rev-parse", "HEAD"], cwd=repo, check=True, capture_output=True, text=True).stdout.strip()

            first = inspect(repo)
            second = inspect(repo)
            combined = first.stdout + first.stderr
            self.assertEqual(first.returncode, 2, combined)
            self.assertEqual(second.returncode, 2, second.stdout + second.stderr)
            self.assertIn(f"starting_revision: {starting}", combined)
            self.assertIn("license: LICENSE", combined)
            self.assertIn("lifecycle_scripts: preinstall", combined)
            self.assertIn("secret_paths: .env", combined)
            self.assertIn("deploy_files: vercel.json", combined)
            self.assertIn("repair_verified: false", combined)
            self.assertIn("relaunch_ready: false", combined)
            self.assertIn("published: false", combined)
            self.assertIn("execute: refused", combined)
            self.assertNotIn(SECRET, combined)
            self.assertFalse((repo / "ran-preinstall").exists())
            self.assertEqual((repo / "NOTES.md").read_text(encoding="utf-8"), "keep-this-sentence\n")

            baseline = subprocess.run(["python", "-m", "unittest", "test_add.py"], cwd=repo, capture_output=True, text=True)
            self.assertNotEqual(baseline.returncode, 0)
            (repo / "add.py").write_text("def add(left, right):\n    return left + right\n", encoding="utf-8")
            repaired = subprocess.run(["python", "-m", "unittest", "test_add.py"], cwd=repo, capture_output=True, text=True)
            self.assertEqual(repaired.returncode, 0, repaired.stdout + repaired.stderr)
            head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=repo, check=True, capture_output=True, text=True).stdout.strip()
            self.assertEqual(head, starting)
            self.assertEqual((repo / ".env").read_text(encoding="utf-8"), SECRET + "\n")
            remotes = subprocess.run(["git", "remote"], cwd=repo, check=True, capture_output=True, text=True).stdout.strip()
            self.assertEqual(remotes, "")


if __name__ == "__main__":
    unittest.main()
