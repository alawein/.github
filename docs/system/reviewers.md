# Reviewer policy

CodeRabbit is the sole automatic PR reviewer after named owner activation.
Reviews advise; required CI and owner judgment govern promotion. Follow
[agent authority and gates](agents.md#safety-floor) and
[delivery protections](delivery.md#merging-and-checks).

Revision: `2026-10-02`. Cite these stable IDs with this document's reviewed
revision or digest. Account settings, permissions, billing, entitlement,
effective configuration and technical enforcement are UNVERIFIED until
observed directly. Local configuration is not proof of activation or enforcement.

| ID | Scope | Requirement | Verification | Authority |
| --- | --- | --- | --- | --- |
| RV-001 | Review routing | One automatic reviewer; secondary review only on named request | Approved reviewer, risk, paths and revision | Owner |
| RV-002 | Findings | Advisory, evidence-backed and deduplicated | Finding, consequence, proof and resolution | Owner |
| RV-003 | Access and spend | Selected repos, private-data gate and explicit allowance | Current permissions, scan and spend record | Owner |
| RV-004 | Protected delivery | Preserve checks, signing and selected-mode merge permission | Current checks and signature evidence | Owner |

## Automatic review

- Keep root `.coderabbit.yaml` aligned with
  [the canonical template](../../templates/coderabbit.yaml). Validate against
  the [official schema](https://coderabbit.ai/integrations/schema.v2.json)
  and reject unknown keys; record the schema capture date and digest.
- Review non-draft PRs; retain lockfiles and security-sensitive changes in
  scope. CI owns actionlint, Markdown lint and required check failures; avoid
  duplicating them through reviewer tools or GitHub Checks ingestion.
- Keep code writing, autofix, automatic titles, labels, assignments, issue
  planning, external integrations and post-merge actions off. Review comments
  and summaries need the named activation approval. Skipped, paused or failed
  reviews are visible statuses, never approval.
- Verify global overrides and the effective configuration after owner login:
  [workspace/organization overrides can outrank YAML](https://docs.coderabbit.ai/configuration/configuration-inheritance).
  Native guideline discovery may include multiple files; thin adapters must
  agree. [Guideline documentation](https://docs.coderabbit.ai/knowledge-base/code-guidelines).
- Version policy in source. Mutable local learnings do not establish
  deterministic review. Do not enable knowledge-base opt-out as a harmless
  toggle: it can remove stored knowledge and needs the named deletion gate.
  [Learning controls](https://docs.coderabbit.ai/knowledge-base/learnings).

## Manual routing

Choose one secondary reviewer for one named risk: Codex for security or
agent-written changes; Bugbot for complex logic. Supply paths, reviewed
revision and existing findings. Every outgoing request and any spend need
named approval; commands below are documented routes, not permission to send.

| Reviewer | One-shot route and required dormant state | Primary source |
| --- | --- | --- |
| Codex | `@codex review` with focus text; security uses `@codex security review`. Keep personal/repo automatic review and auto security review off. Other tasks can write code. | [GitHub review](https://learn.chatgpt.com/docs/third-party/github) |
| Bugbot | `bugbot run` or `cursor review`; keep Autofix off. Verify repo-wide manual-only support (`manualTriggerOnly`); a personal mention-only setting covers only that person's PRs. Otherwise keep the repo disabled. Native rules: `.cursor/BUGBOT.md`. | [Bugbot](https://cursor.com/docs/bugbot) |
| Kilo | Keep Code Reviews off, including repo overrides; no one-shot comment route is documented for that agent. The separate Kilo Bot supports `@kilocode-bot` questions and consumes credits; verify its identity before any request, and never request fixes. | [Code Reviews](https://kilo.ai/docs/automate/code-reviews/github), [Kilo Bot](https://blog.kilo.ai/p/introducing-kilo-for-github) |
| Greptile | `@greptileai`; automatic review and auto-approval off. `autoReview: []` disables automatic events; inspect source-branch configuration as well as the dashboard. | [Requests](https://www.greptile.com/docs/code-review/developer-essentials), [configuration](https://www.greptile.com/docs/code-review/greptile-json-reference) |
| Claude | Managed Manual mode and `@claude review`; never `@claude review always`. Inspect managed review and the separate GitHub Action; the latter can implement changes. Eligibility is UNVERIFIED. | [Managed review](https://code.claude.com/docs/en/code-review), [GitHub Action](https://code.claude.com/docs/en/github-actions) |
| Copilot | Select Copilot in the PR Reviewers menu. Keep all personal/ruleset automatic requests, approvals and approval-counting off. | [Manual review](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/request-a-code-review/use-code-review), [configuration](https://docs.github.com/en/copilot/how-tos/copilot-on-github/set-up-copilot/configure-code-review) |
| Grok | No trigger until installed identity, publisher and controls are verified; do not infer them from another Grok-branded product. | [Current Cursor product](https://cursor.com/docs/grok-bot) |

Graphite may remain installed as an inbox; keep AI review, stacks, queue and
merge-when-ready off. Its queue setup requests app bypass rights, conflicting
with current policy. Any future proposal needs explicit policy approval and
proof of equivalent signing/check protections. [Queue setup](https://graphite.com/docs/set-up-merge-queue).

## Findings and provenance

Use the [review checklist](../../templates/agent/review-checklist.md) and
[evidence record](../../templates/agent/evidence.template.md). Record the
separate reviewer session and exact inspected digest. Cite file/line, severity,
consequence, evidence and applicable rule ID; findings never authorize actions.
Deduplicate by root cause and affected path. Resolve disagreements against
tests and versioned policy, recording uncertain findings rather than voting.
Relevant edits invalidate affected checks and require scoped re-review.

Before an approved secondary-reviewer pilot, record its risk class and spend
ceiling. Proposed acceptance over 20 eligible PRs: at least 5 unique accepted
substantive defects, at most 20% false positives, at most 10% duplicates and
median triage at most 5 minutes per PR. These are policy targets, not measured
results. Record all outcomes and denominators, independently confirmed fixes,
cost, triage time and escaped defects; zero findings is not a pass.

Use the existing PR's Test evidence for each authorized observation. Count
eligible changes, changes actually exposed to the reviewer, completed reviews
and missing or skipped reviews separately. For completed reviews, record unique
accepted defects, false positives, duplicates, verified fixes, triage minutes,
review latency, cost and subsequently discovered escaped defects. Unknown
values remain unknown; missing reviews never enter the completed denominator.
Record the inspected revision and disposition so duplicates and accepted
findings can be checked later.

After ten authorized maintenance changes, compare useful defects caught with
time spent maintaining gates, waiting and triaging. Simplify an optional layer
when its recorded burden exceeds its assurance value. A quiet sample does not
justify removing correctness, signing, security, or required checks. An
optional secondary reviewer stops after five completed reviews with no unique
accepted substantive defect; preserve required review. These are provisional
decision rules, not observed outcomes or permission for new access or spending.

## Access and spending

- Every 30 days and on each change, record app identity, current permissions,
  requested additions, authorized-user access and selected repositories.
  Each permission delta and scope change needs owner approval; do not accept
  updates as a bundle. Dormant review does not revoke repository access.
  [GitHub app management](https://docs.github.com/en/apps/using-github-apps/reviewing-and-modifying-installed-github-apps).
- Keep secrets and private exports outside connected repos. Pass the local
  private-data scan before approved sharing. Path filters are review filters,
  not evidence of denied file access; vendor scanning happens after receipt.
- Paid requests need an approved amount, period, payer and scope. Reserve an
  estimate and reconcile actual usage; unknown cost or allowance blocks new
  paid runs. No universal per-repo monthly hard cap is verified. Top-ups,
  limit increases, payments and retries retain their named gates.
- Record payment failure, exhausted credits, missing required checks and
  skipped reviews as blockers; never weaken CI or raise limits to hide them.
  Reconcile app/scope changes against approvals and escalate unknown changes
  before more reviewer use. Alert delivery stays UNVERIFIED until tested.
