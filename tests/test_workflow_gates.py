"""Exercise the commands embedded in the reusable workflow files."""

import json
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

TESTS = Path(__file__).resolve().parent
if str(TESTS) not in sys.path:
    sys.path.insert(0, str(TESTS))

from workflow_gate_contract import (  # noqa: E402
    GateProfile,
    LINT_GATE_JOBS,
    POLICY_GATE_JOBS,
    PR_TITLE_RUN,
    SUCCESS_ONLY_RUN,
    expected_gate_pass,
    gate_profile,
    gate_result_matrix,
    normalize_gate_run,
)


ROOT = Path(__file__).resolve().parents[1]
NODE_DIR = os.environ.get("NODE22_DIR")
KIT_SHA = "cc3b595f8e9e92a9ed6fc63b3be177cc8a571965"
BASH = Path(r"C:\Program Files\Git\bin\bash.exe") if platform.system() == "Windows" else Path("/bin/bash")


def workflow(name):
    return yaml.safe_load((ROOT / ".github" / "workflows" / name).read_text(encoding="utf-8"))


def step(name):
    return next((s for s in workflow("node-ci.yml")["jobs"]["ci"]["steps"] if s.get("name") == name), None)


class NodeGateTests(unittest.TestCase):
    def run_step(self, manifest, run_test="true", name="Require a runnable test script"):
        self.assertIsNotNone(step(name), f"missing {name} step")
        with tempfile.TemporaryDirectory() as directory:
            Path(directory, "package.json").write_text(manifest, encoding="utf-8")
            env = {**os.environ, "RUN_TEST": run_test}
            if NODE_DIR:
                env["PATH"] = NODE_DIR + os.pathsep + env["PATH"]
            return subprocess.run([str(BASH), "-c", step(name)["run"]], cwd=directory, env=env, capture_output=True, text=True)

    def test_required_test_explains_missing_and_blank_scripts(self):
        for manifest in ['{"scripts":{}}', '{"scripts":{"test":""}}', '{"scripts":{"test":"  "}}']:
            with self.subTest(manifest=manifest):
                result = self.run_step(manifest)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("::error::", result.stderr)
                for detail in ["package.json", "nonempty", "test"]:
                    self.assertIn(detail, result.stderr.lower())

    def test_required_test_explains_conflicting_execution_inputs(self):
        result = self.run_step('{"scripts":{"test":"node -e \'process.exit(0)\'"}}', "false")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("::error::", result.stderr)
        self.assertIn("require-test: true", result.stderr)
        self.assertIn("run-test: true", result.stderr)

    def test_required_test_accepts_runnable_script(self):
        result = self.run_step('{"scripts":{"test":"node -e \'process.exit(0)\'"}}')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_actual_test_step_propagates_failure_and_skips_only_when_optional(self):
        self.assertEqual(step("Test")["run"], "npm test --if-present")
        # The required branch must invoke npm test without --if-present.
        self.assertIsNotNone(step("Test (required)"))
        self.assertEqual(step("Test (required)")["run"], "npm test")
        manifest = json.dumps({"scripts": {"test": 'node -e "console.log(\'KIT_F3_TEST_EXECUTED\'); process.exit(7)"'}})
        result = self.run_step(manifest, name="Test (required)")
        self.assertIn("KIT_F3_TEST_EXECUTED", result.stdout)
        self.assertEqual(result.returncode, 7, f"stdout={result.stdout!r} stderr={result.stderr!r}")


class NodeLintGateTests(unittest.TestCase):
    def run_lint(self, scripts, run_lint="true", name="Require a runnable lint script"):
        guard = step(name)
        self.assertIsNotNone(guard, f"missing {name}")
        with tempfile.TemporaryDirectory() as directory:
            Path(directory, "package.json").write_text(json.dumps({"scripts": scripts}))
            return subprocess.run([str(BASH), "-c", guard["run"]], cwd=directory,
                                  env={**os.environ, "RUN_LINT": run_lint},
                                  capture_output=True, text=True)

    def test_required_lint_rejects_missing_and_empty_scripts(self):
        for scripts in ({}, {"lint": ""}, {"lint": "  "}):
            with self.subTest(scripts=scripts):
                result = self.run_lint(scripts)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("::error::", result.stderr)

    def test_required_lint_rejects_disabled_execution(self):
        self.assertNotEqual(self.run_lint({"lint": "node -e 'process.exit(0)'"}, "false").returncode, 0)

    def test_required_lint_runs_and_propagates_failure(self):
        self.assertEqual(self.run_lint({"lint": "node -e 'process.exit(0)'"}).returncode, 0)
        result = self.run_lint({"lint": 'node -e "process.exit(7)"'}, name="Lint (required)")
        self.assertEqual(result.returncode, 7, result.stdout + result.stderr)


class LinkGateTests(unittest.TestCase):
    def test_reusable_links_preserve_external_checks_by_default(self):
        links = workflow("check-links.yml")
        self.assertIs(links[True]["workflow_call"]["inputs"]["offline"]["default"], False)

    def test_nightly_links_check_external_sites(self):
        self.assertTrue((ROOT / ".github" / "workflows" / "check-links-nightly.yml").exists())
        nightly = workflow("check-links-nightly.yml")
        self.assertIn("schedule", nightly[True])
        self.assertIn("workflow_dispatch", nightly[True])
        call = nightly["jobs"]["run-link-check"]
        self.assertFalse(call["with"]["offline"])


class CiGateListTests(unittest.TestCase):
    def test_kit_self_contexts_use_one_always_gate_or_metadata_job(self):
        checks = json.loads((ROOT / "rulesets/checks.json").read_text(encoding="utf-8"))
        ci = workflow("ci.yml")["jobs"]
        policy = workflow("policy.yml")["jobs"]
        for ctx in checks["kit_self"]:
            if ctx == "metadata-tests":
                self.assertIn(ctx, ci)
                self.assertNotEqual(ci[ctx].get("if"), "${{ always() }}")
                continue
            jobs = ci if ctx in ci else policy
            self.assertIn(ctx, jobs, ctx)
            gate = jobs[ctx]
            self.assertEqual(gate.get("if"), "${{ always() }}", ctx)
            self.assertEqual(gate.get("permissions"), {}, ctx)
            self.assertEqual(gate["needs"], [f"run-{ctx}"], ctx)

    def test_header_names_every_always_report_gate(self):
        # Live ruleset 24266592 required six contexts on 2026-11-11 while this comment listed four.
        gates = sorted(name for name, job in workflow("ci.yml")["jobs"].items()
                       if job.get("if") == "${{ always() }}" and job.get("permissions") == {})
        self.assertEqual(gates, ["actionlint", "link-check", "markdown-lint", "zizmor"])
        text = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
        listed = text.split("The ruleset requires:\n#", 1)[1].splitlines()[0]
        # metadata-tests is a plain job, so it reports its own check under that name.
        self.assertEqual(sorted(name.strip() for name in listed.split(",")), sorted(gates + ["metadata-tests"]))
        self.assertNotIn("needs", workflow("ci.yml")["jobs"]["metadata-tests"])

    def test_only_policy_workflow_reruns_on_edited(self):
        # Run 43116245493 (body edit, same SHA) cancelled push run 43116219207, whose gates then failed.
        # Task 2 sample (2026-11-18): PR cancel rate 0/30 — keep the kit split locked anyway.
        ci, policy = workflow("ci.yml"), workflow("policy.yml")
        self.assertNotIn("edited", ci[True]["pull_request"]["types"])
        self.assertIn("ready_for_review", ci[True]["pull_request"]["types"])
        self.assertIn("edited", policy[True]["pull_request"]["types"])
        self.assertEqual(
            ci["concurrency"]["group"],
            "${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}",
        )
        self.assertEqual(
            ci["concurrency"]["cancel-in-progress"],
            "${{ github.event_name == 'pull_request' }}",
        )
        self.assertEqual(policy["concurrency"]["group"], "policy-${{ github.run_id }}")
        self.assertIs(policy["concurrency"]["cancel-in-progress"], False)
        self.assertNotEqual(ci["concurrency"]["group"], policy["concurrency"]["group"])
        gates = sorted(name for name, job in policy["jobs"].items()
                       if job.get("if") == "${{ always() }}" and job.get("permissions") == {})
        self.assertEqual(gates, ["pr-policy", "pr-title"])
        self.assertEqual(policy["jobs"]["pr-policy"]["needs"], ["run-pr-policy"])
        self.assertIs(policy["jobs"]["run-pr-policy"]["with"]["require-sections"], True)
        self.assertEqual(policy["jobs"]["run-pr-title"]["permissions"], {"pull-requests": "read"})
        self.assertEqual(policy["permissions"], {"contents": "read"})
        for job in ("run-pr-title", "run-pr-policy", "pr-title", "pr-policy"):
            self.assertNotIn(job, ci["jobs"])

    def test_metadata_producers_do_not_cancel_other_events(self):
        for name in ("pr-title.yml", "pr-policy.yml"):
            with self.subTest(name=name):
                concurrency = workflow(name)["concurrency"]
                self.assertIn("github.run_id", concurrency["group"])
                self.assertIs(concurrency["cancel-in-progress"], False)

    def test_no_workflow_runs_on_ubuntu_latest(self):
        # ubuntu-latest moved callers to a new image without review; pin the image instead.
        paths = sorted((ROOT / ".github" / "workflows").glob("*.yml")) + sorted((ROOT / "templates").rglob("*.yml"))
        offenders = []
        for path in paths:
            doc = yaml.safe_load(path.read_text(encoding="utf-8"))
            # A jobs fragment such as pr-policy.jobs.yml holds jobs at the top level.
            jobs = doc.get("jobs", doc) if isinstance(doc, dict) else {}
            offenders += [f"{path.relative_to(ROOT)}:{name}" for name, job in jobs.items()
                          if isinstance(job, dict) and "ubuntu-latest" in str(job.get("runs-on", ""))]
        self.assertEqual(offenders, [])

    def test_templates_pin_one_release_of_this_repo(self):
        # Previously distributed releases drifted apart; all templates must move together.
        pins = set()
        comments = set()
        for path in sorted((ROOT / "templates").rglob("*.yml")):
            source = path.read_text(encoding="utf-8")
            calls = re.findall(r"alawein/\.github/\.github/workflows/[\w.-]+@([^\s#]+)(?:[ \t]+#[ \t]*([^\r\n]*))?", source)
            pins.update(ref for ref, _ in calls)
            comments.update(comment.strip() for _, comment in calls)
            pins.update(re.findall(r"(?m)^[ \t]*kit-ref:[ \t]*([^\s#]+)", source))
        self.assertEqual(pins, {KIT_SHA})
        self.assertEqual(comments, {"quality gates"})

    def test_metadata_job_runs_scripts_suite_with_hashed_dependencies(self):
        # The root suite's own step is guarded from scripts/tests (test_ci_still_runs_the_root_suite).
        runs = [step.get("run", "") for step in workflow("ci.yml")["jobs"]["metadata-tests"]["steps"]]
        self.assertTrue(any("discover -s scripts/tests" in run for run in runs))
        self.assertTrue(any("--require-hashes" in run and "tests/requirements.txt" in run for run in runs))
        self.assertTrue(any('LYCHEE_BIN=$bin/lychee" >> "$GITHUB_ENV"' in run for run in runs))


def run_gate_shell(run, env):
    return subprocess.run(
        [str(BASH), "-c", run],
        env={**os.environ, **env},
        capture_output=True,
        text=True,
    ).returncode


def gate_require_run(workflow_name, gate_job):
    jobs = workflow(workflow_name)["jobs"]
    step = jobs[gate_job]["steps"][0]
    return step["run"], step.get("env", {})


class GateSkipFailMatrixTests(unittest.TestCase):
    def test_helper_encodes_documented_matrix_corners(self):
        # success | any | pass
        for profile in GateProfile:
            self.assertTrue(expected_gate_pass(profile, "success", event="pull_request", ref="x"))
        # failure | cancelled | any | fail
        for profile in GateProfile:
            for result in ("failure", "cancelled", ""):
                self.assertFalse(
                    expected_gate_pass(profile, result, event="push", ref="refs/heads/main"),
                    (profile, result),
                )
        # skipped | pull_request | fail (including pr-title)
        self.assertFalse(
            expected_gate_pass(GateProfile.PR_TITLE, "skipped", event="pull_request", ref="refs/pull/1/merge"),
        )
        # skipped | push + main | pass only pr-title
        self.assertTrue(
            expected_gate_pass(GateProfile.PR_TITLE, "skipped", event="push", ref="refs/heads/main"),
        )
        self.assertFalse(
            expected_gate_pass(GateProfile.SUCCESS_ONLY, "skipped", event="push", ref="refs/heads/main"),
        )
        # skipped | push + main | fail lint / pr-policy (via SUCCESS_ONLY)
        for gate in LINT_GATE_JOBS + ("pr-policy",):
            self.assertEqual(gate_profile(gate), GateProfile.SUCCESS_ONLY, gate)

    def test_matrix_cells_agree_with_predicate(self):
        for cell in gate_result_matrix():
            self.assertEqual(
                expected_gate_pass(cell.profile, cell.result, event=cell.event, ref=cell.ref),
                cell.should_pass,
                cell,
            )

    def test_ci_lint_gates_use_success_only_shell_matching_helper(self):
        for gate_job in LINT_GATE_JOBS:
            with self.subTest(gate=gate_job):
                run, env = gate_require_run("ci.yml", gate_job)
                self.assertEqual(normalize_gate_run(run), SUCCESS_ONLY_RUN)
                self.assertEqual(env.get("RESULT"), "${{ needs.run-" + gate_job + ".result }}")
                for cell in gate_result_matrix():
                    if cell.profile is not GateProfile.SUCCESS_ONLY:
                        continue
                    code = run_gate_shell(run, {"RESULT": cell.result, "EVENT": cell.event, "REF": cell.ref})
                    self.assertEqual(code, 0 if cell.should_pass else 1, cell)

    def test_policy_gates_match_contract_and_matrix(self):
        for gate_job in POLICY_GATE_JOBS:
            with self.subTest(gate=gate_job):
                run, env = gate_require_run("policy.yml", gate_job)
                profile = gate_profile(gate_job)
                canonical = PR_TITLE_RUN if profile is GateProfile.PR_TITLE else SUCCESS_ONLY_RUN
                self.assertEqual(normalize_gate_run(run), canonical, gate_job)
                need_key = "run-pr-title" if gate_job == "pr-title" else "run-pr-policy"
                self.assertEqual(env.get("RESULT"), "${{ needs." + need_key + ".result }}")
                if gate_job == "pr-title":
                    self.assertEqual(env.get("EVENT"), "${{ github.event_name }}")
                    self.assertEqual(env.get("REF"), "${{ github.ref }}")
                for cell in gate_result_matrix():
                    if cell.profile is not profile:
                        continue
                    shell_env = {"RESULT": cell.result, "EVENT": cell.event, "REF": cell.ref}
                    code = run_gate_shell(run, shell_env)
                    self.assertEqual(code, 0 if cell.should_pass else 1, (gate_job, cell))


class ZizmorGateTests(unittest.TestCase):
    def test_gate_requires_successful_audit(self):
        jobs = workflow("ci.yml")["jobs"]
        self.assertEqual(jobs["run-zizmor"]["uses"], "$/.github/workflows/lint-zizmor.yml")
        gate = jobs["zizmor"]
        self.assertEqual(gate["needs"], ["run-zizmor"])
        self.assertEqual(gate["if"], "${{ always() }}")
        self.assertEqual(gate["permissions"], {})
        require_success = gate["steps"][0]
        self.assertEqual(require_success["env"]["RESULT"], "${{ needs.run-zizmor.result }}")
        for result in ("success", "failure", "cancelled", "skipped", ""):
            with self.subTest(result=result):
                code = subprocess.run([str(BASH), "-c", require_success["run"]],
                                      env={**os.environ, "RESULT": result}).returncode
                self.assertEqual(code, 0 if result == "success" else 1)

    def test_audit_installs_a_checksum_verified_release(self):
        steps = workflow("lint-zizmor.yml")["jobs"]["lint"]["steps"]
        install = next(s for s in steps if s.get("name") == "Install zizmor v1.32.0")
        self.assertRegex(install["env"]["ZIZMOR_SHA256"], r"^[0-9a-f]{64}$")
        self.assertIn("sha256sum --check -", install["run"])
        self.assertNotIn("pipx", "".join(s.get("run", "") for s in steps))

    def test_reusable_audit_refuses_archive_repositories(self):
        audit = workflow("lint-zizmor.yml")
        self.assertIn("workflow_call", audit[True])
        self.assertEqual(audit["permissions"], {"contents": "read"})
        self.assertNotIn("archive-guard", audit["jobs"])
        self.assertNotIn("needs", audit["jobs"]["lint"])
        guard = audit["jobs"]["lint"]["steps"][0]
        self.assertEqual(guard["name"], "Refuse to run in an archive repo")
        for repository, expected in (("alawein/.github", 0), ("alawein/ARCHIVE-kit", 1)):
            with self.subTest(repository=repository):
                result = subprocess.run([str(BASH), "-c", guard["run"]],
                                        env={**os.environ, "REPO": repository}, capture_output=True, text=True)
                self.assertEqual(result.returncode, expected, result.stdout + result.stderr)


class DistributedGateTests(unittest.TestCase):
    def assert_paired_workflows(self, directory, code=False):
        ci = yaml.safe_load((directory / "ci.yml").read_text(encoding="utf-8"))
        links = ci["jobs"]["run-link-check"]
        self.assertIs(links["with"]["offline"], True)
        nightly = yaml.safe_load((directory / "check-links-nightly.yml").read_text(encoding="utf-8"))
        self.assertIn("schedule", nightly[True])
        self.assertIn("workflow_dispatch", nightly[True])
        external = nightly["jobs"]["run-link-check"]
        self.assertIs(external["with"]["offline"], False)
        self.assertEqual(links["uses"], external["uses"])
        if code:
            self.assertIs(ci["jobs"]["run-node-ci"]["with"]["require-test"], True)
            self.assertIs(ci["jobs"]["run-node-ci"]["with"]["run-test"], True)

    def test_distributed_stubs_pair_offline_and_external_checks(self):
        for stub in ["docs", "node", "python", "site"]:
            with self.subTest(stub=stub):
                with tempfile.TemporaryDirectory() as temporary:
                    directory = Path(temporary)
                    (directory / "ci.yml").write_bytes((ROOT / "templates/workflows" / f"{stub}.yml").read_bytes())
                    (directory / "check-links-nightly.yml").write_bytes((ROOT / "templates/workflows/check-links-nightly.yml").read_bytes())
                    self.assert_paired_workflows(directory, code=stub in ["node", "site"])

    def test_actual_generated_starters_receive_complete_check_pairs(self):
        variants = [("contract-docs", "docs", "typescript"), ("alawein", "profile", "typescript"),
                    ("contract-node", "tool", "typescript"), ("contract-python", "tool", "python"),
                    ("contract-site", "site", "typescript"), ("contract-lab", "lab", "typescript")]
        for name, repo_class, language in variants:
            with self.subTest(repo_class=repo_class, language=language):
                with tempfile.TemporaryDirectory() as temporary:
                    generated = subprocess.run(["pwsh", "-NoProfile", "-File", str(ROOT / "scripts/new-repo.ps1"),
                                                "-Name", name, "-Class", repo_class, "-Language", language,
                                                "-Path", temporary, "-Create"], capture_output=True, text=True)
                    self.assertEqual(generated.returncode, 0, generated.stderr)
                    self.assert_paired_workflows(Path(temporary) / name / ".github/workflows",
                                                 code=repo_class == "site" or (repo_class == "tool" and language == "typescript"))
                    directory = Path(temporary) / name / ".github/workflows"
                    ci = yaml.safe_load((directory / "ci.yml").read_text(encoding="utf-8"))
                    gates = {"markdown-lint", "link-check", "actionlint", "pr-title"}
                    if repo_class == "site" or (repo_class == "tool" and language == "typescript"):
                        gates.add("node-ci")
                    if repo_class == "lab" or (repo_class == "tool" and language == "python"):
                        gates.add("python-ci")
                    self.assertEqual(set(ci["jobs"]), gates | {"run-" + gate for gate in gates})
                    for job in ci["jobs"].values():
                        if "uses" in job:
                            self.assertTrue(job["uses"].endswith("@" + KIT_SHA))
                    self.assertEqual({path.name for path in directory.iterdir()}, {"ci.yml", "check-links-nightly.yml"})

    def test_manual_opt_in_assembles_generated_consumers_without_replacing_jobs(self):
        actionlint = os.environ.get("ACTIONLINT") or shutil.which("actionlint")
        self.assertTrue(actionlint, "actionlint is required for assembled consumer verification")
        fragment = yaml.safe_load((ROOT / "templates/workflows/pr-policy.jobs.yml").read_text(encoding="utf-8"))
        self.assertEqual(set(fragment), {"run-pr-policy", "pr-policy"}, "fragment must be merged under jobs")
        for repo_class, language, language_gate in (("docs", "typescript", None), ("tool", "typescript", "node-ci"), ("tool", "python", "python-ci")):
            with self.subTest(repo_class=repo_class, language=language), tempfile.TemporaryDirectory() as temporary:
                name = "contract-optin-docs" if repo_class == "docs" else "contract-optin"
                generated = subprocess.run(["pwsh", "-NoProfile", "-File", str(ROOT / "scripts/new-repo.ps1"),
                                            "-Name", name, "-Class", repo_class, "-Language", language,
                                            "-Path", temporary, "-Create"], capture_output=True, text=True)
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                directory = Path(temporary) / name / ".github/workflows"
                ci_path = directory / "ci.yml"
                ci = yaml.safe_load(ci_path.read_text(encoding="utf-8"))
                original_jobs = dict(ci["jobs"])
                ci["jobs"].update(fragment)
                ci[True]["pull_request"]["types"] += ["ready_for_review", "converted_to_draft"]
                # PyYAML 1.1 reads 'on' as true; restore the workflow key when emitting YAML.
                ci["on"] = ci.pop(True)
                ci_path.write_text(yaml.safe_dump(ci, sort_keys=False), encoding="utf-8")
                hygiene = yaml.safe_load((ROOT / "templates/workflows/hygiene-weekly.yml").read_text(encoding="utf-8"))
                checks = "markdown-lint,link-check,actionlint,pr-title"
                if language_gate:
                    checks += "," + language_gate
                hygiene["jobs"]["hygiene"]["with"]["expected-required-checks"] = checks
                hygiene["on"] = hygiene.pop(True)
                (directory / "hygiene-weekly.yml").write_text(yaml.safe_dump(hygiene, sort_keys=False), encoding="utf-8")
                for name, job in original_jobs.items():
                    self.assertEqual(ci["jobs"][name], job)
                self.assertEqual(ci["jobs"]["run-pr-policy"]["with"]["kit-ref"], KIT_SHA)
                self.assertEqual(ci["jobs"]["pr-policy"]["permissions"], {})
                self.assertEqual(ci["permissions"], {"contents": "read"})
                self.assertEqual(hygiene["jobs"]["hygiene"]["with"], {"expected-required-checks": checks})
                lint = subprocess.run([actionlint, "-shellcheck=", "-pyflakes=", *map(str, sorted(directory.glob("*.yml")))],
                                      capture_output=True, text=True)
                self.assertEqual(lint.returncode, 0, lint.stdout + lint.stderr)

    def test_mode_a_consumer_stubs_isolate_edited_from_sha_cancellation(self):
        # Mode A keeps edited on the single CI stub; assert the full concurrency map.
        expected_group = (
            "${{ github.workflow }}-${{ github.event.action == 'edited' && "
            "format('metadata-{0}', github.run_id) || "
            "format('build-{0}', github.event.pull_request.number || github.ref) }}"
        )
        expected_cancel = (
            "${{ github.event_name == 'pull_request' && github.event.action != 'edited' }}"
        )
        paths = [ROOT / "templates/workflows" / f"{stub}.yml" for stub in ("docs", "node", "python", "site")]
        paths += sorted((ROOT / "templates/starters").glob("*/.github/workflows/ci.yml"))
        for path in paths:
            with self.subTest(path=str(path.relative_to(ROOT))):
                text = path.read_text(encoding="utf-8")
                ci = yaml.safe_load(text)
                concurrency = ci["concurrency"]
                self.assertIn("edited", ci[True]["pull_request"]["types"])
                self.assertEqual(
                    concurrency,
                    {"group": expected_group, "cancel-in-progress": expected_cancel},
                )
                # edited → unique metadata run_id group; non-edited → shared build group.
                self.assertIn("github.event.action == 'edited'", concurrency["group"])
                self.assertIn("format('metadata-{0}', github.run_id)", concurrency["group"])
                self.assertIn(
                    "format('build-{0}', github.event.pull_request.number || github.ref)",
                    concurrency["group"],
                )
                # cancel stays on for non-edited pull_request actions only.
                self.assertIn("github.event.action != 'edited'", concurrency["cancel-in-progress"])
                self.assertIn("Mode A", text)
                self.assertIn("policy.yml", text)
                self.assertIn("Do not remove this edited carve-out", text)
                self.assertIn("still cancel superseded runs", text)
                for job in ci["jobs"].values():
                    if "uses" in job:
                        self.assertTrue(job["uses"].endswith("@" + KIT_SHA))
        fragment = (ROOT / "templates/workflows/pr-policy.jobs.yml").read_text(encoding="utf-8")
        self.assertIn("kit-ref: " + KIT_SHA, fragment)
        self.assertIn("edited-only metadata-${{ github.run_id }} carve-out", fragment)
        self.assertIn("still cancel superseded runs", fragment)


if __name__ == "__main__":
    unittest.main()
