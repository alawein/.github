"""Read-only audit fixtures include incomplete data, pagination and commit age."""
import copy
from datetime import datetime, timezone
import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest import mock

SCRIPT = Path(__file__).resolve().parents[1] / "audit-hygiene.py"
REPO = "owner/repo"
ROOT = "repos/" + REPO
CHECKS = ["markdown-lint", "link-check", "actionlint", "pr-title"]


def load_module():
    spec = importlib.util.spec_from_file_location("hygiene", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load():
    return load_module().audit


def fixture():
    rules = [{"type": kind} for kind in ("deletion", "non_fast_forward", "required_signatures", "required_linear_history", "pull_request")]
    rules.append({"type": "required_status_checks", "parameters": {"required_status_checks": [{"context": name} for name in CHECKS]}})
    return {ROOT: {"default_branch": "main", "allow_squash_merge": True, "allow_merge_commit": False, "allow_rebase_merge": False},
            ROOT + "/rules/branches/main?per_page=100&page=1": rules,
            ROOT + "/branches/main/protection": classic_fixture(False),
            ROOT + "/rulesets?includes_parents=true&per_page=100&page=1": [{"id": 1, "enforcement": "active"}],
            ROOT + "/rulesets/1?includes_parents=true": {"enforcement": "active", "bypass_actors": []},
            ROOT + "/pulls?state=open&per_page=100&page=1": [],
            ROOT + "/branches?per_page=100&page=1": [{"name": "main", "commit": {"sha": "a" * 40}}]}


def classic_fixture(protected=True):
    return {"allow_deletions": {"enabled": not protected},
            "allow_force_pushes": {"enabled": not protected},
            "required_signatures": {"enabled": protected},
            "required_linear_history": {"enabled": protected},
            "enforce_admins": {"enabled": protected},
            "required_pull_request_reviews": {"required_approving_review_count": 0} if protected else None,
            "required_status_checks": {"contexts": CHECKS + ["independent-review"],
                                       "checks": [{"context": name, "app_id": 15368} for name in CHECKS]
                                       + [{"context": "independent-review", "app_id": None}]} if protected else None}


class HygieneTests(unittest.TestCase):
    def setUp(self):
        self.module = load_module()
        self.audit = self.module.audit
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

    def test_classic_controls_are_not_lost_in_an_empty_ruleset_view(self):
        self.data[ROOT + "/rules/branches/main?per_page=100&page=1"] = []
        self.data[ROOT + "/branches/main/protection"] = classic_fixture()
        result = self.audit(self.fetch, REPO)
        self.assertEqual(result["status"], "PASS")
        self.assertIn(ROOT + "/branches/main/protection", self.calls)
        self.assertIn("independent-review", result["observed"]["classic_required_checks"])
        self.assertEqual(result["observed"]["classic_required_approvals"], 0)
        self.assertTrue(result["observed"]["classic_enforce_admins"])
        self.assertIn({"source": "classic", "context": "independent-review", "app_id": None},
                      result["observed"]["check_producers"])

    def test_unavailable_or_malformed_classic_never_proves_absence(self):
        self.data[ROOT + "/rules/branches/main?per_page=100&page=1"] = []
        for response in (PermissionError("denied"), OSError("not found"), {}, [],
                         {**classic_fixture(), "allow_deletions": {"enabled": "false"}}):
            with self.subTest(response=response):
                self.data[ROOT + "/branches/main/protection"] = response
                result = self.audit(self.fetch, REPO)
                self.assertEqual(result["status"], "UNKNOWN")
                self.assertIsNone(result["observed"]["effective_rules"])
                self.assertIsNone(result["observed"]["required_checks"])
                self.assertFalse(any("Missing effective" in f or "Missing required" in f for f in result["findings"]))

    def test_denied_ruleset_view_preserves_positive_classic_observation(self):
        self.data[ROOT + "/rules/branches/main?per_page=100&page=1"] = PermissionError("denied")
        self.data[ROOT + "/branches/main/protection"] = classic_fixture()
        result = self.audit(self.fetch, REPO)
        self.assertEqual(result["status"], "UNKNOWN")
        self.assertIn("required_signatures", result["observed"]["classic_rules"])
        self.assertIsNone(result["observed"]["effective_rules"])
        self.assertEqual(result["coverage"]["classic"]["status"], "OBSERVED")
        self.assertEqual(result["coverage"]["rulesets"]["status"], "UNKNOWN")

    def test_false_classic_flags_are_absent_but_missing_flags_are_unknown(self):
        self.data[ROOT + "/rules/branches/main?per_page=100&page=1"] = []
        self.data[ROOT + "/branches/main/protection"] = classic_fixture()
        self.data[ROOT + "/branches/main/protection"]["required_signatures"]["enabled"] = False
        result = self.audit(self.fetch, REPO)
        self.assertEqual(result["status"], "WARN")
        self.assertTrue(any("required_signatures" in f for f in result["findings"]))
        del self.data[ROOT + "/branches/main/protection"]["required_signatures"]
        self.assertEqual(self.audit(self.fetch, REPO)["status"], "UNKNOWN")

    def test_ruleset_producer_identity_is_source_labeled(self):
        checks = self.data[ROOT + "/rules/branches/main?per_page=100&page=1"][-1]["parameters"]["required_status_checks"]
        checks[0]["integration_id"] = 42
        result = self.audit(self.fetch, REPO)
        self.assertIn({"source": "rulesets", "context": CHECKS[0], "app_id": 42}, result["observed"]["check_producers"])

    def test_bad_merge_flag_types_stay_unknown(self):
        for value in (None, 0, 1, "true", "false"):
            with self.subTest(value=value):
                self.data[ROOT]["allow_squash_merge"] = value
                result = self.audit(self.fetch, REPO)
                self.assertEqual(result["status"], "UNKNOWN")
                self.assertIsNone(result["observed"]["squash_only"])

    def test_gh_get_keeps_only_status_and_message(self):
        failed = subprocess.CompletedProcess([], 1, stdout='{"message": "Branch not protected"}',
                                             stderr="gh: Branch not protected (HTTP 404)")
        with mock.patch.object(self.module.subprocess, "run", return_value=failed):
            with self.assertRaises(self.module.HttpError) as caught:
                self.module.gh_get(ROOT + "/branches/main/protection")
        self.assertEqual((caught.exception.status, caught.exception.message), (404, "Branch not protected"))
        failed = subprocess.CompletedProcess([], 1, stdout="", stderr="connection reset")
        with mock.patch.object(self.module.subprocess, "run", return_value=failed):
            with self.assertRaises(OSError) as caught:
                self.module.gh_get(ROOT)
        self.assertNotIsInstance(caught.exception, self.module.HttpError)

    def test_branch_not_protected_is_an_observed_absence(self):
        self.data[ROOT + "/branches/main/protection"] = self.module.HttpError(404, "Branch not protected")
        result = self.audit(self.fetch, REPO)
        self.assertEqual(result["status"], "PASS")
        self.assertEqual(result["coverage"]["classic"]["status"], "OBSERVED")
        self.assertEqual(result["observed"]["classic_rules"], [])
        self.assertIn("required_signatures", result["observed"]["effective_rules"])

    def test_other_not_found_classic_stays_unknown(self):
        self.data[ROOT + "/branches/main/protection"] = self.module.HttpError(404, "Not Found")
        self.assertEqual(self.audit(self.fetch, REPO)["status"], "UNKNOWN")

    def limit_token(self):
        for key in ("allow_squash_merge", "allow_merge_commit", "allow_rebase_merge"):
            del self.data[ROOT][key]
        del self.data[ROOT + "/rulesets/1?includes_parents=true"]["bypass_actors"]
        self.data[ROOT + "/branches/main/protection"] = self.module.HttpError(
            403, "Resource not accessible by integration")

    def test_token_limited_admin_fields_are_unverifiable_not_unknown(self):
        self.limit_token()
        result = self.audit(self.fetch, REPO, token_limited=True)
        self.assertEqual(result["status"], "LIMITED")
        self.assertEqual(result["unknown"], [])
        self.assertEqual(len(result["unverifiable"]), 3)
        self.assertIsNone(result["observed"]["squash_only"])
        self.assertIsNone(result["observed"]["bypass_actors"])
        self.assertEqual(result["coverage"]["classic"]["status"], "UNVERIFIABLE")

    def test_admin_field_gaps_stay_unknown_without_the_flag(self):
        self.limit_token()
        result = self.audit(self.fetch, REPO)
        self.assertEqual(result["status"], "UNKNOWN")
        self.assertEqual(result["unverifiable"], [])

    def test_token_limited_never_hides_malformed_or_failed_reads(self):
        protection = ROOT + "/branches/main/protection"
        cases = (lambda: self.data[ROOT].update(allow_squash_merge="true"),
                 lambda: self.data[ROOT + "/rulesets/1?includes_parents=true"].update(bypass_actors="none"),
                 lambda: self.data.__setitem__(protection, self.module.HttpError(502, "Bad Gateway")),
                 lambda: self.data.__setitem__(protection, OSError("timeout")))
        for index, damage in enumerate(cases):
            with self.subTest(case=index):
                self.data = fixture()
                damage()
                self.assertEqual(self.audit(self.fetch, REPO, token_limited=True)["status"], "UNKNOWN")

    def test_ruleset_gap_with_unverifiable_classic_is_not_a_pass(self):
        self.limit_token()
        rules = self.data[ROOT + "/rules/branches/main?per_page=100&page=1"]
        rules[:] = [rule for rule in rules if rule["type"] != "required_signatures"]
        result = self.audit(self.fetch, REPO, token_limited=True)
        self.assertEqual(result["status"], "LIMITED")
        self.assertTrue(any("required_signatures" in item for item in result["unverifiable"]))
        self.assertFalse(any("Missing effective" in finding for finding in result["findings"]))

    def test_token_limited_accepts_only_permission_denials(self):
        protection = ROOT + "/branches/main/protection"
        for error, expected in ((self.module.HttpError(404, "Not Found"), "LIMITED"),
                                (self.module.HttpError(403, "API rate limit exceeded for installation."), "UNKNOWN"),
                                (self.module.HttpError(404, "Branch not found"), "UNKNOWN")):
            with self.subTest(message=error.message):
                self.data = fixture()
                self.limit_token()
                self.data[protection] = error
                self.assertEqual(self.audit(self.fetch, REPO, token_limited=True)["status"], expected)

    def test_token_limited_partial_merge_flags_stay_unknown(self):
        self.limit_token()
        self.data[ROOT]["allow_squash_merge"] = True
        result = self.audit(self.fetch, REPO, token_limited=True)
        self.assertEqual(result["status"], "UNKNOWN")
        self.assertIsNone(result["observed"]["squash_only"])
        self.assertIn("Repository merge flags missing or malformed.", result["unknown"])

    def test_missing_ruleset_check_with_unverifiable_classic_is_named(self):
        self.limit_token()
        rules = self.data[ROOT + "/rules/branches/main?per_page=100&page=1"]
        status_rule = next(rule for rule in rules if rule["type"] == "required_status_checks")
        checks = status_rule["parameters"]["required_status_checks"]
        checks[:] = [check for check in checks if check["context"] != "pr-title"]
        result = self.audit(self.fetch, REPO, token_limited=True)
        self.assertEqual(result["status"], "LIMITED")
        self.assertEqual(result["unknown"], [])
        self.assertTrue(any("pr-title" in item for item in result["unverifiable"]))
        self.assertNotIn("pr-title", result["observed"]["ruleset_required_checks"])
        self.assertIsNone(result["observed"]["required_checks"])

    def test_gh_get_non_json_permission_error_keeps_status_only(self):
        failed = subprocess.CompletedProcess([], 1, stdout="not JSON",
                                             stderr="gh: Forbidden (HTTP 403)")
        with mock.patch.object(self.module.subprocess, "run", return_value=failed):
            with self.assertRaises(self.module.HttpError) as caught:
                self.module.gh_get(ROOT)
        self.assertEqual((caught.exception.status, caught.exception.message), (403, ""))


if __name__ == "__main__":
    unittest.main()
