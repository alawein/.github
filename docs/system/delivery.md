# Delivery

The single home of how a change gets from an idea to production and stays
safe there: the flow, branch, commit and pull request rules, releases,
environments, Vercel, dependencies, security, secrets, backups, and incidents.
How work is tracked is in [projects.md](projects.md). Repo classes, names,
layout, and licenses are in [repos.md](repos.md). How the shared workflows work
and how to bump a pin is in [ci.md](../ci.md). Moving a domain is in
[vercel.md](../vercel.md).

A line that starts with "Decision:" records a choice that was open. The reason
follows on the same line. A "pull request" (PR) is a proposed change that is
reviewed before it joins `main`.

## Who does what

The owner selects the execution mode for each named repository, target branch
and change scope before publishing. The three modes and separate gates live in
the [agent Safety floor](agents.md#safety-floor); every procedure below follows
that selection. Agents prepare changes, checks, independent review and PR text,
then publish and merge only as that mode permits. Mode (b) waits for explicit
owner merge approval even when checks and GitHub review are green.

Settings, rulesets, secrets, app access, releases and deployments need separate
named authorization. Desired settings are not proof they are active; live
account state is UNVERIFIED until checked. Historical grants remain evidence
for their original scope, rather than permission for a new task.

## The flow

```text
 idea or note
     |
     v
 issue: goal + "done when" list          board: Inbox -> Next
     |
     v
 branch: type/short-topic                board: Doing
     |
     v
 publish as the selected task mode permits
     |
     v
 checks run on every push                four shared checks + tests
     |
     v
 self-review, then a fresh-agent review  board: Review
     |
     v
 merge as the selected task mode permits
     |
     v
 squash merge to main, branch deleted
     |
     +--> versioned repos: release PR -> tag -> release
     |
     v
 deploy (connected Vercel project, when authorized)
     |
     v
 verify the live result                  board: Done
     |
     v
 learn: one line in the log; a check if it can recur
```

| Step | What happens | Gate |
| --- | --- | --- |
| Issue | Prepare a goal and a "done when" list | Named approval before posting |
| Branch | `type/short-topic` from a fresh `main` | One topic |
| Draft PR | Open after local checks and scoped push | Selected task mode |
| Checks | Shared checks plus the repo's tests | All required checks green |
| Review | You read your own diff first. A second agent session with no memory of the work reads it next | Notes fixed or answered |
| Merge | Squash after required checks and independent review | Selected mode; explicit owner approval in (a) and (b) |
| Release | Only repos that publish versions (see Versions and releases) | Owner-approved PR, signed tag and publish |
| Deploy | A connected Vercel project builds eligible `main` changes | Separately authorized effect and verified settings |
| Verify | Open the live URL or run the smoke test | Done when it works live |
| Learn | One line in the log; prepare an issue for a recurring mistake | Named approval before posting |

Decision: a mistake that happens twice becomes a check, a test, or a rule.
Why: memory fades, and a check does not.

## Branches, commits, and pull requests

### Branches

- `main` is the only long-lived branch. It is always releasable.
- Work branches are `type/short-topic`, lowercase with hyphens, no dates:
  `feat/build`, `fix/label-join`, `docs/readme-links`.
- Types: feat, fix, docs, chore, refactor, test.
- Topics have no empty hyphen segments or calendar dates. Agent-prefixed
  branches such as `codex/task` fail the opt-in metadata check. Only the exact
  `dependabot[bot]` author of type `Bot` on a generated `dependabot/` branch is
  exempt from human branch naming and linkage.
- One agent per branch. Run parallel agents in separate Git worktrees
  (extra working folders on the same repo), each on its own branch, and keep
  them on different files where you can.
- At most three PRs wait for review at once, including dependency PRs.
- Branch deletion after merge is an owner-approved setting or named action.

### Commits

Decision: the PR title and body are the record. Commits on a branch are
scratch. Why: squash merge flattens a branch into one commit, so a rule about
branch commits would only slow down agents.

- Keep branch commits short and imperative ("add parser test").
- Where a repo takes direct pushes to `main` (private tooling under the light
  ruleset), every commit subject follows the PR title format below.
- Never use `--no-verify` to skip a hook. Fix the hook's complaint.
- An approved force-push targets only your own branch and uses
  `--force-with-lease`. Never `main`.
- Commit and PR text says what changed and why. It does not narrate which
  tool wrote it. No `Co-Authored-By` trailer unless a person co-wrote the change.

### Pull request titles

Format: `type(scope): summary`. GitHub uses it as the squash commit title.

- Types: feat, fix, docs, chore, refactor, test. The title check accepts more
  types, because tools generate them. House rule is these six.
- Scope is optional, one lowercase word: `fix(parser): handle empty input`.
- Summary is an imperative verb phrase, 72 characters or fewer for the whole
  title, no final period, specific ("fix the strict-label join", not "fix bug").
- A breaking change adds `!` (`feat(api)!: drop the v1 route`) and the body
  explains the migration.
- A revert is `fix(scope): revert <summary>`. GitHub's Revert button writes a
  title that starts with `Revert`, which fails the title check. Edit it.
- A release PR is `chore(release): vX.Y.Z`.

### Pull request rules

- One topic per PR, about 300 changed lines or fewer. Lockfiles and generated
  files do not count. A bigger change is split, or it uses the long checklist in
  [pull-request-checklist.md](../../templates/pull-request-checklist.md).
- Fill every section of the template. Write "n/a" and say why if one does not
  apply.
- Ready human PRs link an issue in the Why section, for example `Closes #12`.
  If no existing tracking issue applies, use `No-issue: <specific reason>` with
  an actual reason, such as `No-issue: shared workflow policy has no existing
  tracking issue`. Empty and placeholder reasons do not qualify; drafts may
  defer linkage. Issue references inside code examples or HTML comments do not
  qualify. The metadata check proves syntax, not issue existence or a meaningful
  explanation; owner review checks the exception, including issues-off profiles.
- Include the real task ID in evidence and, when public-safe, the Why section.
  Do not invent private task IDs or rename branches to add one.
- Open it as a draft within the selected mode. Mark it ready after passing
  checks and the recorded review of the current diff, within that same mode.
- A behavior change comes with a test. For a bug fix the test fails before the
  fix.
- Stacked PRs (a PR based on another unmerged PR) are not used. Land the base
  first, or split the work into independent PRs.

Decision: no stacked PRs. Why: with squash merging, every merge forces a rebase
of the PRs above it, and one reviewer gains nothing from the extra layers.

Decision: draft PRs are the default for work in progress. Why: CI runs on
drafts, a pushed draft is an off-machine backup, and auto-merge cannot fire on
a draft by mistake.

### Labels

Five canonical labels, required in every repo. The set lives in
[labels.yml](../../templates/labels.yml); owner-approved setup applies it.
Shared forms and their label references live in
[.github/ISSUE_TEMPLATE](../../.github/ISSUE_TEMPLATE/), GitHub's
[supported default location](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file).

| Label | Meaning |
| --- | --- |
| feat | New feature or capability |
| fix | Bug fix or correction |
| docs | Documentation only change |
| chore | Maintenance, tooling, or cleanup with no behavior change |
| blocked | Cannot proceed until an external dependency or decision is resolved |

- Labels go on issues. The issue form sets the type label. A PR carries no
  label, because its title already says the type.
- A `refactor` or `test` issue uses `chore`.
- `blocked` means waiting on something outside the repo. The issue says what.
- Missing canonical labels or mismatched colors and descriptions fail verification.
- Report additional labels as informational notes. Useful supplemental labels
  may remain; renaming, mapping or removal requires named owner approval.
- The owner can apply one approved entry with
  `gh label create NAME --color HEX --description "TEXT" --force`.

Decision: no labels for refactor, test, or ready. Why: the PR title holds the
type, and a draft PR that becomes ready already says "ready".

### Reading an agent's diff

An agent's diff can look right and be wrong. Look for these first:

- Tests deleted, skipped, or loosened to make a check pass.
- Files you did not expect, especially config, CI, lockfiles, and dotfiles.
- A new dependency, install script, or network call.
- A rewrite where a small edit would do.
- A secret, a token, a personal path, or a debug print.
- A claim in the PR body that the diff does not show.

## Merging and checks

- Squash merge only. Merge commits and rebase merges are off.
- Squash commit title is the PR title. The message is blank.
- The branch may fall behind `main`. Use the Update branch button or rebase
  locally. Branch history does not reach `main`.
- Auto-merge may be used only where enabled and within the selected mode's
  merge permission (`gh pr merge --auto --squash`). Required checks and current
  independent review still apply; mode (b) requires explicit owner approval.
- No merge queue. No bypass actors on any ruleset, so the rules bind the owner
  too. A bad rule requires a separately approved repair, saved prior JSON and
  immediate restoration of enforcement; do not add a bot bypass.
- Required approvals: 0. GitHub does not let an author approve their own PR, so
  any higher number would block every merge.
- Required checks for the kit, profile and standard full ruleset:
  `markdown-lint`, `link-check`, `actionlint`, `pr-title`. They are the job
  names in each repo's `ci.yml`, so a rename there would block every PR.
- `pr-policy` is an additional opt-in context. The kit's always-report producer
  exists locally; settings promotion requires an eligible successful PR run and
  named owner approval. Preserve legacy consumers until their reviewed adoption.
- A repo with code (tool, site, or lab) also requires its test check:
  `node-ci` for TypeScript tools and sites, `python-ci` for Python tools and
  labs. A check that never blocks is decoration, and code is where agents make
  mistakes.
- The approved hub profile uses the single required `check` job; its exact
  scope is in [CI](../ci.md). Preserve all current names and always-report
  behavior. Site E2E stays advisory pending the owner's 30-clean-day decision.
- PR test retries remain zero. Preserve failure evidence and repair flakes;
  never skip, weaken or quarantine a required check. Two flake occurrences
  in 14 days require a dated issue proposal; posting it stays gated.
- CodeQL and other scanners report but never block. A flaky required check
  blocks every merge.
- How the shared workflows report those names is in [ci.md](../ci.md).

Decision: the test check is required for repos with code. Why: green tests are
the only review that scales to an agent's pace.

Decision: the squash commit message is blank, not the PR body. Why: the body
holds a template with checklists. In `git log` that is noise. The title ends in
`(#12)`, which leads to the PR with the why, the tests, and the risk.

### Rulesets

A ruleset is a set of branch or tag rules that GitHub enforces. The files are
in `rulesets/`; owner-approved `scripts/setup-repo.ps1` applies them.
The templates use active enforcement and no bypass actors. Verify live state
after application; a local template or successful dry run proves neither.

| File | Name in GitHub | Applies to | Rules |
| --- | --- | --- | --- |
| `main-public.json` | `main-protection` | `main` in public repos | No deletion, no force push, linear history, signed commits, PR with 0 approvals and squash only, the required checks |
| `main-site.json` | `main-guard` | Private sites | No deletion or force push, linear history, PR with 0 approvals and squash only, four shared checks plus `node-ci` |
| `main-hub.json` | `main-guard` | Approved private hub profile | No deletion or force push, required `check` |
| `main-private.json` | `main-guard` | `main` in private repos | No deletion, no force push |
| `main-private.json` with `-Strict` | `main-guard` | `main` in private sites, and any private repo run with `-Strict` | The two above, plus linear history, PR with 0 approvals and squash only, and the required checks when `ci.yml` defines them |
| `tags.json` | `release-tags` | Tags `v*` in every live repo | No deletion, no move |

- `repo-settings-public.json` and `repo-settings-private.json` hold the merge
  settings (squash only, blank commit message, auto-merge on, branch deleted on
  merge) and, for public repos, secret scanning.
- The script adds the test check to the required list for a repo with code.
- Missing jobs or all-zero workflow pins block CI readiness. Public branch
  setup skips its ruleset; strict private setup may omit required checks;
  the approved hub profile fails closed. Report the actual bootstrap gap,
  never an enforcement pass, and rerun owner-approved setup after CI is ready.
- Private repos get the light ruleset. A private site always gets `-Strict`.
  Any other private repo takes `-Strict` once its CI exists.
- Wiki and projects are off everywhere. Issues and discussions are off only in
  the profile repo, where nothing needs a reply.
- The script never deletes labels or rulesets. Any deletion needs a named
  owner approval after reviewing the exact list.
- The script and `verify-repo.ps1` refuse any repo named `ARCHIVE-...`.
- Ruleset recovery follows the separately approved repair above.

Decision: shared community files (security policy, contributing guide, code of
conduct, support page, issue and PR templates) live once in `alawein/.github`.
Why: one copy stays correct. A repo's own copy replaces the default. They are
not merged. `CODEOWNERS`, workflows, and the license stay per repo.

### Signed commits

A commit signature verifies a signing identity; it does not prove who wrote
every line. Record GitHub's observed verification state before promotion.

- Public policy requires signed commits on `main`. Unsigned head commits can
  block a squash merge even when GitHub would sign its final commit. Do not
  promise that an unsigned branch will pass. See
  [GitHub's signing rule](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets#require-signed-commits).
- Private repos leave the rule out. Sign locally anyway once you have a key.
- Keep local edits moving while signing is unavailable, but block promotion
  until the owner verifies signing identity, head signatures and the actual
  merge path. Never disable the rule to pass. No signing test authorizes a
  commit, push or merge by itself.
- The owner registers one key for all tools under named approval:
  1. Create an SSH key of type ed25519 and keep it in your password manager's
     SSH agent, so nothing prompts during an agent run.
  2. Add the public half at GitHub, Settings, SSH and GPG keys, as a Signing
     key. This is a separate entry from an authentication key.
  3. Set `gpg.format` to `ssh`, `user.signingkey` to the public key, and
     `commit.gpgsign` to `true`. On Windows, set `gpg.ssh.program` to the
     OpenSSH `ssh-keygen.exe` that Git for Windows ships.
  4. Make one test commit and check for Verified on GitHub.

Decision: one signing key, registered once, shared by all tools on the machine.
Why: a key per tool is more keys to track, and all of them act as you.

## Versions and releases

Decision: owner-created signed annotated tags with a short routine, not
release-please (a bot that opens release PRs for you). Why: the owner controls
the reviewed release target and signing. Current GitHub behavior permits
approval-required runs for token-created PR opened, synchronize and reopened
events; other token-created PR activity remains suppressed. A token-created PR
does not itself prove eligible successful checks. The manual routine needs no
additional stored token or GitHub App.

| Kind of repo | Versioned? | Scheme |
| --- | --- | --- |
| Libraries, CLIs, and packages others install | Yes | Semantic version, GitHub release, registry publish |
| Templates and shared workflows others pin | Yes | Semantic version, so a pin comment is checkable |
| Research code | Once, at paper release | `v1.0.0` tag and release |
| Sites, docs, the profile repo | No | The deploy from `main` is the release |
| Private apps and ops tools | No | Same. Tag only if another repo pins it |

### Semantic version

`MAJOR.MINOR.PATCH`, read as: Patch means a fix or a dependency update nobody
notices. Minor means a new capability that is backward compatible. Major means
something a caller relied on is gone or incompatible. Before 1.0 (`0.y.z`), a
minor bump may break.

### The routine

1. Confirm `main` is green. If a milestone exists for this version, confirm it
   has no open issues.
2. List what merged since the last tag:
   `gh pr list --state merged --search "merged:>=YYYY-MM-DD" --json number,title`.
3. Pick the version from those titles. A `!` means major. A `feat` means minor.
   Anything else is a patch.
4. Use hyphens between version numbers in the branch, for example
   `chore/release-v1-3-0` for `v1.3.0`. Update the version in the one file that
   holds it. Add the changelog entry.
5. With named approval, open the PR titled `chore(release): vX.Y.Z`.
   The owner reviews and merges it.
6. The owner creates a signed annotated tag on the verified merge commit:
   `git tag -s vX.Y.Z -m "vX.Y.Z"`; verify with `git verify-tag vX.Y.Z`
   and record the signer and target. Push only with named approval:
   `git push origin vX.Y.Z`.
7. With named publish approval, publish the release and changelog notes:
   `gh release create vX.Y.Z --verify-tag --notes-file <file>`.
8. If the repo publishes a package, the tag starts the publish workflow (below).
9. Verify from outside: install the release in a clean folder and run it.
10. Close the milestone.

The `v*` tag ruleset forbids deleting or moving a tag, because a moved tag
silently changes what people pinned. A wrong release gets a new patch version.
That ruleset does not require a tag signature. Signed annotated releases are
owner policy; record local verification and the remote tag's signature and
target before treating a release as verified. Existing tags are not certified
by this policy. See [GitHub tag signing](https://docs.github.com/en/authentication/managing-commit-signature-verification/signing-tags).
For a package, mark the bad one deprecated or yanked (a flag that tells
installers to skip it), then ship the fix.

Publishing to a registry (npm, PyPI) runs only from a workflow started by a `v*`
tag, using the registry's trusted publishing (OIDC: a short-lived login that
GitHub proves for the workflow, so no stored password). The job sits in a
GitHub Environment named `release` that needs the owner's approval where the
plan allows it.

### Changelog

Repos with versioned releases keep a `CHANGELOG.md` in the Keep a Changelog
format.

- Write the entry in the release PR, from the merged PR titles. PRs do not edit
  the changelog. Why: every PR touching the same lines makes merge conflicts,
  and parallel agents would hit them daily.
- Sections: Added, Changed, Deprecated, Removed, Fixed, Security. Write for a
  user: what changed for them.
- Header: `## [X.Y.Z] - YYYY-MM-DD`. Never edit a released section. A
  correction goes in the next version.
- Repos without versions keep no changelog. The git log and the PRs are the
  history.

## Environments

There are three. There is no shared staging, because a preview is a private
staging copy for every PR.

| | Local | Preview | Production |
| --- | --- | --- | --- |
| What | Your machine | One per branch and PR | The live site or app |
| Runs from | Working folder | Any non-`main` branch | `main` only |
| Who sees it | You | You and the team, behind a login | Everyone |
| Data | Throwaway or fixtures | Test data, never production data | Real |
| Secrets | Dev-only keys | Preview-only keys | Production keys |
| Deployed by | Nobody | Vercel, on push | Vercel, on merge |

Rules:

- No environment reads another's secrets or data. A preview never points at the
  production database. Use a separate database or a database branch.
- Every value that differs by environment is an environment variable, never
  a code branch.
- A schema or data change ships in its own PR, with a backup taken first. A
  rollback of code does not roll back data.

## Vercel

Vercel builds and hosts the personal site and other web apps. Nothing else
here uses it.

- One Vercel scope (your account or one team) owns every project. Do not
  create projects elsewhere. The free Hobby plan is for non-commercial use. A
  site that earns money needs a paid plan.
- The project name equals the repo name. Never reuse a name in two scopes.
- After separate authorization, connect the project to its GitHub repo and
  verify `main` as its production branch. Starter files do not provision the
  project or establish deployment/protection settings. The environment table
  describes the intended configured state, with the preview exception below.
- Production deploys come from a merged PR, never from a laptop, and never
  through a linked personal project.
- Deployment Protection is Standard: previews sit behind a login and the
  production domain stays public. Never choose All Deployments, because it puts
  a login wall on the production domain.
- Share a preview by adding the person to the team, or use the protection
  bypass secret for an automation. Never turn protection off to test.
- The Vercel Toolbar is off. The Node version is set in project settings and in
  `package.json`.
- Check the preview before merge when a change touches what a visitor sees. Put
  the preview URL, and a screenshot if useful, in the PR.
- The site's current starter `ignoreCommand` skips every `dependabot/*` branch,
  including application dependency updates. Those PRs get no Vercel preview;
  CI still applies. Report this exception when preview evidence is absent.
  Changing the skip policy needs a separate proposal.
- A redirect starts temporary (307). Change it to 308 only after 7 clean days,
  because browsers cache a 308 and it cannot be recalled.
- Never move or remove a domain without the saved baselines and the steps in
  [vercel.md](../vercel.md), which also holds the `vercel.json` template.
- Never commit `.vercel/` or any `.env*` file.

### Environment variables on Vercel

- Set them in the dashboard or with `vercel env add NAME production`. Never
  commit a value and never put an `env` block in `vercel.json`.
- Names are `UPPER_SNAKE_CASE`. A value read in the browser needs the framework's
  public prefix (`NEXT_PUBLIC_`, `PUBLIC_`, `VITE_`). Nothing secret gets one.
- Mark every secret Sensitive. Vercel offers this for Production and Preview. A
  sensitive value cannot be read back, so local values come from your password
  manager, not from `vercel env pull`.
- Give each variable only the environments it needs. Production and Preview use
  different values.
- A changed value applies to new deployments only. Redeploy after a change.
- The repo README lists the variable names under "Environment". Never the values.

### Roll back a bad deploy

1. Vercel dashboard, Deployments, pick the last good production deployment,
   choose Instant Rollback. CLI: `vercel rollback <deployment-url>`.
2. A rollback stops automatic assignment of the production domain. New deploys
   will not go live until you promote one by hand.
3. Fix forward: revert the bad PR with a new PR, merge it, check the new
   deployment, promote it.
4. Check the live URL and the certificate.

## Dependencies

Dependabot (GitHub's bot that opens PRs for new versions) runs in every repo.

- Schedule: weekly, Monday, for npm or Python packages and for GitHub Actions.
- A new version waits 7 days before Dependabot proposes it (the cooldown). Most
  bad releases are pulled in the first week.
- Minor and patch updates arrive as one grouped PR per ecosystem. A major
  update arrives as its own PR.
- Security updates arrive at once. The cooldown does not delay them.
- The kit caps open version PRs at one per configured ecosystem and explicitly
  marks its minor/patch group as version updates. Security PRs are outside that
  cap. This is not an atomic global three-waiting-PR limit. If arrivals exceed it,
  pause new promotion and ask the owner to resolve the backlog without stacks.
- Review release notes and the lockfile diff, including changed install scripts
  and new transitive dependencies; run affected consumer checks before promoting
  an update. Do not add dependencies, scopes or test skips to make an update pass.
- Actions are pinned to a full 40-character commit SHA with the tag in a
  comment. A tag can move. A SHA cannot. Turn on the setting that rejects
  unpinned actions once the repo runs green. The pins are listed in
  [pins.md](../pins.md). Bump steps are in [ci.md](../ci.md).
- Packages are pinned by a committed lockfile (`package-lock.json`, `uv.lock`).
  CI installs exactly what the lockfile says (`npm ci`, `uv sync --locked`).
  Ranges in the manifest are fine when the lockfile is committed.
- Tools that Dependabot cannot bump (a downloaded binary, a Docker image tag)
  are pinned by version and checksum, and listed in the repo's pins file.
- Runtimes (Node, Python) move once a year in their own PR, when the old one is
  within six months of end of life.
- Adding a dependency says why in the PR: what the standard library or an
  existing package cannot do. Check the maintainer, the last release date, and
  the license.

### Review a bump

1. Patch or minor group: read the PR's release notes summary and the lockfile
   diff. Look for new packages that were not there before. After checks and
   current review, follow the selected task mode before merge or auto-merge.
2. Major: read the release notes for breaking changes. Run the app or the
   tests locally. Check that the preview works. Merge alone, not with others.
3. Any bump with an install script, a new maintainer, or a sudden size jump:
   stop and look at the package's page before merging.
4. Stuck for a week: propose closure or a documented pin for owner approval.

Decision: Dependabot creation never grants merge permission. Each update needs
checks, current review and a selected task mode covering its scope.

## Security baseline

### Account

- Two-factor login with a passkey or hardware key. Recovery codes are in the
  password manager.
- Review authorized apps and installed GitHub Apps every 30 days and on each
  permission or repository-scope change. Use selected repos only; follow
  [reviewer access and spending policy](reviewers.md#access-and-spending).
- Fine-grained personal access tokens only, never classic. Scope each to named
  repos and the fewest permissions. Set an expiry of 90 days or less.

### Every repo

- Dependabot alerts and security updates on.
- Actions token default is read-only (`contents: read`). Raise a permission per
  job, never for the whole file.
- Workflows never use `pull_request_target`, which runs with secrets, and never
  run code from a PR with secrets.
- Text from outside (issue titles, PR titles, branch names) is never placed
  inside a `run:` script. Pass it through an `env:` variable.
- Checkout uses `persist-credentials: false`. Every job has `timeout-minutes`.
- `.gitignore` covers `.env*`, key files, and tool state folders.

### Public repos

- Secret scanning and push protection on. Push protection blocks a push that
  contains a known token pattern. It is free on public repos.
- Private vulnerability reporting on, and `SECURITY.md` says how to report.
- CodeQL (GitHub's code scanner) on, using the default setup in Settings, Code
  security. It is never a required check. Read its alerts in the weekly review.
- Require approval for first-time contributors' workflow runs.

### Private repos

- Hosted secret scanning may not be available on your plan. Check Settings.
  Until you know, scan locally.
- Run a local scanner (gitleaks) before every push. A global pre-push hook does
  it for all repos. A repo that uses its own hook manager calls the same scan.
  A clean scan exits 0. Run it with no network, and pin the tool by version or
  image digest.
- Rulesets and required checks on private repos need GitHub Pro. Decision: use
  Pro. Why: it costs little next to one unprotected `main`. Without Pro, keep a
  local pre-push hook that refuses `main`, and work through PRs by habit.
- What else depends on the plan is in [repos.md](repos.md), "Private repo
  limits and fallback".

### If a secret leaks

Treat any secret that reached a commit, a log, a screenshot, a chat, or a public
repo as stolen. Order matters.

1. Notify the owner privately without the value; the owner authorizes and
   revokes or rotates it at the source first. Do not expose it again.
2. Check the provider's usage log for the window it was exposed. Note anything
   you did not do.
3. Put the new value in place (see Secrets) and redeploy what used it.
4. Remove the value from the code in a PR. Rewriting history is optional and
   does not undo the leak, because forks and caches keep copies.
5. Close the scanning alert as "revoked".
6. Fill in [incident.md](../../templates/incident.md). If money, data, or an
   attacker was involved, fill in
   [postmortem.md](../../templates/postmortem.md) within a week.
7. Add the check that would have caught it (a pattern, a hook, a `.gitignore`
   line).

## Secrets

Decision: Bitwarden is the source of truth for every secret. Why: one place to
rotate, audit, and recover from. The repo, Vercel, and GitHub hold copies only.

The best secret is one that does not exist. Prefer, in this order:

1. No secret: the automatic `GITHUB_TOKEN`, Vercel's Git integration, and OIDC.
2. A short-lived token.
3. A scoped, expiring key, stored in Bitwarden.

Rules:

- Nothing secret goes in a repo, in `vercel.json`, in an issue or PR, in chat,
  or in a screenshot. Never open, paste, or print a `.env*` file.
- Each secret has a name, an owner (the service), a place it is used, and an
  expiry or rotation date, recorded in its Bitwarden entry.
- Local work reads secrets from a `.env.local` file that is ignored by Git,
  filled from Bitwarden.
- A machine account token for the command-line tool lives in your user
  environment, not in a file in a repo.

### Move a secret to GitHub Actions or Vercel

Owner-run procedure after named secret and destination approval: pipe the value
from Bitwarden straight to the destination. It never lands in a
file, in the repo, or on the command line.

```powershell
# GitHub Actions secret: read from Bitwarden, send to GitHub on stdin
(bws secret get <secret-id> | ConvertFrom-Json).value | gh secret set NAME --repo alawein/<repo>

# Vercel variable: the same, to one environment
(bws secret get <secret-id> | ConvertFrom-Json).value | vercel env add NAME production
```

Use a repository secret for one repo, never an organization-wide secret for a
single use. Give a workflow a secret only in the job step that needs it.

### Rotation rhythm

- On any leak or suspected leak: at once.
- When a tool, machine, or service you used is retired or lost: at once.
- Keys that can spend money or write to production: every 90 days.
- Other keys with no built-in expiry: every 180 days.
- Tokens with a built-in expiry: set to 90 days or less, and renew before it ends.

The first Monday of each quarter is rotation day. It is a dated task on the
board.

To rotate: create the new secret at the source, update Bitwarden, update GitHub
and Vercel, redeploy, then revoke the old one. Revoke last, so nothing breaks.

## Backups

Every repo has a remote on GitHub, private repos included. That is one copy. A
laptop clone is a second copy, but both depend on you and one login.

- Keep local recovery evidence at session end. A remote backup push or draft
  PR still needs its named owner approval.
- Each month, back up everything to a place outside the working folder and
  outside any folder that syncs deletions: an external drive, or an encrypted
  cloud bucket. Do both for private repos.
  - Git: `git clone --mirror` of every repo (a full copy with all branches
    and tags).
  - Issues and PRs: export to JSON with `gh issue list --state all --json ...`
    and `gh pr list --state all --json ...`, per repo, with a high `--limit`.
  - The board: `gh project item-list <number> --owner alawein --format json`.
  - Notion: its own export.
- Secrets are backed up by Bitwarden. Env variable names are in each README.
- Each quarter, restore one repo from a mirror into a scratch folder and run its
  tests. A backup you have not restored is a guess.
- A repo you archive stays on GitHub as read-only. Keep its mirror. Retired
  repos are renamed `ARCHIVE-<name>` and isolated as described in
  [archive.md](../archive.md).

## Incidents and rollback

An incident is anything live that is broken, exposed, or losing data.

| Severity | Meaning | Response |
| --- | --- | --- |
| High | Production down, data loss, or a leaked secret | Stop now. Roll back first |
| Medium | Degraded, or one feature broken | Fix the same day |
| Low | Cosmetic, or a workaround exists | Normal issue |

Steps, in order:

1. Stop dependent promotion and preserve evidence. The owner authorizes and
   executes rollback, feature disablement or secret revocation. Prepare the
   smallest local revert or fix; an incident does not waive action gates.
2. Open a copy of [incident.md](../../templates/incident.md) in your log. Note the
   time you noticed, and keep a one-line timeline as you go.
3. Prepare a plain update for affected people; sending it needs named approval.
4. Fix forward in a normal PR with a `fix(scope): ...` title. A fix in a hurry
   still uses a PR and the checks.
5. Verify live.
6. Write the postmortem for any High incident, and for any Medium that repeated.
   Use [postmortem.md](../../templates/postmortem.md). Each fix becomes an issue
   on the board.

How to undo each kind of change:

| What went wrong | How to undo |
| --- | --- |
| A bad merge to `main` | Revert the PR (a new `fix(scope): revert ...` PR) |
| A bad site deploy | Instant Rollback on Vercel, then revert the PR |
| A bad package release | Deprecate or yank it, ship a patch. Tags cannot be moved |
| A bad data change | Restore from the backup taken before the change |
| A leaked secret | Rotate at the source first. See "If a secret leaks" |
| A bad ruleset or setting | Owner-approved repair with saved prior settings and restored enforcement |

Code rollback does not restore data or DNS. Use the saved baseline and obtain
the owner's separate approval for each remote rollback.

## Review tools

Follow [reviewers.md](reviewers.md): CodeRabbit is the sole automatic reviewer
after named owner activation; secondary review is scoped and manual. Review
findings are advisory. Preserve required checks, selected-mode merge permission,
three waiting PRs, no stacks, no queue and no bypass actors.
