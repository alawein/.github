# CI standard

How the reusable workflows in this repo work, and how to keep their pins
current. One place to fix, one pin to bump. Which checks are required, and why,
is in [delivery.md](system/delivery.md), "Merging and checks". Do not copy that
list here.

## Use it

`scripts/new-repo.ps1` already puts the right stub in a new repo. Use these
steps to add one by hand.

1. Pick the stub for the class (next section).
2. Copy it from `templates/workflows/` to `.github/workflows/ci.yml`.
3. Set the pin after each `@` to a full commit SHA of `alawein/.github` (see
   "After the first commit" and "Bump a pin").
4. Copy the matching `templates/dependabot-*.yml` to `.github/dependabot.yml`.
5. Run `scripts/setup-repo.ps1`. It requires the check names that `ci.yml`
   defines.

## Which workflow runs where

| Class | Stub | Dependabot file | Test check |
| --- | --- | --- | --- |
| profile, docs | `docs.yml` | `dependabot-actions.yml` | none |
| tool in TypeScript | `node.yml` | `dependabot-npm.yml` | `node-ci` |
| tool in Python, lab | `python.yml` | `dependabot-pip.yml` | `python-ci` |
| site | `site.yml` | `dependabot-npm.yml` | `node-ci` |

| Reusable workflow | Check it backs | Runs |
| --- | --- | --- |
| `lint-markdown.yml` | `markdown-lint` | Every class |
| `check-links.yml` | `link-check` | Every class |
| `lint-actions.yml` | `actionlint` | Every class |
| `pr-title.yml` | `pr-title` | Every class |
| `node-ci.yml` | `node-ci` | `npm ci`, lint, test, build |
| `python-ci.yml` | `python-ci` | uv or pip, ruff, pytest |

CodeQL is not a workflow here. Turn it on with GitHub's default setup
(Settings, Code security) on public repos.

## Reusable workflow inputs

`node-ci.yml` defaults `require-test` to `false`, so optional callers retain
`npm test --if-present`. Callers for code classes can opt in with
`require-test: true` and must also set `run-test: true`. The guard fails before
install with a diagnostic if execution is disabled or `package.json` lacks a
nonempty `scripts.test` string. The mandatory branch runs `npm test` without
`--if-present` and propagates the test command's failure.

`check-links.yml` defaults `offline` to `false`, preserving external checking
for existing callers when they update their kit pin. Deliberately migrating
PR checks to `offline: true` requires a paired scheduled external scan using
`offline: false`. This API does not establish that distributed templates or
consumer repositories have completed that migration.

## Check names and gate jobs

A called workflow reports its checks as `<caller job> / <called job>`, for
example `run-markdown-lint / lint`. A ruleset needs the bare name. So each
caller file ends with small gate jobs named exactly `markdown-lint`,
`link-check`, `actionlint`, and `pr-title` (plus `node-ci` or `python-ci`). A
gate passes only if the job it waits on passed. `pr-title` also passes when the
title check is skipped, which happens on push to `main`.

The names are identical in `ci.yml`, every stub, the rulesets,
`setup-repo.ps1`, and `verify-repo.ps1`. The profile repo runs the same four
checks inline.

## Archive guard

Every reusable workflow starts with a job named `archive-guard`. It fails when
the repository name starts with `ARCHIVE-`, and every other job in the file
lists it under `needs`. The job is in [archive.md](archive.md), Layer 4. Copy
it unchanged into any new reusable workflow.

## After the first commit

The caller stubs in `templates/workflows/` (`docs.yml`, `node.yml`,
`python.yml`, `site.yml`) and the `ci.yml` files in `templates/starters/` pin
`alawein/.github` itself. Done on 2026-09-30: they pin the first commit,
`a2f16663330afe2bd8ac4ee548121f495e866e4c`, tagged `v1.0.0`, and the banner
comment is gone. Before that they carried an all-zero placeholder SHA that
failed on purpose, so no caller ran unpinned code. The steps, for the record:

1. Get the SHA: `gh api repos/alawein/.github/commits/main --jq .sha`.
2. Replace every all-zero SHA in the stubs and starters with it.
3. Tag the commit `v1.0.0` so the `# v1.0.0` comment next to each pin is true.
4. Later bumps follow "Bump a pin".

## Permission rules

- Every workflow sets `permissions: contents: read` at the top. Raise a
  permission per job, never for the whole file. A job that needs no token
  (`archive-guard`, the gate jobs) sets `permissions: {}`.
- A reusable workflow can only lower what its caller grants. If a callee needs
  more than the caller job has, the call fails. So the caller job must grant
  `pull-requests: read` for `pr-title.yml`.
- Checkout always uses `persist-credentials: false`. No workflow needs to push.
- No secrets in these workflows. The automatic `secrets.GITHUB_TOKEN` is the
  only credential.
- Every job has `timeout-minutes`.
- Concurrency cancels older runs on the same PR. Runs on `main` are never
  canceled.
- Each reusable workflow uses its own concurrency prefix, so it never clashes
  with the caller's group.

## Pin policy

- Every `uses:` points to a full 40-character commit SHA, with the tag in a
  trailing comment. A tag can be moved. A SHA cannot.
- After the first green run in a repo, turn on the setting that rejects
  unpinned actions (`sha_pinning_required`). `setup-repo.ps1
  -EnableShaPinning` does it.
- [pins.md](pins.md) lists every pin, the date it was verified, and its source.
- Dependabot (`github-actions` ecosystem, weekly, 7-day cooldown) proposes
  bumps as one grouped PR. This repo's own `.github/dependabot.yml` does the
  same for the workflows here.
- Two pins are not `uses:` lines and need a manual bump: the actionlint version
  and sha256 in `lint-actions.yml`, and the default `uv-version` in
  `python-ci.yml`. The list is in `pins.md`.

## Bump a pin

Third-party action, in this repo:

1. Read the release notes of the new tag.
2. Confirm the SHA: `gh api repos/<owner>/<repo>/commits/<tag> --jq .sha`.
3. Replace the SHA and the tag comment in every workflow that uses it. Search
   the repo for the old SHA.
4. Update the row in `pins.md`.
5. Open a PR. The required checks run on it.

`alawein/.github` itself, in a caller repo:

1. Get the SHA of the commit you want:
   `gh api repos/alawein/.github/commits/main --jq .sha`.
2. Replace every `@<sha>` in `.github/workflows/ci.yml` and the tag comment.
3. Open a PR in the caller repo.

Tag `alawein/.github` (`v1.0.0`, `v1.1.0`, ...) after each change to a reusable
workflow, so the comment next to a pin says something a reader can check.

## Why `pull_request` and never `pull_request_target`

`pull_request` runs the workflow from the PR's own merge commit with a
read-only token and no secrets when the PR comes from a fork.
`pull_request_target` runs with a write token and the repo's secrets, so it
must never check out or run code from the PR. The checks here only read files
and lint them, so `pull_request` is enough. Do not add `pull_request_target` to
any workflow in this repo or in a caller repo.

## Fork PR behavior

- The token is read-only and secrets are empty. All the checks in this kit work
  with that.
- A first-time contributor's run waits for the owner's approval. Keep the repo
  setting on "Require approval for first-time contributors".
- Dependabot PRs get a read-only token too. That is enough here.

## Defaults worth knowing

- `lint-markdown.yml`: if the repo has no markdownlint config, it uses one that
  turns off line length (MD013) and first-line heading (MD041) for that run. A
  repo config replaces it.
- `check-links.yml`: accepts status 200 to 299 only, and retries a failing link
  3 times, 10 seconds apart. Put ignored URL patterns in a `.lycheeignore` file
  at the repo root.
- `pr-title.yml`: runs `amannn/action-semantic-pull-request` with no inputs and
  no custom regex, so the action's defaults apply. It accepts
  `feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert`, an optional
  scope, an optional `!`, then a colon, a space, and any subject. House rules are stricter
  (six types, 72 characters) and are in delivery.md. The action does not check
  length.
- `node-ci.yml`: `npm ci`, then lint, test, and build. Optional scripts use
  `--if-present`; `require-test: true` requires and runs a nonempty test
  script. Inputs: `node-version`, `working-directory`, `run-lint`,
  `run-test`, `run-build`, `require-test`.
- `python-ci.yml`: with `uv`, `uv sync --locked` then `ruff check`,
  `ruff format --check`, `pytest`. With `pip`, the requirements file must list
  ruff and pytest. Inputs: `python-version`, `installer`, `uv-version`,
  `requirements-file`, `working-directory`, `run-lint`, `run-test`.

## Decisions

- Decision: gate jobs carry the required check names. Why: a called job reports
  as `caller / called`, and the ruleset needs the bare names.
- Decision: `pr-title.yml` sets no custom regex. Why: the profile repo uses the
  action's defaults, and this kit must match it.
- Decision: npm only in `node-ci.yml`. Why: every current repo uses npm, and
  pnpm or yarn would add another pinned action.
- Decision: `node-version` defaults to `lts/*`. Why: it needs no upkeep. A repo
  that must freeze a version passes one.
- Decision: `python-version` defaults to `3.13`. Why: the newest release many
  libraries fully support.
- Decision: the `uv` version is pinned by default. Why: a moving uv makes a
  green run hard to reproduce.
- Decision: the site stub matches the TypeScript tool stub. Why: Vercel builds
  and deploys, so CI only proves that lint, tests, and the build pass.
- Decision: stub pins use an all-zero SHA until the first commit exists. Why:
  `alawein/.github` has no SHA yet, and a zero SHA fails loudly instead of
  running unpinned code.
