# .github kit

This public repo holds shared GitHub standards, workflows, rulesets, scripts,
and starters for alawein repositories. This is the root agent instruction file;
`CLAUDE.md` only points here.

## Start here

1. Read the latest lines of `docs/lessons.md` and inspect `git status`.
2. Read [agent rules](docs/system/agents.md) and
   [delivery rules](docs/system/delivery.md) for shared policy.
3. Run `just check` before editing and again after editing. Report any check
   that could not run.

## Commands and checks

- `just lint`: markdownlint-cli2 0.23.2 over Markdown files.
- `just test`: lychee checks local Markdown links offline.
- `just build`: no build output in this docs repo.
- `just check`: lint, test, build; `just fix` applies Markdown fixes.
- CI also runs `markdown-lint`, `link-check`, `actionlint`, and `pr-title`.
  See [CI](docs/ci.md) for the exact workflow behavior and pins.

Install `just` with `winget install Casey.Just`; use Node.js/npm for the pinned
Markdown runner and install lychee separately. Do not add a package manifest
only to run this repo's Markdown check.

## Layout and protected paths

- `templates/` contains files copied into other repos. Keep placeholders
  intentional and verify any changed starter in its own context.
- `scripts/` and `rulesets/` control setup and verification. Test behavior
  changes before editing implementation.
- `.github/workflows/` and `docs/ci.md` define checks and pins; preserve check
  names and full action SHAs.
- Do not edit `LICENSE`, brand art or source, protected site data, rulesets,
  security settings, or CI permissions without task-specific authorization.
- Never open, print, or copy secrets, credentials, or `.env` files.

## Remote actions

For each new task, name the repository, target branch and scope, and follow
the owner's selected publishing mode under AG-001 in the shared agent policy.
If no mode is selected, ask before publishing. Checks and review approval do
not supply owner merge permission. Other gated actions need named approval;
never expose secrets.
Follow the [shared authority and evidence rules](docs/system/agents.md#safety-floor).

## Review guidelines

Follow the [reviewer policy](docs/system/reviewers.md). CodeRabbit is the sole
automatic reviewer after named owner activation; secondary reviewers need
named, scoped requests. Findings need actionable evidence and never authorize
gated actions. Preserve required CI, frozen inputs, zero PR test retries, no
stacks or queue and at most three waiting PRs. Effective account settings and
technical enforcement remain UNVERIFIED until observed.

## Verify and close out

- Run relevant local checks and inspect the diff for accidental paths.
- Record the command and exit result; never claim an unrun check passed.
- Use the [evidence template](templates/agent/evidence.template.md); relevant
  edits require affected checks and scoped re-review.
- Add one dated line to `docs/lessons.md` after a work session.
