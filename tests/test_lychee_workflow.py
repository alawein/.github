"""Run the pinned lychee CLI with each link mode from check-links.yml."""

import http.server
import os
import shlex
import subprocess
import tempfile
import threading
import unittest
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[1]
LYCHEE = os.environ.get("LYCHEE_BIN")


class Unavailable(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(503)
        self.end_headers()

    def log_message(self, *_args):
        pass


def link_args(offline):
    workflow = yaml.safe_load((ROOT / ".github/workflows/check-links.yml").read_text(encoding="utf-8"))
    action = next(s for s in workflow["jobs"]["lint"]["steps"] if "lycheeverse/lychee-action" in s.get("uses", ""))
    expression = "${{ inputs.offline && '--offline' || '--max-retries 3 --retry-wait-time 10' }}"
    args = action["with"]["args"].replace(expression, "--offline" if offline else "--max-retries 3 --retry-wait-time 10")
    return shlex.split(args.replace("${{ inputs.paths }}", "fixture.md"))


@unittest.skipUnless(LYCHEE, "set LYCHEE_BIN to the verified pinned CLI")
class LinkModes(unittest.TestCase):
    def run_lychee(self, content, offline, extra=None):
        with tempfile.TemporaryDirectory() as directory:
            Path(directory, "fixture.md").write_text(content, encoding="utf-8")
            if extra:
                Path(directory, extra).write_text("ok", encoding="utf-8")
            return subprocess.run([LYCHEE, *link_args(offline)], cwd=directory, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=90)

    def test_offline_keeps_local_validation_and_ignores_external_outage(self):
        content = "[local](target.md)\n[external](https://unreachable.invalid)\n"
        valid = self.run_lychee(content, True, "target.md")
        self.assertEqual(valid.returncode, 0, valid.stdout + valid.stderr)
        missing = self.run_lychee(content, True)
        self.assertNotEqual(missing.returncode, 0, missing.stdout + missing.stderr)
        self.assertIn("target.md", missing.stdout + missing.stderr)

    def test_external_mode_fails_on_http_503(self):
        with http.server.ThreadingHTTPServer(("127.0.0.1", 0), Unavailable) as server:
            worker = threading.Thread(target=server.serve_forever, daemon=True)
            worker.start()
            try:
                url = f"http://127.0.0.1:{server.server_port}/unavailable"
                failed = self.run_lychee(f"[external]({url})\n", False)
                self.assertNotEqual(failed.returncode, 0, failed.stdout + failed.stderr)
                self.assertIn("503", failed.stdout + failed.stderr)
            finally:
                server.shutdown()
                worker.join()


if __name__ == "__main__":
    unittest.main()
