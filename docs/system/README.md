# System

How a repo under github.com/alawein is shaped, built, shipped, and kept healthy.
Start with the page for the step you are on. Each fact has one home, and the
other pages link to it.

```text
  pick a class        make the folder          work and ship
  ------------        ---------------          -------------
  profile, docs,  --> new-repo.ps1        -->  issue, branch, draft PR,
  tool, site, lab     copies a starter         checks, selected-mode merge
  (repos.md)          (templates/starters)     (projects.md, delivery.md)
```

## Pages

| Page | What it covers |
| --- | --- |
| [repos.md](repos.md) | Repo classes and how to choose, visibility, one repo or many, naming, layout, day-one files, tasks, testing, documentation, decision records, changelog, licenses |
| [delivery.md](delivery.md) | The flow, branches, commits, PR titles and rules, labels, merging, rulesets, versions and releases, environments, Vercel, dependencies, security, secrets, backups, incidents |
| [projects.md](projects.md) | Issues, the Work board, milestones, triage, the weekly review, definition of done |
| [agents.md](agents.md) | How AI agents work in a repo: instructions file, session routine, work loop, parallel work, model routing, safety floor |
| [reviewers.md](reviewers.md) | Reviewer routing, findings, and CodeRabbit as the sole automatic reviewer after named activation |
| [agents-examples.md](agents-examples.md) | Five sample task briefs |

Pages outside this folder: [ci.md](../ci.md) (shared workflows and pin bumps),
[pins.md](../pins.md), [vercel.md](../vercel.md) (domain moves),
[archive.md](../archive.md), and [brand.md](../brand.md).

## Files that belong to these pages

| Path | What it is |
| --- | --- |
| [../../scripts/new-repo.ps1](../../scripts/new-repo.ps1) | Creates a new local repo folder from a starter. Dry run by default |
| [../../scripts/setup-repo.ps1](../../scripts/setup-repo.ps1), [verify-repo.ps1](../../scripts/verify-repo.ps1) | Apply and audit the settings and rulesets of one repo |
| [../../templates/starters/](../../templates/starters) | One complete minimal repo per starter: docs, typescript, python, site, lab |
| [../../templates/agent/](../../templates/agent) | Agent instruction templates and prompts |
| [../../templates/adr/0000-template.md](../../templates/adr/0000-template.md) | The decision record template |
| [../../templates/pull-request-checklist.md](../../templates/pull-request-checklist.md) | The long checklist for a big or risky PR |
| [../../templates/project-board.md](../../templates/project-board.md) | The Work board setup |

## Adding a page

Add a row to the Pages table in the same pull request as the page. A page has
one topic. If two pages overlap, merge them.
