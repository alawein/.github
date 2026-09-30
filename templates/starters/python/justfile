# Tasks. Install just once: winget install Casey.Just
set windows-shell := ["powershell.exe", "-NoLogo", "-NoProfile", "-Command"]

default:
    @just --list

# Style checks. Changes nothing.
lint:
    uv run ruff check .
    uv run ruff format --check .

# Tests. Anything marked slow is left out: uv run pytest -m slow
test:
    uv run pytest

# Build the wheel and the source archive into dist/.
build:
    uv build

# Everything the pull request checks run, plus the build.
check: lint test build

# Apply the automatic fixes.
fix:
    uv run ruff check --fix .
    uv run ruff format .
