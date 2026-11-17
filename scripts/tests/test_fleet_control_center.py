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
