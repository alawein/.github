"""Unit tests for kit_self context classification (CQ shape 1)."""

import sys
import unittest
from pathlib import Path

TESTS = Path(__file__).resolve().parent
if str(TESTS) not in sys.path:
    sys.path.insert(0, str(TESTS))

from workflow_gate_contract import (  # noqa: E402
    KitSelfKind,
    always_gates,
    classify_kit_self,
    iter_kit_self,
    plain_jobs,
    slash_contexts,
    slash_parts,
)


class ClassifyKitSelfTests(unittest.TestCase):
    def test_slash_producer(self):
        ctx = "run-markdown-lint / lint"
        self.assertEqual(classify_kit_self(ctx), KitSelfKind.SLASH_PRODUCER)
        self.assertEqual(slash_parts(ctx), ("run-markdown-lint", "lint"))

    def test_plain_job_metadata_tests(self):
        self.assertEqual(classify_kit_self("metadata-tests"), KitSelfKind.PLAIN_JOB)

    def test_always_gate_policy_names(self):
        for ctx in ("pr-title", "pr-policy"):
            with self.subTest(ctx=ctx):
                self.assertEqual(classify_kit_self(ctx), KitSelfKind.ALWAYS_GATE)

    def test_slash_beats_plain_job_name_collision(self):
        # Defensive: a slash string never becomes PLAIN_JOB even if left of " / " matches.
        self.assertEqual(
            classify_kit_self("metadata-tests / lint"),
            KitSelfKind.SLASH_PRODUCER,
        )

    def test_slash_parts_rejects_non_slash(self):
        with self.assertRaises(ValueError):
            slash_parts("metadata-tests")

    def test_iterators_preserve_order(self):
        contexts = [
            "run-zizmor / lint",
            "metadata-tests",
            "pr-title",
            "run-actionlint / lint",
            "pr-policy",
        ]
        self.assertEqual(
            list(iter_kit_self(contexts)),
            [
                ("run-zizmor / lint", KitSelfKind.SLASH_PRODUCER),
                ("metadata-tests", KitSelfKind.PLAIN_JOB),
                ("pr-title", KitSelfKind.ALWAYS_GATE),
                ("run-actionlint / lint", KitSelfKind.SLASH_PRODUCER),
                ("pr-policy", KitSelfKind.ALWAYS_GATE),
            ],
        )
        self.assertEqual(
            slash_contexts(contexts),
            ["run-zizmor / lint", "run-actionlint / lint"],
        )
        self.assertEqual(plain_jobs(contexts), ["metadata-tests"])
        self.assertEqual(always_gates(contexts), ["pr-title", "pr-policy"])


if __name__ == "__main__":
    unittest.main()
