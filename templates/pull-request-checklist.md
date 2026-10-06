# Long pull request checklist

Use this for a big or risky change. Copy the parts that apply into the pull
request body, under the short checklist in the template, and delete the rest.
The rules behind it are in [delivery.md](../docs/system/delivery.md).

A change is big or risky when any of these is true:

- It is over 300 changed lines. Lockfiles and generated files do not count.
- It touches login, permissions, or anything that handles personal data.
- It changes a database schema or migrates data.
- It changes deploy settings, environment variables, or a domain.
- It changes a workflow or a ruleset.
- It adds or upgrades a dependency by a major version.
- It changes a public interface that others call.

If it is over 300 lines only because it is one mechanical change (a rename, a
formatter run), say so in the Summary. Otherwise, consider splitting it.

## Scope

- [ ] One topic. Every file in the diff belongs to it.
- [ ] No unrelated cleanup mixed in.
- [ ] The issue's "done when" list is covered. Link: #

## Correctness

- [ ] A test covers the new behavior. For a bug fix, it fails without the fix.
- [ ] Edge cases are covered: empty input, a missing value, a very large value.
- [ ] No test was deleted, skipped, or loosened. If one changed, say why.
- [ ] I ran it myself. Command and result are in Test evidence.

## Security

- [ ] No secret, token, key, or personal path in the diff or the PR text.
- [ ] Input from outside is checked before use.
- [ ] Permissions are the fewest that work. Workflow `permissions:` are per job.
- [ ] No untrusted text (issue, PR, or branch names) goes into a `run:` script.

## Data

- [ ] A backup was taken before the migration. Where:
- [ ] The migration runs on a copy first, and the result was checked.
- [ ] The change can be undone, or the PR says it cannot and why.
- [ ] A preview does not point at the production database.

## Dependencies

- [ ] New dependency: why the standard library or an existing package will not
      do.
- [ ] Maintainer, last release date, and license checked.
- [ ] The lockfile diff shows only the packages I expect.
- [ ] Major upgrade: release notes read, breaking changes handled.

## Deploy

- [ ] New environment variables are set in Vercel for Preview and Production,
      with different values, marked Sensitive where secret.
- [ ] The variable names are in the README. No values.
- [ ] The preview works. URL:
- [ ] Nothing here needs a manual step after the merge. If it does, the steps
      are in the PR.

## Rollback

- [ ] How to undo it: revert this PR, roll back the deploy, or restore a
      backup. Write which.
- [ ] Time to undo, in minutes:

## Docs

- [ ] README, docs, and examples match the new behavior.
- [ ] A breaking change is marked with `!` in the title and explains the
      migration.

## Agent work

Fill in when an agent wrote most of the diff.

- [ ] I read the whole diff, not the summary.
- [ ] A second agent session with no memory of the work reviewed the diff.
- [ ] No files I did not expect. No new install scripts or network calls.
- [ ] The PR body matches what the diff does.
