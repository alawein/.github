# Postmortem: short name

A postmortem is a short write-up after an incident, so the same thing does not
happen twice. Write it within a week, while you still remember. It blames no
one. A step that failed is a missing check, not a bad person.

Copy this into your log. Link the incident note and each fix issue.

## Summary

Two or three sentences: what broke, for how long, and how it ended.

## Impact

- Who or what was affected:
- How long:
- Data lost or exposed: none, or what
- Money or access at risk: none, or what

## Timeline

Times with time zone. One line per event.

- HH:MM the change or event that started it
- HH:MM first sign of trouble
- HH:MM noticed, and how
- HH:MM harm stopped, and how
- HH:MM resolved and verified live

## Root cause

Ask "why" until you reach something you can change. Write the chain, one line
per step.

1. It broke because ...
2. That happened because ...
3. That was possible because ...

The last line is the root cause. It should be a missing check or a missing
rule, not a person.

## What went well

What limited the damage.

## What went wrong

What made it worse or slower.

## Where we got lucky

What could have made it much worse, and did not.

## Detection

- Did a check, alert, or test catch it? yes or no
- If no, which check would have?
- How long from start to noticed?

## Fixes

Each fix is a GitHub issue on the Work board. Every row says which kind it is.

| Fix | Kind | Issue |
| --- | --- | --- |
| What changes | Prevent, Detect, or Recover | Link |

Prevent means it cannot happen again. Detect means it is caught sooner. Recover
means it is undone faster.

## Lesson

One sentence for the log. If a rule in the shared `delivery.md` changes
because of this, open that PR now and link it here.
