"""Reference predicates for required workflow gate jobs (fail-closed matrix)."""

from __future__ import annotations

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