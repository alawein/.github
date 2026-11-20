# Change evidence

Complete locally before promotion. Use repo-relative paths in public copies;
redact private identifiers and inputs. Blank, unrun or inaccessible means
UNVERIFIED, never PASS. Follow [agent policy](../../docs/system/agents.md) and
[reviewer policy](../../docs/system/reviewers.md).

## Routine (required)

- Task: {{REAL_TASK_ID_OR_DESCRIPTION; do not invent an ID}}
- Scope: {{GOAL_AND_AUTHORIZED_LOCAL_SCOPE}}
- Branch: {{REPO_TARGET_AND_WORKING_BRANCH}}
- Digest: {{REVIEWED_REVISION_OR_DIRTY_TREE_DIGEST}}

| Command and working directory | Exit/result | Evidence path |
| --- | --- | --- |
| {{EXACT_COMMAND_AND_DIRECTORY}} | {{EXIT_AND_OBSERVED_RESULT}} | {{LOG_OR_NONE}} |

| Required gate not run | Reason | Owner or next action |
| --- | --- | --- |
| {{GATE_OR_NONE}} | {{REASON}} | {{NEXT_ACTION}} |

- Risk: {{FAILURE_MODES_AND_UNRESOLVED_FINDINGS}}
- Approval: {{NAMED_ACTION_TARGET_SCOPE_AND_MERGE_PERMISSION_OR_NOT_APPROVED}} (include merge permission)

## Optional (promotion only)

- Selected task mode (a/b/c) detail: {{A_B_OR_C_AND_NAMED_SCOPE}}
- Base revision and digest method/manifest: {{BASE_AND_SORTED_PATH_SHA256_MANIFEST}}
- Runtime/tool versions and input digests: {{VERSIONS_AND_INPUTS}}
- Independent review session, verdict, and findings table: {{REVIEW_PROVENANCE}}
- Rollback preparation and unverified account/enforcement limits: {{ROLLBACK_AND_LIMITS}}
