import copy
import os
import subprocess
from pathlib import Path
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

from ci.common import RECIPE_FILES, REQUIRED_STEPS, build_environment, policy_hash, run, seal, verify
from ci.pipeline import execute, regression, remove_tree
from ci.runner import trusted_pull


class ExternalCITests(unittest.TestCase):
    def test_cleanup_refuses_root_symlink_and_parent_component(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "outside").mkdir()
            (root / "outside/keep").write_text("unchanged")
            (root / "alias").symlink_to(root / "outside", target_is_directory=True)
            with self.assertRaises(OSError):
                remove_tree(root / "alias")
            with self.assertRaises(ValueError):
                remove_tree(root / "outside/..")
            self.assertEqual((root / "outside/keep").read_text(), "unchanged")

    def test_cleanup_handles_real_depth_under_a_low_descriptor_limit(self):
        script = '''
import errno, os, resource, shutil, tempfile
from pathlib import Path
from ci.pipeline import remove_tree
with tempfile.TemporaryDirectory() as temporary:
    base = Path(temporary)
    (base / "real").mkdir()
    (base / "alias").symlink_to(base / "real", target_is_directory=True)
    root = base / "alias/owned"
    root.mkdir()
    outside = base / "outside"
    outside.mkdir()
    (outside / "keep").write_text("unchanged")
    (root / "link").symlink_to(outside, target_is_directory=True)
    cursor = root
    for _ in range(280):
        cursor = cursor / "d"
        cursor.mkdir()
    (cursor / "file").write_text("owned")
    soft, hard = resource.getrlimit(resource.RLIMIT_NOFILE)
    resource.setrlimit(resource.RLIMIT_NOFILE, (32, hard))
    try:
        try:
            shutil.rmtree(root)
        except OSError as error:
            assert error.errno == errno.EMFILE, error
        else:
            raise AssertionError("Legacy removal must reproduce descriptor exhaustion")
        (root / "link-after-red").symlink_to(outside, target_is_directory=True)
        remove_tree(root)
        assert not root.exists()
        assert (outside / "keep").read_text() == "unchanged"
    finally:
        resource.setrlimit(resource.RLIMIT_NOFILE, (soft, hard))
'''
        result = subprocess.run([sys.executable, "-B", "-c", script], capture_output=True,
                                text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_cleanup_failure_keeps_original_step_and_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = root / "output"
            (output / "DerivedData").mkdir(parents=True)
            with patch("ci.pipeline.run", side_effect=RuntimeError("original heartbeat failure")), \
                 patch("ci.pipeline.remove_tree", side_effect=OSError(24, "synthetic cleanup exhaustion")):
                report = execute(root, output, "web", "a" * 40, root / "cache")
            self.assertEqual(report["result"], "failure")
            self.assertEqual(report["failure"], "RuntimeError")
            self.assertEqual(report["steps"][0]["name"], "release-policy")
            self.assertEqual(report["steps"][0]["result"], "failure")
            self.assertEqual(report["cleanupFailures"], [
                {"target": target, "error": "OSError", "errno": 24} for target in ("fixtures", "DerivedData")])

    def test_cleanup_failure_also_rejects_otherwise_successful_job(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            assets = root / "web/dist/client/assets"
            assets.mkdir(parents=True)
            for extension in ("js", "css"):
                (assets / ("index." + extension)).write_text("x")
            with patch("ci.pipeline.run", return_value=""), \
                 patch("ci.pipeline.remove_tree", side_effect=OSError(24, "synthetic cleanup exhaustion")):
                report = execute(root, root / "output", "web", "a" * 40, root / "cache")
            self.assertTrue(all(step["result"] == "success" for step in report["steps"]))
            self.assertEqual(report["result"], "failure")
            self.assertEqual(report["failure"], "CleanupError")
            self.assertEqual(report["cleanupFailures"][0]["errno"], 24)

    def report(self):
        return {"revision": "a" * 40, "lane": "web", "policy": "pinned",
                "result": "success", "finishedAt": time.time(),
                "steps": [{"name": name, "result": "success"} for name in REQUIRED_STEPS["web"]]}

    def test_exact_commit_policy_and_lane_are_required(self):
        key = b"x" * 32
        envelope = seal(self.report(), key)
        self.assertEqual(verify(envelope, key, "a" * 40, "web", "pinned")["result"], "success")
        for revision, lane, policy in (("b" * 40, "web", "pinned"), ("a" * 40, "native", "pinned"),
                                       ("a" * 40, "web", "changed")):
            with self.subTest(revision=revision, lane=lane, policy=policy), self.assertRaises(ValueError):
                verify(envelope, key, revision, lane, policy)

    def test_modified_or_unsigned_evidence_fails(self):
        envelope = seal(self.report(), b"x" * 32)
        envelope["report"]["result"] = "failure"
        with self.assertRaises(ValueError):
            verify(envelope, b"x" * 32, "a" * 40, "web", "pinned")
        with self.assertRaises(ValueError):
            verify(seal(self.report(), b"y" * 32), b"x" * 32, "a" * 40, "web", "pinned")

    def test_missing_failed_and_stale_steps_fail_even_when_signed(self):
        for change in ("missing", "failed", "stale", "future", "empty"):
            report = self.report()
            if change == "missing": report["steps"].pop()
            if change == "failed": report["steps"][0]["result"] = "failure"
            if change == "stale": report["finishedAt"] -= 8 * 86400
            if change == "future": report["finishedAt"] += 86400
            if change == "empty": report["steps"] = []
            with self.subTest(change=change), self.assertRaises(ValueError):
                verify(seal(report, b"x" * 32), b"x" * 32, "a" * 40, "web", "pinned")

    def test_build_environment_strips_service_and_signing_credentials(self):
        with patch.dict(os.environ, {"GH_TOKEN": "private", "GITHUB_TOKEN": "private", "POSTHOG_API_KEY": "private",
                                     "SPARKLE_PRIVATE_KEY": "private", "MACOS_CERT_PASSWORD": "private"}):
            env = build_environment("a" * 12)
        self.assertFalse(any(key in env for key in ("GH_TOKEN", "GITHUB_TOKEN", "POSTHOG_API_KEY",
                                                    "SPARKLE_PRIVATE_KEY", "MACOS_CERT_PASSWORD")))
        self.assertEqual(env["SO_CI_JOB"], "a" * 12)
        self.assertEqual(env["SO_CI"], "1")
        self.assertEqual(env["TEST_RUNNER_SO_CI"], "1")
        self.assertEqual(env["TEST_RUNNER_SO_CI_JOB"], "a" * 12)

    def test_changing_the_performance_checker_changes_the_trusted_recipe(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in RECIPE_FILES:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("original")
            original = policy_hash(root)
            (root / "tools/analyze_scan_performance.py").write_text("changed")
            self.assertNotEqual(original, policy_hash(root))
            (root / "tools/analyze_scan_performance.py").write_text("original")
            (root / "ci/install.py").write_text("changed scheduling")
            self.assertNotEqual(original, policy_hash(root))

    def test_forks_and_other_pr_authors_never_run(self):
        valid = {"head": {"repo": {"full_name": "unknown6003/tessera"}},
                 "base": {"repo": {"full_name": "unknown6003/tessera"}}, "user": {"login": "unknown6003"}}
        self.assertTrue(trusted_pull(valid))
        for field in ("head", "base", "user", "deleted"):
            pull = copy.deepcopy(valid)
            if field in ("head", "base"): pull[field]["repo"]["full_name"] = "fork/tessera"
            if field == "user": pull["user"]["login"] = "someone-else"
            if field == "deleted": pull["head"]["repo"] = None
            self.assertFalse(trusted_pull(pull))

    def test_real_timeout_cannot_leave_a_child_running(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            child = "import time,pathlib; time.sleep(1); pathlib.Path('escaped').write_text('bad')"
            leader = "import subprocess,sys,time; subprocess.Popen([sys.executable,'-c',sys.argv[1]]); time.sleep(5)"
            with self.assertRaises(RuntimeError):
                run([sys.executable, "-c", leader, child], cwd=root, log=root / "deadline.log", timeout=0.1)
            time.sleep(1.1)
            self.assertFalse((root / "escaped").exists())
            self.assertFalse((root / "deadline.log.pid").exists())

    def test_successful_leader_also_stops_its_children(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            child = "import time,pathlib; time.sleep(1); pathlib.Path('escaped').write_text('bad')"
            run([sys.executable, "-c", "import subprocess,sys; subprocess.Popen([sys.executable,'-c',sys.argv[1]])", child],
                cwd=root, log=root / "finished.log", timeout=5)
            time.sleep(1.1)
            self.assertFalse((root / "escaped").exists())

    def test_relative_p99_regression_is_not_silently_accepted(self):
        before = {"metadata": {"hardware": "M1"}, "cohorts": {"wide100k": {"empiricalP99MS": 1000}}}
        after = copy.deepcopy(before)
        after["cohorts"]["wide100k"]["empiricalP99MS"] = 2000
        with self.assertRaises(ValueError): regression(after, before)
        after["cohorts"]["wide100k"]["empiricalP99MS"] = 1200
        regression(after, before)
        after["metadata"]["hardware"] = "different"
        with self.assertRaises(ValueError): regression(after, before)
        after["metadata"]["hardware"] = "M1"
        before["metadata"]["runnerScheduling"] = {"ProcessType": "Background"}
        after["metadata"]["runnerScheduling"] = {"ProcessType": "Standard"}
        with self.assertRaisesRegex(ValueError, "runnerScheduling"):
            regression(after, before)

    def test_partial_fixture_setup_is_removed_after_io_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, output, fixture = root / "source", root / "output", root / "partial-fixture"
            source.mkdir()
            fixture.mkdir()

            def command(command, **kwargs):
                if "xcresulttool" in command:
                    return '{"passedTests":90,"failedTests":0,"skippedTests":0}'
                if "Release" in command:
                    binary = output / "DerivedData/Build/Products/Release/Tessera.app/Contents/MacOS/Tessera"
                    binary.parent.mkdir(parents=True)
                    binary.write_bytes(b"test binary")
                return ""

            def broken_setup(output, owned):
                (owned / "created-before-disk-error").write_bytes(b"test")
                raise OSError("synthetic disk error")

            with patch("ci.pipeline.platform.system", return_value="Darwin"), \
                 patch("ci.pipeline.run", side_effect=command), \
                 patch("ci.pipeline.tempfile.mkdtemp", return_value=str(fixture)), \
                 patch("ci.pipeline.fixtures", side_effect=broken_setup):
                report = execute(source, output, "native", "a" * 40, root / "cache")
            self.assertEqual(report["result"], "failure")
            self.assertFalse(fixture.exists())
            self.assertFalse((output / "DerivedData").exists())

    def test_report_write_failure_does_not_skip_build_cleanup(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = root / "output"
            (output / "DerivedData").mkdir(parents=True)
            with patch("ci.pipeline.run", side_effect=RuntimeError("synthetic build error")), \
                 patch("ci.pipeline.write_json", side_effect=OSError("synthetic full disk")), \
                 self.assertRaises(OSError):
                execute(root, output, "web", "a" * 40, root / "cache")
            self.assertFalse((output / "DerivedData").exists())


if __name__ == "__main__":
    unittest.main()
