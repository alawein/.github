# Change evidence

Complete locally before promotion. Use repo-relative paths in public copies;
redact private identifiers and inputs. Blank, unrun or inaccessible means
UNVERIFIED, never PASS. Follow [agent policy](../../docs/system/agents.md) and
[reviewer policy](../../docs/system/reviewers.md).

## Identity and scope

- Task: {{REAL_TASK_ID_OR_DESCRIPTION; do not invent an ID}}
- Goal and authorized local scope: {{GOAL_AND_SCOPE}}
- Repository and branch: {{REPO_AND_BRANCH}}
- Base revision: {{BASE_COMMIT}}
- Reviewed revision or dirty-tree digest: {{REVISION_OR_SHA256}}
- Digest method and manifest: {{SORTED_PATH_AND_SHA256_MANIFEST; include new files}}
- Files reviewed: {{EXACT_FILES}}
- Policy citations: {{RULE_ID, owning document, revision or digest}}
- Captured at: {{UTC_TIME}}

## Checks

- Runtime, tools and versions: {{VERSIONS}}
- OS, lockfile and approved input digests: {{INPUTS}}

| Command and working directory | Exit/result | Duration | Evidence path | Content digest |
| --- | --- | --- | --- | --- |
| {{EXACT_COMMAND_AND_DIRECTORY}} | {{EXIT_AND_OBSERVED_RESULT}} | {{SECONDS}} | {{LOG}} | {{SHA256}} |

| Required gate not run | Reason | Owner or next action |
| --- | --- | --- |
| {{GATE_OR_NONE}} | {{REASON}} | {{NEXT_ACTION}} |

For account checks, record expected state, observed state, source, capture
time and PASS/WARN/FAIL or UNVERIFIED separately from local validation.

## Independent review

- Separate reviewer session and tool/model: {{SESSION_AND_REVIEWER}}
- Scope and inspected content digest: {{FILES_AND_DIGEST}}
- Review started/completed: {{UTC_TIMES}}
- Verdict and review artifact: {{PASS_OR_FIX_AND_PATH}}
- Checks run by reviewer: {{COMMANDS_RESULTS_OR_NOT_RUN_REASON}}

| Finding and rule citation | File/line and evidence | Resolution | Verification |
| --- | --- | --- | --- |
| {{ID_SEVERITY_RULE_OR_NONE}} | {{LOCATION_AND_PROOF}} | {{FIX_REJECT_DUPLICATE_UNCERTAIN}} | {{CHECK_OR_REVIEW_ARTIFACT}} |

The implementer cannot certify their own separate review. This record proves
provenance, not independence of judgment. After relevant edits, record the new
digest, rerun affected checks and obtain scoped re-review before promotion.
Stop all review producers before freezing accepted artifacts. Record their
completed state and exact content hashes; preserve prior failures, UNKNOWN and
NOT RUN results. Recheck frozen bytes before using them as promotion evidence.

## Risk, rollback and approval

- Risk and unresolved findings: {{FAILURE_MODES_AND_LIMITS}}
- Local rollback preparation: {{SMALLEST_REVERT_OR_FIX}}
- Remote/data/DNS rollback and owner gate: {{ACTION_AND_BASELINE_OR_NA}}
- Approval: {{NAMED_ACTION_TARGET_SCOPE_AND_REFERENCE_OR_NOT_APPROVED}}
- Exception, if any: {{RULE_ID_SCOPE_REASON_APPROVAL_EXPIRY_COMPENSATING_CHECK_CLOSURE}}
- Unverified account state or technical enforcement: {{LIMITATIONS}}
