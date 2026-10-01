# {{name}}

{{description}}

This file is the one source of truth for any AI agent working here. Tool files
(`CLAUDE.md`, Cursor rules) only point to it. Keep it under 150 lines. Every
line must prevent a mistake.

## Start here

1. Read this file.
2. Read the last 20 lines of `docs/lessons.md`.
3. Run `git status` and the check command below once, before any change.
4. Shared standards: the `alawein/.github` repo, `docs/system/agents.md` for
   agent rules and `docs/system/delivery.md` for branches, commits, and PRs. This
   file adds restrictions; it cannot relax owner gates or account policy.
   Follow AG-002 in the shared agent policy for precedence.

## Commands

| Task | Command |
| --- | --- |
| Install | `npm install` |
| Run | `npm run build && node dist/index.js` |
| Test | `npm test` |
| Lint | `npm run lint` |
| Build | `npm run build` |
| All checks (run before every PR) | `npm run check` |

Shell: PowerShell on Windows, bash in CI.

## Layout

| Path | What is in it |
| --- | --- |
| `src/` | Source. Tests sit next to the code as `*.test.ts` |
| `dist/` | Build output. Never commit it |
| `docs/` | Docs. `docs/lessons.md` is the lessons log |

## Rules for this repo

- Tests sit next to the code. Copy the pattern in `src/index.test.ts`.
- Every exported function has a test. Name a file for what it does, never `utils` or `helpers`.
- Behavior changes come with a test, written first.
- One topic per PR, about 300 changed lines or fewer.

## Do not touch without asking

- `package-lock.json` by hand. Change it only with `npm install`.
- `dist/`. It is generated.
- Rulesets, branch protection, and CI permissions.
- Secrets, `.env` files, and anything that holds credentials. Never open
  them, print them, or copy them into a file.

## Remote actions

Mode: LOCAL-ONLY. Follow AG-001 in the shared agent policy.

Every send, spend, publish, purge or delete, commit, push, merge, PR creation,
secret rotation or other remote change needs owner approval naming the action,
target and scope. Only the owner merges or enables auto-merge. General
"Continue" never crosses an unnamed gate. Never expose secrets.

## Verify before you say done

- Run `npm run check`. Paste the commands and results into the PR's Test
  evidence section.
- Run `npm run build`, then import the built package once and call the export.
- No "done" without command output. If a check could not run, say "not run"
  and why.

## Skills

None yet. A repo skill lives at `.claude/skills/NAME/SKILL.md` and is listed here by name.

## Known traps

- `npm run lint` includes the type check, so a type error fails lint.
- CI installs with `npm ci`, which fails if `package-lock.json` and `package.json` disagree. Commit both together.

## Close out

1. Prepare PR text from the template locally; opening it needs named approval.
2. Add one line to `docs/lessons.md`.
3. Leave no stray files: stage named paths only, never `git add -A`.
