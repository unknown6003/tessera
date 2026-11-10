# Native tests and local fixture campaign

Branch head `02c6a3485df4fb353d38a056164360925f2036ce` passed
[app CI](https://github.com/unknown6003/tessera/actions/runs/42512151056) and
[stress qualification](https://github.com/unknown6003/tessera/actions/runs/42512151055).
83 tests in seven suites passed. The unsigned Release build passed. The
new source, crash-storage and four-host consent-header regressions all passed.

The campaign ran 100 full application pipelines in each cohort. All 400
trials matched file and directory counts and finished with complete coverage.
No trial exceeded 120 seconds, failed or read through a provider helper.
The local analyzer reproduced every summary from the raw trial inventory.

| Warm-cache fixture | Files | Directories | Empirical p99 | Maximum |
|---|---:|---:|---:|---:|
| Mixed | 20,000 | 251 | 0.831 s | 1.030 s |
| Wide | 100,000 | 1 | 7.103 s | 8.153 s |
| Deep | 420 | 421 | 0.535 s | 0.577 s |
| Long Unicode | 2,000 | 1 | 0.468 s | 0.529 s |

Host: VirtualMac2,1, arm64, macOS 26.7.2, 7 GiB memory. Fixtures were written
immediately before trials. The mixed fixture had also been scanned earlier.
Nearest-rank p99 includes the complete view-model pipeline and a 100 ms UI
settle. Slow and failed trials were retained. There is no 120-second scan cap.
These results cover this runner and these workloads, not population p99 or
other devices. Cloud and remote drives are outside these cohorts.

Responsiveness remains open. The longest heartbeat was 818.6 ms in the wide
cohort. 69 wide trials and one mixed trial had a delay over 500 ms. No cause
was profiled. UI iteration 2 changes the browser and map snapshot path and
needs the same native measurement.

`report.json`, `metadata.json` and `trials.json` preserve the raw artifact.
`provenance.json` records the tested PR merge and branch head. GitHub's commit
API returned tree `1afca45fdf0474df00005dd9723e5e66f8a9f5ba` for both, so the
merge artifact with revision `e21b62f` tested exactly the branch contents.
