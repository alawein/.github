"""The repos.md exceptions table and repo-exceptions.json name the same repos."""
from pathlib import Path
import json
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def table_repos() -> set[str]:
    text = (ROOT / "docs/system/repos.md").read_text(encoding="utf-8")
    section = text.split("### Recorded exceptions", 1)[1].split("\n## ", 1)[0]
    rows = [line for line in section.splitlines() if line.startswith("| `")]
    return {name for row in rows for name in re.findall(r"`([^`]+)`", row.split("|")[1])}


class RepoExceptionsTests(unittest.TestCase):
    def test_table_and_file_name_the_same_repos(self):
        doc = json.loads((ROOT / "docs/system/repo-exceptions.json").read_text(encoding="utf-8"))
        self.assertEqual(doc["schema"], 1)
        in_file = {e["repo"].removeprefix("alawein/") for e in doc["exceptions"]}
        self.assertEqual(table_repos(), in_file)
        self.assertEqual(len(in_file), len(doc["exceptions"]), "a repo is listed twice")
        for e in doc["exceptions"]:
            self.assertTrue(e["checks"], e["repo"])
            self.assertRegex(e["decided"], r"^\d{4}-\d{2}-\d{2}$")


if __name__ == "__main__":
    unittest.main()
