"""Report empirical local-drive p99 without dropping slow or failed trials."""

import argparse
import json
import math
from collections import defaultdict
from pathlib import Path


def summarize(rows, expected_per_cohort=100):
    groups = defaultdict(list)
    ids = set()
    for row in rows:
        case_id = row["id"]
        if case_id in ids:
            raise ValueError(f"Duplicate trial: {case_id}")
        ids.add(case_id)
        duration = row["durationMS"]
        if isinstance(duration, bool) or not isinstance(duration, (int, float)) or not math.isfinite(duration) or duration < 0:
            raise ValueError(f"Invalid duration: {case_id}")
        groups[case_id.rsplit("-", 1)[0]].append(row)
    if not groups:
        raise ValueError("No trials")
    report = {}
    for cohort, samples in sorted(groups.items()):
        durations = sorted(row["durationMS"] for row in samples)
        p99 = durations[math.ceil(0.99 * len(durations)) - 1]
        failed = sum(row["outcome"] != "complete" or not row["countsMatch"] or row["coverageGaps"] != 0 for row in samples)
        mixed = sum(row["providerReads"] != 0 or row["sourceClass"] not in ("local_internal", "local_external", "local_unknown") for row in samples)
        enough = len(samples) >= expected_per_cohort
        report[cohort] = {
            "samples": len(samples), "empiricalP99MS": p99 if enough else None,
            "maxMS": max(durations), "over120Seconds": sum(value > 120_000 for value in durations),
            "failedOrPartial": failed, "cloudRemoteOrUnknown": mixed,
            "longestHeartbeatMS": max(row["longestHeartbeatMS"] for row in samples),
            "goalMetForThisCohort": enough and p99 <= 120_000 and failed == 0 and mixed == 0,
        }
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("--revision", required=True)
    parser.add_argument("--expected-per-cohort", type=int, default=100)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    cohorts = summarize(json.loads(args.input.read_text()), args.expected_per_cohort)
    report = {"revision": args.revision, "method": "nearest rank; full pipeline plus 100 ms UI settle; slow and failed trials retained",
              "scope": "Empirical p99 for these local fixture cohorts and this host. Population and other-device p99 are not established.",
              "cohorts": cohorts}
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    raise SystemExit(0 if all(cohort["goalMetForThisCohort"] for cohort in cohorts.values()) else 1)
