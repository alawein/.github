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

Stack naming and structure guidance lives in `docs/system/repos.md#stack-conventions`
in `alawein/.github`. Follow the current framework and package layout; do not
copy the shared guidance into this instruction file.

## Commands

| Task | Command |
| --- | --- |
| Install | `uv sync` |
| Run | `see README.md, Reproduce` |
| Test | `just test` |
| Lint | `just lint` |
| Build | `just build` |
| All checks (run before every PR) | `just check` |

Shell: PowerShell on Windows, bash in CI.

## Layout

| Path | What is in it |
| --- | --- |
| `src/{{module}}/` | Pure logic. No files or network calls in `core.py` |
| `results/` | Outputs. Each one rebuilds from the commands in `README.md` |
| `docs/` | Docs. `docs/lessons.md` is the lessons log |

## Rules for this repo

- One question per repo. It is in the README. A change that does not serve it belongs in another repo.
- Never edit a result by hand. Rebuild it with the README commands. Log what you tried, failures too, in `NOTES.md`, newest first.
- Behavior changes come with a test, written first.
- One topic per PR, about 300 changed lines or fewer.

## Do not touch without asking

- `data/`. Large or private data is never committed. The README says where it comes from.
- `results/`. Regenerate, do not hand-edit.
- Rulesets, branch protection, and CI permissions.
- Secrets, `.env` files, and anything that holds credentials. Never open
  them, print them, or copy them into a file.

## Remote actions

For each new task, name the repository, target branch and scope, and follow
the owner's selected publishing mode under AG-001 in the shared agent policy.
If no mode is selected, ask before publishing. Checks and review approval do
not supply owner merge permission. Other gated actions need named approval;
never expose secrets.

## Verify before you say done

- Run `just check`. Paste the commands and results into the PR's Test
  evidence section.
- Rerun the README commands for any result you changed and compare the output.
- No "done" without command output. If a check could not run, say "not run"
  and why.

## Skills

None yet. A repo skill lives at `.claude/skills/NAME/SKILL.md` and is listed here by name.

## Known traps

- Seed anything random. A flaky test is fixed or deleted the same day.
- A lab with no commit for 90 days is promoted to a tool repo or archived. Do not let it sit.

## Close out

1. Prepare PR text from the template; open it only within the selected mode.
2. Add one line to `docs/lessons.md`.
3. Leave no stray files: stage named paths only, never `git add -A`.
