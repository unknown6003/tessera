# Native wide-folder recheck

Exact source: `778dfdf259902fb5f6a28df67681e936aeb8b073`, tree
`4ae9c29fbaa6209d4184961e6151b0ca45ade020`. Source manifest SHA-256:
`a0942e67570638142211d5da724ea6cedeb90df60bbbddfe091acf2c7c521b4a`.

An Opus run on 9 November 2026 used an M1 Max, 10 cores, 32 GB,
macOS 27.0.1. The same warm-cache fixture had 100,000 files, two directories,
150,049,000 logical bytes and 409,600,000 allocated bytes. The name and size
manifest stayed equal. This is one synthetic workload, not drive-population p99.

## Results

| Run | Build | Published, s | Heartbeat max, ms | End busy, ms | AX reply, ms | RSS after End, MB |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 1 | Debug | 0.431 | 82.0 | 6* | 69 | 146 |
| 2 | Debug | 0.436 | 82.4 | 8 | 63 | 171 |
| 3 | Debug | 0.463 | 64.0 | 86 | 69 | 170 |
| 4 | Release | 0.292 | 104.1 | 76 | 65 | 169 |
| 5 | Release | 0.268 | 63.0 | 66 | 64 | 169 |
| 6 | Release | 0.301 | 95.7 | 68 | 62 | 168 |

End busy time comes from 2 ms main-thread samples, not an end-to-end stopwatch.
Run 1's sampler attached after End, so its 6 ms value can miss initial work.
Runs 2–6 started sampling 0.5 seconds before the key. Run 1 sampled the scan;
the other five scan heartbeats had no sampler. These limits matter when
comparing the results with the baseline.

All six runs passed the agreed workload bars: heartbeat under 500 ms, End busy
under one second, AX reply under 200 ms and RSS after End under 300 MB. No
`ForEachState.firstOffset` or `ScrollViewProxy.scrollTo` frame appeared.
The c590 Release baseline took about 31 seconds for End and reached 2.28 GB.

Every End selected and showed the last row. Home, Down, Page Down, Return
and Command-Up worked. Resize and Items/Details switching kept that row
visible. A manual scroll after reveal stayed where the user put it. Row
50,000 was not tested; resize used the last row instead. Focus after toggling
Details still landed on the window group and needs further work.

## Build and removal proof

Release built. Debug compiled and ran 89 tests: 88 passed; the new removal
test failed its fixture assertions. Its action-local summary assertions passed.
The test-only fixture correction is in `5f90ec2`. This run is not a passing
full-suite qualification.

A real Review and confirmation moved only an owned disposable file, with an
unrelated protected `.docker/keep.qcow2` in the plan. Cancel kept Review open.
The result read "Moved 1 item (2 MB allocated) to Trash." It showed a success
icon and no held or failed count. The protected file's hash, size and mtime
stayed equal. Trash was not emptied. Command-Y opened and then closed Quick
Look. The toolbar read "Rescan".

The XCTest updater guard passed. Sparkle wrote neither `SULastCheckTime` nor
`TesseraLastRunVersion`. The fake-transport SDK test left two PostHog version
keys in the qualification domain. No packet capture ran; network exclusion
rests on the guard and intercepted wire tests.

## Limits and safety

The app used an isolated qualification bundle and an archived source tree.
The original Mac checkout stayed clean at `a538b8d`. Production preference
hash, size and mtime stayed equal. Created domains were backed up and removed.
Owned processes stopped. Input used PID targeting plus executable, front-app
and window checks. Wrong-target controls posted zero keys.

The full private report is `/tmp/tessera-778d-qual/REPORT.md` on the Mac.
Its window captures contain real source labels and remain unpublished.
Full UI scoring, VoiceOver, real contrast and motion settings, source rename
and source Scan labels remain open. The later visual patch has no native
score yet. No area is qualified at 9/10.
