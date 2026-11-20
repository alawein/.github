# Review instructions

Review-only rules for this repository. CodeRabbit reads this file through
`knowledge_base.code_guidelines`, and the planned `claude-review.yml` prompt (not yet shipped) will tell
Claude to read it. Codex reads the `## Code Review Rules` section of
`AGENTS.md`, and Bugbot reads `.cursor/BUGBOT.md`; both point here. Reviewers
read this file from the base branch, so merge a change here before relying on
it.

## Shared policy

The owner of these rules is `docs/system/reviewers.md`, revision `2026-10-02`.
Some reviewers cannot open links, so the parts a review needs are copied here.
If this file and the policy disagree, the policy wins.

- RV-001 routing: CodeRabbit is the only automatic reviewer. Any other reviewer
  runs once, on the owner's named request, for one named risk. A request an
  agent posts for itself is not an owner request.
- RV-002 findings: findings are advice. Each needs evidence. Drop a finding
  whose root cause and path another reviewer or CI already reported on this
  revision.
- RV-003 access and spend: never quote secrets, credentials or private data in
  a finding. Path filters do not limit what a reviewer can read.
- RV-004 protected delivery: comment only. Never approve, request changes,
  push, merge, resolve another reviewer's thread or edit the PR. Required
  checks, signing and the owner's merge permission stay as they are. A
  skipped, paused, rate-limited or failed review is a visible blocker, never a
  pass.

## Labels

Start every finding with one label.

| Label | Use when |
| --- | --- |
| `bug:` | Wrong behavior, a broken contract, a security regression, data loss, a failed rollback or an unsupported public claim |
| `question:` | Intent is unclear and the answer changes correctness |
| `nit:` | Real but minor; at most 5 per review |

Then give the fact, `file:line`, the input or state that triggers it, and a
fix.

## Evidence bar

- Post a `bug:` only at 80% confidence or more, with a named trigger.
- Cite `file:line` for every behavior claim. A name alone is not evidence.
- Mark remote or account claims UNVERIFIED without current evidence.
- "No issues found at `<sha>`" is a complete review.

## Do not report

- Anything CI owns here: `markdown-lint`, `link-check`, `actionlint`,
  `zizmor`, `metadata-tests`, `pr-title` and `pr-policy`.
- Style that no checked-in rule requires.
- Build output and vendored code: `dist/`, `build/`, `node_modules/`,
  `vendor/`.

Lockfiles stay in scope for integrity only: report an unexpected source,
version or hash change, never formatting.

## Always check

- Workflows: full-SHA pins with a version comment that match `docs/pins.md`,
  `persist-credentials: false`, least-privilege `permissions`, a
  `timeout-minutes`, `ubuntu-24.04` rather than `ubuntu-latest`, no new
  `pull_request_target`, and no secrets in fork-reachable jobs.
- Only `policy.yml` reruns on `edited`; required check names stay unchanged.
- `templates/`: placeholders stay intentional, and every template pins the
  same kit revision.
- Owner gates: rulesets, signing, squash-only merges, no bypass actors and CI
  permissions change only with named owner approval.
- Secrets: nothing credential-like in code, logs, fixtures or PR text.
