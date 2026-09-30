import pytest

from {{module}}.core import mean


def test_mean_of_values():
    assert mean([1, 2, 3]) == 2


def test_mean_of_empty_input_raises():
    with pytest.raises(ValueError):
        mean([])
