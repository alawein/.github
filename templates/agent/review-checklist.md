# Review checklist

What a reviewing agent checks before a PR goes to the owner. Run it in a fresh
session with no memory of writing the change, and use a different model from
the author when you can. The reviewer reads and reports. It does not edit the
code unless the owner says so. Follow the [reviewer policy](../../docs/system/reviewers.md)
and save the [evidence record](evidence.template.md). No verdict authorizes a
gated action.

## Before you read the diff

- [ ] Read the repo's `AGENTS.md` and the PR Summary.
- [ ] Run the repo's check command yourself. Do not trust the author's
      Test evidence.
- [ ] Record the base revision and exact reviewed digest, including new files.
      Confirm the diff shows only the intended change.
- [ ] Record this separate reviewer session and its scope; an author cannot
      certify their own independent review.

## Scope

- [ ] The diff matches the Summary and touches one topic.
- [ ] About 300 changed lines or fewer. A larger PR uses the long checklist.
- [ ] No unrelated edits, renames, or formatting churn.
- [ ] No files that should not be there: `.env`, logs, build output, local
      settings.

## Correctness

- [ ] The change does what the Summary says, including the edge cases.
- [ ] A behavior change has a test. The test fails without the change.
- [ ] Error paths and empty input are handled.
- [ ] No leftover debug code, commented-out code, or TODOs with no owner.
- [ ] Nothing was deleted that other code still uses. Search for references.

## Security

- [ ] No secrets, tokens, keys, or personal data in the diff or the history of
      the branch.
- [ ] No new dependency without a stated reason. Check it is maintained and
      pinned the way the repo pins others.
- [ ] Input from outside is checked before use. No shell, SQL, or path built
      from raw input.
- [ ] No check, hook, or permission was loosened to make the PR pass.
- [ ] CI files: permissions stay minimal, and actions stay pinned.
- [ ] Owner gates, signing, no bypass actors, no stacks or queue, the three-PR
      cap and zero PR test retries remain intact.
- [ ] Repository, target, scope and selected mode are recorded. Owner merge
      permission is distinct from GitHub review approval and green checks.

## Evidence

- [ ] Evidence lists task, files, tool versions, commands, exits, durations,
      artifact paths and the content digest, not "tested".
- [ ] Any "not run" is explained.
- [ ] Claims in the PR match what you verified.
- [ ] Findings cite file/line, consequence, evidence and any applicable rule
      ID; duplicates and disagreements have recorded resolutions.
- [ ] Relevant edits after review have new digests, affected checks and scoped
      re-review. Unverified account settings are not presented as active.

## Docs and text

- [ ] Docs and the changelog are updated, or the PR says why not.
- [ ] The PR title is `type(scope): summary`, 72 characters or fewer.
- [ ] Commit and PR text say what changed and how it was checked. No process
      narration, no authorship trailer, no private paths or names.
- [ ] Plain words, American spelling, no em dashes.

## Risk

- [ ] The Risk and rollback section names what could break.
- [ ] Revert is safe: no migration or data change that a revert cannot undo.
- [ ] Remote rollback, data recovery and DNS restoration have separate named
      owner gates and saved baselines where relevant.

## How to report

Return a verdict first: PASS or FIX. Then findings, blockers first.

```text
Verdict: FIX
1. path/file.ext:42 blocker: the empty-list case returns None and the caller
   indexes it. Test needed.
2. path/other.ext:10 nit: name does not match the repo pattern.
Checks I ran: the repo check command, result: 2 failures (list them).
```

- One line per finding, on the file and line. State the fact and its
  consequence, then stop.
- Ask when unsure: "still used?", not "you should remove it".
- Prefix a minor point with `nit:`. Drop the weakest nits.
- No praise padding, no recap of the diff.
