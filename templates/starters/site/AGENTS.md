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
   file adds to them and wins on conflict for this repo only.

## Commands

| Task | Command |
| --- | --- |
| Install | `npm install` |
| Run | `npm run dev` |
| Test | `npm test` |
| Lint | `npm run lint` |
| Build | `npm run build` |
| All checks (run before every PR) | `npm run check` |

Shell: PowerShell on Windows, bash in CI.

## Layout

| Path | What is in it |
| --- | --- |
| `src/pages/` | Astro pages. One file per route |
| `src/lib/` | Pure logic, with tests next to it as `*.test.ts` |
| `docs/` | Docs. `docs/lessons.md` is the lessons log |

## Rules for this repo

- Keep logic in `src/lib/` with a test next to it. Pages only call it. Copy `src/lib/slugify.ts` and its test.
- Variable names go in the README under Environment, never values. A value the browser reads needs the public prefix, and no secret gets one.
- Behavior changes come with a test, written first.
- One topic per PR, about 300 changed lines or fewer.

## Do not touch without asking

- `vercel.json` and the Vercel project settings. A bad redirect or header reaches production.
- `package-lock.json` by hand. Change it only with `npm install`.
- Rulesets, branch protection, and CI permissions.
- Secrets, `.env` files, and anything that holds credentials. Never open
  them, print them, or copy them into a file.

## Remote actions

Mode: push branches and open draft PRs.

The owner's typed words come first for: spending money, rotating or exposing a
secret, permanently deleting data or a repo, sending anything other people
will read, and touching anyone else's repo. Only the owner merges.

## Verify before you say done

- Run `npm run check`. Paste the commands and results into the PR's Test
  evidence section.
- Open the preview URL from the PR and check the page you changed. Put the URL in the PR.
- No "done" without command output. If a check could not run, say "not run"
  and why.

## Skills

None yet. A repo skill lives at `.claude/skills/NAME/SKILL.md` and is listed here by name.

## Known traps

- A redirect starts temporary (307). Never switch it to 308 before 7 clean days.
- `npm run lint` includes `astro check`, so a type error in a page fails lint.

## Close out

1. Open the PR from the template. Describe the change and its checks only.
2. Add one line to `docs/lessons.md`.
3. Leave no stray files: stage named paths only, never `git add -A`.
