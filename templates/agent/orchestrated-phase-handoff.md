# Orchestrated improvement — handoff

Load only when this phase starts.

## 10. Living handoff document

The handoff must be maintained throughout execution and must contain exactly these six top-level sections:

### 1. Goals

Include:

- Objective.
- Scope.
- Acceptance criteria.
- Constraints.
- Non-goals.

### 2. Current State

Include:

- What works.
- What does not.
- Current phase.
- Relevant revision or working-tree state.
- Blockers.
- Verification status.

Clearly distinguish:

- Reviewed areas.
- Changed areas.
- Tested areas.
- Unverified areas.

### 3. Active Files

Include:

- Relevant files.
- Why they matter.
- Change state.
- Owner when applicable.

Do not invent file paths or line numbers.

### 4. Changes Made

Include:

- Completed modifications, additions, and deletions.
- Links to finding IDs or named tasks.
- Distinction between implemented-but-unverified work and verified work.

### 5. Failed Attempts

Include:

- Approaches actually attempted.
- Observed results.
- Why they failed.
- What not to repeat without new evidence.

Do not label an unattempted proposal, rejected finding, or deferred recommendation as a failed attempt.

If no failed attempts occurred, say: `None`.

### 6. Next Steps

Include:

- Ordered, immediately actionable steps.
- Owners or role assignments.
- Prerequisites.
- Relevant commands when known.
- Approval needs.
- Unresolved risks.
- Next verification action.

Include compact lessons or references to lessons here when useful. Do not add a seventh top-level section.

### Mandatory handoff update checkpoints

Update the handoff at least at these checkpoints:

- Context established.
- Triage completed.
- Patch implemented.
- Verification completed or failed.
- Iteration closed.
- Execution blocked or stopped.
- Interruption recovery.

Do not promise impossible guarantees. The handoff cannot be guaranteed after an abrupt crash. Instead, update it promptly at each checkpoint and make it resumable from the latest available artifact.

If repository persistence is authorized, write ledger, handoff, or lessons only to authorized paths. If persistence is not authorized, maintain them in the conversation.

## 11. Lessons and preventive improvements

For material findings, capture:

- Root cause.
- Why existing checks missed it, or that the reason remains unknown.
- Preventive test, rule, documentation, or design constraint.
- Other components or reviewers that should receive the lesson.
- Evidence supporting broader applicability.
- Remaining uncertainty.

Rules:

- Avoid speculative lessons unsupported by the investigation.
- Do not expand scope automatically when a reusable pattern is found.
- Propose or perform only authorized, proportional follow-up.
- Record lessons in the ledger and reference them in the handoff’s Next Steps section.
