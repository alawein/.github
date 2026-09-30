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
| Install | `winget install Casey.Just` |
| Run | `just --list` |
| Test | `just test` |
| Lint | `just lint` |
| Build | `just build` |
| All checks (run before every PR) | `just check` |

Shell: PowerShell on Windows, bash in CI.

## Layout

| Path | What is in it |
| --- | --- |
| `README.md` | Front door. Links every page in `docs/` |
| `docs/overview.md` | First page. Add one page per topic and link it from `README.md` |
| `docs/` | Docs. `docs/lessons.md` is the lessons log |

## Rules for this repo

- Plain words, short sentences, American spelling, no em dashes. A fact has one home: link to it, never copy it.
- Every page is linked from `README.md`. A page holds one topic.
- Behavior changes come with a test, written first.
- One topic per PR, about 300 changed lines or fewer.

## Do not touch without asking

- `LICENSE`, if the repo has one.
- `.markdownlint-cli2.yaml` and `.lycheeignore`. Fix the text, not the lint rule.
- Rulesets, branch protection, and CI permissions.
- Secrets, `.env` files, and anything that holds credentials. Never open
  them, print them, or copy them into a file.

## Remote actions

Mode: push branches and open draft PRs.

The owner's typed words come first for: spending money, rotating or exposing a
secret, permanently deleting data or a repo, sending anything other people
will read, and touching anyone else's repo. Only the owner merges.

## Verify before you say done

- Run `just check`. Paste the commands and results into the PR's Test
  evidence section.
- Open each page you changed and follow every link you added.
- No "done" without command output. If a check could not run, say "not run"
  and why.

## Skills

None yet. A repo skill lives at `.claude/skills/NAME/SKILL.md` and is listed here by name.

## Known traps

- The link check needs the network. A failure on a new external link may be a typo or a site that is down. Open the link before you touch the ignore file.
- The README opens with a picture element, not a heading. Do not add a title line above it.

## Close out

1. Open the PR from the template. Describe the change and its checks only.
2. Add one line to `docs/lessons.md`.
3. Leave no stray files: stage named paths only, never `git add -A`.
