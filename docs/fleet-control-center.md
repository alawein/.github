# GitHub Fleet Control Center

Read-only local evidence aggregator and Cursor Canvas for `alawein/.github`.

## Regenerate snapshot (offline / CI-safe)

```bash
python3 scripts/fleet_control_center.py \
  --pins scripts/tests/fixtures/fleet/pins.json \
  --kit-commit fc72c586b68d6141b84d35303ee60ad69d7e8c55 \
  --output /tmp/fleet-evidence/fleet.json \
  --offline
```

## Live kit enrichment (read-only `gh`)

```bash
python3 scripts/audit_fleet_pins.py --format json --output /tmp/pins.json
python3 scripts/fleet_control_center.py \
  --pins /tmp/pins.json \
  --live \
  --output /cursor/stores/<project>/internal/fleet-evidence/latest/fleet.json
```

## Authority

| Action | Status |
| --- | --- |
| Local collectors / Canvas / docs | APPROVED for this workstream |
| Ruleset / settings Apply | NOT APPROVED without owner APPROVE |
| Consumer pin bump PRs | NOT APPROVED without owner APPROVE |
| Merge | NOT APPROVED without owner APPROVE |

`rulesets/checks.json` remains the only required-check authority.

## Related

- Schema: Project store `docs/fleet-evidence-schema.md`
- MAIOS consumer contract: Project store `docs/maios-github-fleet-evidence-contract.md`
- Canvas: GitHub Fleet Control Center in the `.github` Cursor Project
- Pin auditor: `scripts/audit_fleet_pins.py`
