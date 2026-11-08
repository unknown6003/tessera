"""Fail closed unless both external CI lanes passed this exact clean commit."""

import argparse
import base64
import json
import os
from pathlib import Path
import subprocess
import tempfile

from .common import LANES, REPOSITORY, policy_hash, run, verify


def check(source, key, log_root):
    revision = run(["git", "rev-parse", "HEAD"], cwd=source, log=log_root / "head.log", timeout=10).strip()
    dirty = run(["git", "status", "--porcelain"], cwd=source, log=log_root / "tree.log", timeout=10)
    if dirty.strip():
        raise ValueError("Release source is not clean")
    policy = policy_hash(source)
    statuses = json.loads(run(["gh", "api", f"repos/{REPOSITORY}/commits/{revision}/status?per_page=100"],
                             cwd=source, log=log_root / "statuses.log", timeout=30))
    for lane in LANES:
        matching = [s for s in statuses["statuses"] if s["context"] == "Tessera CI / " + lane]
        if not matching or matching[0]["state"] != "success":
            raise ValueError("External CI did not pass: " + lane)
        body = json.loads(run(["gh", "api", f"repos/{REPOSITORY}/contents/reports/{lane}/{revision}.json?ref=ci-reports"],
                              cwd=source, log=log_root / (lane + ".log"), timeout=30))
        envelope = json.loads(base64.b64decode(body["content"]))
        verify(envelope, key, revision, lane, policy)
    return revision


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path.cwd())
    parser.add_argument("--key", type=Path, required=True)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="tessera-release-gate-") as directory:
        revision = check(args.source.resolve(), args.key.read_bytes(), Path(directory))
    print("Both external CI lanes passed " + revision)


if __name__ == "__main__":
    main()
