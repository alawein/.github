# Bugbot rules

Bugbot reads this file, not `.cursor/rules`. Follow `REVIEW.md` at the repo
root for the shared policy, labels, evidence bar and skip list, and the
`## Code Review Rules` section of `AGENTS.md`. Do not duplicate those rules
here.

- Run only on the owner's named request. Comment only; never push, open a
  branch or run Autofix.
- Start each finding with `bug:`, `question:` or `nit:`; at most 5 `nit:`.
- A `bug:` needs 80% confidence, a named trigger and a `file:line` citation.
- Skip anything CI reports and anything CodeRabbit already posted on this
  revision.
- Lockfiles: integrity only (sources, versions, hashes).
