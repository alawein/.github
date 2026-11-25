# GitHub Fleet Control Center

Read-only local evidence aggregator and Cursor Canvas for `alawein/.github`.

## Regenerate snapshot (offline / CI-safe)

Offline mocks are the default. Prefer `--offline` (or omit `--live`) in CI and
local checks:

```bash
python3 scripts/fleet_control_center.py \
  --pins scripts/tests/fixtures/fleet/pins.json \
  --kit-commit fc72c586b68d6141b84d35303ee60ad69d7e8c55 \
  --output /tmp/fleet-evidence/fleet.json \
  --offline
```

Fail-closed CI and governance shapes (sanitized, no private store paths):

```bash
python3 scripts/fleet_control_center.py \
  --kit-commit aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  --output /tmp/fleet-evidence/fleet.json \
  --offline
# Then merge scripts/tests/fixtures/fleet/live-kit-fail-closed.json via unit tests
# or pass an equivalent live_kit dict in Python callers.
```

## Live kit enrichment (read-only `gh`)

```bash
python3 scripts/audit_fleet_pins.py --format json --output /tmp/pins.json
python3 scripts/fleet_control_center.py \
  --pins /tmp/pins.json \
  --live \
  --output /tmp/fleet-evidence/fleet.json
```

Do not write private Project store paths from kit scripts. Collectors never
export secrets, tokens, or `.env` values into the snapshot.

## Status vocabulary

Every section and repo row uses: `PASS` | `WARN` | `FAIL` | `UNKNOWN` |
`LIMITED` | `STALE`.

| Status | Meaning |
| --- | --- |
| `PASS` | Explicit successful evidence of the reported property |
| `WARN` | Explicit negative or degraded signal (for example CI `failure`) |
| `FAIL` | Hard failure of the reported property |
| `UNKNOWN` | Observation missing (failed GET, no data) |
| `LIMITED` | Partial or inconclusive evidence; not success |
| `STALE` | Freshness window exceeded (consumer-side) |

Missing or inconclusive evidence must never be represented as `PASS`.

## Schema (v1.1.0)

`schema_version` is `1.1.0` (still `1.x` for consumers). Additive change under
`governance.observed`:

| Field | List-endpoint meaning |
| --- | --- |
| `api_observation` | Successful ruleset list GET |
| `ruleset_presence` | Nonempty ruleset list |
| `active_enforcement` | At least one ruleset with `enforcement: active` |
| `policy_compliance` | Verified required checks / branch targets |

The ruleset **list** endpoint cannot verify policy compliance. Overall
`governance.status` therefore stays `LIMITED` (or weaker) unless separately
authorized detail inspection proves compliance. Nonempty lists that only contain
disabled or unrelated rulesets are not `PASS`.

`ci_reliability.status` is `PASS` only when every recent run concludes
`success`. Empty runs stay `LIMITED`. Conclusions such as `null`, `cancelled`,
`timed_out`, `skipped`, and `action_required` are never rolled up to `PASS`.

FCC evidence never translates into merge authorization. Green CI and observed
rulesets are not owner merge permission.

## Authority

| Action | Status |
| --- | --- |
| Local collectors / Canvas / docs | APPROVED for this workstream |
| Ruleset / settings Apply | NOT APPROVED without owner APPROVE |
| Consumer pin bump PRs | NOT APPROVED without owner APPROVE |
| Merge | NOT APPROVED without owner APPROVE |

`rulesets/checks.json` remains the only required-check authority.

## Related

- Schema constants: `scripts/fleet_evidence_schema.py`
- Fail-closed fixture: `scripts/tests/fixtures/fleet/live-kit-fail-closed.json`
- MAIOS consumer contract: Project store `docs/maios-github-fleet-evidence-contract.md`
- Canvas: GitHub Fleet Control Center in the `.github` Cursor Project
- Pin auditor: `scripts/audit_fleet_pins.py`
