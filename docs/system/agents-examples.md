# Task brief examples

Five sample briefs for an agent or a helper. The rules they follow are in
[agents](agents.md). The repos and files below are made up.

## What a good brief contains

- Goal: the outcome and the reason, in one or two sentences.
- Scope: the exact paths the agent may touch, and what is off limits.
- Inputs: where to look (files, issue, error text), so it does not search blind.
- Done check: the commands that must pass, and what "pass" looks like.
- Limits: a cap on size or tool calls, and when to stop and ask.
- Output: where the result goes (files, a PR, a short report) and its shape.

A brief that leaves one of these out gets a guess in its place.

## 1. Bug fix

```text
Goal: fix the crash when `parse_range("")` is called. Users see a stack trace
instead of an empty result.
Scope: src/parser/range.py and tests/test_range.py only.
Inputs: the trace is in issue 41. The caller is src/cli/run.py, line 88.
Done check: add a test for the empty string that fails first. Then
`pytest tests/test_range.py` and the repo check command both pass. Paste the
failing run and the passing run.
Limits: under 40 changed lines. If the fix needs a change to the caller, stop
and ask.
Output: one PR titled `fix(parser): handle empty range`. Test evidence lists
both runs.
```

## 2. Small feature

```text
Goal: add a `--dry-run` flag to the sync command so a user can see what would
change. Today the command always writes.
Scope: src/cli/sync.py, src/cli/options.py, tests/test_sync.py, and the
"Usage" section of README.md.
Inputs: copy the flag style from `--verbose` in options.py. The write calls
are in sync.py, lines 50 to 90.
Done check: a test shows that with the flag nothing is written and the plan is
printed. The repo check command passes.
Limits: about 120 changed lines. No new dependency. Do not rename any
existing flag.
Output: one PR titled `feat(cli): add dry-run flag to sync`, with a
CHANGELOG bullet under Added.
```

## 3. Refactor with helpers

```text
Goal: move the three date helpers out of `utils.py` into `dates.py`, and update
every import. Behavior must not change.
Lead plan: first list every file that imports those helpers (cheap tier).
Helper A owns src/api/*.py. Helper B owns src/jobs/*.py. Helper C owns
tests/. The lead owns utils.py, dates.py, and the final merge.
Helper brief: edit only the files you own, change imports only, run the tests
for your folder, and write a short report (under 200 words) listing each file
you changed. Do not commit.
Lead checks: after each helper, list the changed files and read the diff. Run
the full check command on the merged result. Confirm with a search that no
old import is left.
Done check: the full test suite passes with the same test count as the
baseline.
Output: one PR titled `refactor(utils): move date helpers to dates`.
```

## 4. Docs fix

```text
Goal: the install steps in README.md fail on a clean machine. Fix them and
prove it.
Scope: README.md and docs/install.md only.
Inputs: the error is in issue 52 (a missing step before `npm run build`).
Done check: follow the steps in a fresh clone, in order, and paste the last
ten lines of output. Then run the markdown and link checks from the repo check
command.
Limits: do not rewrite sections that work. No new pages.
Output: one PR titled `docs(readme): fix install steps`. Test evidence is the
fresh-clone run.
```

## 5. Read-only audit

```text
Goal: find every place the repo reads an environment variable, so we can
document them.
Scope: read only. Change nothing. Use the cheap model tier.
Inputs: search src/ and scripts/ for the usual patterns (`process.env`,
`os.environ`, `getenv`).
Done check: a table with variable name, file and line, whether it has a
default, and whether the code breaks without it.
Limits: 25 tool calls. If a file is generated or vendored, list it and skip it.
Never print a variable's value.
Output: write the table to docs/env-vars.md in the repo, then a report of
under 100 words that says how many variables you found and what you could not
check.
```
