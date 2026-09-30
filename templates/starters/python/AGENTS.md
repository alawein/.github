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
| Install | `uv sync` |
| Run | `uv run {{name}}` |
| Test | `just test` |
| Lint | `just lint` |
| Build | `just build` |
| All checks (run before every PR) | `just check` |

Shell: PowerShell on Windows, bash in CI.

## Layout

| Path | What is in it |
| --- | --- |
| `src/{{module}}/` | The package. `cli.py` is the entry point |
| `tests/` | pytest tests, one file per module |
| `docs/` | Docs. `docs/lessons.md` is the lessons log |

## Rules for this repo

- Type-hint every public function. Copy the style of `src/{{module}}/cli.py`.
- Mark a test that needs the network or runs long with `@pytest.mark.slow`. `just test` skips it.
- Behavior changes come with a test, written first.
- One topic per PR, about 300 changed lines or fewer.

## Do not touch without asking

- `uv.lock` by hand. Change it only with `uv sync` or `uv lock`.
- Dependencies in `pyproject.toml`. Say why in the PR before you add one.
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
- Run `uv run {{name}}` once and check its output.
- No "done" without command output. If a check could not run, say "not run"
  and why.

## Skills

None yet. A repo skill lives at `.claude/skills/NAME/SKILL.md` and is listed here by name.

## Known traps

- CI runs `uv sync --locked`, which fails if `uv.lock` is stale. Commit the lock with the dependency change.
- The package needs Python 3.13 or newer. Do not run it on an older interpreter.

## Close out

1. Open the PR from the template. Describe the change and its checks only.
2. Add one line to `docs/lessons.md`.
3. Leave no stray files: stage named paths only, never `git add -A`.
