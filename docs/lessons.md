# Lessons

One line per session, newest at the bottom. Format:
`YYYY-MM-DD | area | observation | rule`.

## Log

- 2026-09-30 | day-one docs | The kit had no local check entry point and the approved banner assets were unavailable | Pin the local runner, check links offline, and wait for owner assets before embedding a banner.
- 2026-09-30 | CI | Optional Node callers could pass without a test script, while external link outages could block a merge | Require tests only for ready callers; check local links offline on PRs and scan external links nightly.
- 2026-09-30 | hub policy | A missing workflow or wrong repo class could otherwise produce a misleading green policy result | Fail closed before GitHub calls and prove dry-run behavior with a fake `gh` that rejects mutations.
- 2026-09-30 | retirement references | Historical text needs narrow exceptions and CLI errors need distinct outcomes | Match exceptions to one exact line in one repo and file; reject unsafe paths and fail the CLI on live references or missing roots.
- 2026-09-30 | reviewer governance | Shared prose allowed actions that local gates prohibit and overstated signing | Keep one named-action policy, content-bound review evidence and separate live verification of reviewer settings and signatures.
