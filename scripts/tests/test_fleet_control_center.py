"""Offline tests for Fleet Control Center schema and aggregator."""
from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1]
KIT_ROOT = SCRIPTS.parent
FIXTURES = Path(__file__).resolve().parent / "fixtures" / "fleet"


def load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class FleetEvidenceSchemaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.schema = load("fleet_evidence_schema", SCRIPTS / "fleet_evidence_schema.py")

    def test_validates_store_snapshot_shape(self):
        store = Path(
            "/cursor/stores/bc-4a304935-6087-40bb-937e-c46affff3da7/internal/fleet-evidence/latest/fleet.json"
        )
        if not store.is_file():
            self.skipTest("store fleet.json not available")
        data = json.loads(store.read_text(encoding="utf-8"))
        errors = self.schema.validate_snapshot(data)
        self.assertEqual(errors, [])

    def test_rejects_wrong_artifact(self):
        data = {
            "schema_version": "1.0.0",
            "artifact": "wrong",
            "observed_at": "2026-11-17T00:00:00Z",
            "freshness": {"status": "PASS", "max_age_seconds": 1},
            "provenance": {"scope": "LIMITED", "sources": []},
            "status_legend": sorted(self.schema.STATUSES),
            "fleet_overview": {"status": "PASS", "repositories": []},
            "workflow_registry": {},
            "ci_reliability": {},
            "pull_requests": {},
            "governance": {},
            "security": {},
            "automation": {},
            "drift": {},
            "recommendations": [],
            "maios_export": {"read_only": True},
        }
        errors = self.schema.validate_snapshot(data)
        self.assertTrue(any("artifact" in error for error in errors))


class FleetControlCenterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # fleet_control_center imports fleet_evidence_schema from scripts/
        sys.path.insert(0, str(SCRIPTS))
        cls.fcc = load("fleet_control_center", SCRIPTS / "fleet_control_center.py")

    def test_offline_aggregator_marks_stale_pins(self):
        pins = json.loads((FIXTURES / "pins.json").read_text(encoding="utf-8"))["rows"]
        kit_commit = "fc72c586b68d6141b84d35303ee60ad69d7e8c55"
        snapshot = self.fcc.build_snapshot(
            kit_root=KIT_ROOT,
            pin_rows=pins,
            kit_commit=kit_commit,
            observed_at="2026-11-17T12:00:00Z",
            scope="LIMITED",
            sources=["fixture"],
        )
        self.assertEqual(snapshot["artifact"], "github-fleet-control-center")
        self.assertEqual(snapshot["workflow_registry"]["outdated_pin_count"], 2)
        self.assertEqual(snapshot["drift"]["status"], "WARN")
        names = {row["name"] for row in snapshot["fleet_overview"]["repositories"]}
        self.assertIn("alawein/.github", names)
        self.assertIn("alawein/alawein", names)
        self.assertTrue(snapshot["maios_export"]["read_only"])
        self.fcc.assert_valid(snapshot)

    def test_multi_pin_row_records_every_distinct_sha(self):
        pins = json.loads((FIXTURES / "pins-multi.json").read_text(encoding="utf-8"))["rows"]
        kit_commit = "fc72c586b68d6141b84d35303ee60ad69d7e8c55"
        snapshot = self.fcc.build_snapshot(
            kit_root=KIT_ROOT,
            pin_rows=pins,
            kit_commit=kit_commit,
            observed_at="2026-11-18T00:00:00Z",
            scope="LIMITED",
            sources=["fixture-multi"],
        )
        consumer = snapshot["workflow_registry"]["consumer_pins"]
        multi = [
            row
            for row in consumer
            if row["repository"] == "alawein/standards-pathfinder"
            and row["path"] == ".github/workflows/ci.yml"
        ]
        recorded = sorted(row["pin"] for row in multi)
        self.assertEqual(
            recorded,
            [
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
            ],
        )
        self.assertTrue(all(row["vs_kit"] == "STALE" for row in multi))
        self.assertGreaterEqual(snapshot["workflow_registry"]["outdated_pin_count"], 2)
        drift_pins = {
            finding["observed"]
            for finding in snapshot["drift"]["findings"]
            if finding["repository"] == "alawein/standards-pathfinder"
        }
        self.assertEqual(
            drift_pins,
            {
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
            },
        )
        # single-pin current kit SHA still records as PASS and does not inflate stale count alone
        current = [
            row
            for row in consumer
            if row["repository"] == "alawein/alawein" and row["pin"] == kit_commit
        ]
        self.assertEqual(len(current), 1)
        self.assertEqual(current[0]["vs_kit"], "PASS")

    def test_cli_writes_observed_at(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "fleet.json"
            code = self.fcc.main(
                [
                    "--kit-root",
                    str(KIT_ROOT),
                    "--pins",
                    str(FIXTURES / "pins.json"),
                    "--kit-commit",
                    "fc72c586b68d6141b84d35303ee60ad69d7e8c55",
                    "--output",
                    str(out),
                    "--offline",
                ]
            )
            self.assertEqual(code, 0)
            self.assertTrue(out.is_file())
            stamp = out.parent / "observed_at.txt"
            self.assertTrue(stamp.is_file())
            data = json.loads(out.read_text(encoding="utf-8"))
            self.assertEqual(data["observed_at"], stamp.read_text(encoding="utf-8").strip())

    def test_empty_recent_runs_ci_reliability_is_not_pass(self):
        live_kit = {
            "visibility": "public",
            "default_branch": "main",
            "latest_ci_status": "UNKNOWN",
            "open_pr_count": 0,
            "blocked_pr_count": 0,
            "active_workflows": [],
            "governance_state": "UNKNOWN",
            "status": "LIMITED",
            "notes": "synthetic empty runs",
            "ci_status": "PASS",  # buggy producer claim
            "recent_runs": [],
            "prs": [],
            "partial": True,
            "governance_status": "UNKNOWN",
            "governance_observed": {},
            "governance_unknown": [],
        }
        snapshot = self.fcc.build_snapshot(
            kit_root=KIT_ROOT,
            pin_rows=[],
            kit_commit="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            observed_at="2026-11-18T00:00:00Z",
            scope="PASS",  # caller mistakenly asks for PASS
            sources=["unit-test"],
            live_kit=live_kit,
        )
        self.assertNotEqual(snapshot["ci_reliability"]["status"], "PASS")
        self.assertNotEqual(snapshot["provenance"]["scope"], "PASS")
        self.assertIn(snapshot["ci_reliability"]["status"], {"LIMITED", "UNKNOWN"})
        self.assertEqual(snapshot["provenance"]["scope"], "LIMITED")
        self.assertEqual(snapshot["ci_reliability"]["recent_runs"], [])

    def test_collect_live_kit_marks_partial_when_runs_get_fails(self):
        calls = {"n": 0}

        def fake_gh_get(path: str):
            calls["n"] += 1
            if path.startswith(f"repos/{self.fcc.KIT}/actions/runs"):
                return None
            if path.startswith(f"repos/{self.fcc.KIT}/pulls"):
                return []
            if path.startswith(f"repos/{self.fcc.KIT}/rulesets"):
                return []
            if path == f"repos/{self.fcc.KIT}":
                return {"private": False, "default_branch": "main"}
            raise AssertionError(f"unexpected path {path}")

        original = self.fcc._gh_get
        self.fcc._gh_get = fake_gh_get
        try:
            live = self.fcc.collect_live_kit()
        finally:
            self.fcc._gh_get = original

        self.assertTrue(live["partial"])
        self.assertEqual(live["recent_runs"], [])
        self.assertNotEqual(live["ci_status"], "PASS")
        self.assertGreaterEqual(calls["n"], 1)

    def _install_gh_get(self, fake_gh_get):
        original = self.fcc._gh_get
        self.fcc._gh_get = fake_gh_get
        return original

    def _live_kit(
        self,
        *,
        conclusions: list[object] | None = None,
        rulesets: list[dict] | None = None,
    ):
        if conclusions is None:
            conclusions = ["success"]
        if rulesets is None:
            rulesets = []

        def fake_gh_get(path: str):
            if path == f"repos/{self.fcc.KIT}":
                return {"private": False, "default_branch": "main"}
            if path.startswith(f"repos/{self.fcc.KIT}/actions/runs"):
                return {
                    "workflow_runs": [
                        {
                            "name": f"run-{index}",
                            "conclusion": conclusion,
                            "head_branch": "main",
                            "created_at": "2026-11-25T00:00:00Z",
                            "html_url": f"https://example.test/{index}",
                        }
                        for index, conclusion in enumerate(conclusions)
                    ]
                }
            if path.startswith(f"repos/{self.fcc.KIT}/pulls"):
                return []
            if path.startswith(f"repos/{self.fcc.KIT}/rulesets"):
                return rulesets
            raise AssertionError(f"unexpected path {path}")

        original = self._install_gh_get(fake_gh_get)
        try:
            return self.fcc.collect_live_kit()
        finally:
            self.fcc._gh_get = original

    def test_aggregate_ci_status_per_conclusion(self):
        """Each non-success conclusion alone (and mixed with success) must not PASS."""
        cases = [
            (None, "LIMITED"),
            ("cancelled", "LIMITED"),
            ("skipped", "LIMITED"),
            ("neutral", "LIMITED"),
            ("stale", "LIMITED"),
            ("timed_out", "WARN"),
            ("action_required", "WARN"),
            ("failure", "WARN"),
        ]
        for conclusion, expected in cases:
            with self.subTest(mode="alone", conclusion=conclusion):
                live = self._live_kit(conclusions=[conclusion])
                self.assertEqual(live["ci_status"], expected)
                self.assertNotEqual(live["ci_status"], "PASS")
            with self.subTest(mode="mixed_with_success", conclusion=conclusion):
                live = self._live_kit(conclusions=["success", conclusion])
                self.assertEqual(live["ci_status"], expected)
                self.assertNotEqual(live["ci_status"], "PASS")

    def test_aggregate_ci_pass_only_when_all_recent_runs_succeed(self):
        live = self._live_kit(conclusions=["success", "success"])
        self.assertEqual(live["ci_status"], "PASS")
        self.assertEqual(live["latest_ci_status"], "PASS")

    def test_governance_not_pass_for_disabled_unrelated_ruleset(self):
        """Nonempty ruleset list with only disabled unrelated rulesets is not governance PASS."""
        live = self._live_kit(
            conclusions=["success"],
            rulesets=[
                {
                    "id": 1,
                    "name": "unrelated-disabled",
                    "enforcement": "disabled",
                }
            ],
        )

        self.assertNotEqual(live["governance_status"], "PASS")
        self.assertNotEqual(live["governance_state"], "PASS")
        self.assertEqual(live["governance_status"], "LIMITED")
        observed = live["governance_observed"]
        self.assertEqual(observed["api_observation"], "PASS")
        self.assertEqual(observed["ruleset_presence"], "PASS")
        self.assertNotEqual(observed["active_enforcement"], "PASS")
        self.assertNotEqual(observed["policy_compliance"], "PASS")
        self.assertIn(
            observed["policy_compliance"],
            {"LIMITED", "UNKNOWN", "WARN", "FAIL"},
        )

    def test_governance_list_endpoint_never_claims_verified_policy_pass(self):
        """Active ruleset names from the list endpoint still cannot verify policy compliance."""
        live = self._live_kit(
            conclusions=["success"],
            rulesets=[
                {"id": 10, "name": "main-protection", "enforcement": "active"},
                {"id": 11, "name": "release-tags", "enforcement": "active"},
            ],
        )

        observed = live["governance_observed"]
        self.assertEqual(observed["api_observation"], "PASS")
        self.assertEqual(observed["ruleset_presence"], "PASS")
        self.assertEqual(observed["active_enforcement"], "PASS")
        self.assertNotEqual(observed["policy_compliance"], "PASS")
        # Overall governance must not upgrade list presence into verified compliance.
        self.assertEqual(live["governance_status"], "LIMITED")
        self.assertNotEqual(live["governance_status"], "PASS")

    def test_sanitized_fail_closed_fixture_builds_offline(self):
        schema = load("fleet_evidence_schema", SCRIPTS / "fleet_evidence_schema.py")
        fixture = FIXTURES / "live-kit-fail-closed.json"
        live_kit = json.loads(fixture.read_text(encoding="utf-8"))
        snapshot = self.fcc.build_snapshot(
            kit_root=KIT_ROOT,
            pin_rows=[],
            kit_commit="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            observed_at="2026-11-25T12:00:00Z",
            scope="LIMITED",
            sources=["fixture-fail-closed"],
            live_kit=live_kit,
        )
        self.assertNotEqual(snapshot["ci_reliability"]["status"], "PASS")
        self.assertNotEqual(snapshot["governance"]["status"], "PASS")
        observed = snapshot["governance"]["observed"]
        for key in schema.GOVERNANCE_EVIDENCE_KEYS:
            self.assertIn(key, observed)
            self.assertIn(observed[key], self.fcc.STATUSES)
        self.fcc.assert_valid(snapshot)
        # No private store paths or secret-shaped fields in fixture-driven output.
        blob = json.dumps(snapshot)
        self.assertNotIn("/cursor/stores/", blob)
        self.assertNotIn("github_pat", blob.lower())
        self.assertNotIn("authorization", blob.lower())

class FleetPinAuditorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pins = load("audit_fleet_pins", SCRIPTS / "audit_fleet_pins.py")

    def test_collect_inventory_from_items(self):
        items = [
            {
                "repository": {"full_name": "alawein/demo"},
                "path": ".github/workflows/ci.yml",
            }
        ]

        def fake_fetch(_repo: str, _path: str) -> str:
            return "uses: alawein/.github/.github/workflows/ci.yml@aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n"

        original = self.pins.fetch_file
        self.pins.fetch_file = fake_fetch
        try:
            inventory = self.pins.collect_inventory(items)
        finally:
            self.pins.fetch_file = original
        self.assertEqual(len(inventory["rows"]), 1)
        self.assertEqual(
            inventory["rows"][0]["pin"],
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        )


if __name__ == "__main__":
    unittest.main()
