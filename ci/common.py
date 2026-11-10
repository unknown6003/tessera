import hashlib
import hmac
import json
import os
from pathlib import Path
import signal
import subprocess
import time

from tools.run_bounded import signal_owned_group

REPOSITORY = "unknown6003/tessera"
LANES = ("native", "web")
RECIPE_FILES = ["ci/" + name for name in ("__init__.py", "common.py", "pipeline.py", "runner.py", "web_check.py")]
RECIPE_FILES += ["tools/" + name for name in ("run_bounded.py", "analyze_scan_performance.py", "validate_release.py")]
RECIPE_FILES.append("ci/install.py")
NATIVE_LAUNCHD_POLICY = {"ProcessType": "Standard", "Nice": 10, "LowPriorityIO": True}
REQUIRED_STEPS = {
    "native": {"release-policy", "tool-regressions", "xcodegen", "debug-tests", "test-summary", "release-build",
               "scanner", "rescan", "hardware", "memory", "full-pipeline-400", "performance-goals"},
    "web": {"release-policy", "tool-regressions", "web-install", "web-check", "web-lint", "web-test", "web-build", "web-browser"},
}


def write_json(path, value):
    path = Path(path)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, allow_nan=False) + "\n")
    temporary.replace(path)


def run(command, *, cwd, log, timeout, env=None, data=None):
    """Run a finite command and stop its descendants on every exit path."""
    log = Path(log)
    log.parent.mkdir(parents=True, exist_ok=True)
    pid_file = log.with_suffix(log.suffix + ".pid")
    with log.open("w") as output:
        process = subprocess.Popen(command, cwd=cwd, env=env, stdout=output,
                                   stderr=subprocess.STDOUT, start_new_session=True,
                                   stdin=subprocess.PIPE if data is not None else subprocess.DEVNULL)
        pid_file.write_text(str(process.pid))
        try:
            if data is not None:
                process.stdin.write(data)
                process.stdin.close()
            try:
                status = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                status = 124
        finally:
            try:
                if signal_owned_group(process.pid, signal.SIGTERM):
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        pass
                    signal_owned_group(process.pid, signal.SIGKILL)
                process.wait(timeout=5)
            finally:
                pid_file.unlink(missing_ok=True)
    if status:
        raise RuntimeError(f"{log.name}: exit {status}")
    return log.read_text(errors="replace")


def build_environment(job):
    # Build commands receive no GitHub, signing, cloud or analytics credentials.
    allowed = ("PATH", "HOME", "USER", "LOGNAME", "TMPDIR", "DEVELOPER_DIR", "LANG", "LC_ALL")
    result = {key: os.environ[key] for key in allowed if key in os.environ}
    result.update(CI="1", SO_CI="1", SO_CI_JOB=job, GIT_TERMINAL_PROMPT="0",
                  TEST_RUNNER_SO_CI="1", TEST_RUNNER_SO_CI_JOB=job,
                  COREPACK_ENABLE_DOWNLOAD_PROMPT="0", COREPACK_ENABLE_AUTO_PIN="0",
                  NSUnbufferedIO="YES")
    return result


def policy_hash(root):
    root = Path(root)
    digest = hashlib.sha256()
    for name in RECIPE_FILES:
        path = root / name
        digest.update(str(path.relative_to(root)).encode() + b"\0" + path.read_bytes())
    return digest.hexdigest()


def seal(report, key):
    payload = json.dumps(report, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()
    return {"report": report, "signature": hmac.new(key, payload, hashlib.sha256).hexdigest()}


def verify(envelope, key, revision, lane, policy):
    if len(key) != 32:
        raise ValueError("CI signing key must be 32 bytes")
    report = envelope["report"]
    expected = seal(report, key)["signature"]
    if not hmac.compare_digest(expected, envelope["signature"]):
        raise ValueError("CI report signature does not match")
    if (report.get("revision"), report.get("lane"), report.get("policy")) != (revision, lane, policy):
        raise ValueError("CI report has a different commit, lane or policy")
    if report.get("result") != "success" or not report.get("steps"):
        raise ValueError("CI did not pass")
    if any(step.get("result") != "success" for step in report["steps"]):
        raise ValueError("A required CI step did not pass")
    if ({step.get("name") for step in report["steps"]} != REQUIRED_STEPS[lane]
            or len(report["steps"]) != len(REQUIRED_STEPS[lane])):
        raise ValueError("CI evidence has a missing or unknown step")
    if lane == "native":
        cohorts = report.get("performance", {}).get("cohorts", {})
        if set(cohorts) != {"mixed20k", "wide100k", "deep420", "unicode2k"}:
            raise ValueError("Performance campaign is incomplete")
        if any(c.get("samples") != 100 or c.get("goalMetForThisCohort") is not True
               or c.get("failedOrPartial") != 0 or c.get("cloudRemoteOrUnknown") != 0
               or c.get("longestHeartbeatMS", 1000) > 500 for c in cohorts.values()):
            raise ValueError("Performance or coverage did not qualify")
    age = time.time() - report.get("finishedAt", 0)
    if not 0 <= age <= 7 * 86400:
        raise ValueError("CI evidence is stale or from the future")
    return report
