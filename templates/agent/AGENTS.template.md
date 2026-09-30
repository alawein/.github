# {{REPO_NAME}}

{{ONE_LINE: what this repo is and who uses it.}}

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
| Install | `{{INSTALL_COMMAND}}` |
| Run | `{{RUN_COMMAND}}` |
| Test | `{{TEST_COMMAND}}` |
| Lint | `{{LINT_COMMAND}}` |
| Build | `{{BUILD_COMMAND}}` |
| All checks (run before every PR) | `{{CHECK_COMMAND}}` |

Shell: {{SHELL: for example PowerShell on Windows, bash in CI}}.

## Layout

| Path | What is in it |
| --- | --- |
| `{{PATH_1}}` | {{WHAT_1}} |
| `{{PATH_2}}` | {{WHAT_2}} |
| `docs/` | Docs. `docs/lessons.md` is the lessons log |

## Rules for this repo

- {{RULE_1: a style or pattern to copy, with a file to copy it from.}}
- {{RULE_2: a naming or structure rule the tools do not enforce.}}
- Behavior changes come with a test, written first.
- One topic per PR, about 300 changed lines or fewer.

## Do not touch without asking

- {{PROTECTED_1: generated files, vendored code, migrations, lockfiles by hand.}}
- {{PROTECTED_2}}
- Rulesets, branch protection, and CI permissions.
- Secrets, `.env` files, and anything that holds credentials. Never open
  them, print them, or copy them into a file.

## Remote actions

Mode: {{MODE: "push branches and open PRs" or "local only"}}.

The owner's typed words come first for: spending money, rotating or exposing a
secret, permanently deleting data or a repo, sending anything other people
will read, and touching anyone else's repo. Only the owner merges.

## Verify before you say done

- Run `{{CHECK_COMMAND}}`. Paste the commands and results into the PR's Test
  evidence section.
- {{EXTRA_VERIFY: for a web app, open it and check the changed page. For a
  library, run the example.}}
- No "done" without command output. If a check could not run, say "not run"
  and why.

## Skills

{{List repo skills by name and path, or write "none".}}

## Known traps

- {{TRAP_1: a thing that looks right and is wrong here, and what to do.}}
- {{TRAP_2}}

## Close out

1. Open the PR from the template. Describe the change and its checks only.
2. Add one line to `docs/lessons.md`.
3. Leave no stray files: stage named paths only, never `git add -A`.
