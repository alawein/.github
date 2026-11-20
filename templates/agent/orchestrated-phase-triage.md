# Orchestrated improvement — triage

Load only when this phase starts.

## 4. Goal definition and success criteria

Before review or implementation, create a Goal Record in the ledger.

The Goal Record must contain:

- Overall objective.
- In-scope outcomes.
- Explicit non-goals.
- Constraints and invariants.
- Measurable acceptance criteria.
- Evidence needed to demonstrate success.
- Dependencies and blockers.
- Definition of done for each selected fix.
- Definition of successful completion for the overall run.
- Definition of responsible termination.

Rules:

- Do not quietly weaken acceptance criteria to declare success.
- Acceptance criteria may be clarified to remove ambiguity, but not lowered, unless the user explicitly approves the change or the original criterion is impossible and the blocker is recorded.
- Distinguish successful completion from responsible termination.
- A run may be complete as a review-only run even if no fixes are implemented.
- A run may terminate responsibly because of budget exhaustion, missing approval, missing capability, or unresolved risk without the full engineering objective being achieved.

## 5. Coordination architecture

### 5.1 Coordinator

The coordinator owns:

- Scope interpretation.
- Planning.
- Delegation or pass sequencing.
- Triage.
- Approval routing.
- Resource allocation.
- File ownership assignments.
- Integration decisions.
- Ledger integrity.
- Handoff updates.
- Final reporting.

The coordinator must prevent duplicate edits, conflicting ownership, unsupported claims, and unbounded iteration.

### 5.2 Security and privacy reviewer

Examines:

- Injection.
- Unsafe rendering and XSS.
- Authentication and authorization.
- Tenant isolation.
- Trust and privilege boundaries.
- Validation and encoding.
- Paths, uploads, and SSRF.
- Secret handling and sensitive logging.
- Data exposure.
- Relevant dependency and configuration risks.

Requirements:

- Provide concrete input-to-sensitive-operation tracing where possible.
- Describe plausible exploit conditions.
- Do not label generic security language as a finding without a credible path, impact, and triggering condition.

### 5.3 Correctness and reliability reviewer

Examines:

- Business logic and invariants.
- Boundary conditions and malformed inputs.
- Ordering, pagination, dates, time zones, and numeric precision.
- Error handling and cleanup.
- Partial failure.
- Concurrency and transactions.
- Retries, timeouts, and idempotency.
- Compatibility, migrations, and data integrity.

Requirements:

- Distinguish confirmed defects from ambiguous requirements.
- If behavior may be intended, mark the item as a product decision requiring clarification unless evidence proves a defect.

### 5.4 Performance and scalability reviewer

Examines:

- N+1 behavior.
- Repeated computation or I/O.
- Unbounded reads and allocations.
- Pagination and payload size.
- Query plans and indexes when evidence is available.
- Blocking operations.
- Concurrency limits and contention.
- Caching and invalidation.

Requirements:

- State workload assumptions.
- Use measurement when feasible.
- Label unmeasured concerns as hypotheses.
- Do not claim performance improvement without before-and-after evidence.

### 5.5 Maintainability, accessibility, and usability reviewer

Examines:

- Established conventions.
- Unnecessary complexity and duplication.
- Coupling and ownership.
- Public API clarity.
- Error messages.
- Documentation.
- Non-obvious design constraints.
- Accessibility and user-facing usability where relevant.

Requirements:

- Show concrete maintenance cost, consumer cost, accessibility barrier, or usability failure.
- Do not report mere stylistic preference.

### 5.6 Fixer

Owns:

- Small, focused patches.
- Regression tests when practical.
- Implementation notes.
- Disclosure of new risks introduced by the patch.
- Preservation of unrelated work.

The fixer must not expand scope beyond the assigned finding or approved task.

### 5.7 Verification reviewer

Examines:

- Whether the original problem is resolved.
- Whether acceptance criteria are met.
- Whether tests assert meaningful outcomes.
- Missing failure-path coverage.
- Unrealistic mocks.
- Flaky tests.
- Integration boundaries.
- Cross-family regressions.
- Operational diagnostics where relevant.

Verification must be based on the integrated patch state, not only isolated diffs.

### 5.8 Role combination and independence

When separate workers are available:

- Reviewer, fixer, and verifier should be separate where risk justifies it.
- Security and correctness review should be separate for high-risk work when feasible.

When separate workers are unavailable:

- Use clearly separated sequential passes.
- Do not claim independent review or independent verification.
- Label verification as self-verification or same-session verification.
- State the limits of self-review.

Roles may be combined for low-risk work, but the final report must disclose which roles were combined and what independence claims are unavailable.

### 5.9 Worker assignment format

Use this compact assignment format when delegating to real workers or when defining an internal pass:

```yaml
assignment_id: ""
role: ""
revision_or_patch_state: ""
scope: ""
exclusions: []
authority: ""
inputs: []
budget_limit: ""
required_output:
  - facts
  - assumptions
  - hypotheses
  - findings
  - executed_checks
  - proposed_checks
  - blockers
  - next_recommendations
```

### 5.10 Worker return format

Every review pass or worker return must contain:

```yaml
assignment_id: ""
role: ""
revision_reviewed: ""
facts: []
assumptions: []
hypotheses: []
findings: []
executed_checks: []
proposed_checks: []
blockers: []
next_recommendations: []
```

Do not report a worker as having participated if the work was performed as an internal reasoning pass. In that case, describe it as an internal review pass.

## 6. Shared ledger and finding lifecycle

Maintain one authoritative shared ledger for findings, decisions, evidence, ownership, dependencies, and lessons.

The living handoff is a concise continuity view derived from the ledger. It is not a competing source of truth.

If repository persistence is authorized, store the ledger in an authorized location. Otherwise, maintain it in the conversation and include it in the handoff or final report as appropriate.

### 6.1 Required finding fields

Each finding must include:

- Stable ID, such as `F-001`.
- Family: security, correctness, performance, maintainability, accessibility, usability, process, or other.
- Title.
- Location by file, symbol, and line when available. Do not invent paths or line numbers.
- Status.
- Priority: P0, P1, P2, or P3.
- Impact.
- Likelihood.
- Confidence.
- Expected behavior.
- Actual behavior.
- Evidence.
- Triggering conditions.
- Recommended minimal fix.
- Verification plan.
- Acceptance criteria.
- Owner.
- Dependencies and related findings.
- Approval requirements.
- Decision and rationale.
- Actual checks and results.
- Residual risk.
- Relevant iteration and code revision.

### 6.2 Finding lifecycle states

Use these states:

- `suspected`
- `confirmed`
- `approval_pending`
- `fixing`
- `verification_pending`
- `verified`
- `deferred`
- `rejected`
- `reopened`

Separate status from approval and verification evidence when doing so prevents ambiguity.

### 6.3 Valid transitions and evidence requirements

Valid transitions:

- `suspected -> confirmed`
  - Requires observed facts, location, expected versus actual behavior, impact, confidence, and evidence.
- `suspected -> rejected`
  - Requires disconfirming evidence, scope exclusion, duplicate resolution, or insufficient evidence after adversarial challenge.
- `confirmed -> approval_pending`
  - Required when the fix is outside current authority.
- `confirmed -> fixing`
  - Allowed when authority is sufficient or approval has been granted.
- `approval_pending -> fixing`
  - Requires explicit approval evidence.
- `approval_pending -> deferred`
  - Allowed when approval is denied, unavailable, or budget exhausted.
- `fixing -> verification_pending`
  - Requires patch state, implementation notes, updated tests if practical, and disclosed new risks.
- `verification_pending -> verified`
  - Requires acceptance criteria met at the current revision, with actual check results.
- `verification_pending -> fixing`
  - Requires failed verification evidence and precise failure details.
- `verified -> reopened`
  - Required when code changes invalidate evidence, a regression appears, acceptance criteria were wrong, or new contradictory evidence appears.
- `reopened -> confirmed`
  - Requires revalidation of the defect or risk.
- `confirmed -> deferred`
  - Requires rationale, residual risk, and any approval or budget reason.
- `deferred -> confirmed`
  - Requires new evidence, new approval, or scope expansion.

### 6.4 Duplicate handling

When findings duplicate:

- Choose one canonical finding.
- Merge evidence, provenance, and related IDs into the canonical finding.
- Close duplicate records with `status=rejected`, `rejection_reason=duplicate`, and `duplicate_of=canonical_id`.
- Preserve the duplicate’s original evidence in the ledger so provenance is not lost.

### 6.5 Conflicting recommendations

When recommendations conflict:

1. Identify the affected files, findings, acceptance criteria, and constraints.
2. Compare evidence, impact, likelihood, confidence, and risk.
3. Prefer the minimal change that satisfies acceptance criteria and preserves invariants.
4. If conflict remains unresolved, mark dependent work blocked or deferred and escalate.
5. Record the decision, rationale, and rejected alternative in the ledger.

Do not implement conflicting patches simultaneously unless integration is explicitly coordinated.

### 6.6 Stale evidence

Evidence becomes stale when:

- The code revision changes.
- Affected files are modified.
- A dependency, configuration, or environment changes.
- A test or benchmark is flaky and cannot be trusted.
- A prior verification result no longer matches the current patch state.

When evidence becomes stale:

- Mark the affected finding’s verification state as stale.
- Do not use stale evidence to close a finding.
- Re-run targeted checks before marking the finding verified.

### 6.7 Reopening verified findings

Reopen a verified finding when:

- A later change causes a regression.
- The original acceptance criteria are shown to be incomplete or incorrect.
- The verification evidence was stale, flaky, or invalid.
- New evidence contradicts the prior verification.
- The integrated patch state differs from the verified patch state.

### 6.8 Cross-family findings

If a finding spans multiple families:

- Assign one primary owner.
- Add the other relevant reviewer families as consultants.
- Keep one finding ID unless the concerns are independently actionable.
- Record cross-family verification requirements before closure.

## 7. End-to-end workflow

Use the following workflow unless proportionality justifies a lightweight path. Even in lightweight paths, preserve goals, evidence, authority, verification, and handoff.

### 7.1 Intake and capability assessment

Purpose: establish what is available and what is authorized.

Inputs:

- Input contract.
- Available tools.
- Worker capabilities.
- Budget.
- Mode and approval boundaries.

Outputs:

- Ledger initialized.
- Handoff initialized.
- Capability statement.
- Missing-information questions, if blocking.

Exit criteria:

- Authority, capabilities, and budget are understood.
- Unsafe or impossible requests are identified.

Failure behavior:

- If blocking information is missing, ask once.
- If unsafe, stop or downgrade to review-only.

### 7.2 Goal definition and scope confirmation

Purpose: define what success and responsible termination mean.

Inputs:

- Input contract.
- Documentation.
- Assumptions.

Outputs:

- Goal Record.
- Scope boundaries.
- Non-goals.
- Acceptance criteria.

Exit criteria:

- Goals are explicit and testable where possible.
- Scope conflicts are recorded or resolved.

Failure behavior:

- If acceptance criteria are impossible or ambiguous, record the issue and request clarification if material.

### 7.3 Repository and working-tree inspection

Purpose: understand the actual code state.

Inputs:

- Repository, changeset, feature, or code excerpt.
- Available version-control state.

Outputs:

- Baseline revision or patch state.
- Active file map.
- Protected file list.
- Existing work that must be preserved.

Exit criteria:

- The coordinator knows which files are in scope.
- Unrelated work is identified and protected.

Failure behavior:

- If repository access is unavailable, record the limitation and proceed with static analysis only.

### 7.4 Baseline checks

Purpose: establish current behavior before changes.

Inputs:

- Test, lint, type-check, build, security, and benchmark commands.
- Authorization to run commands.

Outputs:

- Baseline results.
- Pre-existing failures.
- Unexecuted but proposed checks.

Exit criteria:

- Baseline evidence is recorded or limitations are documented.

Failure behavior:

- If commands fail due to environment issues, record environmental failures separately from code defects.
- Do not fix pre-existing failures unless in scope.

### 7.5 Risk-based review planning

Purpose: allocate review effort proportionally.

Inputs:

- Goal Record.
- Risk level.
- Available budget.
- Worker capabilities.

Outputs:

- Review plan.
- Assigned families.
- Depth of review.
- Worker or pass assignments.

Exit criteria:

- Plan is recorded in the ledger.
- High-risk areas receive appropriate review.

Failure behavior:

- If budget is insufficient, reduce scope or request approval to continue.

### 7.6 Specialist review

Purpose: produce evidence-backed findings.

Inputs:

- Review plan.
- Code state.
- Scope and exclusions.

Outputs:

- Findings.
- Evidence.
- Hypotheses.
- Proposed checks.

Exit criteria:

- Each finding has required fields.
- Unsupported claims are labeled as hypotheses.

Failure behavior:

- If a reviewer lacks capability, record the gap and adjust confidence.

### 7.7 Evidence consolidation

Purpose: normalize evidence and prevent mixed claim types.

Inputs:

- Raw review outputs.

Outputs:

- Structured facts, assumptions, hypotheses, defects, product questions, executed checks, and proposed checks.

Exit criteria:

- Each claim is categorized.
- Evidence is linked to findings.

Failure behavior:

- Return incomplete claims to the relevant review pass for clarification if budget allows.

### 7.8 Deduplication and adversarial challenge

Purpose: remove noise and unsupported claims.

Inputs:

- Consolidated findings.

Outputs:

- Deduplicated findings.
- Challenge notes.
- Rejected findings with rationale.

Exit criteria:

- High-priority findings survive evidence-based challenge.
- Duplicates are merged with provenance.

Failure behavior:

- If evidence remains insufficient, keep finding as suspected or reject it according to the evidence standard.

### 7.9 Triage and approval routing

Purpose: decide what to fix, defer, reject, or escalate.

Inputs:

- Deduplicated findings.
- Authority boundaries.
- Budget.
- Risk.

Outputs:

- Triage decisions.
- Approval requests.
- Deferred and rejected findings with rationale.

Exit criteria:

- Each active finding has a decision and owner.
- Approval-dependent work is clearly marked.

Failure behavior:

- If approval is unavailable, defer dependent work and continue safe independent work.

### 7.10 Fix assignment and file ownership

Purpose: prevent conflicting edits and preserve unrelated work.

Inputs:

- Approved findings.
- Active file map.
- Protected files.

Outputs:

- Fix assignments.
- File ownership.
- Integration order.

Exit criteria:

- No two uncoordinated owners are assigned to the same file or symbol.
- Assignments are within scope and authority.

Failure behavior:

- If ownership conflicts arise, coordinate integration or defer one fix.

### 7.11 Focused implementation

Purpose: apply minimal, safe fixes.

Inputs:

- Fix assignments.
- Acceptance criteria.
- Verification plans.

Outputs:

- Patch or file changes.
- Regression tests when practical.
- Implementation notes.
- New risk disclosures.

Exit criteria:

- Patch is ready for verification.
- Unrelated work is preserved.

Failure behavior:

- If the fix requires out-of-scope changes, stop and return to triage.

### 7.12 Independent review where available

Purpose: catch errors before verification.

Inputs:

- Patch state.
- Finding evidence.
- Authority constraints.

Outputs:

- Review notes.
- Objections.
- Additional findings.

Exit criteria:

- Patch is accepted for verification or returned for repair.

Failure behavior:

- If independent review is unavailable, perform a separated self-review pass and disclose the limitation.

### 7.13 Targeted and broader verification

Purpose: verify the fix against acceptance criteria and detect regressions.

Inputs:

- Patch state.
- Baseline results.
- Verification plan.
- Available commands.

Outputs:

- Actual commands.
- Execution context.
- Results.
- Limitations.

Exit criteria:

- Finding can be marked verified or returned to fixing.

Failure behavior:

- If verification fails, return precise failure evidence to the fixer.
- If environment failure prevents verification, mark the finding unverified and record proposed checks.

### 7.14 Regression analysis

Purpose: ensure the integrated patch state did not break other behavior.

Inputs:

- Baseline results.
- Post-change results.
- Risk profile.

Outputs:

- Regression findings.
- Comparison summary.
- Cross-family concerns.

Exit criteria:

- No unresolved blocking regressions remain for completed findings, or regressions are triaged.

Failure behavior:

- If regressions appear, open new findings or reopen affected findings.

### 7.15 Ledger and handoff updates

Purpose: maintain continuity.

Inputs:

- All decisions, evidence, and results.

Outputs:

- Updated ledger.
- Updated handoff.

Exit criteria:

- Ledger and handoff are consistent.
- Current revision or patch state is recorded.

Failure behavior:

- If persistence is unavailable, update the conversation handoff immediately.

### 7.16 Lessons and feedback routing

Purpose: prevent recurrence.

Inputs:

- Verified findings.
- Root causes.
- Missed detection reasons.

Outputs:

- Lessons.
- Preventive tests, rules, documentation, or design constraints.
- Targeted follow-up recommendations.

Exit criteria:

- Material findings have root-cause and prevention information.

Failure behavior:

- If root cause is unknown, record that explicitly.

### 7.17 Targeted follow-up or responsible termination

Purpose: decide whether another bounded iteration is useful.

Inputs:

- Remaining budget.
- Open findings.
- Risk.
- Iteration count.

Outputs:

- Decision to continue with targeted follow-up or terminate responsibly.

Exit criteria:

- Continuation is authorized and bounded, or termination is justified.

Failure behavior:

- If no safe progress is possible, terminate and report.

### 7.18 Final reporting and handoff

Purpose: provide a complete, honest account.

Inputs:

- Ledger.
- Handoff.
- Verification evidence.
- Lessons.

Outputs:

- Final report.
- Six-section handoff or authorized artifact location.

Exit criteria:

- The report satisfies the final output contract.

Failure behavior:

- If reporting budget is insufficient, prioritize unresolved critical risks, current state, and next steps.

## 8. Bounded feedback and iteration loops

### 8.1 Definition of iteration

An iteration is consumed when any implementation-and-verification cycle is started for one or more approved findings or tasks. This includes:

- A planned fix followed by verification.
- A repair retry after failed verification.
- An integration fix after combined patches fail.
- A cross-review fix caused by a previous patch.

Pure diagnosis does not consume an iteration if it does not modify code, configuration, tests, documentation, or other delivered artifacts.

Default maximum iterations: **3**, unless the input contract specifies another value.

Nested loops must not evade the iteration budget. Every repair retry or integration retry that modifies artifacts consumes budget.

Reserve enough budget for verification, handoff updates, and final reporting. If budget is numeric, reserve at least 20% after each major phase unless a different reserve is specified.

### 8.2 Local repair loop

Trigger:

- A fix fails a targeted check or acceptance criterion.

Information moved:

- Finding ID.
- Failed command or check.
- Actual output.
- Expected output.
- Patch revision.
- Acceptance criteria.

Owner:

- Fixer.

Closure:

- Targeted check passes and acceptance evidence is recorded.

Budget:

- Consumes an iteration when code or delivered artifacts change.

Escalation:

- If the same failure repeats twice without new evidence, stop repairing and defer or escalate.

### 8.3 Cross-review loop

Trigger:

- A proposed fix resolves one problem but creates or exposes another family of risk.

Information moved:

- Original finding ID.
- New finding ID.
- Affected family.
- Evidence of new risk.
- Patch revision.

Owner:

- Coordinator for triage; appropriate reviewer for evidence; fixer if authorized repair is needed.

Closure:

- New risk is rejected, deferred, fixed and verified, or escalated.

Budget:

- Consumes an iteration if implementation changes are made.

Escalation:

- If the new risk is high severity and unresolvable within budget, defer the original fix or stop.

### 8.4 Evidence-resolution loop

Trigger:

- Reviewers disagree.
- Evidence is incomplete.
- Requirements are ambiguous.
- A finding may be intended behavior.

Information moved:

- Conflicting claims.
- Evidence gaps.
- Required checks.
- Product or architecture questions.

Owner:

- Coordinator.

Closure:

- Finding is confirmed, rejected, deferred, or escalated for user clarification.

Budget:

- Does not consume an iteration unless artifact changes are made.
- Consumes time, token, or cost budget.

Escalation:

- If ambiguity materially affects safety or scope, ask the user once and record the blocker.

### 8.5 Learning loop

Trigger:

- A root cause suggests a reusable preventive improvement.

Information moved:

- Root cause.
- Why existing checks missed it, or that the reason is unknown.
- Preventive test, rule, documentation, or design constraint.
- Other components that should receive the lesson.
- Evidence of broader applicability.

Owner:

- Coordinator.

Closure:

- Lesson is recorded and either implemented if authorized or recommended.

Budget:

- Consumes an iteration only if authorized implementation occurs.

Escalation:

- Do not expand scope automatically. Propose follow-up unless already authorized.

### 8.6 Integration loop

Trigger:

- Individually acceptable patches conflict or fail when combined.

Information moved:

- Conflicting finding IDs.
- File ownership map.
- Merge or runtime failure evidence.
- Integrated revision.

Owner:

- Coordinator for integration order; fixer for repair.

Closure:

- Integrated patch state passes relevant verification.

Budget:

- Consumes an iteration when artifacts change.

Escalation:

- If conflicts cannot be resolved safely, defer one or more fixes.

### 8.7 Recovery loop

Trigger:

- Execution is interrupted.
- Context is lost.
- Repository state changes unexpectedly.
- A worker returns stale results.

Information moved:

- Latest ledger.
- Latest handoff.
- Current repository revision or patch state.
- Budget and iteration status.
- Stale evidence list.

Owner:

- Coordinator.

Closure:

- State is reconciled.
- Stale evidence is marked.
- Work resumes at a safe phase or terminates responsibly.

Budget:

- Does not consume an iteration unless artifact changes are made.
- Consumes execution budget.

Escalation:

- If state cannot be reconciled safely, stop and produce a recovery handoff.

### 8.8 Non-progress detection

Stop repeating a loop when:

- The same failure occurs twice without new evidence.
- Budget reserve is threatened.
- Approval is missing and blocks dependent work.
- A fix creates higher-severity problems than it resolves.
- Evidence remains insufficient after a reasonable challenge.

When non-progress is detected, choose one of:

- Defer the finding.
- Escalate to the user.
- Reduce scope.
- Terminate responsibly.
