# Repos

The single home for how a repo is shaped: its class, its name, its layout, what
it holds on day one, how it is tested and documented, and how decisions and
releases are recorded. Other pages point here and do not copy it.

Lines that start with "Decision:" record a choice that was open. The reason
follows on the same line.

## Make a repo

1. Pick the class (next section).
2. Run `scripts/new-repo.ps1 -Name <name> -Class <profile|docs|tool|site|lab>`.
   A tool also takes `-Language typescript` (default) or `-Language python`.
   It prints the plan and writes nothing. Add `-Create` to write the folder.
   It never runs git and never touches the network.
3. Read "Next steps" at the end of its output. They are short.

The script copies a starter from `templates/starters/`, fills the placeholders,
and stops if the name breaks the rules below. A starter is a complete minimal
repo: it passes its own checks once the lockfile exists. It also carries
`AGENTS.md`, `CLAUDE.md`, and `docs/lessons.md`, filled in for the class.

An archived repo has no starter. The script refuses `-Class archive` and any
name that starts with `ARCHIVE-`.

## Classes

A class is the shape of a repo. It sets the starter, the layout, the license,
and the banner. Visibility is a separate choice (see "Visibility").

| Class | What it is | Starter | CI stub | Test check | Banner kind |
| --- | --- | --- | --- | --- | --- |
| profile | The `alawein/alawein` repo. One screen: who, selected work, links. Always public | `docs` | `docs.yml` | none | docs |
| docs | Guides, notes, a knowledge base, or a kit of templates | `docs` | `docs.yml` | none | docs |
| tool | A library, CLI, or app in TypeScript or Python | `typescript` or `python` | `node.yml` or `python.yml` | `node-ci` or `python-ci` | library or tool |
| site | A website built with Astro and deployed on Vercel | `site` | `site.yml` | `node-ci` | site |
| lab | An experiment or research code. One question per repo | `lab` (Python) | `python.yml` | `python-ci` | lab |
| archive | A retired repo, read only, named `ARCHIVE-<old-name>` | none | none | none | none |

Only the site class uses Vercel. Archive rules are in
[archive.md](../archive.md). The stubs, Dependabot files, and what each check
does are in [ci.md](../ci.md).

How to choose. Stop at the first yes.

1. Is the work finished and no longer maintained? Class archive.
2. Does it serve web pages to visitors? Class site.
3. Do other programs or people import or run it? Class tool.
4. Is the point to find an answer, not to ship a product? Class lab.
5. Otherwise it is text. Class docs (or profile, if it is the repo named like
   the user).

A lab that turns into something people use is promoted: create a tool repo from
a starter, copy the code over, and archive the lab. The history stays in the
archived lab. A lab with no commit for 90 days is either promoted or archived.

Decision: six classes, and visibility is not a class. Why: the same shape (a
tool, say) can be private today and public next year, and a class that changes
with visibility would need a rename.

Decision: a TypeScript lab uses the `typescript` starter with a `-lab` name. Why:
one more starter for a rare case is more upkeep than it saves.

## Visibility

- Default is private. Make a repo public only when someone else should read or
  use it.
- Public means public-safe: no secrets, no personal or private paths, no email
  addresses, no data about other people, and no names of private systems.
- History cannot be unpublished. Before going public, run a secret scan over the
  whole history. If anything was ever committed that should not be seen, publish
  a fresh repo from a clean copy instead.
- The profile repo and the kit of shared defaults are always public.

Decision: private by default. Why: going public is a one-way step, and going
private is not.

### Private repo limits and fallback

Some protections on private repos depend on the GitHub plan. This is what
applies and what does not.

| Feature | Public repo | Private repo | Fallback for private |
| --- | --- | --- | --- |
| Branch and tag rulesets | Yes | Yes, on a paid personal plan (Pro) | If a call answers 403 "Upgrade to GitHub Pro", the plan is Free and no server-side rule is possible. Use a local pre-push hook that refuses `main`, and keep to pull requests by habit. Both scripts stop on that 403, so nothing is written or judged until the plan changes |
| Required signed commits | Yes | Left out on purpose, because a tool that pushes unsigned would be blocked | Sign commits locally anyway (`commit.gpgsign true`) |
| Required checks | Yes | Only with `-Strict`, and only when `ci.yml` defines the jobs | Run `setup-repo.ps1 -Strict` again after CI exists |
| Secret scanning and push protection | Yes, free | Plan-dependent | Run a local scanner before every push (below) |
| CodeQL and dependency review | Yes, free | Plan-dependent | None. Keep Dependabot on |
| Dependabot alerts and security updates | Yes | Yes, free | Not needed |
| Private vulnerability reporting, first-time contributor approval | Yes | No such setting | `SECURITY.md` tells reporters to open a task issue with no details |
| Merge settings, Actions token settings, labels | Yes | Yes | Not needed |

Check your plan under Settings, Billing. `setup-repo.ps1 -Apply` turns on
private vulnerability reporting for a public repo and reads the fork PR
approval setting. It prints what to change if first-time contributors are not
held for approval. It does not change that setting. `verify-repo.ps1` checks
that private vulnerability reporting is on.

Local secret scan for private repos, run from the repo root before you push.
Pin the image by digest after the first pull, and run it with the network off:

```powershell
docker run --rm --network none -v "${PWD}:/repo:ro" zricethezav/gitleaks@sha256:<digest> git /repo --redact --no-banner
```

Older gitleaks releases call the subcommand `detect` instead of `git`. Check
`git --help` once. A clean scan exits 0.

## One repo or many

Polyrepo means one repo per thing. Monorepo means one repo that holds many
packages.

Decision: polyrepo by default. Why:

- Visibility, branch rules, checks, and access are set per repo. A private
  service and a public library cannot share one repo without leaking or
  loosening something.
- Each Vercel project deploys one repo. A site and a library in one repo means
  one of them redeploys for no reason.
- An AI coding agent works best in a small repo with one clear root and one
  instructions file. A big repo fills its context with code that does not
  matter.
- A failed check or a bad release hurts one repo, not everything.

Use a monorepo only when all three hold:

1. The packages ship together, on one version or one deploy.
2. They change in the same pull request most of the time.
3. They share one owner and one visibility.

Then the repo takes the class of its main product. Put packages under
`packages/<name>/`, use npm workspaces (TypeScript) or a uv workspace (Python),
and pass `working-directory` to the shared workflows. There is no starter for
this. Create the repo from a starter and move the code in.

Shared code goes in a small tool repo that the others install. Copy a file
instead when it is under about 50 lines and unlikely to change.

Small throwaway experiments that do not deserve their own repo live in one
private repo, `scratch-lab`, one folder each, with no checks required.

## Naming

One name per thing. The repo, the local folder, the package, the deploy project,
and the docs title all use the same name.

- Lowercase words joined by hyphens: `label-sync`, not `Label_Sync`.
- 3 to 30 characters. Letters, digits, and hyphens only.
- No version, date, status word (`new`, `old`, `final`, `draft`, `wip`, `beta`),
  `tmp`, `copy`, `backup`, or owner prefix.
- A suffix says the kind, and the class must match it:

| Suffix | Class | Example |
| --- | --- | --- |
| `-site` | site | `notes-site` |
| `-docs` | docs | `guide-docs` |
| `-kit` | docs (templates and starters) | `starter-kit` |
| `-lab` | lab | `sandbox-lab` |
| none | tool | `label-sync` |

- A tool never ends in `-site`, `-docs`, `-kit`, or `-lab`.
- The profile repo is named like the user, `alawein/alawein`. Shared defaults
  live in `alawein/.github`.
- The prefix `ARCHIVE-` is reserved for retired repos (see archive.md). No live
  repo uses it, and no live repo is named with a status word.
- The display name in the README is the repo name in sentence case ("Label
  sync"), at most 28 characters.

`new-repo.ps1` checks these rules before it writes anything.

## Layout per class

Every class shares the root files listed in "Day one". Below is what each adds.
`.` is the repo root. Files in brackets are created on the first run of the
install command.

```text
docs / profile             tool (typescript)           tool (python)
.                          .                           .
  README.md                  README.md                   README.md
  docs/                      CHANGELOG.md                CHANGELOG.md
    overview.md              package.json                pyproject.toml
  justfile                   [package-lock.json]         [uv.lock]
                             tsconfig.json               .python-version
                             tsconfig.build.json         justfile
                             eslint.config.js            src/<module>/
                             .prettierrc.json              __init__.py
                             vitest.config.ts              cli.py
                             src/                        tests/
                               index.ts                    test_cli.py
                               index.test.ts

site                       lab
.                          .
  README.md                  README.md
  package.json               NOTES.md
  [package-lock.json]        pyproject.toml
  astro.config.mjs           [uv.lock]
  tsconfig.json              .python-version
  eslint.config.js           justfile
  vercel.json                src/<module>/
  public/                      __init__.py
  src/                         core.py
    pages/index.astro        tests/
    lib/                       test_core.py
      slugify.ts             data/README.md
      slugify.test.ts        results/README.md
```

Rules that hold in every class:

- Source in `src/`, tests as described in "Testing", docs in `docs/`, scripts
  in `scripts/`, images in `assets/`.
- No file named `utils`, `helpers`, `misc`, or `temp`. Name a file for what it
  does.
- Generated output (`dist/`, `.astro/`, `.venv/`) is never committed.
- Large or private data is never committed. The lab README says where it comes
  from and how to fetch it.

## Stack conventions

Follow the existing framework and package layout when changing a repository.
Colocate code that changes together and name each module for its purpose.
Directory depth and file count are signals to inspect a confusing area, not
reasons to flatten working routes or package boundaries.

Python modules use `snake_case`, for example `release_manifest.py` and
`test_release_manifest.py`. Preserve `__init__.py` and namespace package layouts.
Do not use `release-manifest.py` as an importable module name.

TypeScript source follows the repository's established filename style.
`user.service.ts` is suitable for a service architecture; `packet.ts` is suitable
for a focused packet module. Do not introduce `helpers.ts` as a catch-all.
Tests use the existing test layout and runner.

Framework entrypoints retain required names and exports: Next.js `page.tsx`,
`layout.tsx` and `route.ts`, Astro pages, and package entrypoints. A framework
default export is valid. Named exports are preferred where the local public
interface already uses them.

Use existing ESLint flat config, Ruff or Biome configuration. Do not add a
second linter, hook manager or package manager just to adopt these conventions.
Keep aliases and relative imports consistent with the existing package API.

Keep one documentation owner per topic. Update a contract when its interface
changes, and use the decision-record convention below when an ADR is warranted.
Age or lack of a textual importer does not prove a file is unused: inspect
framework discovery, CLI registrations, templates, fixtures and build inputs.

Apply a structural migration to one named component at a time. Update imports,
exports, references and build inputs in the same change, then run the affected
product checks. Do not rename public interfaces or move private records merely
to satisfy a generic layout example.

## Day one

A repo is ready for its first commit when it has all of these. Every starter
ships the applicable files, except the lockfile, which appears on first install. `AGENTS.md`
comes filled in for the class, so edit it to fit the repo.

| File | What it is |
| --- | --- |
| `README.md` | Front door, from the brand template: banner, what it does, quick start, checks, contributing, license |
| `LICENSE` | Only when the repo is public and the class has a license (see "License"). A private repo has none |
| `.gitignore` | Secrets, local environment files, build output, editor files |
| `.editorconfig` | UTF-8, LF line ends, final newline, no trailing spaces |
| `.gitattributes` | LF line ends everywhere, images marked binary |
| `.markdownlint-cli2.yaml` | The markdown lint rules the shared check uses (the README opens with a picture element) |
| `.lycheeignore` | Skips the banner images until they exist. Delete the line when they do |
| task list | `package.json` scripts or a `justfile` with `lint`, `test`, `build`, `check`, `fix` |
| lockfile | npm and uv starters create `package-lock.json` or `uv.lock` on first install; commit it. Node CI runs `npm ci`. Python CI runs `uv sync --locked` when `installer` is `uv`. Docs/profile starters have no package lockfile |
| `.github/workflows/ci.yml` | A stub that calls the shared workflows. Its pin is a full commit SHA of the kit |
| `.github/dependabot.yml` | Weekly grouped updates for the package manager and for Actions |
| `.github/CODEOWNERS` | The owner of every path |
| one passing test | Even in a docs repo the link check plays this part |
| `AGENTS.md` | Short instructions for AI coding agents, from `templates/agent/AGENTS.template.md`, filled in for the class |
| `CLAUDE.md` | One line that imports `AGENTS.md` |
| `docs/lessons.md` | The lessons log that agents add one line to after each PR |

Tool repos also carry `CHANGELOG.md`. There is no CodeQL file: on public repos
code scanning uses GitHub's default setup.

Decision: every repo has the same five task names. Why: a person or an agent
can type `check` in any repo without reading anything first.

## Tasks

| Task | Does | Fails when |
| --- | --- | --- |
| `lint` | Style and type checks, changes nothing | Anything is off |
| `test` | Runs the tests | A test fails |
| `build` | Produces the output, or does nothing if there is none | The build breaks |
| `check` | `lint`, then `test`, then `build` | Any of those fails |
| `fix` | Applies every automatic fix `lint` would ask for | Never, unless a tool crashes |

- TypeScript and site repos define them in `package.json` (`npm run check`).
  The shared Node workflow runs `lint`, `test`, and `build` by these names.
  `lint` includes the type check, so CI catches type errors.
- Docs, Python, and lab repos define them in a `justfile`. `just` is a small
  task runner. Install it once: `winget install Casey.Just`. The Python shared
  workflow runs the same commands directly (`ruff check`, `ruff format --check`,
  `pytest`), so a green `check` locally means a green CI.
- `check` is the one command to run before every pull request.

## Testing

| Class | What is tested | Where |
| --- | --- | --- |
| docs, profile | Links and markdown style | The `test` and `lint` tasks |
| tool | Every public function and every bug that was fixed | TypeScript: `*.test.ts` next to the code. Python: `tests/` |
| site | Pure logic in `src/lib/`. The build is the page test | `src/lib/*.test.ts` |
| lab | Pure logic only. Results are checked by rerunning | `tests/` |

Rules:

- A change in behavior comes with a test, written first when practical.
- A bug fix comes with a test that fails before the fix and passes after.
- Tests run offline, finish in under a minute, and need no secrets. A test that
  needs the network or takes longer is marked `slow` (Python) and left out of
  `test`.
- Tests are deterministic. Seed anything random. A flaky test is fixed or
  deleted the same day.
- No coverage target. Coverage shows what is untested. It does not say what is
  worth testing.
- Test the behavior, not the wiring. Mock only what crosses the network, the
  clock, or the disk.

Decision: TypeScript tests sit next to the code, Python tests sit in `tests/`.
Why: each matches what the tool defaults to, so no extra config is needed.

## Documentation

- The README is the front door and stays under about 150 lines. A fact has one
  home: link to it, never copy it.
- The README opens with the banner, not a heading, then one paragraph that says
  what the repo does and for whom. Sections: Quick start, Checks, Contributing,
  License. A site adds Environment (variable names only, never values) and
  Deploy. A lab adds Question, Status, and Reproduce.
- When a topic outgrows the README, it gets a page in `docs/`, linked from the
  README. `docs/` has no index file unless it has more than five pages.
- Decisions go in `docs/adr/` (next section). Releases go in `CHANGELOG.md`.
- Comments say why, not what. Code that needs a comment to say what it does
  should be renamed.
- Write in plain words, American spelling, no em dashes, no hosted badge walls.

## Decision records

An ADR (architecture decision record) is a short file that records one choice
and why. The template is `templates/adr/0000-template.md`.

Write one only when at least two of these are true:

- The choice crosses a repo, a service, or a team boundary.
- Reversing it is costly, visible to others, or touches security.
- A future reader will need the reasoning.
- It sets an owner, a contract, or a lasting exception.

A local trade-off belongs in the pull request description. A status update is
not a record.

Rules:

- Files are `docs/adr/NNNN-short-title.md`. Numbers start at 0001, never
  repeat, and never change. `0000` is the template.
- One decision per file, under one page.
- Status is `proposed`, `accepted`, or `superseded by NNNN`.
- Never rewrite an accepted record. Write a new one that supersedes it, and
  change only the status line of the old one.
- Keep rejected options in the record with the reason. They stop the same idea
  from coming back.
- The same pull request that makes the change adds the record.

## Changelog

Only repos with versioned releases keep one: tool repos. Sites, docs, labs, and
the profile deploy from `main` and do not version.

- The file is `CHANGELOG.md` in the [Keep a Changelog](https://keepachangelog.com)
  format.
- The entry is written in the release PR, from the merged PR titles. Ordinary
  PRs do not edit the file.
- The release routine, the entry format, and the version rules are in
  [delivery.md](delivery.md), "Versions and releases".

Decision: no changelog for repos that do not version. Why: the history and the
release notes already say what shipped.

## License

| Class | Public license | Private |
| --- | --- | --- |
| profile | none, all rights reserved | same |
| docs | CC BY 4.0 (MIT for a `-kit`) | none |
| tool | MIT | none |
| site | none, all rights reserved | none |
| lab | MIT for code, CC BY 4.0 for text, CC0-1.0 for data | none |
| archive | Keep the original, and always keep the `LICENSE` file | same |

- A private repo gets no `LICENSE` file. No license file means all rights stay
  with the owner. That is also the intent for the profile and the site.
- Write licenses as their short SPDX ids (`MIT`, `CC-BY-4.0`, `Apache-2.0`).
- A lab that publishes text and data under different licenses says so in its
  README, next to the license line.
- The kit itself (`alawein/.github`) is public and keeps its MIT `LICENSE`.

Decision: MIT is the default for public code. Why: people copy and edit small
tools, and MIT asks the least of them. Use Apache-2.0 instead only when users
would want an explicit patent grant.

Decision: copyleft (GPL-3.0-only or AGPL-3.0-only) only when question 3 below
says so. Why: it limits reuse, so it needs a reason.

### Choose a license

Answer in order. Stop at the first answer that names a license.

1. Will anyone else be allowed to copy or reuse this? If it is private,
   unreleased, or you may sell it or dual-license it: no. **No license file.**
   All rights stay with you. If yes, go to 2.
2. Is it text or data rather than software? If yes, **CC BY 4.0** for text, or
   **CC0-1.0** for pure data. If no, go to 3.
3. Must changes by others stay open? Answer yes if you want that, or if a
   dependency is GPL and forces it. If no, go to 4. If yes, go to 5.
4. Do you want an explicit patent grant? If yes, **Apache-2.0**. If no, **MIT**.
5. Do users reach it only over a network, as a hosted service? If yes,
   **AGPL-3.0-only**. If no, **GPL-3.0-only**.

Write SPDX ids exactly as above. Never write bare `GPL-3.0`, which is
deprecated. Use Creative Commons licenses for text and data, never for
software.

## Keeping starters current

The starters hold copies of the kit's workflow stubs, dependabot files,
CODEOWNERS, README template, and the agent files in `templates/agent/`
(`AGENTS.md`, `CLAUDE.md`, `lessons.md`). When one of those changes, copy it
into the actual starters in the same pull request, then test real generator
outputs, including class aliases. Workflow examples alone do not cover them.
[Pin guidance](../pins.md) owns the current legacy and opt-in pins; a guard or
documentation correction does not release the kit or migrate consumers.
