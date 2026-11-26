"""Reference predicates for required workflow gate jobs (fail-closed matrix).

Also classifies kit_self required-context strings from rulesets/checks.json:

- contains ``" / "`` → slash_producer (caller / called job, e.g. ``run-* / lint``)
- member of PLAIN_JOB_IDS (today: ``metadata-tests``) → plain_job
- else → always_gate (policy bare names such as ``pr-title`` / ``pr-policy``)

checks.json remains the only literal list; callers must not hardcode slash arrays.
"""

from __future__ import annotations

from collections.abc import Iterable, Iterator
from dataclasses import dataclass
from enum import Enum


class GateProfile(Enum):
    SUCCESS_ONLY = "success_only"
    PR_TITLE = "pr_title"


LINT_GATE_JOBS = ("markdown-lint", "link-check", "actionlint", "zizmor")
POLICY_GATE_JOBS = ("pr-policy", "pr-title")

SUCCESS_ONLY_RUN = 'test "$RESULT" = "success"'

PR_TITLE_RUN = (
    '[ "$RESULT" = "success" ] || {\n'
    '  [ "$RESULT" = "skipped" ] && [ "$EVENT" = "push" ] && [ "$REF" = "refs/heads/main" ]\n'
    "}"
)


def gate_profile(gate_job: str) -> GateProfile:
    if gate_job == "pr-title":
        return GateProfile.PR_TITLE
    if gate_job in LINT_GATE_JOBS or gate_job == "pr-policy":
        return GateProfile.SUCCESS_ONLY
    raise KeyError(f"unknown gate job: {gate_job}")


def expected_gate_pass(
    profile: GateProfile,
    result: str,
    *,
    event: str = "pull_request",
    ref: str = "refs/pull/1/merge",
) -> bool:
    """Whether the gate shell step should exit 0 for this producer result and event context."""
    if result == "success":
        return True
    if result in ("failure", "cancelled", ""):
        return False
    if result == "skipped":
        if profile is GateProfile.PR_TITLE:
            return event == "push" and ref == "refs/heads/main"
        return False
    return False


def normalize_gate_run(run: str) -> str:
    """Collapse insignificant whitespace so workflow YAML can match canonical predicates."""
    lines = [line.rstrip() for line in run.strip().splitlines()]
    return "\n".join(line for line in lines if line != "")


@dataclass(frozen=True)
class MatrixCell:
    result: str
    event: str
    ref: str
    profile: GateProfile
    should_pass: bool


def gate_result_matrix() -> tuple[MatrixCell, ...]:
    """Cells implied by the kit gate contract (Task 10 matrix)."""
    events = (
        ("pull_request", "refs/pull/1/merge"),
        ("push", "refs/heads/main"),
        ("push", "refs/heads/topic"),
        ("workflow_dispatch", "refs/heads/main"),
    )
    results = ("success", "failure", "cancelled", "skipped", "")
    cells: list[MatrixCell] = []
    for profile in GateProfile:
        for result in results:
            for event, ref in events:
                accepted = expected_gate_pass(profile, result, event=event, ref=ref)
                cells.append(MatrixCell(result, event, ref, profile, accepted))
    return tuple(cells)


class KitSelfKind(Enum):
    SLASH_PRODUCER = "slash_producer"
    PLAIN_JOB = "plain_job"
    ALWAYS_GATE = "always_gate"


PLAIN_JOB_IDS: frozenset[str] = frozenset({"metadata-tests"})


def classify_kit_self(context: str) -> KitSelfKind:
    """Classify one kit_self context string. Deterministic; no I/O."""
    if " / " in context:
        return KitSelfKind.SLASH_PRODUCER
    if context in PLAIN_JOB_IDS:
        return KitSelfKind.PLAIN_JOB
    return KitSelfKind.ALWAYS_GATE


def slash_parts(context: str) -> tuple[str, str]:
    """Split a slash_producer context into (caller_job_id, called_job_id)."""
    if classify_kit_self(context) is not KitSelfKind.SLASH_PRODUCER:
        raise ValueError(f"not a slash_producer context: {context!r}")
    caller, called = context.split(" / ", 1)
    return caller, called


def iter_kit_self(contexts: Iterable[str]) -> Iterator[tuple[str, KitSelfKind]]:
    for context in contexts:
        yield context, classify_kit_self(context)


def slash_contexts(contexts: Iterable[str]) -> list[str]:
    return [c for c, kind in iter_kit_self(contexts) if kind is KitSelfKind.SLASH_PRODUCER]


def plain_jobs(contexts: Iterable[str]) -> list[str]:
    return [c for c, kind in iter_kit_self(contexts) if kind is KitSelfKind.PLAIN_JOB]


def always_gates(contexts: Iterable[str]) -> list[str]:
    return [c for c, kind in iter_kit_self(contexts) if kind is KitSelfKind.ALWAYS_GATE]