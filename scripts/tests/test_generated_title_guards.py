"""Run PR-title guards from real generator outputs, including the profile alias."""

import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
BASH = (str(Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Git/bin/bash.exe")
        if os.name == "nt" else shutil.which("bash"))
VARIANTS = (
    ("guard-docs", "docs", "typescript"),
    ("alawein", "profile", "typescript"),
    ("guard-node", "tool", "typescript"),
    ("guard-python", "tool", "python"),
    ("guard-site", "site", "typescript"),
    ("guard-lab", "lab", "typescript"),
)


class GeneratedTitleGuardTests(unittest.TestCase):
    def test_generated_guards_reject_skips_except_actual_main_push(self):
        self.assertIsNotNone(shutil.which("pwsh"), "generator tests require PowerShell")
        # Reintroducing unconditional skip acceptance must fail for each output.
        for name, repo_class, language in VARIANTS:
            with tempfile.TemporaryDirectory() as temporary:
                generated = subprocess.run(
                    ["pwsh", "-NoProfile", "-File", str(ROOT / "scripts/new-repo.ps1"),
                     "-Name", name, "-Class", repo_class, "-Language", language,
                     "-Path", temporary, "-Create"], capture_output=True, text=True,
                    timeout=60,
                )
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                text = (Path(temporary) / name / ".github/workflows/ci.yml").read_text(encoding="utf-8")
                self.assertIn("\n  pr-title:\n", text)
                job = re.split(r"\n  [\w-]+:\n", text.split("\n  pr-title:\n", 1)[1], maxsplit=1)[0]
                script = job.split("        run:", 1)[1].strip()
                if script.startswith("|"):
                    script = "\n".join(line[10:] for line in script[1:].splitlines() if line.startswith("          "))
                else:
                    script = script.strip("'")
                bindings = re.findall(r"^          (\w+): \$\{\{ (.*?) \}\}$", job, re.M)
                for event, ref in (
                    ("pull_request", "refs/pull/1/merge"),
                    ("pull_request", "refs/heads/main"),
                    ("push", "refs/heads/main"),
                    ("workflow_dispatch", "refs/heads/main"),
                    ("push", "refs/heads/topic"),
                    ("merge_group", "refs/heads/main"),
                ):
                    # Literal expectations independent of the guard implementation.
                    cases = (("success", 0), ("failure", 1), ("cancelled", 1), ("", 1),
                             ("skipped", 0 if (event, ref) == ("push", "refs/heads/main") else 1))
                    for result, expected in cases:
                        with self.subTest(repo_class=repo_class, language=language,
                                          event=event, ref=ref, result=result):
                            context = {"needs.run-pr-title.result": result,
                                       "github.event_name": event, "github.ref": ref}
                            # Bind exactly the generated step's environment. Missing or
                            # wrong EVENT/REF wiring cannot be hidden by the test harness.
                            env = {k: v for k, v in os.environ.items() if k not in ("RESULT", "EVENT", "REF")}
                            env.update({key: context[expression] for key, expression in bindings})
                            code = subprocess.run([BASH, "--noprofile", "--norc", "-e", "-c", script],
                                                  env=env, capture_output=True, text=True, timeout=10).returncode
                            self.assertEqual(code, expected)


if __name__ == "__main__":
    unittest.main()
