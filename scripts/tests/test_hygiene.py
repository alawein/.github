"""Read-only audit fixtures include incomplete data, pagination and commit age."""
import copy
from datetime import datetime, timezone
import importlib.util
from pathlib import Path
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "audit-hygiene.py"
REPO = "owner/repo"
ROOT = "repos/" + REPO
CHECKS = ["markdown-lint", "link-check", "actionlint", "pr-title"]


def load():
    spec = importlib.util.spec_from_file_location("hygiene", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.audit


def fixture():
    rules = [{"type": kind} for kind in ("deletion", "non_fast_forward", "required_signatures", "required_linear_history", "pull_request")]
    rules.append({"type": "required_status_checks", "parameters": {"required_status_checks": [{"context": name} for name in CHECKS]}})
    return {ROOT: {"default_branch": "main", "allow_squash_merge": True, "allow_merge_commit": False, "allow_rebase_merge": False},
            ROOT + "/rules/branches/main?per_page=100&page=1": rules,
            ROOT + "/rulesets?includes_parents=true&per_page=100&page=1": [{"id": 1, "enforcement": "active"}],
            ROOT + "/rulesets/1?includes_parents=true": {"enforcement": "active", "bypass_actors": []},
            ROOT + "/pulls?state=open&per_page=100&page=1": [],
            ROOT + "/branches?per_page=100&page=1": [{"name": "main", "commit": {"sha": "a" * 40}}]}


class HygieneTests(unittest.TestCase):
    def setUp(self):
        self.audit = load()
        self.data = fixture()
        self.calls = []

    def fetch(self, path):
        self.calls.append(path)
        value = self.data[path]
        if isinstance(value, Exception):
            raise value
        return copy.deepcopy(value)

    def test_observed_complete_state_is_pass(self):
        result = self.audit(self.fetch, REPO)
        self.assertEqual(result["status"], "PASS")
        self.assertEqual(result["observed"]["bypass_actors"], [])
        self.assertEqual(result["observed"]["ready_prs"], 0)

    def test_second_page_changes_ready_count(self):
        self.data[ROOT + "/pulls?state=open&per_page=100&page=1"] = [
            {"number": n, "draft": True, "head": {"ref": "feat/topic", "repo": {"full_name": REPO}}} for n in range(1, 101)]
        self.data[ROOT + "/pulls?state=open&per_page=100&page=2"] = [
            {"number": 101, "draft": False, "head": {"ref": "fix/ready", "repo": {"full_name": REPO}}}]
        result = self.audit(self.fetch, REPO)
        self.assertEqual(result["observed"]["ready_prs"], 1)
        self.assertIn(ROOT + "/pulls?state=open&per_page=100&page=2", self.calls)

    def test_denied_effective_rules_are_unknown(self):
        self.data[ROOT + "/rules/branches/main?per_page=100&page=1"] = PermissionError("denied")
        result = self.audit(self.fetch, REPO)
        self.assertEqual(result["status"], "UNKNOWN")
        self.assertIsNone(result["observed"]["effective_rules"])
        self.assertTrue(result["unknown"])

    def test_observed_no_rules_is_warning_not_unknown(self):
        self.data[ROOT + "/rules/branches/main?per_page=100&page=1"] = []
        result = self.audit(self.fetch, REPO)
        self.assertEqual(result["status"], "WARN")
        self.assertEqual(result["observed"]["effective_rules"], [])
        self.assertTrue(result["findings"])

    def test_denied_ruleset_details_never_prove_zero_bypass(self):
        self.data[ROOT + "/rulesets/1?includes_parents=true"] = PermissionError("denied")
        result = self.audit(self.fetch, REPO)
        self.assertEqual(result["status"], "UNKNOWN")
        self.assertIsNone(result["observed"]["bypass_actors"])

    def test_partial_pagination_never_reports_complete_count(self):
        self.data[ROOT + "/pulls?state=open&per_page=100&page=1"] = [
            {"number": n, "draft": False, "head": {"ref": "feat/topic", "repo": {"full_name": REPO}}} for n in range(1, 101)]
        self.data[ROOT + "/pulls?state=open&per_page=100&page=2"] = PermissionError("denied")
        result = self.audit(self.fetch, REPO)
        self.assertEqual(result["status"], "UNKNOWN")
        self.assertIsNone(result["observed"]["ready_prs"])
        self.assertIsNone(result["observed"]["orphan_branches"])

    def test_last_commit_age_identifies_orphan_not_branch_creation(self):
        self.data[ROOT + "/branches?per_page=100&page=1"].extend([
            {"name": "feat/old", "created_at": "2026-10-01T00:00:00Z", "commit": {"sha": "b" * 40}},
            {"name": "feat/fresh", "created_at": "2000-01-01T00:00:00Z", "commit": {"sha": "c" * 40}}])
        self.data[ROOT + "/commits/" + "b" * 40] = {"commit": {"committer": {"date": "2026-08-01T00:00:00Z"}}}
        self.data[ROOT + "/commits/" + "c" * 40] = {"commit": {"committer": {"date": "2026-10-01T00:00:00Z"}}}
        result = self.audit(self.fetch, REPO, now=datetime(2026, 10, 1, tzinfo=timezone.utc))
        self.assertEqual([item["branch"] for item in result["observed"]["orphan_branches"]], ["feat/old"])

    def test_open_pr_branch_is_not_orphan(self):
        self.data[ROOT + "/pulls?state=open&per_page=100&page=1"] = [
            {"number": 1, "draft": True, "head": {"ref": "feat/old", "repo": {"full_name": REPO}}}]
        self.data[ROOT + "/branches?per_page=100&page=1"].append({"name": "feat/old", "commit": {"sha": "b" * 40}})
        self.assertEqual(self.audit(self.fetch, REPO)["observed"]["orphan_branches"], [])
        self.assertNotIn(ROOT + "/commits/" + "b" * 40, self.calls)

    def test_drift_and_wip_are_findings(self):
        self.data[ROOT]["allow_merge_commit"] = True
        self.data[ROOT + "/rulesets/1?includes_parents=true"]["bypass_actors"] = [{"actor_id": 1}]
        self.data[ROOT + "/pulls?state=open&per_page=100&page=1"] = [
            {"number": n, "draft": False, "head": {"ref": "feat/topic", "repo": {"full_name": REPO}}} for n in range(4)]
        result = self.audit(self.fetch, REPO)
        self.assertEqual(result["status"], "WARN")
        self.assertGreaterEqual(len(result["findings"]), 3)

    def test_missing_fields_never_become_pass(self):
        for path, value in ((ROOT, {}), (ROOT + "/pulls?state=open&per_page=100&page=1", [{}]),
                            (ROOT + "/rulesets/1?includes_parents=true", {}),
                            (ROOT + "/branches?per_page=100&page=1", [{}])):
            with self.subTest(path=path):
                previous = self.data[path]
                self.data[path] = value
                self.assertEqual(self.audit(self.fetch, REPO)["status"], "UNKNOWN")
                self.data[path] = previous

    def test_expected_checks_are_configurable(self):
        result = self.audit(self.fetch, REPO, required_checks=CHECKS + ["pr-policy"])
        self.assertEqual(result["status"], "WARN")
        self.assertTrue(any("pr-policy" in finding for finding in result["findings"]))

    def test_repository_input_cannot_change_endpoint_scope(self):
        for repository in ("owner/repo/../../x", "https://github.com/owner/repo", "owner/repo?x=1", "owner/..", "../repo"):
            self.assertEqual(self.audit(self.fetch, repository)["status"], "UNKNOWN")
        self.assertEqual(self.calls, [])

    def test_second_page_rulesets_and_branches_are_observed(self):
        self.data[ROOT + "/rulesets?includes_parents=true&per_page=100&page=1"] = [
            {"id": n, "enforcement": "disabled"} for n in range(100)]
        self.data[ROOT + "/rulesets?includes_parents=true&per_page=100&page=2"] = [{"id": 101, "enforcement": "active"}]
        self.data[ROOT + "/rulesets/101?includes_parents=true"] = {"enforcement": "active", "bypass_actors": [{"actor_id": 123}]}
        self.data[ROOT + "/branches?per_page=100&page=1"] = [{"name": "main"} for n in range(100)]
        self.data[ROOT + "/branches?per_page=100&page=2"] = [{"name": "feat/old", "commit": {"sha": "b" * 40}}]
        self.data[ROOT + "/commits/" + "b" * 40] = {"commit": {"committer": {"date": "2026-08-01T00:00:00Z"}}}
        result = self.audit(self.fetch, REPO, now=datetime(2026, 10, 1, tzinfo=timezone.utc))
        self.assertEqual(result["observed"]["bypass_actors"], [{"ruleset_id": 101, "actor_id": 123}])
        self.assertEqual(result["observed"]["orphan_branches"][0]["branch"], "feat/old")
        self.assertEqual(result["status"], "WARN")

    def test_denied_commit_age_is_unknown(self):
        self.data[ROOT + "/branches?per_page=100&page=1"].append({"name": "feat/old", "commit": {"sha": "b" * 40}})
        self.data[ROOT + "/commits/" + "b" * 40] = PermissionError("denied")
        result = self.audit(self.fetch, REPO)
        self.assertIsNone(result["observed"]["orphan_branches"])
        self.assertEqual(result["status"], "UNKNOWN")


if __name__ == "__main__":
    unittest.main()
