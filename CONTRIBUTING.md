# Contributing

Issues are welcome. Discuss a change in an issue unless the documented
`No-issue:` exception applies.
This is a solo project, so replies are best effort.

## The short version

1. Discuss an issue (bug, feature, or task), or explain a specific `No-issue:` exception.
2. Branch from `main`: `type/short-topic`, for example `fix/label-join`.
3. Make one change. Run the checks.
4. Open a draft pull request titled `type(scope): summary`. Mark it ready when
   the checks pass.
5. Complete review and squash merge within the owner-selected task mode.
   Agents name the repo, target and scope before publishing; mode (b) waits
   for explicit owner merge approval.

Full rules for branches, commits, pull requests, versions, and review are in
[delivery](https://github.com/alawein/.github/blob/main/docs/system/delivery.md).
How a repo is shaped and named is in
[repos](https://github.com/alawein/.github/blob/main/docs/system/repos.md).

## Run the checks

The repository README lists its own test and lint commands. Run them before
you push. CI runs the same ones.

Every repository also runs these shared checks on each pull request:

| Check | What it covers | Local command |
| --- | --- | --- |
| markdown-lint | Markdown style | `npx markdownlint-cli2 "**/*.md"` |
| link-check | Links in Markdown files | `lychee './**/*.md'` |
| actionlint | Workflow files | `actionlint` |
| pr-title | PR title format | See "Pull requests" below |

A repository with code also runs its tests as `node-ci` or `python-ci`.

## Commits

- Commits on your branch are scratch. Keep them short and imperative, for
  example `add parser test`.
- The pull request title becomes the squash commit title, and the squash commit
  has no message. The pull request holds the why.
- Sign your commits when the repository requires it (its README says so).

## Pull requests

- Title format: `type(scope): summary`. Types: feat, fix, docs, chore,
  refactor, test. 72 characters at most, imperative, no final period. Example:
  `fix(parser): handle empty input`.
- Use the template. Fill in every section, or write n/a and say why. Link the
  issue with `Closes #12` under Why, or use `No-issue: <specific reason>` in
  ready human PR prose. The metadata check validates syntax; owner review
  checks that the reason is meaningful. See [delivery](docs/system/delivery.md#pull-requests).
- One topic per pull request, about 300 changed lines at most. A bigger or
  riskier change uses the long checklist from the template.
- Open it as a draft at the first push. Do not stack pull requests on each
  other.
- If `main` moved, update your branch with the button or a rebase.
- Add a test for a bug fix, and update docs when users would notice the change.
  The maintainer writes the changelog in the release.
- Automated review comments are advice. The maintainer decides.

## Your contribution

By sending a pull request you agree that your work is released under the
repository's license.

## Conduct and security

Be kind: see the
[code of conduct](https://github.com/alawein/.github/blob/main/CODE_OF_CONDUCT.md).
Report security problems privately: see the
[security policy](https://github.com/alawein/.github/blob/main/SECURITY.md).
