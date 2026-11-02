"""Site naming, host split, and generator preservation."""

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SHELL = shutil.which("pwsh")


def run_new_repo(tmp: Path, name: str, repo_class: str, create: bool = False) -> subprocess.CompletedProcess[str]:
    command = [
        SHELL, "-NoProfile", "-File", str(ROOT / "scripts/new-repo.ps1"),
        "-Name", name, "-Class", repo_class,
        "-Description", "A directory of referral programs.",
        "-Path", str(tmp),
    ]
    if create:
        command.append("-Create")
    return subprocess.run(command, cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                          errors="replace", check=False, timeout=60)


@unittest.skipUnless(SHELL, "PowerShell is required")
class SiteScaffoldTests(unittest.TestCase):
    def test_starter_declares_astro_check_peers(self):
        package = (ROOT / "templates/starters/site/package.json").read_text(encoding="utf-8")
        self.assertIn('"@emnapi/core"', package)
        self.assertIn('"@emnapi/runtime"', package)

    def test_product_site_name_is_previewed_without_a_host(self):
        with tempfile.TemporaryDirectory() as temporary:
            result = run_new_repo(Path(temporary), "referrals", "site")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("DRY RUN", result.stdout)
            self.assertNotIn("vercel.json", result.stdout)
            self.assertEqual(list(Path(temporary).iterdir()), [])

    def test_unrelated_suffix_rules_stay(self):
        cases = (
            ("widget-site", "tool", "class site"),
            ("notes", "docs", "-docs or -kit"),
            ("sandbox", "lab", "-lab"),
            ("guide-docs", "site", "class docs"),
        )
        with tempfile.TemporaryDirectory() as temporary:
            for name, repo_class, expected in cases:
                with self.subTest(name=name, repo_class=repo_class):
                    result = run_new_repo(Path(temporary), name, repo_class)
                    self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                    self.assertIn(expected, result.stdout + result.stderr)
                    self.assertFalse((Path(temporary) / name).exists())

    def test_generated_site_has_no_host_and_preserves_an_existing_tree(self):
        with tempfile.TemporaryDirectory() as temporary:
            parent = Path(temporary)
            created = run_new_repo(parent, "referrals", "site", create=True)
            self.assertEqual(created.returncode, 0, created.stdout + created.stderr)
            repo = parent / "referrals"
            config = (repo / "astro.config.mjs").read_text(encoding="utf-8")
            self.assertNotIn("vercel", config.lower())
            self.assertFalse((repo / "vercel.json").exists())
            self.assertTrue((repo / "package.json").exists())
            marker = repo / "UNRELATED.txt"
            marker.write_text("keep", encoding="utf-8")

            again = run_new_repo(parent, "referrals", "site", create=True)
            self.assertEqual(again.returncode, 1, again.stdout + again.stderr)
            self.assertEqual(marker.read_text(encoding="utf-8"), "keep")
            self.assertIn("already exists", again.stdout + again.stderr)

    def test_interrupted_folder_is_not_replaced(self):
        with tempfile.TemporaryDirectory() as temporary:
            parent = Path(temporary)
            partial = parent / "referrals"
            partial.mkdir()
            readme = partial / "README.md"
            readme.write_text("partial", encoding="utf-8")
            result = run_new_repo(parent, "referrals", "site", create=True)
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertEqual(readme.read_text(encoding="utf-8"), "partial")
            self.assertFalse((partial / "package.json").exists())


if __name__ == "__main__":
    unittest.main()
