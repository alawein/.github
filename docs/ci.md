# CI standard

How the reusable workflows in this repo work, and how to keep their pins
current. One place to fix, one pin to bump. Which checks are required, and why,
is in [delivery.md](system/delivery.md), "Merging and checks". Do not copy that
list here.

For the November 2026 measure-first streamline (what changed, what was
deferred, and where required names come from), see
[Kit self streamline](#kit-self-streamline). The coordinating plan lives in the
human CI Workflow Review track (`2026-11-17-ci-streamline`); current-vs-proposed
architecture diagrams stay there. This repo does not ship SVG copies.

## Use it

`scripts/new-repo.ps1` already puts the right stub in a new repo. Use these
steps to add one by hand.

1. Pick the stub for the class (next section).
2. Copy it from `templates/workflows/` to `.github/workflows/ci.yml`, and copy
   `check-links-nightly.yml` from the same folder beside it.
3. Set the pin after each `@` to a full commit SHA of `alawein/.github` (see
   "After the first commit" and "Bump a pin").
4. Run `scripts/setup-repo.ps1`. It requires the class check names in `ci.yml`.
   Prefer the kit split: keep SHA lint/build in `ci.yml` without `edited`, and put
   title/policy (including `edited`) in `policy.yml` with complete PR event coverage,
   immutable producers, matching implementation refs, required evidence sections,
   and always-report wrappers. Metadata events and their reusable producers must
   complete independently instead of cancelling earlier events. Until a consumer
   migrates, Mode A keeps a single `CI` stub with `edited` and the
   `metadata-${{ github.run_id }}` concurrency carve-out so a body edit cannot
   cancel SHA gates; do not remove that carve-out while `edited` remains.

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

| Class | Stub | Test check |
| --- | --- | --- |
| profile, docs | `docs.yml` | none |
| tool in TypeScript | `node.yml` | `node-ci` |
| tool in Python, lab | `python.yml` | `python-ci` |
| site | `site.yml` | `node-ci` |

| Reusable workflow | Check it backs | Runs |
| --- | --- | --- |
| `lint-markdown.yml` | `markdown-lint` | Every class |
| `check-links.yml` | `link-check` | Every class |
| `lint-actions.yml` | `actionlint` | Every class |
| `pr-title.yml` | `pr-title` | Every class |
| `pr-policy.yml` | `pr-policy` (opt-in) | Branch and ready-PR linkage metadata |
| `lint-zizmor.yml` | `zizmor` (kit only) | Offline zizmor audit of `.github/workflows` |
| `hygiene.yml` | Advisory scheduled report | Read-only repository observations |
| `node-ci.yml` | `node-ci` | `npm ci`, lint, test, build |
| `python-ci.yml` | `python-ci` | uv or pip, ruff, pytest |

CodeQL is not a workflow here. Turn it on with GitHub's default setup
(Settings, Code security) on public repos.

## Reusable workflow inputs

`node-ci.yml` and `python-ci.yml` accept optional `runner` (default `ubuntu-24.04`).
Pass a GitHub-hosted label or a self-hosted label expression (for example
`[self-hosted, railway, ephemeral]`) when dual-running jobs off hosted runners.
Keep the default until a self-hosted pool is proven green. Fork pull requests
ignore `runner` and always use `ubuntu-24.04`, so fork code never reaches a
self-hosted pool.

`railway-pool-probe.yml` proves the Railway pool on a weekly schedule (and
`workflow_dispatch`): it runs the `scripts/tests` fast path on
`[self-hosted, railway, ephemeral]` with `continue-on-error` and is not a
required check. It is intentionally absent from PR/push `ci.yml` so every kit
change does not dual-run metadata on self-hosted.

`python-ci.yml` accepts `uv-install-method` (`setup-uv` default, or `pip`). Use
`pip` when `astral-sh/setup-uv` fails on GitHub Releases CDN timeouts (504s); it
installs the pinned `uv-version` from PyPI with `--only-binary=:all:` then runs
`uv sync --locked`.

`node-ci.yml` also supports `require-lint: true`, paired with `run-lint: true`.
It refuses a missing or blank lint script before installation, runs `npm run lint`
without optional-script suppression, and propagates its exit code. Code repositories
use zero-warning lint scripts and include formatting and type checks.

`pr-policy.yml` supports `require-sections: true` for ready PRs. It requires
Context, Changes, Testing Evidence, Screenshots/Logs, and Rollback Plan with actual
prose. Drafts may defer these sections. Existing callers retain the earlier
metadata contract until they opt in at a compatible immutable kit revision.

`pr-policy.yml` also rejects any PR commit whose message carries an AI
`Co-authored-by:` trailer or a "Generated with" footer, because squash merges
copy every commit's trailers into the merged commit. It lists the PR's commits
through the API, so a caller pinning a revision with this check must grant its
`run-pr-policy` job `contents: read` and `pull-requests: read`. The distributed
`pr-policy.jobs.yml` fragment already grants both so opt-in callers stay valid
when the freeze advances past that revision; older freeze pins that only declare
`contents: read` simply do not use the extra grant.

The metadata job also validates `default.json` with Renovate `44.238.1` on
Node `26.13.0`, then exercises its actual update-rule and template engines.
The cases reject ordinary patch, minor, major, unknown, pin, and digest
auto-merges, keep digest pins on Actions and Docker managers, and verify
protected-tool exceptions. Generated update PRs must pass the ordinary evidence
gate and state the owner merge requirement. npm's download cache is keyed by the
preset; the 15-minute timeout includes cold validator installation and
generated-starter tests. These tests do not prove app installation, repository
permissions, hosted reviews, or actual merges. Kit consumer merge holds are also
exercised through Renovate's actual merged rules.
Metadata events use distinct run groups and always-report wrappers, so cancelling
a latest producer cannot silently skip its required success check.

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

The kit's own `pr-title` and `pr-policy` gates live in `policy.yml`, the only
kit workflow that reruns on `edited`; `ci.yml` omits it so a PR body edit never
cancels a CI run on the same SHA. The always-report `pr-policy` gate requires a
successful policy producer, including on push to main; cancellation, failure or
a skipped producer cannot pass it. `ci.yml`'s `metadata-tests` job is its own
required context. It always runs `scripts/tests` once, then on the heavy path
runs the pinned Renovate config validator and offline matcher cases, then the
root `tests` suite after installing PyYAML from the hash-pinned wheels in
`tests/requirements.txt`
(Renovate's pip_requirements manager updates that file's version and hashes together) and the pinned
actionlint, just and lychee archives. It exports `LYCHEE_BIN`; with `CI=true`
the lychee tests fail instead of skipping when it is unset. The metadata
suite also generates docs, profile, TypeScript, Python, site and lab outputs
with `new-repo.ps1`, then executes their actual PR-title guards with the generated
environment bindings across 180 event/ref/result cases. Only an actual push to
`refs/heads/main` may accept a skipped title producer. This tests generated
workflow behavior, not fresh installation or hosted deployment settings.
The original four required contexts and distributed v1.2.0 pins remain unchanged. Other
consumers opt in after a reviewed signed release. Require `pr-policy` in live
rules only after observing an eligible successful PR run at its current SHA.

`rulesets/checks.json` is the canonical required-check list: `fleet_base` for
consumers, the per-language extra, the `pr-policy` opt-in, and `kit_self` for this
repo's own ruleset. Required bare names and why they matter are in
[delivery.md](system/delivery.md), "Merging and checks" — do not copy that list
here. Consumer copies must match `fleet_base`. This kit's required contexts are
`kit_self`: reusable slash producers (`run-* / lint`), the plain `metadata-tests`
job, and policy bare always-gates (`pr-title`, `pr-policy`). The kit
`hygiene-weekly.yml` expected list must match `kit_self`.
`metadata-tests-railway` is intentionally absent (`continue-on-error`, not
required). `tests/test_check_list.py` fails when any fleet copy (ruleset
templates, setup and verify scripts, hygiene defaults) disagrees with
`fleet_base`, or when kit hygiene-weekly disagrees with `kit_self`, so change
the list in `checks.json` first.

`language_extra` maps a language to `node-ci` or `python-ci` only when that job
exists in the consumer's `ci.yml`. Profile and docs classes stay on `fleet_base`
(plus opt-in `pr-policy`); they never take a language check from the catalog
alone. Named hold (2026-11-20): `alawein/alawein` required checks are
`fleet_base` + `pr-policy` only — do **not** require `node-ci` until a job
publishes that context. `Get-CheckPolicy` already omits language checks for
`profile` and `docs`; setup and Settings Apply must match that, not invent a
language from the repo name.

`hygiene.yml` accepts `expected-required-checks`, a comma-separated list defaulting
to the original four contexts; it has no `kit-ref` input. Callers pin the reviewed
workflow release SHA on `uses:`. Released v1.3.0 separately pins audit source to
implementation commit `ce04a21e332e42c3137b26f3becb0de77086b6cb`.
The current source workflow pins main commit `98c7496007ae504a3509be1c29d02afa87640aca`.
Its audit script bytes match the reviewed PR head, and it runs with
`--token-limited`; the kit's local weekly caller uses it after merge. Unchanged v1.3.0 callers
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

The hosted token lacks [Administration read](https://docs.github.com/en/rest/branches/branch-protection#get-branch-protection).
A hosted run on 2026-10-14 could not read merge settings or ruleset bypass
actors; its access to classic branch protection stays `UNVERIFIED` until a
hosted run shows the response. The workflow passes `--token-limited`: those
fields are listed as unverifiable and the status is `LIMITED` (exit 0) only
when no read is `UNKNOWN` and nothing is found. Findings produce `WARN`, which
also exits 0. Permissions stay unexpanded; to verify those fields, run the
script locally with an admin `GH_TOKEN` and without the flag. Configured protection is separate from eligible
PR execution, check conclusions, signing, artifact behavior and production.
The PR-title gate permits a skipped producer only on an actual main-push event.

## Opt in to PR policy and hygiene

Distributed stubs, starters, and opt-in templates pin the freeze SHA in
[pins](pins.md) (reviewed `main` `cc3b595f8e9e92a9ed6fc63b3be177cc8a571965`
until a new release tag). Keep `uses:` and `kit-ref` identical. Existing
published callers on older pins (including signed `v1.4.0` at
`f5dbd4d7656e286e20d2aa24463253c32a56521b`) keep old behavior until they
repin. Copy templates and run helpers from the same reviewed revision you pin.

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

Class check lists are minimum requirements. Verification accepts additional
required checks and reports their GitHub App producer bindings. Setup reads
and validates the paginated existing rulesets before its first settings write.
Unavailable or malformed configuration stops the run. A ruleset update retains
existing requirements, complete producer records, strict check freshness,
additional rule types, existing parameterized protections and additional
protected refs, then adds any missing baseline checks and refs. Ref scopes
must use arrays of matching `refs/heads/` or `refs/tags/` patterns with no
exclusions. Unsupported conditions, special selectors, exclusions or mismatched
targets stop before any write and require a scoped reconciliation. Repeated
setup keeps that merged configuration stable.
An unbound baseline does not replace a check already bound to an app.
Pull-request parameters use the higher approval count, true enforcement flags,
and the intersection of allowed merge methods. Additional existing fields remain
intact. Malformed parameters, incompatible methods, or differing unknown strengths
stop during preflight, before any settings write.

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
example `run-markdown-lint / lint`. Consumer rulesets need the bare name, so
each distributed caller ends with small gate jobs named exactly `markdown-lint`,
`link-check`, `actionlint`, and `pr-title` (plus `node-ci` or `python-ci`). A
gate passes only if the job it waits on passed. `pr-title` also passes when the
title check is skipped, which happens on push to `main`.

This kit repo is different: its live ruleset requires the slash names for the
four lint producers (see `kit_self` in `rulesets/checks.json`) and does not run
thin CI gate jobs. Policy still uses bare always-report gates for `pr-title`
and `pr-policy`.

Consumer bare names stay identical in every stub, the `fleet_base` rulesets,
`setup-repo.ps1`, and `verify-repo.ps1`. The profile repo runs the same four
checks inline.

## Archive guard

Every reusable workflow starts its primary job with a step that refuses
`ARCHIVE-*` repository names before checkout or other work. The step is Layer 4
in [archive.md](archive.md). Keep it as the first step of the work job so archive
repos fail closed without a separate billed job.

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

Current distributed template pins freeze to reviewed `main`
`cc3b595f8e9e92a9ed6fc63b3be177cc8a571965` (2026-11-17). Comments stay
`# quality gates` until a release tag exists. Prior published callers may still use
signed `v1.4.0` at `f5dbd4d7656e286e20d2aa24463253c32a56521b` until they repin.
v1.4.0 added the separate policy gates, `::error::` policy annotations, wider branch types, checksum-pinned zizmor and the `ubuntu-24.04` runner pins; it keeps `require-test` and the paired local/external link inputs.

Claude review is **not** ready-to-copy at this freeze: see
`templates/workflows/claude-review.WITHHELD.md`. The reusable workflow exists on
later `main` commits, but a consumer pin at the freeze SHA 404s. Do not copy a
Claude starter, invent a SHA, pin `@main`, or activate Claude until a freeze or
release that contains the workflow is published and the owner names activation.

### Publication contract (offline + remote preflight)

Before cutting a kit freeze advance or release tag that redistributes templates:

1. Run `python3 scripts/check-publication-contract.py` (offline, deterministic).
   It checks ready-to-copy `uses:` targets exist at the locally available pinned
   commit, `workflow_call` inputs/secrets match callers, caller permissions cover
   each pinned callee, generated starters stay on one freeze, and `uses:`/`kit-ref`
   stay lockstep. Root suite: `tests/test_publication_contract.py`.
2. Remote confirmation is separate and explicit:
   `python3 scripts/check-publication-contract.py --remote` (needs `gh` auth).
   Do not treat offline PASS as hosted existence proof.

## Permission rules

- Every workflow sets `permissions: contents: read` at the top. Raise a
  permission per job, never for the whole file. A job that needs no token
  (the gate jobs) sets `permissions: {}`.
- A reusable workflow can only lower what its caller grants. If a callee needs
  more than the caller job has, the call fails. So the caller job must grant
  `pull-requests: read` for `pr-title.yml`.
- Checkout always uses `persist-credentials: false`. No workflow needs to push.
- No secrets in these workflows. The automatic `secrets.GITHUB_TOKEN` is the
  only credential.
- Every job has `timeout-minutes`.
- Kit jobs and distributed templates use `ubuntu-24.04`, never `ubuntu-latest`
  (a root test enforces it); hosted image software still changes.
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
- The scoped quality rollout uses the shared Renovate preset for update PRs;
  see [dependency policy](system/delivery.md#dependencies). Action and tool pins
  still require reviewed updates. Existing Dependabot version-update config is
  disabled when a repository adopts Renovate, so both bots do not open duplicates.

### Dependency update bots and `pr-policy`

Ready PRs must use a house branch (`chore/deps-…`) and the five evidence sections
(Context, Changes, Testing Evidence, Screenshots/Logs, Rollback Plan), or stay
draft until those are filled. A fixture for a compliant bot PR lives at
`scripts/tests/fixtures/dependabot-pr-valid.json`.

- Prefer Renovate with `default.json`: `branchPrefix` is `chore/deps-` and
  `prBodyTemplate` already fills the five sections plus `No-issue:` for scheduled
  maintenance.
- Dependabot is off (owner decision 2026-10-06, reaffirmed 2026-11-17): no
  `dependabot.yml`, no alerts and no security updates. Its default `dependabot/…`
  branches also fail `pr-policy` (observed Policy failures such as run
  `43650759868`).
- Two pins are not `uses:` lines and need a manual bump: the actionlint version
  and sha256 in `lint-actions.yml`, and the default `uv-version` in
  `python-ci.yml`. The list is in `pins.md`.

## Fleet pin inventory

Run `python3 scripts/audit_fleet_pins.py` (needs `gh` auth) for a read-only table of
consumer `uses: alawein/.github/...@<sha>` pins. Code search can be incomplete under
rate limits; treat gaps as UNVERIFIED and re-run before a fleet bump.

For the aggregated Fleet Control Center snapshot (pins + kit checks + optional live
kit enrichment), see [fleet-control-center.md](fleet-control-center.md).

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

## Kit self streamline

November 2026 work on `alawein/.github` followed measure-first gates: live
ruleset verification and per-job timing samples (Tasks 1–2) set explicit
yes/no flags before workflow edits. Structural cuts ran only when those flags
allowed them; YAML on this branch reflects that scope.

**Job-level path routing.** `metadata-tests` chooses fast vs heavy with an
in-job `Detect generator paths` step, not workflow-level `paths` filters.
Required producers must always report, so `ci.yml` and `policy.yml` have no
`on.pull_request.paths` / `paths-ignore`. The heavy-path regex is frozen to
`^(scripts/[^/]+$|scripts/lib/|templates/|tests/|\.github/workflows/|default\.json|renovate\.json|rulesets/)`;
unresolved base SHA fails closed to heavy. Fast path runs `scripts/tests` only
(docs-only and `scripts/tests/**` edits stay here). Heavy path adds the pinned
Renovate validator, offline matcher cases, tool installs, and the root `tests/`
suite whenever dependency policy, rulesets, top-level scripts, templates,
workflows, or root tests change (see `metadata-tests` above).

**Policy vs CI split preserved.** SHA and metadata gates stay in `ci.yml`
without `edited`. Title, body, and `pr-policy` gates stay in `policy.yml`, the
only kit workflow that reruns on `edited`, so a body edit does not cancel CI on
the same SHA.

**Railway pool probe.** Fresh 2026-11-20 timings found `metadata-tests-railway`
on **25/25** recent successful CI runs (median ~27s job; earlier Task 2 sample
had it on only 26.7% of PRs). The probe now lives in `railway-pool-probe.yml`
(weekly Monday `37 8 * * 1` plus `workflow_dispatch`), still non-required with
`continue-on-error`, and is removed from PR/push `ci.yml`.

**Gate consolidation (kit slash-name migration).** Task 2 allowed collapsing
duplicate work inside jobs; a later ruleset migration dropped the four thin
`if: ${{ always() }}` CI lint gates. Kit `kit_self` now requires the reusable
producer slash names (`run-markdown-lint / lint`, `run-link-check / lint`,
`run-actionlint / lint`, `run-zizmor / lint`) plus `metadata-tests`, and keeps
`pr-title` / `pr-policy` as always-report gates in `policy.yml`. That is still
exactly seven required contexts. Consumer stubs keep bare `fleet_base` gate
names; only this repo's live ruleset uses the slash form.

**Caching unchanged.** Task 2 had no per-step install median ≥30s across jobs;
dependency caches in reusables and the heavy-path npm cache on `default.json`
were left as-is. Pinned curl+sha256 installs for actionlint, just, and lychee
were not given cross-job download caches without new measurements.

**Merge queue.** Live ruleset reads found no merge-queue rule and no
`merge_group` trigger on kit workflows; auto-merge on the repo is not Merge
Queue. No `merge_group` workflow was added (YAGNI unless settings change).

**Open PR budget.** House streamline branches use `chore/ci-streamline-<topic>`.
Pause new kit PRs when three or more are already waiting on `alawein/.github`.

## Keeping CI lean

Runner time is rounded up per job, and every run of every PR uses it. These
rules apply to any caller of the kit.

- Rerun on `edited` only what reads the PR title or body. Prefer the kit split:
  `ci.yml` omits `edited`; `policy.yml` owns title/policy and `edited`. Distributed
  stubs still keep `edited` in one `CI` workflow (Mode A) while title gates live
  there. Mode A isolates only `edited` onto `metadata-${{ github.run_id }}` with
  `cancel-in-progress` false for that action; opened/synchronize/reopened stay on
  the per-PR build group and still cancel superseded runs. Do not remove that
  edited carve-out while `edited` remains. With plain per-PR cancellation and no
  carve-out, an edit-triggered run cancels the push run on the same SHA, and that
  run's always-report gates then fail their required contexts. A repo with no such
  gates should leave `edited` out.
- Trigger on `push` for `main` only, plus `pull_request` for `main`, so a branch
  with an open PR does not run twice.
- Cancel superseded non-edited `pull_request` runs with a per-PR `concurrency`
  group. Mode A disables cancel only for `edited`; kit `policy.yml` uses a
  per-run group and never cancels. Never cancel `main` pushes or scheduled runs.
- Set `timeout-minutes` on every job, sized to the slowest normal run plus a
  margin.
- Prefer fewer jobs. Each job repeats setup and rounds up to a whole minute, so
  fold small steps together unless they must report separate required check
  names.
- Do not put workflow-level `paths` filters on workflows that produce required
  checks. A skipped workflow leaves its required check pending. Skip inside a
  job, or use an always-running aggregator job.
- Run browser, end-to-end and performance suites weekly or on demand unless a
  PR needs them. Install only the browser the suite uses.
- Skip heavy jobs that are not required while a PR is a draft. Add
  `ready_for_review` to `pull_request.types` so they run when it is ready.
- Cache dependencies and keep artifact retention short, 7 to 14 days.

## Decisions

- Decision: consumer gate jobs carry the required bare check names. Why: a
  called job reports as `caller / called`, and consumer rulesets need the bare
  names. The kit itself requires the slash names so it can drop four thin
  always() CI gates.
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

## Local commit-msg hook

`githooks/commit-msg` rejects AI co-author trailers and "Generated with", "Generated by" or "Made with" footers before a commit is created. It mirrors the attribution patterns in `scripts/check-pr-policy.py`. Enable it in a checkout with `git config core.hooksPath githooks`; `scripts/tests/test_commit_msg_hook.py` holds its bad and good fixtures.
