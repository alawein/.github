# Projects

How work is tracked. One place for work that touches code (GitHub), one place
for the log and loose ideas (Notion). How changes ship is in
[delivery.md](delivery.md). The board setup is in
[project-board.md](../../templates/project-board.md).

A line that starts with "Decision:" records a choice that was open. The reason
follows on the same line.

## The short version

- Track repo work in a GitHub issue, unless the specific `No-issue:` exception
  in [delivery](delivery.md#pull-request-rules) applies.
- One board, named Work, shows every open issue across every repo.
- Milestones exist only for a release or a dated push.
- Inbox is emptied at least weekly, on Monday.
- Notion holds the log and ideas. It links to GitHub and never copies it.
- Work is done when it works live, not when it merges.

## Issues

An issue is one piece of work with a goal and a finish line. Write it so an
agent or a person can start cold.

- Use the form: bug, feature, or task. Each asks for a goal and a "done when"
  checklist.
- A good "done when" line can be checked yes or no: "`--dry-run` prints the
  plan and writes nothing".
- One issue, one PR. If an issue needs three PRs, it is three issues under one
  milestone, or one issue with a short checklist of PRs.
- Link the issue with `Closes #12`, or explain the specific `No-issue:` exception
  in ready human PR prose; owner review checks its meaning.
- Agents may open issues. They land in Inbox and wait for triage.
- Write for the reader: what and why in the first two lines.

Labels are the same in every repo: feat, fix, docs, chore, blocked. The form
sets the type label. `blocked` means waiting on something outside the repo, and
the issue says what.

Decision: no priority or size labels. Why: those are board fields, and a label
would be a second place to keep them in sync.

## The board

Decision: one account-level Project named Work, private, for all repos. Why: one
person has one queue. A board per repo would hide the trade-offs between repos.

Status is the column. An item moves right, one step at a time.

| Status | Meaning | Limit |
| --- | --- | --- |
| Inbox | New, not yet looked at | None, but empty on Monday |
| Next | Decided, small enough, ready to start | 5 |
| Doing | A branch exists | 3 |
| Review | A PR is open and waiting for the owner | 3 |
| Done | Merged and verified live | Archived after 14 days |

Fields, besides Status:

| Field | Values | Use |
| --- | --- | --- |
| Repo | Built in | Which repo the item belongs to |
| Priority | Now, Soon, Later | Now means this week. Soon means this month. Later means maybe |
| Size | Small, Medium, Large | Small is under 2 hours. Medium is up to a day. Large must be split before it reaches Next |
| Milestone | Built in | Release or dated push |

Views:

- Board: columns by Status. The default view.
- This week: Status is Next, Doing, or Review.
- By repo: a table grouped by Repo, for the weekly review.
- Blocked: issues with the `blocked` label.

Decision: limits of 5, 3, and 3. Why: with agents, starting is cheap and
reading is slow. The limits stop the pile-up in Review.

Decision: no dates on items. Why: a date on every item goes stale. Milestones
carry the few real dates.

## Milestones

A milestone groups issues for one release or one dated push, such as a site
launch.

- A repo with versioned releases names a milestone after the version:
  `v1.2.0`. It closes when the release ships.
- A dated push uses a plain name: `site launch`. It carries a due date.
- Repos that deploy from `main` with no versions have no milestones.
- A milestone with nothing due in 30 days is closed and its issues go back to
  Later.

## Triage rhythm

- At the start of each work session, spend two minutes on Inbox. Give each
  new item one answer: Next, Later, needs more info, or close.
- On Monday, do the full review below.
- Close, do not hoard. An issue untouched in Later for 90 days is closed with
  "not doing". It can be reopened. An issue list that only grows stops being
  read.

Decision: Monday for the weekly review. Why: it starts the week with one fixed
sitting for open PRs, alerts and failed runs.

## GitHub and Notion

One home per record. The other place holds a link, never a copy.

| Record | Home | Why |
| --- | --- | --- |
| Work on a repo, with a done-when list | GitHub issue | It links to the PR and closes itself |
| A change and the reason for it | GitHub PR | It stays with the code |
| A choice that binds more than one repo, or is costly to reverse | A short file in the repo | It travels with the code |
| Release notes | `CHANGELOG.md` and the release page | Users read them there |
| The weekly log | Notion | Private, time-ordered, cheap |
| Ideas and loose notes, before they are work | Notion | No repo yet, no finish line yet |
| Reading and research notes | Notion | Not tied to one repo |
| Incident and postmortem records | Notion | May hold details that do not belong in a public repo |
| Non-code tasks (accounts, errands, money) | Notion | Not repo work |
| The board | GitHub | Never mirrored to Notion |

Rules:

- When a Notion idea becomes work, create the issue, paste its link into the
  note, and stop editing the note.
- A public repo never links to a Notion page, because readers cannot open it.
- Incident fixes are tracked as GitHub issues. The story stays in the log.
- A private detail (a name, a number, a path) never goes in a public issue or
  PR.

## Weekly review

Monday. Thirty minutes. Do it in this order.

1. Inbox: empty it. Each item gets Next, Later, or close.
2. Review column: anything there more than three days? Read it, merge it, or
   say why it waits.
3. Doing column: anything there more than a week? Split it, finish it, or drop
   it.
4. Dependency updates you started by hand: finish or close with a reason. Method is in
   [delivery.md](delivery.md), "Review a bump".
5. Security: look at the Security tab alerts of each active repo.
6. Failed runs: `gh run list --status failure --limit 20` in active repos. Fix
   or open an issue.
7. Open PRs older than 7 days: finish or close them.
8. Pick the week: set Priority to Now for at most five items, and move them to
   Next.
9. Write one line in the log: what shipped, what slipped, what you learned.

First Monday of each month, also:

- Run the backup and check that the files exist.
- Close milestones with nothing due.

First Monday of each quarter, also:

- Rotation day for secrets and tokens.
- Restore one repo from its backup and run its tests.
- Review authorized apps and GitHub Apps.
- Archive repos you no longer touch.

## Definition of done

A piece of work is done when every line is true.

- [ ] Each line of its "done when" list is true.
- [ ] The PR is merged within its selected mode; its issue is closed by
      `Closes #N`, or the specific `No-issue:` exception is reviewed.
- [ ] The required checks passed, and a behavior change has a test.
- [ ] It is deployed, and you checked the live result: the URL, the command, or
      the screenshot.
- [ ] Docs and the README are right, or the PR says why not.
- [ ] A versioned repo with a change users are waiting for has its release cut.
- [ ] Follow-ups are issues. No "TODO" in the code without an issue number.
- [ ] The board item is in Done (it moves by itself).
- [ ] A surprise, if any, is one line in the log, and a check or rule exists
      if it can happen again.

A release is done when the tag and the release page exist, the package installs
from a clean folder, and the milestone is closed.
