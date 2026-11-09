"""A fixed recipe, installed outside the repository under test."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import signal
import sys
import tempfile
import time

from .common import build_environment, policy_hash, run, write_json


def remove_tree(root):
    """Remove an owned tree with bounded descriptors and no symlink traversal."""
    root = Path(root)
    if root.name in ("", ".", ".."):
        raise ValueError("Cleanup requires one named owned root")
    flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
    # macOS /tmp is itself a symlink. Resolve only the root's containing path;
    # the root and every entry inside it still require no-follow opens.
    parent_fd = os.open(root.parent.resolve(strict=True), flags)
    try:
        try:
            root_fd = os.open(root.name, flags, dir_fd=parent_fd)
        except FileNotFoundError:
            return
        try:
            identity = os.fstat(root_fd)

            def directory(parts):
                fd = os.dup(root_fd)
                try:
                    for part in parts:
                        child = os.open(part, flags, dir_fd=fd)
                        os.close(fd)
                        fd = child
                    return fd
                except BaseException:
                    os.close(fd)
                    raise

            pending = [((), False)]
            while pending:
                parts, visited = pending.pop()
                fd = directory(parts)
                try:
                    if not visited:
                        with os.scandir(fd) as entries:
                            children = [(entry.name, entry.is_dir(follow_symlinks=False)) for entry in entries]
                        pending.append((parts, True))
                        for name, is_directory in children:
                            if is_directory:
                                pending.append((parts + (name,), False))
                            else:
                                os.unlink(name, dir_fd=fd)
                    elif parts:
                        ancestor = directory(parts[:-1])
                        try:
                            os.rmdir(parts[-1], dir_fd=ancestor)
                        finally:
                            os.close(ancestor)
                    else:
                        current = os.stat(root.name, dir_fd=parent_fd, follow_symlinks=False)
                        if (current.st_dev, current.st_ino) != (identity.st_dev, identity.st_ino):
                            raise ValueError("Owned cleanup root changed")
                        os.rmdir(root.name, dir_fd=parent_fd)
                finally:
                    os.close(fd)
        finally:
            os.close(root_fd)
    finally:
        os.close(parent_fd)


def fixtures(output, root):
    mixed, wide, deep, unicode = [root / name for name in ("mixed20k", "wide100k", "deep420", "unicode2k")]
    for directory in (mixed, wide, deep, unicode):
        directory.mkdir()
    for index in range(250):
        directory = mixed / f"d{index:04}"
        directory.mkdir()
        for item in range(80):
            (directory / f"f{item:04}.dat").write_bytes(b"tessera")
    for index in range(100000):
        (wide / f"w{index:06}.dat").write_bytes(b"tessera")
    cursor = deep
    for _ in range(420):
        cursor = cursor / "d"
        cursor.mkdir()
        (cursor / "file.dat").write_bytes(b"tessera")
    for index in range(2000):
        (unicode / (str(index) + "-" + "界" * 150)).write_bytes(b"tessera")
    cohorts = [("mixed20k", mixed, 20000, 251), ("wide100k", wide, 100000, 1),
               ("deep420", deep, 420, 421), ("unicode2k", unicode, 2000, 1)]
    cases = [{"id": f"{name}-{index:03}", "path": str(path), "expectedFiles": files,
              "expectedDirectories": directories}
             for name, path, files, directories in cohorts for index in range(100)]
    write_json(output / "cases.json", cases)
    return mixed, cohorts


def regression(current, baseline):
    for field in ("hardware", "os", "memoryBytes", "cacheState", "workload", "xcode"):
        if current["metadata"].get(field) != baseline["metadata"].get(field):
            raise ValueError("Performance baseline has different " + field)
    if set(current["cohorts"]) != set(baseline["cohorts"]):
        raise ValueError("Performance baseline has different cohorts")
    for name, cohort in current["cohorts"].items():
        before = baseline["cohorts"][name]["empiricalP99MS"]
        after = cohort["empiricalP99MS"]
        if not isinstance(before, (int, float)) or before <= 0 or after is None:
            raise ValueError("Invalid performance baseline")
        if after > before * 1.5 and after - before > 500:
            raise ValueError(f"Full-pipeline p99 regressed in {name}")


def execute(source, output, lane, revision, cache, baseline=None):
    source, output, cache = Path(source), Path(output), Path(cache)
    output.mkdir(parents=True, exist_ok=True)
    cache.mkdir(parents=True, exist_ok=True)
    env = build_environment(revision[:12])
    report = {"revision": revision, "lane": lane, "policy": policy_hash(Path(__file__).resolve().parent.parent),
              "startedAt": time.time(), "host": platform.platform(), "steps": [], "result": "failure"}
    fixture_root = None

    def step(name, command, timeout=300, cwd=source, extra=None):
        start = time.monotonic()
        entry = {"name": name, "result": "failure"}
        report["steps"].append(entry)
        try:
            text = run(command, cwd=cwd, log=output / (name + ".log"), timeout=timeout,
                       env=env | (extra or {}))
            entry["result"] = "success"
            return text
        finally:
            entry["durationSeconds"] = round(time.monotonic() - start, 3)

    try:
        step("release-policy", [sys.executable, "tools/validate_release.py"])
        step("tool-regressions", [sys.executable, "-m", "unittest", "discover", "-s", "tools", "-p", "test_*.py"])
        if lane == "web":
            web = source / "web"
            pnpm = ["corepack", "pnpm@9.15.9"]
            step("web-install", pnpm + ["install", "--frozen-lockfile"], 600, web)
            for name in ("check", "lint", "test", "build"):
                step("web-" + name, pnpm + [name], 300, web)
            sizes = {kind: sum(p.stat().st_size for p in (web / "dist/client/assets").glob("*." + kind))
                     for kind in ("js", "css")}
            if not 0 < sizes["js"] <= 550000 or not 0 < sizes["css"] <= 100000:
                raise ValueError("Web asset budget failed")
            report["assets"] = sizes
            step("web-browser", [sys.executable, "-m", "ci.web_check", str(web / "dist/client"), str(output)],
                 120, Path(__file__).resolve().parent.parent)
        elif lane == "native":
            if platform.system() != "Darwin":
                raise ValueError("Native CI requires macOS")
            step("xcodegen", ["xcodegen", "generate"])
            derived = output / "DerivedData"
            common = ["xcodebuild", "-project", "Tessera.xcodeproj", "-scheme", "Tessera",
                      "-destination", "platform=macOS", "-derivedDataPath", str(derived),
                      "-clonedSourcePackagesDirPath", str(cache / "spm"),
                      "PRODUCT_BUNDLE_IDENTIFIER=com.abdwy.$(PRODUCT_NAME:rfc1034identifier).CI." + revision[:12]]
            step("debug-tests", common + ["test", "-configuration", "Debug", "-test-iterations", "5",
                 "-resultBundlePath", str(output / "tests.xcresult"), "CODE_SIGN_IDENTITY=-", "CODE_SIGN_STYLE=Manual", "DEVELOPMENT_TEAM="], 1500)
            summary = json.loads(step("test-summary", ["xcrun", "xcresulttool", "get", "test-results", "summary",
                                                        "--path", str(output / "tests.xcresult")], 60))
            if summary.get("failedTests", 0) or summary.get("passedTests", 0) < 90 or summary.get("skippedTests", 0):
                raise ValueError("Native tests missing, failed or skipped")
            report["tests"] = {key: summary.get(key) for key in ("totalTestCount", "passedTests", "failedTests", "skippedTests")}
            step("release-build", common + ["build", "-configuration", "Release", "CODE_SIGNING_ALLOWED=NO",
                                            "CODE_SIGNING_REQUIRED=NO"], 900)
            binary = derived / "Build/Products/Release/Tessera.app/Contents/MacOS/Tessera"
            report["binarySHA256"] = hashlib.sha256(binary.read_bytes()).hexdigest()
            # Own the root before setup so a partial fixture is also removed.
            fixture_root = Path(tempfile.mkdtemp(prefix="tessera-ci-", dir="/tmp"))
            mixed, cohorts = fixtures(output, fixture_root)
            for name, extra in (("scanner", {"SO_BENCH": str(mixed), "SO_BENCH_REPEATS": "3", "SO_BENCH_PARALLEL": "1"}),
                                ("rescan", {"SO_BENCH_RESCAN": str(mixed)})):
                text = step(name, [str(binary)], 300, extra=extra | {"SO_AUTOQUIT": "1"})
                required = ["BENCH serial BEST:", "BENCH parallel BEST:"] if name == "scanner" else ["RESCAN correctness:", "MATCH"]
                if any(marker not in text for marker in required) or "MISMATCH" in text:
                    raise ValueError(f"{name} correctness proof missing")
            metadata = {"hardware": step("hardware", ["sysctl", "-n", "hw.model"], 10).strip(),
                        "os": platform.platform(), "memoryBytes": int(step("memory", ["sysctl", "-n", "hw.memsize"], 10)),
                        "cacheState": "warm; fixtures created before measurement; mixed cohort scanned earlier",
                        "workload": [{"cohort": name, "files": files, "directories": directories, "trials": 100}
                                     for name, _, files, directories in cohorts]}
            metadata["xcode"] = run(["xcodebuild", "-version"], cwd=source,
                                    log=output / "xcode-version.log", timeout=30, env=env).strip()
            metadata["loadAverage"] = list(os.getloadavg())
            write_json(output / "metadata.json", metadata)
            step("full-pipeline-400", [str(binary)], 1800, extra={"SO_PERF_CASES": str(output / "cases.json"),
                 "SO_PERF_OUTPUT": str(output / "trials.json"), "SO_AUTOQUIT": "1"})
            step("performance-goals", [sys.executable, "tools/analyze_scan_performance.py", str(output / "trials.json"),
                 "--revision", revision, "--cases", str(output / "cases.json"), "--metadata", str(output / "metadata.json"),
                 "--output", str(output / "performance.json")])
            performance = json.loads((output / "performance.json").read_text())
            if max(c["longestHeartbeatMS"] for c in performance["cohorts"].values()) > 500:
                raise ValueError("UI heartbeat exceeded 500 ms")
            if baseline:
                regression(performance, json.loads(Path(baseline).read_text()))
            report["performance"] = performance
            report["baselineCompared"] = baseline is not None
        else:
            raise ValueError("Unknown CI lane")
        report["result"] = "success"
    except Exception as error:
        # Keep private command output in local logs; publish only the failure class.
        report["failure"] = type(error).__name__
        print(str(error), file=sys.stderr)
    finally:
        # Cleanup must neither exhaust descriptors on deep fixtures nor replace
        # the original failure and step inventory in the signed report.
        cleanup = [(name, output / name) for name in ("fixtures", "DerivedData")]
        if fixture_root is not None:
            cleanup.append(("fixture-root", fixture_root))
        for name, path in cleanup:
            try:
                remove_tree(path)
            except Exception as error:
                report.setdefault("cleanupFailures", []).append(
                    {"target": name, "error": type(error).__name__, "errno": getattr(error, "errno", None)})
                report["result"] = "failure"
                report.setdefault("failure", "CleanupError")
                print(f"{name} cleanup: {error}", file=sys.stderr)
        report["finishedAt"] = time.time()
        write_json(output / "report.json", report)
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for field in ("source", "output", "cache"):
        parser.add_argument("--" + field, type=Path, required=True)
    parser.add_argument("--lane", choices=("native", "web"), required=True)
    parser.add_argument("--revision", required=True)
    parser.add_argument("--baseline", type=Path)
    args = parser.parse_args()
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
    result = execute(args.source.resolve(), args.output.resolve(), args.lane, args.revision,
                     args.cache.resolve(), args.baseline)
    raise SystemExit(0 if result["result"] == "success" else 1)
