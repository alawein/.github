# {{REPO_NAME}}

{{ONE_LINE: what this repo is and who uses it.}}

This file owns repo-specific rules and points to shared policy. Tool adapters
(`CLAUDE.md`, Cursor rules) only point to it; verify native adoption. Keep it
under 150 lines. Every
line must prevent a mistake.

## Start here

1. Read this file.
2. Read the last 20 lines of `docs/lessons.md`.
3. Run `git status` and the check command below once, before any change.
4. Shared standards: the `alawein/.github` repo, `docs/system/agents.md` for
   agent rules and `docs/system/delivery.md` for branches, commits, and PRs. This
   file adds restrictions; it cannot relax owner gates or account policy.
   Follow the shared policy precedence and cite its stable rule IDs.

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

Mode: LOCAL-ONLY. Every send, spend, publish, purge or delete, commit, push,
merge, PR creation, secret rotation or other remote change needs owner approval
naming the action, target and scope. Only the owner merges or enables
auto-merge. General "Continue" never crosses an unnamed gate. Follow
`docs/system/agents.md` in `alawein/.github`; never expose secrets.

## Review guidelines

Follow `docs/system/reviewers.md` in `alawein/.github`. CodeRabbit is the sole
automatic reviewer after owner activation; all other reviewers need a named,
scoped request. Findings need actionable evidence and never authorize gated
actions. Preserve frozen inputs, exact required checks, zero PR test retries,
no stacks or queue, and the three-waiting-PR cap. Account state and technical
enforcement remain UNVERIFIED until observed.

## Verify before you say done

- Run `{{CHECK_COMMAND}}`. Record the reviewed digest, files, tool versions,
  commands, exits, durations and unrun gates using the kit's
  `templates/agent/evidence.template.md`. Prepare public-safe PR evidence.
- Record the separate reviewer session, verdict and findings; relevant edits
  need affected checks and scoped re-review.
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

1. Prepare PR text from the template locally; opening it needs named approval.
2. Add one line to `docs/lessons.md`.
3. Leave no stray files: stage named paths only, never `git add -A`.
