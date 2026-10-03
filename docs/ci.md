# CI standard

How the reusable workflows in this repo work, and how to keep their pins
current. One place to fix, one pin to bump. Which checks are required, and why,
is in [delivery.md](system/delivery.md), "Merging and checks". Do not copy that
list here.

## Use it

`scripts/new-repo.ps1` already puts the right stub in a new repo. Use these
steps to add one by hand.

1. Pick the stub for the class (next section).
2. Copy it from `templates/workflows/` to `.github/workflows/ci.yml`, and copy
   `check-links-nightly.yml` from the same folder beside it.
3. Set the pin after each `@` to a full commit SHA of `alawein/.github` (see
   "After the first commit" and "Bump a pin").
4. Copy the matching `templates/dependabot-*.yml` to `.github/dependabot.yml`.
5. Run `scripts/setup-repo.ps1`. It requires the check names that `ci.yml`
   defines.

For the approved private TypeScript hub `alawein/career-engine`, the local
`-CheckProfile hub-check` option reads `.github/workflows/check.yml` and expects
the single `check` job. The default `standard` profile keeps the class-specific
`ci.yml` checks. The hub profile refuses other repo, class, or language values.
Both setup and verification fail when the hub workflow or job is missing.
`rulesets/main-hub.json` and `rulesets/main-site.json` are local branch policy
templates; a setup dry run only prints its proposed writes. Use of the hub
option for owner setup remains gated on this extension merging and a green hub
CI run.

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
| `pr-policy.yml` | `pr-policy` (opt-in) | Branch and ready-PR linkage metadata |
| `hygiene.yml` | Advisory scheduled report | Read-only repository observations |
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
`offline: false`. The kit and distributed stubs/starters explicitly use the paired policy.
An existing consumer must copy both files when migrating.

`pr-policy.yml` requires `kit-ref` to be a full lowercase
40-character SHA from a reviewed kit release when called by another repository.
Pass the same SHA used on the workflow's `uses:` line. This workflow checks out
`alawein/.github` at that validated ref, never the caller's policy script. Only
same-repository kit self-tests may omit the input and use the current SHA.
Both metadata workflows use Python `3.12.10`, standard-library scripts and
read-only credentials.

The policy script reads `GITHUB_EVENT_PATH`; PR prose is never interpolated into
shell commands. It checks branch naming on drafts and ready PRs, and checks
linkage when ready. Callers must include `ready_for_review` and
`converted_to_draft` alongside opened, edited, synchronize and reopened events.
Missing or malformed PR metadata fails. Explicit push events succeed without
PR linkage. The existing title producer retains its behavior.

The kit runs metadata fixtures and an always-report `pr-policy` gate that
requires successful policy and test producers, including on push to main.
Cancellation, failure or skipped producers cannot pass this gate. The original
four required contexts and distributed v1.2.0 pins remain unchanged. Other
consumers opt in after a reviewed signed release. Require `pr-policy` in live
rules only after observing an eligible successful PR run at its current SHA.

`hygiene.yml` accepts `expected-required-checks`, a comma-separated list defaulting
to the original four contexts; it has no `kit-ref` input. Callers pin the reviewed
workflow release SHA on `uses:`. Released v1.3.0 separately pins audit source to
implementation commit `ce04a21e332e42c3137b26f3becb0de77086b6cb`.
The current source workflow pins `63f7c5cd0a24a99018fc8e0997579449813e6030`;
the kit's local weekly caller uses it after merge. Unchanged v1.3.0 callers
retain the released implementation. Caller input cannot select executable code.
Audit source changes require review and a coordinated implementation pin and
source-digest fixture update. Read-only repository permissions alone do not
restrict the runner's cache token; no cache-mode enforcement is claimed.
Its caller grants `contents: read` and
`pull-requests: read`; its existing automatic token becomes in-memory `GH_TOKEN`.
It uses GET-only REST calls and paginates lists. The current-source audit observes
classic protection and ruleset rules/checks separately, with their endpoint
coverage. Combined
fields are null unless both views are known; incomplete views cannot establish
missing protection. Producer IDs retain their source; null/-1 means no bound
app, not independent review. Classic approval count zero does not prove human
approval. Bypass actors cover active rulesets (including inherited rulesets),
not classic bypass policy; classic administrator enforcement is separate.
The report also observes squash flags,
ready PR count and branches without open PRs whose last commit is 30 days old.
Commit age does not prove branch creation age. A per-repository report cannot
enforce the global three-PR admission limit.

Reports go to the job log, step summary and runner-local JSON, with no artifact
upload or mutating API. Observed drift is `WARN`; denied, malformed or incomplete
data is `UNKNOWN` and exits nonzero. An empty observed response is distinct from
unavailable data. `hygiene-weekly.yml` is the kit's weekly/manual caller; a
schedule declaration does not prove a successful scheduled run.

The existing hosted token may lack [Administration read](https://docs.github.com/en/rest/branches/branch-protection#get-branch-protection)
for the classic endpoint. Preserve UNKNOWN instead of expanding permissions
to obtain a complete report. Configured protection is separate from eligible
PR execution, check conclusions, signing, artifact behavior and production.
The PR-title gate permits a skipped producer only on an actual main-push event.

## Opt in to PR policy and hygiene

The new opt-in callers use signed annotated `v1.3.0`, verified on 2026-10-01
at `b5f8bc3a916b41e22e5e09ec72f34c01428c2933`. Existing stubs and generated
starters retain their v1.2.0 pins and default checks.

Adoption has two phases: `v1.3.0` supplies the released reusable workflow
code; reviewed kit main supplies the follow-on templates and `-RequirePrPolicy`
setup/verification support. Copy those templates and run the helpers from
reviewed main after adoption merges; retain the released workflow pins.

1. Merge the two jobs in
   [pr-policy.jobs.yml](../templates/workflows/pr-policy.jobs.yml) under the
   existing `jobs:` in `.github/workflows/ci.yml`. This is a fragment, never
   a standalone workflow. Retain every existing producer and bare gate.
2. Set `pull_request.types` to
   `[opened, edited, synchronize, reopened, ready_for_review, converted_to_draft]`.
   Retain push to main, concurrency and top-level `contents: read`.
3. Keep the full release SHA identical in the policy `uses:` and `kit-ref`.
   The bare `pr-policy` gate requires success; failed, cancelled, skipped or
   absent producer results fail. Released kit fixtures run in the kit.
4. Copy [hygiene-weekly.yml](../templates/workflows/hygiene-weekly.yml) beside
   CI. Its `uses:` pins the same release. It has no `kit-ref`; the released
    workflow uses v1.3.0's independently reviewed literal audit-source pin above.
5. Set hygiene's `expected-required-checks` to current effective contexts:
   the original four, plus `node-ci` or `python-ci` for code classes. Add
   `pr-policy` only after its live required-context promotion. The kit caller
   expects all five contexts; the distributed template starts with four.
6. Run actionlint on the complete assembled workflows and the consumer's
   existing checks. Observe an eligible successful PR policy check at the
   current head before changing live required contexts.

`Get-CheckPolicy`, `setup-repo.ps1` and `verify-repo.ps1` accept
`-RequirePrPolicy`, defaulting off. It appends one context after the complete
class list and keeps the workflow path and strictness calculation. The switch
refuses `hub-check` before GitHub calls. Private repos also need explicit
`-Strict`, unless class `site` already implies it. Verification without
`-Class` still requires the original four plus policy when opted in, while
allowing unknown language contexts. Missing gates and placeholder pins fail
opt-in readiness. The checked-in ruleset JSON templates remain unchanged.

Setup plans whole-repo settings, labels and rulesets; it is for owner-approved
bootstrap, not narrow live promotion. For an existing repo, save its live
ruleset JSON and add only `pr-policy` after eligible success, then read back
required contexts, signing, bypass and merge fields. Preserve existing class
checks, security, reviewer, label and permission settings. No site adoption
follows automatically.

For a manual 20-PR review sample, use the
[review observations template](../templates/agent/review-observations.template.md).
Record measured results and source evidence; no automated writes or spend.

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

Current distributed pins use verified `v1.2.0` at
`6f6dbe7f3a23ab830a32007bb52b83fd1bb40563`; its required checks passed before tagging.
This release preserves `require-test` and paired local/external link inputs, and fixes recursive link patterns at the Bash action boundary.

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
- Active kit jobs use `ubuntu-24.04`; hosted image software still changes.
- Concurrency cancels older runs on the same PR. Runs on `main` are never
  canceled.
- Each reusable workflow uses its own concurrency prefix, so it never clashes
  with the caller's group.

## Pin policy

- External actions and reusable workflow calls pin full 40-character commit
  SHAs, with the tag in a trailing comment. Same-repository `./` calls use
  the current revision. A tag can be moved. A SHA cannot.
- After the first green run in a repo, turn on the setting that rejects
  unpinned actions (`sha_pinning_required`). `setup-repo.ps1
  -EnableShaPinning` does it.
- [pins.md](pins.md) lists every pin, the date it was verified, and its source.
- Dependabot (`github-actions` ecosystem, weekly, 7-day cooldown) proposes
  bumps as one grouped PR. This repo's own `.github/dependabot.yml` does the
  same for the workflows here, caps version PRs at one, and explicitly groups
  version updates. Security updates are outside that limit and cooldown.
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
2. Replace every `@<sha>` and tag comment in both `.github/workflows/ci.yml`
   and `.github/workflows/check-links-nightly.yml`.
3. Open a PR in the caller repo.

Tag `alawein/.github` (`v1.0.0`, `v1.2.0`, ...) after each change to a reusable
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
- `check-links.yml`: its reusable default remains external checking. The kit
  and distributed callers explicitly validate local links offline on PR/push,
  so a third-party outage cannot block a merge. The scheduled and manual
  `check-links-nightly.yml` runs the full external scan with three retries and
  10 seconds between retries. It accepts status 200 to 299. Put ignored URL
  patterns in a `.lycheeignore` file at the repo root.
- `pr-title.yml`: runs `amannn/action-semantic-pull-request` with no inputs and
  no custom regex, so the action's defaults apply. It accepts
  `feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert`, an optional
  scope, an optional `!`, then a colon, a space, and any subject. House rules are stricter
  (six types, 72 characters) and are in delivery.md. The action does not check
  length.
- `node-ci.yml`: `npm ci`, then `npm run lint`, `npm test`, `npm run build`.
  Optional callers keep `--if-present`; a caller with `require-test: true`
  fails before install if `run-test` is false or `test` is missing or blank,
  then runs `npm test` without `--if-present`. Inputs: `node-version`,
  `working-directory`, `run-lint`, `run-test`, `require-test`, `run-build`.
  Set `require-test: true` only after bumping the caller to a verified kit pin.
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
