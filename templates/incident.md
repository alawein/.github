# Incident: short name

Copy this into your log when something live is broken, exposed, or losing data.
Stop the harm first, then fill it in as you go. The steps are in
[delivery.md](../docs/system/delivery.md), "Incidents and rollback".

## Status

- Severity: High, Medium, or Low
- State: Investigating, Mitigated, or Resolved
- Noticed: date and time, with time zone
- Resolved: date and time
- Affected: the repo, site, or service, and who or what it touches

## What is wrong

What a user or a system sees, in one or two sentences.

## Stop the harm

- [ ] Rolled back, turned off, or revoked. Write what you did and when.
- [ ] Live result checked after the step.
- [ ] Anyone affected told, with the time of the next update.

## Timeline

One line per event, newest last.

- HH:MM what happened or what you did

## Current theory

What you think caused it. Mark it as a guess until it is proven.

## Fix

- Fix issue or PR: link
- Verified live: yes or no, and how

## Secret involved

- [ ] No secret was exposed.
- [ ] A secret was exposed. It was revoked at the source before anything else,
      and the provider's usage log was checked.

## Next

- [ ] Postmortem needed: yes for High, and for Medium that repeated. Use
      [postmortem.md](postmortem.md).
