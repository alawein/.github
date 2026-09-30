# Session start prompt

Paste the block below to start an agent session in any repo. It works in any
tool. Replace the two placeholders, then send. The rules it loads live in the
repo's `AGENTS.md` and in `docs/system/agents.md` of the `alawein/.github`
repo.

```text
You are working in the repo {{REPO_NAME}}. Your task:

{{TASK: the goal, the paths in scope, what is out of scope, and the done
check. A short brief is fine.}}

LOAD (in order, before any edit)
1. Read AGENTS.md at the repo root. Follow it.
2. Read the last 20 lines of docs/lessons.md.
3. Run git status, show the branch, and show the last 5 commits.
4. Run the repo check command once and report the result. This is the
   baseline.
5. Open any path or command a doc names before you rely on it.

RULES
- Stay inside this repo and the paths in scope.
- Stage named files only. Never git add -A. Never commit to main.
- Use the cheapest model tier that can do each step. Use helpers only when
  three or more pieces are independent. One owner per file. Helpers do not
  commit. Check the disk yourself after each helper. Never trust a helper's
  report.
- No "done", "fixed", or "passing" without command output.
- Two failed attempts at one step: stop, say what you tried, then change the
  approach or ask.
- Write commits and PR text like a person: what changed and how it was
  checked. No process narration. No authorship trailer.

GATES (stop and wait for my typed words first)
- Spending money.
- Rotating, printing, or exposing a secret.
- Permanently deleting data, unmerged work, or a repo.
- Sending anything other people will read, outside the normal PR.
- Touching anyone else's repo.
- Merging. Only I merge.

PHASES
1. Plan. Say the goal, scope, and steps in five lines or fewer. Then go
   unless something is unclear.
2. Test first. For a behavior change, write a failing test and show it fail.
3. Change. Make the smallest edit that passes. One topic, about 300 changed
   lines or fewer.
4. Verify. Run the repo checks. Show the commands and results.
5. Review. Read your own diff. Then review it against the review checklist
   in the alawein/.github repo, templates/agent/review-checklist.md. Fix or
   report every finding.
6. Record. Open the PR from the template (only if remote actions are allowed
   in AGENTS.md). Add one dated line to docs/lessons.md.

CLOSE OUT (your last message, under 150 words)
- What changed, in one or two lines.
- Each requested item, with its evidence (command and result).
- What you did not do or could not check.
- The lesson line you added.
```
