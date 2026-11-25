# Claude review consumer template — WITHHELD

**Status:** not ready-to-copy. Do not copy this into a consumer repository.

## Why

The reusable workflow `.github/workflows/claude-review.yml` first landed on
`main` at `b08779a44cc49ac1e3f3e83a653e3d73d0b7cb01` (#79). The published
distributed freeze in [pins.md](../../docs/pins.md) remains
`cc3b595f8e9e92a9ed6fc63b3be177cc8a571965` (`# quality gates`). That freeze
commit has no `claude-review.yml`, so a consumer `uses:` pin at the freeze SHA
returns 404.

## Containment

- Keep the kit reusable workflow in-tree for review and zizmor work.
- Do **not** distribute a consumer starter that pins the freeze SHA to a missing
  workflow path.
- Do **not** invent a SHA, pin `@main`, or self-pin `@{{ github.sha }}`.
- Do **not** activate Claude review (no consumer copy, no org enablement, no
  secret rollout) until a reviewed freeze that contains the reusable workflow
  is published and the owner names activation.

## When it becomes copyable

1. Owner authorizes a freeze advance (or release tag) whose tree includes
   `.github/workflows/claude-review.yml`.
2. Restore a consumer template under `templates/workflows/claude-review.yml`
   with `uses:` and comments locked to that same freeze SHA (`# quality gates`
   or `# vX.Y.Z`).
3. Keep caller permissions at least
   `contents: read`, `pull-requests: write`, `issues: write`, `id-token: write`
   for the calling job, matching the reusable workflow.
4. Run `python3 scripts/check-publication-contract.py` (offline) before
   publishing the template.

Restore steps and freeze policy live in [pins.md](../../docs/pins.md) and
[ci.md](../../docs/ci.md) (publication contract / quality-gates narrative).

See [reviewers](../../docs/system/reviewers.md) (Claude row) and
[REVIEW.md](../../REVIEW.md).
