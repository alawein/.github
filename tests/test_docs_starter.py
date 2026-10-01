"""Run generated docs tasks to verify pinned lint and offline local links."""

import http.server
import os
import subprocess
import tempfile
import threading
import unittest
from contextlib import contextmanager
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LYCHEE = os.environ.get("LYCHEE_BIN")
NODE_DIR = os.environ.get("NODE22_DIR")


@contextmanager
def generated_docs():
    with tempfile.TemporaryDirectory(prefix="kit-docs-starter-") as temporary:
        result = subprocess.run(
            ["pwsh", "-NoProfile", "-File", str(ROOT / "scripts/new-repo.ps1"),
             "-Name", "contract-docs", "-Class", "docs", "-Path", temporary, "-Create"],
            cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=30,
        )
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)
        directory = Path(temporary) / "contract-docs"
        # Keep generated task/config files; isolate Markdown inputs from public URLs.
        for markdown in directory.rglob("*.md"):
            markdown.write_text("# Fixture\n", encoding="utf-8")
        yield directory


def run_task(directory, recipe, dry_run=False):
    env = dict(os.environ)
    additions = ([NODE_DIR] if NODE_DIR else []) + ([str(Path(LYCHEE).parent)] if LYCHEE else [])
    env["PATH"] = os.pathsep.join([*additions, env["PATH"]])
    args = ["just", "--dry-run", recipe] if dry_run else ["just", recipe]
    return subprocess.run(args, cwd=directory, env=env, capture_output=True, text=True,
                          encoding="utf-8", errors="replace", timeout=90)


class Unavailable(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.server.requests.append(self.path)
        self.send_response(503)
        self.end_headers()

    def log_message(self, *_args):
        pass


@unittest.skipUnless(LYCHEE, "set LYCHEE_BIN to the verified pinned CLI")
class GeneratedLinkTasks(unittest.TestCase):
    def test_local_check_skips_unavailable_external_links(self):
        with generated_docs() as directory:
            with http.server.ThreadingHTTPServer(("127.0.0.1", 0), Unavailable) as server:
                server.requests = []
                worker = threading.Thread(target=server.serve_forever, daemon=True)
                worker.start()
                try:
                    url = f"http://127.0.0.1:{server.server_port}/unavailable"
                    (directory / "target.txt").write_text("ok\n", encoding="utf-8")
                    (directory / "README.md").write_text(
                        f"# Fixture\n\n[local](target.txt)\n[external]({url})\n", encoding="utf-8",
                    )
                    result = run_task(directory, "test")
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertEqual(server.requests, [], "local checks must not make network requests")
                finally:
                    server.shutdown()
                    worker.join()

    def test_local_check_rejects_missing_root_and_nested_targets(self):
        with generated_docs() as directory:
            (directory / "README.md").write_text("# Fixture\n\n[root](root-target.txt)\n", encoding="utf-8")
            nested = directory / "docs/policy"
            nested.mkdir()
            (nested / "deep.md").write_text("# Fixture\n\n[deep](deep-target.txt)\n", encoding="utf-8")
            missing = run_task(directory, "test")
            self.assertNotEqual(missing.returncode, 0, missing.stdout + missing.stderr)
            self.assertIn("root-target.txt", missing.stdout + missing.stderr)
            self.assertIn("deep-target.txt", missing.stdout + missing.stderr)
            (directory / "root-target.txt").write_text("ok\n", encoding="utf-8")
            (nested / "deep-target.txt").write_text("ok\n", encoding="utf-8")
            repaired = run_task(directory, "test")
            self.assertEqual(repaired.returncode, 0, repaired.stdout + repaired.stderr)


class GeneratedMarkdownTasks(unittest.TestCase):
    def test_lint_and_fix_execute_the_exact_reviewed_runner(self):
        with generated_docs() as directory:
            for recipe in ["lint", "fix"]:
                with self.subTest(recipe=recipe):
                    result = run_task(directory, recipe)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertRegex(result.stdout + result.stderr, r"(?m)^markdownlint-cli2 v0\.23\.2(?:\s|$)")
                    command = run_task(directory, recipe, dry_run=True)
                    self.assertEqual(command.returncode, 0, command.stdout + command.stderr)
                    # A moving invocation may resolve today's version but still drift tomorrow.
                    self.assertRegex(command.stdout + command.stderr, r"(?m)^npx --yes markdownlint-cli2@0\.23\.2(?:\s|$)")


if __name__ == "__main__":
    unittest.main()
