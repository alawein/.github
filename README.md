# .github

Shared standards for every repository under github.com/alawein: community
health files, issue and pull request templates, reusable workflows, rulesets,
scripts, repo starters, and the rules for how work ships. Start with
[docs/system/README.md](docs/system/README.md).

GitHub applies the files in the root of this public repo to any repo that has
no copy of its own. A repo's own copy replaces the default. They are not
merged. Everything else here is copied or run by hand.

## Make a repo in ten minutes

You need git, the GitHub CLI signed in once (`gh auth login`), PowerShell, and
the tools for the class: `npm` (TypeScript tool, site) or `uv` and `just`
(Python tool, lab, docs). Run the scripts from the root of this folder. They
print a plan first and change nothing until you add a flag.

1. Plan the folder. The name rules and classes are in
   [docs/system/repos.md](docs/system/repos.md).

   ```powershell
   .\scripts\new-repo.ps1 -Name label-sync -Class tool -Language python -Description "Sync GitHub labels from a file." -Path C:\src
   ```

2. Add `-Create` to write it. `-Path` must be a folder outside this kit, and
   the new folder must not exist yet. Private is the default. Add
   `-Visibility public` only when others should read it.
3. In the new folder: run the install and check commands that the script
   prints, then `git init -b main` and make the first commit.
4. Still in the new folder, create the repo on GitHub and push:
   `gh repo create alawein/label-sync --private --source . --push`.
5. Back in this kit folder, apply the standard. The first command reads and
   prints only. The second writes.

   ```powershell
   .\scripts\setup-repo.ps1 -Repo alawein/label-sync -Class tool -Language python
   .\scripts\setup-repo.ps1 -Repo alawein/label-sync -Class tool -Language python -Apply
   ```

6. Audit the result: `.\scripts\verify-repo.ps1 -Repo alawein/label-sync -Class tool -Language python`.

If `new-repo.ps1` says to replace a placeholder pin (all zeros), follow
[docs/ci.md](docs/ci.md), "After the first commit". Until that is done the
branch ruleset (the rules GitHub enforces on `main`) is skipped on purpose. Rulesets on a private repo need GitHub
Pro (see [docs/system/repos.md](docs/system/repos.md), "Private repo limits and
fallback").

## What is here

| Path | What it is |
| --- | --- |
| [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md), [SUPPORT.md](SUPPORT.md), [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) | Default community files, applied to every repo |
| [LICENSE](LICENSE), [.gitignore](.gitignore), [.gitattributes](.gitattributes) | The kit's own license (MIT), ignore rules (no env files, keys, CSV, or log data), and LF line ends. Not inherited by other repos |
| [PULL_REQUEST_TEMPLATE.md](PULL_REQUEST_TEMPLATE.md) | Sections every PR fills in. Same file as in the profile repo |
| [ISSUE_TEMPLATE/](ISSUE_TEMPLATE) | Bug, feature, and task forms. Blank issues are off |
| [docs/system/repos.md](docs/system/repos.md) | Six repo classes, naming, layout, day-one files, testing, licenses, private repo limits |
| [docs/system/delivery.md](docs/system/delivery.md) | Flow, branches, PR titles, merging, rulesets, releases, Vercel, dependencies, security, incidents |
| [docs/system/projects.md](docs/system/projects.md) | Issues, the Work board, milestones, weekly review |
| [docs/system/agents.md](docs/system/agents.md), [agents-examples.md](docs/system/agents-examples.md) | How AI agents work in a repo, and five sample task briefs |
| [docs/ci.md](docs/ci.md), [docs/pins.md](docs/pins.md) | How the shared workflows work, how to bump a pin, and every pinned version |
| [docs/vercel.md](docs/vercel.md), [docs/brand.md](docs/brand.md), [docs/archive.md](docs/archive.md) | Domain moves and `vercel.json`, banners and README copy, retiring repos as `ARCHIVE-` |
| [.github/workflows/ci.yml](.github/workflows/ci.yml) | This repo's own CI. It calls the four checks and carries their names |
| [lint-markdown.yml](.github/workflows/lint-markdown.yml), [check-links.yml](.github/workflows/check-links.yml), [lint-actions.yml](.github/workflows/lint-actions.yml), [pr-title.yml](.github/workflows/pr-title.yml) | Reusable workflows for `markdown-lint`, `link-check`, `actionlint`, `pr-title` |
| [node-ci.yml](.github/workflows/node-ci.yml), [python-ci.yml](.github/workflows/python-ci.yml) | Reusable test workflows for `node-ci` and `python-ci` |
| [.github/dependabot.yml](.github/dependabot.yml), [.github/CODEOWNERS](.github/CODEOWNERS) | Dependabot for this repo's own pins, and the owner of every path here |
| [templates/workflows/](templates/workflows) | CI stubs to copy to `.github/workflows/ci.yml`: `docs.yml`, `node.yml`, `python.yml`, `site.yml` |
| [templates/dependabot-actions.yml](templates/dependabot-actions.yml), [dependabot-npm.yml](templates/dependabot-npm.yml), [dependabot-pip.yml](templates/dependabot-pip.yml) | Dependabot files to copy to `.github/dependabot.yml` |
| [templates/CODEOWNERS](templates/CODEOWNERS), [templates/labels.yml](templates/labels.yml) | Owner of every path, and the five labels (record only) |
| [templates/README.template.md](templates/README.template.md), [templates/adr/0000-template.md](templates/adr/0000-template.md) | README with the brand banner, and the decision record template |
| [templates/pull-request-checklist.md](templates/pull-request-checklist.md), [templates/project-board.md](templates/project-board.md) | Long PR checklist, and the Work board setup |
| [templates/incident.md](templates/incident.md), [templates/postmortem.md](templates/postmortem.md) | Incident note and postmortem |
| [templates/agent/AGENTS.template.md](templates/agent/AGENTS.template.md), [CLAUDE.template.md](templates/agent/CLAUDE.template.md), [cursor-rules.template.mdc](templates/agent/cursor-rules.template.mdc), [codex-notes.template.md](templates/agent/codex-notes.template.md) | Agent instructions and the thin pointer file for each tool |
| [templates/agent/lessons.template.md](templates/agent/lessons.template.md), [session-start-prompt.md](templates/agent/session-start-prompt.md), [review-checklist.md](templates/agent/review-checklist.md) | Lessons log, prompt to start a session, what a reviewing agent checks |
| [templates/starters/](templates/starters) | One complete minimal repo per starter: `docs`, `typescript`, `python`, `site`, `lab`. Each has `AGENTS.md`, `CLAUDE.md`, and `docs/lessons.md` |
| [rulesets/main-public.json](rulesets/main-public.json), [main-private.json](rulesets/main-private.json), [tags.json](rulesets/tags.json) | `main` rules for public and private repos, and the `v*` tag rule |
| [rulesets/repo-settings-public.json](rulesets/repo-settings-public.json), [repo-settings-private.json](rulesets/repo-settings-private.json) | Merge and security settings |
| [scripts/new-repo.ps1](scripts/new-repo.ps1) | Create a repo folder from a starter. Dry run by default |
| [scripts/setup-repo.ps1](scripts/setup-repo.ps1), [scripts/verify-repo.ps1](scripts/verify-repo.ps1) | Apply the standard to one repo, and audit one repo read-only |
| [scripts/archive-repos.ps1](scripts/archive-repos.ps1), [scripts/audit-archive.ps1](scripts/audit-archive.ps1) | Retire repos in small batches, and audit the archive read-only |
| [.markdownlint-cli2.yaml](.markdownlint-cli2.yaml), [.lycheeignore](.lycheeignore) | Lint settings for this repo |

All scripts are PowerShell. Dry run is the default, and none of them deletes
anything.

## Changing this repo

Change it the same way as any repo: a branch, a draft pull request with a
`type(scope): summary` title, green checks, and a squash merge by the owner.
The rules are in [docs/system/delivery.md](docs/system/delivery.md).
