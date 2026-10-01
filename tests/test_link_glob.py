"""Exercise workflow path inputs through lychee-action's Bash eval boundary."""

import os
import platform
import subprocess
import tempfile
import unittest
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[1]
BASH = Path(r"C:\Program Files\Git\bin\bash.exe") if platform.system() == "Windows" else Path("/bin/bash")
LYCHEE = os.environ.get("LYCHEE_BIN")

# The pinned action evaluates the assembled argument string with globstar off.
ACTION_EVAL = """
set -uo pipefail
shopt -u globstar
export PATH="$PWD/bin:$PATH"
chmod +x bin/lychee
CHECKBOX=""
FORMAT="--format markdown"
LYCHEE_TMP=summary.md
ARGS="${INPUT_ARGS}"
eval lychee ${CHECKBOX} ${FORMAT} --output ${LYCHEE_TMP} ${ARGS}
"""


def workflow_args(paths=None):
    workflow = yaml.safe_load((ROOT / ".github/workflows/check-links.yml").read_text(encoding="utf-8"))
    inputs = workflow[True]["workflow_call"]["inputs"]
    action = next(step for step in workflow["jobs"]["lint"]["steps"] if "lycheeverse/lychee-action" in step.get("uses", ""))
    expression = "${{ inputs.offline && '--offline' || '--max-retries 3 --retry-wait-time 10' }}"
    return action["with"]["args"].replace(expression, "--offline").replace("${{ inputs.paths }}", inputs["paths"]["default"] if paths is None else paths)


def fixture(directory):
    (directory / "docs/policy").mkdir(parents=True)
    (directory / "README.md").write_text("[root](root-target.txt)\n", encoding="utf-8")
    (directory / "docs/lessons.md").write_text("No links here.\n", encoding="utf-8")
    (directory / "docs/policy/deep.md").write_text("[deep](deep-target.txt)\n", encoding="utf-8")
    (directory / "bin").mkdir()


def run_action(directory, executable, paths=None):
    (directory / "bin/lychee").write_text(executable, encoding="utf-8")
    env = {**os.environ, "INPUT_ARGS": workflow_args(paths)}
    if LYCHEE:
        env["LYCHEE_BIN"] = LYCHEE.replace("\\", "/")
    return subprocess.run([str(BASH), "-c", ACTION_EVAL], cwd=directory, env=env, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=30)


class GlobArgumentTests(unittest.TestCase):
    def arguments(self, paths=None):
        with tempfile.TemporaryDirectory(prefix="kit-link-argv-") as temporary:
            directory = Path(temporary)
            fixture(directory)
            result = run_action(directory, '#!/bin/bash\nprintf "%s\\0" "$@" > argv.bin\n', paths)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            return (directory / "argv.bin").read_bytes().decode().rstrip("\0").split("\0")

    def test_default_recursive_glob_reaches_lychee_without_shell_expansion(self):
        self.assertEqual(self.arguments(), ["--format", "markdown", "--output", "summary.md", "--no-progress", "--verbose", "--offline", "--accept", "200..=299", "./**/*.md"])

    def test_custom_paths_keep_multiple_patterns_and_spaces(self):
        self.assertEqual(self.arguments("'./README.md' './docs/**/*.md' 'notes with spaces.md'"), ["--format", "markdown", "--output", "summary.md", "--no-progress", "--verbose", "--offline", "--accept", "200..=299", "./README.md", "./docs/**/*.md", "notes with spaces.md"])


@unittest.skipUnless(LYCHEE, "set LYCHEE_BIN to the verified pinned CLI")
class RecursiveLinkTests(unittest.TestCase):
    def test_default_scan_detects_broken_root_and_nested_links(self):
        native_cli = '#!/bin/bash\nexport MSYS2_ARG_CONV_EXCL="*"\nexec "$LYCHEE_BIN" "$@"\n'
        with tempfile.TemporaryDirectory(prefix="kit-link-scan-") as temporary:
            directory = Path(temporary)
            fixture(directory)
            broken = run_action(directory, native_cli)
            self.assertNotEqual(broken.returncode, 0, broken.stdout + broken.stderr)
            self.assertIn("root-target.txt", broken.stdout + broken.stderr)
            self.assertIn("deep-target.txt", broken.stdout + broken.stderr)
            (directory / "root-target.txt").write_text("ok\n", encoding="utf-8")
            (directory / "docs/policy/deep-target.txt").write_text("ok\n", encoding="utf-8")
            repaired = run_action(directory, native_cli)
            self.assertEqual(repaired.returncode, 0, repaired.stdout + repaired.stderr)


if __name__ == "__main__":
    unittest.main()
