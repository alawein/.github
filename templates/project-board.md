# Project board setup

Checklist to build the one board, Work, for every repo. The rules behind it are
in [projects.md](../docs/system/projects.md). Menu names on GitHub shift from
time to time. If one is missing, look for the closest match.

The command-line steps need the project scope once:
`gh auth refresh -s project`.

## Create the project

- [ ] Create a project on your account, not in a repo. Title: `Work`.
      `gh project create --owner alawein --title "Work"` or Projects, New
      project, Table.
- [ ] Set visibility to Private (Settings, Visibility). Items from private
      repos stay visible only to you.
- [ ] Write the description: `One queue for every repo. Rules: docs/system/projects.md in the shared .github repo.`
- [ ] Note the project number from its URL. Backups and scripts use it.

## Status field

The project starts with Status set to Todo, In Progress, Done. Change the
options in the UI (Status field, Edit options), in this order:

- [ ] Inbox
- [ ] Next
- [ ] Doing
- [ ] Review
- [ ] Done
- [ ] Give each option a one-line description that matches the table in
      projects.md.

## Other fields

- [ ] Priority, single select: Now, Soon, Later.
      `gh project field-create <number> --owner alawein --name Priority --data-type SINGLE_SELECT --single-select-options "Now,Soon,Later"`
- [ ] Size, single select: Small, Medium, Large.
      `gh project field-create <number> --owner alawein --name Size --data-type SINGLE_SELECT --single-select-options "Small,Medium,Large"`
- [ ] Keep the built-in Repo, Milestone, Labels, and Linked pull requests
      columns visible. Hide the rest.

## Views

- [ ] Board: layout Board, column by Status. Sort by Priority. Name it `Board`.
- [ ] This week: layout Table, filter `status:Next,Doing,Review`. Name it
      `This week`.
- [ ] By repo: layout Table, group by Repo, sort by Priority. Name it
      `By repo`.
- [ ] Blocked: layout Table, filter `label:blocked`. Name it `Blocked`.

## Workflows

In the project's Workflows page:

- [ ] Item added to project: set Status to Inbox.
- [ ] Item closed: set Status to Done.
- [ ] Pull request merged: set Status to Done.
- [ ] Item reopened: set Status to Next.
- [ ] Auto-archive items: on, for items in Done for 14 days.
- [ ] Auto-add to project: one workflow per active repo, filter `is:issue
      is:open`, so new issues land in Inbox. If the plan limits the number of
      these, add the rest by hand during triage.

## Connect the repos

- [ ] In each active repo, open Projects and link the Work project, or add
      issues from the board with Add item.
- [ ] Open issues of each active repo are on the board with a Status.
- [ ] Every active repo has the five labels from the shared set: feat, fix,
      docs, chore, blocked.

## Check it works

- [ ] Open a test issue in one repo. It appears in Inbox.
- [ ] Move it to Next, open a draft PR with `Closes #<issue>`, and merge a
      trivial change. The issue closes and the item moves to Done.
- [ ] Delete the test issue's branch and close the test item.
- [ ] Run `gh project item-list <number> --owner alawein --format json` and
      confirm it prints items. The monthly backup uses this.
- [ ] Put the first Monday review on your calendar as a repeating event.
