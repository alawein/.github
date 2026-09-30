"""Pure logic for the experiment. Keep side effects (files, network) out of here."""

from collections.abc import Sequence


def mean(values: Sequence[float]) -> float:
    """Return the arithmetic mean. Raise ValueError on empty input."""
    if not values:
        raise ValueError("values is empty")
    return sum(values) / len(values)
