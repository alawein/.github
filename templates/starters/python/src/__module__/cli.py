"""Command line entry point."""

import sys
from collections.abc import Sequence


def main(argv: Sequence[str] | None = None) -> int:
    """Print a greeting. Replace this with the real tool."""
    args = list(sys.argv[1:] if argv is None else argv)
    name = args[0] if args else "world"
    print(f"hello, {name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
