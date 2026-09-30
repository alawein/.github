# Archived repos

How an old repo is archived so that nothing ever touches it again. Archived repos are kept for
their history, their activity, and as a source of ideas. They are not used, not deployed, and not
revived. `scripts/archive-repos.ps1` applies the standard, and `scripts/audit-archive.ps1` checks it.
Other files point here and do not copy it.

Two decisions, both final:

- **Prefix.** Every archived repo is named `ARCHIVE-<old-name>`. One prefix, no exceptions. The old
  profile repo becomes `ARCHIVE-<owner>` (the owner name after the prefix). The earlier `RETIRED-` prefix is replaced everywhere.
- **Never delete.** An archived repo is never deleted. Deleting loses the record (next section).
  Isolation, not deletion, is how an archived repo stays out of the way.

## What deleting would lose

Deleting a repo is not something to do. A deleted repo loses, for good:

- its commits and full history
- its issues and pull requests
- its releases and tags
- its stars and watchers
- its activity on the contribution graph and in insights

Archiving keeps all of it, read-only. For a private repo, the profile setting "Include private
contributions" decides whether its activity shows on the graph, so keep that setting on. Moving a
repo to the archive org (Layer 1) keeps its history, issues and pull requests. Verify: after the
first move, compare the profile graph before and after, and read
`gh api repos/<org>/<repo>/commits?per_page=1` on the moved repo.

## The isolation system

```text
  GitHub account (live work)        Org "alawein-archive" (the folder)
  +--------------------------+      +------------------------------------------+
  | active repos             |      | LAYER 1  org: no Actions, no apps,       |
  | never pinned archives    |      |          no secrets, no forks, no access |
  | LAYER 3  account rules   |      |   +------------------------------------+ |
  +--------------------------+      |   | LAYER 2  each repo                 | |
            |                       |   | ARCHIVE-<name>, read-only, topics, | |
            | guards refuse         |   | [ARCHIVE] description, no homepage | |
            v  ARCHIVE- names       |   +------------------------------------+ |
  +--------------------------+      +------------------------------------------+
  | LAYER 4  tooling guards  |                        ^
  | setup, verify, workflows |                        | read-only GETs
  | agents, Vercel           |      +------------------------------------------+
  +--------------------------+      | LAYER 5  audit-archive.ps1: PASS or FAIL |
                                    +------------------------------------------+
```

### Layer 1: a separate org is the folder

Move every archived repo to an org named `alawein-archive`. The org is a folder: one place, one set
of rules, and nothing else lives there. GitHub has no API to create an org, so the owner creates it
by hand, then applies these settings by hand:

- Actions: disabled for all repositories.
- GitHub Apps: none installed. No OAuth apps approved.
- Member privileges: base permission none; repository creation disabled; forking disabled
  (including private repos).
- Access: no outside collaborators, no other members, two-factor required.
- Pages: off. No Pages site can be created.
- Webhooks: none on the org or on any repo. Deploy keys: none.
- Secrets and variables: none, at org and repo level.
- Security features: off for new repos. Leave on only what is free and read-only, such as alerts.
  Dependabot version updates and security updates off, because they open pull requests.
- Custom property: optional `status` with the value `archived` on every repo. Organizations only.
  Verify: `gh api orgs/alawein-archive/properties/schema` (200 means the plan allows it).

`scripts/audit-archive.ps1 -Owner alawein-archive` checks every setting above that an API can read.

### Layer 2: each repo

| Part | Rule |
| --- | --- |
| Name | `ARCHIVE-<old-name>`. Keep the old name after the prefix, even if it breaks the naming rules. A leading `RETIRED-` is dropped. |
| Archived flag | On. The archive step comes last. The repo is then read-only. |
| Topics | `archived`, `do-not-use`, `stats-only`, `origin-<year>` (the year the repo was created), then the old content topics. Drop old status topics such as `retired`, `frozen`, `demo`, `active`. Maximum 20. |
| Description | `[ARCHIVE]`, a space, then the old description, at most 350 characters. No description? `[ARCHIVE] No description was recorded`. |
| Homepage | Cleared. A live site belongs to its new home, not to an archived repo. |
| Pages | Unpublished. Owner step (see Owner-only steps). |
| Actions | Off. The script turns it off before the archive step. |
| Webhooks, deploy keys, secrets | None. Owner step; the audit counts them. |
| Visibility | Unchanged. A private repo stays private. |
| Custom property | `status=archived`, if the org plan allows. The transfer step sets it when the org has the property. |

### Layer 3: the account

- Never pin an archived repo on the profile.
- Do not list archived repos in any README, site, catalog or portfolio page as live work.
- Keep "Include private contributions" on so archived activity still counts on the graph.
- Every live repo that once deployed from an archived one points at its new repo. No link goes the
  other way.

### Layer 4: tooling guards

- The kit's setup and verify scripts refuse any repo whose name starts with `ARCHIVE-`.
- Every reusable workflow starts with a guard job that fails when the repository name starts with
  `ARCHIVE-`, and every other job in that workflow lists it under `needs`. The guard:

  ```yaml
  jobs:
    archive-guard:
      runs-on: ubuntu-latest
      timeout-minutes: 1
      permissions: {}
      steps:
        - name: Refuse to run in an archive repo
          env:
            REPO: ${{ github.repository }}
          run: |
            case "${REPO#*/}" in
              ARCHIVE-*) echo "::error::${REPO} is an archive repo. Workflows never run here."; exit 1 ;;
            esac
  ```

- Local rule for people and agents: never clone, edit, fork, or reference an `ARCHIVE-` repo in
  new work. Read one only to look up an idea, and copy nothing into a live repo without rewriting it.
- Vercel: disconnect every project from an archived repo before archiving. In the project, open
  Settings, then Git, then Disconnect. This keeps the project and its last deployment, and stops
  any new one. The script asks you to confirm this for each batch that has Vercel-linked repos.
- Cloudflare and other hosts: same rule. No host keeps a live link to an archived repo.

### Layer 5: the audit

`scripts/audit-archive.ps1` uses GET requests only. For every repo named `ARCHIVE-*` it checks:

| Check | Pass when |
| --- | --- |
| archived flag | on |
| topics | `archived`, `do-not-use`, `stats-only`, and one `origin-<year>` are present |
| description | starts with `[ARCHIVE]` and a space |
| homepage | empty |
| Pages | off |
| Actions | off |
| webhooks | 0 |
| deploy keys | 0 |
| secret names | 0 (names are counted, values are never read) |
| installed apps | 0 for an org. Verify by hand on a personal account (no per-repo API). |

It prints PASS, WARN or FAIL per repo and a summary. It exits 4 when anything fails. Run it after
every batch and once a month. It never writes.

## What an archived repo may still contain

- The full history, issues, and pull requests, as they were.
- The `LICENSE` file, always.
- The old README. A banner that says `ARCHIVED, do not use` is welcome but optional. It needs a
  commit, so add it before archiving, through a pull request.
- Nothing new. No commits, no releases, no new branches after the archive step.

## Unarchiving

Never, to revive it. If the work matters again, start a new repo and copy what you need. The old
repo stays a record.

The only allowed unarchive is inside the script, for the few seconds needed to edit the name,
description, topics, or homepage. The script archives the repo again in the same run.

## Redirects

GitHub redirects the old repo URL to the new one after a rename or a move. The redirect lasts until
a new repo takes the old name. Do not reuse an old name for an unrelated repo. The one planned
exception is a profile repo, which must be named like its owner. Rename the old one first, and
expect its old URL to stop redirecting once the new one exists.

## Looking up an archived repo

- List them all: `gh repo list alawein-archive --limit 300`.
- List by topic: `gh repo list alawein-archive --topic do-not-use`.
- Find by old name: search for `ARCHIVE-<old-name>`, or `gh repo view <owner>/<old-name>` while the
  redirect lasts.
- Find by what it did: read the description. Every one starts with `[ARCHIVE]`.
- Keep the map file (`archive-rename-map.csv`) as the old-name to new-name index. It also holds the
  old description and topics for rollback. It is private and stays out of git.

## The map file

One row per repo. Columns:

| Column | Meaning |
| --- | --- |
| `batch` | `AR0` is the one-repo test. `AR1` and up hold ten repos or fewer. Held repos get their own batches. The old profile repo is last. |
| `old_name`, `new_name` | Current name and target name (`ARCHIVE-` plus the old name). |
| `old_description`, `new_description` | What it says now, and what it will say. |
| `old_topics`, `new_topics` | Semicolon-separated. |
| `old_homepage` | Homepage now. Restored by rollback. |
| `has_pages`, `bot_deploy`, `deploy_creator`, `hooks_count`, `fork`, `created_year` | Survey facts. |
| `hold_reason`, `suggested` | Why a repo is held, and what the survey suggests. |
| `decision` | `go`, `clear`, `keep`, `skip`, or blank. Blank and `skip` are not run. `go` and `clear` clear the homepage. `keep` leaves it, for a live site the owner has chosen to keep for now. |

## The script

```powershell
# Plan (default). Prints the plan and the typed phrase. Makes no network call.
.\scripts\archive-repos.ps1 -MapPath .\archive-rename-map.csv -Batch AR0

# Write one batch. Type the phrase it prints: APPLY AR0
.\scripts\archive-repos.ps1 -MapPath .\archive-rename-map.csv -Batch AR0 -Apply

# Read-only check of live state against the map.
.\scripts\archive-repos.ps1 -MapPath .\archive-rename-map.csv -Batch AR0 -Verify

# Move renamed repos into the archive org. Refuses unless the org exists and you own it.
.\scripts\archive-repos.ps1 -MapPath .\archive-rename-map.csv -Batch AR0 -Transfer
.\scripts\archive-repos.ps1 -MapPath .\archive-rename-map.csv -Batch AR0 -Transfer -Apply

# Undo a batch: name, description, topics, homepage. Type: APPLY AR0 ROLLBACK
.\scripts\archive-repos.ps1 -MapPath .\archive-rename-map.csv -Batch AR0 -Rollback -Apply

# Read-only audit of everything named ARCHIVE-.
.\scripts\audit-archive.ps1 -Owner alawein
```

Per repo, in this order:

1. Unarchive, because an archived repo cannot be edited.
2. Rename.
3. Edit the description.
4. Set the topics.
5. Clear the homepage (`go` and `clear` rows).
6. Turn Actions off.
7. Archive again.
8. Read the repo back and compare it with the map.

The transfer is its own step, after the rename batches, with its own typed phrase
(`TRANSFER AR0`). Archived repos may not move in one call. Verify: run the transfer on the test
batch first. If GitHub refuses, unarchive, move, and archive again by hand, and record it here.

Safety rules built in:

- Plan is the default. Writing needs one batch and a typed phrase. The plan above the prompt lists
  every repo in the batch.
- A batch with Vercel-linked repos asks for a second typed phrase: `VERCEL DISCONNECTED <batch>`.
- A repo whose Pages site is still published blocks its batch before any write.
- Three seconds between writes.
- It stops on any 403 or 429, and on any other error. Rerunning the same batch resumes, because
  finished steps are skipped.
- It never deletes: no repo, no webhook, no Pages site, no branch, no secret, no key.
- It checks the map first: prefix, description format and length, topic rules, duplicate names
  (case-insensitive), and that every name and `-Owner` hold only letters, digits, dot, underscore
  and hyphen (they go into API paths). A bad map stops the run before any call.
- It logs every step to a local NDJSON file with the state before each change. The default folder
  is under the local app data folder.
- After a transfer, use `-Owner alawein-archive` for `-Verify` and for any later edit.

## Owner-only steps

The script does not do these, because each one is a delete or lives outside the repo settings:

- Unpublish Pages: `gh api -X DELETE repos/<owner>/<repo>/pages`. This removes the published
  content. Record the build type first.
- Remove a webhook: list with `gh api repos/<owner>/<repo>/hooks --jq '.[].config.url'`, then delete
  each one.
- Remove deploy keys and secrets: list them with `gh api repos/<owner>/<repo>/keys` and
  `gh api repos/<owner>/<repo>/actions/secrets`, then delete each one.
- Disconnect the repo in the host's dashboard (Vercel, Cloudflare).
- Verify: GitHub may refuse these deletes on a repo that is already archived. If it does, unarchive
  that repo by hand, remove the items, and archive it again.
- Create the `alawein-archive` org and set its settings (Layer 1).
- Move a repo back out of the org, if it is ever needed, with the same transfer endpoint. Do this
  only for a wrong move.

## Order of work

1. Create the org and apply its settings. Run `audit-archive.ps1 -Owner alawein-archive`.
2. Plan the test batch (`AR0`). Apply it. Look at the repo on GitHub. Roll back if it looks wrong.
3. Transfer the test repo. Run the audit on both owners. Check the profile graph.
4. Run the clean batches one at a time, each with its own phrase, read-back, and audit.
5. Decide each held repo, disconnect its host project, then run the held batches.
6. Rename the old profile repo last, after the new profile repo is ready.
7. Transfer every renamed batch. Run the audit. Repeat monthly.
