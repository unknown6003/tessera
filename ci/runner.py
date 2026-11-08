"""A timer calls this once. No GitHub Actions runner or hosted CI is used."""

import argparse
import base64
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import signal
import sys
import tarfile
import time

from .common import LANES, REPOSITORY, policy_hash, run, seal, write_json
from .pipeline import execute


class GitHub:
    def __init__(self, state):
        self.state = state

    def api(self, endpoint, data=None):
        command = ["gh", "api", endpoint, "--method", "GET" if data is None else "POST"]
        if data is not None:
            command += ["--input", "-"]
        text = run(command, cwd=self.state, log=self.state / "github.log", timeout=30,
                   data=None if data is None else json.dumps(data).encode())
        return json.loads(text) if text.strip() else None

    def status(self, revision, lane, result, description, target=None):
        data = {"state": result, "context": "Tessera CI / " + lane, "description": description[:140]}
        if target:
            data["target_url"] = target
        self.api(f"repos/{REPOSITORY}/statuses/{revision}", data)

    def publish(self, revision, lane, envelope):
        root = f"repos/{REPOSITORY}"
        refs = self.api(root + "/git/matching-refs/heads/ci-reports")
        if not any(ref["ref"] == "refs/heads/ci-reports" for ref in refs):
            base = self.api(root + "/git/ref/heads/main")["object"]["sha"]
            self.api(root + "/git/refs", {"ref": "refs/heads/ci-reports", "sha": base})
        name = f"reports/{lane}/{revision}.json"
        tree = self.api(root + "/git/trees/ci-reports?recursive=1")
        existing = next((item["sha"] for item in tree["tree"] if item["path"] == name), None)
        data = {"message": f"CI {lane} {revision[:12]}", "branch": "ci-reports",
                "content": base64.b64encode(json.dumps(envelope, indent=2).encode()).decode()}
        if existing:
            data["sha"] = existing
        # The contents endpoint uses PUT rather than the API helper's POST.
        run(["gh", "api", root + "/contents/" + name, "--method", "PUT", "--input", "-"],
            cwd=self.state, log=self.state / "publish.log", timeout=30, data=json.dumps(data).encode())
        return f"https://github.com/{REPOSITORY}/blob/ci-reports/{name}"


def trusted_pull(pull):
    return (pull["head"]["repo"] is not None
            and pull["head"]["repo"]["full_name"] == REPOSITORY
            and pull["base"]["repo"]["full_name"] == REPOSITORY
            and pull["user"]["login"] == REPOSITORY.split("/")[0])


def candidates(github):
    # Forks and other authors never reach this personal machine or its keys.
    pulls = github.api(f"repos/{REPOSITORY}/pulls?state=open&per_page=100")
    revisions = [p["head"]["sha"] for p in pulls if trusted_pull(p)]
    revisions.append(github.api(f"repos/{REPOSITORY}/git/ref/heads/main")["object"]["sha"])
    return list(dict.fromkeys(revisions))


def archive(revision, destination, state):
    if not re.fullmatch("[a-f0-9]{40}", revision):
        raise ValueError("A full Git commit SHA is required")
    repository = state / "repository.git"
    if not repository.exists():
        run(["git", "init", "--bare", str(repository)], cwd=state, log=state / "init.log", timeout=30)
    run(["git", "-C", str(repository), "-c", "core.hooksPath=/dev/null", "fetch", "--depth=1", "--no-tags",
         f"https://github.com/{REPOSITORY}.git", revision], cwd=state, log=state / "fetch.log", timeout=180,
        env={"PATH": os.environ["PATH"], "HOME": str(state), "GIT_TERMINAL_PROMPT": "0"})
    target = destination.parent / "source.tar"
    run(["git", "-C", str(repository), "archive", "--output", str(target), revision],
        cwd=state, log=state / "archive.log", timeout=60)
    destination.mkdir()
    with tarfile.open(target) as bundle:
        bundle.extractall(destination, filter="data")
    target.unlink()


def clean_preferences(revision, state, before):
    if sys.platform != "darwin":
        return
    preferences = Path.home() / "Library/Preferences"
    suffix = ".CI." + revision[:12]
    prefixes = ("TesseraTests.CI." + revision[:12] + ".",)
    for path in preferences.glob("*.plist"):
        if path.name in before or path.is_symlink():
            continue
        domain = path.stem
        if domain in ("com.abdwy.Tessera" + suffix, "com.abdwy.TesseraTests" + suffix) or domain.startswith(prefixes):
            # A newly created exact job namespace, never a shared app domain.
            try:
                run(["defaults", "delete", domain], cwd=state, log=state / "preferences.log", timeout=10)
            except RuntimeError:
                pass  # Empty domains may already be absent from cfprefsd.
            path.unlink(missing_ok=True)
    support = Path.home() / "Library/Application Support" / ("com.abdwy.Tessera" + suffix)
    if support.is_dir() and not support.is_symlink():
        try:
            support.rmdir()  # Remove only an empty, job-specific directory.
        except OSError:
            pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state", type=Path, required=True)
    parser.add_argument("--lane", choices=LANES, required=True)
    parser.add_argument("--revision")
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    state = args.state.resolve()
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    key = (state / "attestation.key").read_bytes()
    if len(key) != 32:
        raise ValueError("CI signing key must be 32 bytes")
    lock = (state / "runner.lock").open("w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return 0
    github = GitHub(state)
    revisions = candidates(github)
    if args.revision:
        if args.revision not in revisions:
            raise ValueError("Revision is not a trusted open PR head or main")
        revisions = [args.revision]
    completed_path = state / "completed.json"
    completed = json.loads(completed_path.read_text()) if completed_path.exists() else {}
    policy = policy_hash(Path(__file__).resolve().parent.parent)
    baseline = args.baseline or (state / "baseline.json" if (state / "baseline.json").exists() else None)
    for revision in revisions:
        job_id = args.lane + "-" + revision
        if not args.force and completed.get(job_id) == policy:
            continue
        if shutil.disk_usage(state).free < 6 * 1024**3:
            raise RuntimeError("Less than 6 GiB free; CI stays pending")
        directory = state / "jobs" / (job_id + "-" + str(time.time_ns()))
        directory.mkdir(parents=True)
        source, output = directory / "source", directory / "output"
        preferences = Path.home() / "Library/Preferences"
        before = {p.name for p in preferences.glob("*.plist")}
        github.status(revision, args.lane, "pending", "Running on owned hardware, outside GitHub Actions")
        try:
            archive(revision, source, state)
            if policy_hash(source) != policy:
                raise ValueError("CI recipe changed; install the reviewed recipe before running")
            report = execute(source, output, args.lane, revision, state / "cache", baseline)
        except Exception as error:
            report = {"revision": revision, "lane": args.lane, "policy": policy, "result": "failure",
                      "failure": type(error).__name__, "steps": [], "finishedAt": time.time()}
            print(str(error), file=sys.stderr)
        finally:
            clean_preferences(revision, state, before)
        envelope = seal(report, key)
        write_json(directory / "attestation.json", envelope)
        if report["result"] == "success" and args.lane == "native" and baseline is None:
            write_json(state / "baseline.json", report["performance"])
        url = github.publish(revision, args.lane, envelope)
        github.status(revision, args.lane, report["result"], "Passed" if report["result"] == "success" else "Failed; see signed report", url)
        completed[job_id] = policy
        write_json(completed_path, completed)
        # One job per timer tick; new PR heads take priority over main.
        return 0 if report["result"] == "success" else 1
    return 0


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
    raise SystemExit(main())
