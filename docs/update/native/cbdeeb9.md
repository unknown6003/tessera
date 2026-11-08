# Exact cbdeeb9 qualification

Build, tests, root duration and root heartbeat gates PASS. Native Sidebar loading, Refresh, custom-folder retention and Sources hide/show PASS. A distinct in-flight selection sample is unproved because discovery finished in 0.001 seconds. No source fix was made.

Target origin/codex/tessera-2 resolves to cbdeeb964f09b0e3827999d6498db7b76eb93e98. Original Mac checkout /Users/abdwy/development/tessera stayed clean at a538b8d4431430e0d497a3f94d44e83147062730. Target source came from git archive cbdeeb9 into this folder's BUILDSTAGING. XcodeGen changed only its staged project. All 55 production and test files match the exact commit, with zero mismatches.

## Contract and controls

Outcome: qualify the exact build, real Sources callback and one actual Release root scan.
Proof: full Debug tests, unsigned Release, native AX/HID input, worker and phase logs, root completion, RSS observations and fixture hashes.
Constraints: no source edits, subagents, Git checkouts, SDK installs, user cleanup, PR, watch or release. Total deadline 20 minutes. No repeat controlled benchmark, wide audit or seven-variant capture.

Read shared engineering-rules.md, engineering-workflow/SKILL.md, its references/performance.md, unslop/SKILL.md and memory/model-guide.md. Applied the performance measurement route and writing self-audit. The memory registry supplied no Tessera finding used as evidence. The user-supplied 7319 report supplied reusable paths and prior context only.

Bootstrap instruction reads ran inside GNU timeout -k3s 10s with redirected logs and tracked wrapper PID files. Fullrun.py then bounded each command, wrote command/PID/deadline/exit/elapsed JSON and logs, started a new process group and used TERM followed by KILL on timeout. It caps each deadline by the remaining total budget. UI and root apps had separate tracked process groups, logs and deadlines. All owned app PIDs were stopped. The final audit found no remaining owned PID. No substantive command timed out. Several UI helpers returned missing-target or wrong-frontmost errors; these are retained and were not counted as passes.

Final integrity audit finished 521.082 seconds after the first bootstrap log was created, within the 1200-second total limit. The runner used an earlier conservative start, with 677.297 seconds elapsed at that audit.

## Commands and artifact signatures

The original checkout was used only for Git reads and the requested branch fetch:

```bash
git fetch origin codex/tessera-2
git rev-parse origin/codex/tessera-2
git archive cbdeeb9 | tar -x -C /tmp/tessera-cbdeeb9-qualify/BUILDSTAGING
```

Build commands ran from BUILDSTAGING, each through fullrun.py:

```bash
xcodegen generate
xcodebuild test -project Tessera.xcodeproj -scheme Tessera -configuration Debug -destination platform=macOS -derivedDataPath /tmp/tessera-native-verification.1GZiGk/dd-updated -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
xcodebuild build -project Tessera.xcodeproj -scheme Tessera -configuration Release -destination platform=macOS -derivedDataPath /tmp/tessera-native-verification.1GZiGk/dd-updated -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

Reused existing dd-updated dependencies and toolchains. No install ran. Test deadline 240 seconds, Release deadline 180 seconds. Debug xcodebuild exited 0 in 42.466 seconds with TEST SUCCEEDED. Swift Testing reports all 72 tests in five suites passed in 8.421 seconds. Release xcodebuild exited 0 in 32.238 seconds with BUILD SUCCEEDED.

Unsigned Release executable:

```text
/tmp/tessera-native-verification.1GZiGk/dd-updated/Build/Products/Release/Tessera.app/Contents/MacOS/Tessera
SHA-256 c076a63448a7af1cd0956185aa6cb174800c1db967df0862cc225d94f3c65562
```

The empty-haystack guard now includes !value.isEmpty before the ASCII predicate. Empty input reaches the original String.contains fallback. The full suite passed. No new classifier speed ratio or checksum comparison was run. The prior 7319 median CPU result, 5.984602 to 0.528163 seconds, remains prior evidence only.

## Native input and source worker

Used the existing input and axaction helpers with Accessibility access confirmed from earlier native evidence, plus System Events for the actual folder picker. No screenshots were taken. AX text dumps stayed in the local evidence folder. No account-name screenshot exists.

Both fixture app launches used SO_AUTOSCAN pointing to the owned Sample disk, SO_PRIVATE_SUMMARY=1 and NSUnbufferedIO=YES. They used isolated automation preference domains and no snapshot directory. First fixture scan reported nine files, 17/17 directories, 52428800 bytes, complete coverage, zero gaps, error=none and cancelled=false. Its longest heartbeat was 51.5 ms. The second reported the same counts, complete coverage and a 109.0 ms longest heartbeat.

Initial Sources loading showed six discovered sources. Native AXPress Refresh returned 0 and produced source discovery main=false. The first picker attempt did not complete reliably: the helper reported missing targets or refused input when another app was frontmost. AX text showed a still-open picker. That attempt is not custom-folder acceptance. A read-only diagnostic also captured unrelated foreground-app AX text while identifying the focus issue; it is excluded from product evidence and no action was sent to that app.

A second bounded fixture launch completed Choose Folder through the real native picker using System Events. It added this owned custom source:

```text
/tmp/tessera-cbdeeb9-qualify/NativeScoped
```

The folder contains a 28-byte owned probe.txt. ui2-before-ax.log shows AXDescription=NativeScoped and AXValue=Selected. AXPress Refresh returned 0. ui2-refresh-ax.log and ui2-selected-after-ax.log show the same NativeScoped selection and Scan NativeScoped prompt. This tests the real Sidebar callback with an actual custom folder, rather than calling the discovery API from a probe.

The relevant worker output is:

```text
[DebugAutomation] source discovery: main=false elapsed=0.001s sources=6
```

Sources hide and show each returned AXPress result 0. ui2-hidden-ax.log has no Sources panel header or Refresh button. ui2-shown-ax.log restores both and NativeScoped remains Selected. During the root scan, Sources hide/show also succeeded, with Cancel scan still enabled in the AX tree. A transient missing-target attempt was followed by a successful focused retry.

The source worker finished in about one millisecond. AX captures show selection before, immediately after and after completion. They do not catch a disabled Refresh button or independently observe selection during that one-millisecond interval. Selection retention across actual completion passes; strict in-flight selection observation remains open. Concurrent custom additions, request-coalescing saturation and active Delete completion were not forced. Optional Cancel scan and Review Escape were not run. Historical drag/Review/confirmation paths were not replayed.

## One actual unprofiled Release root run

The app launched once for root with inherited SO_ variables removed, then SO_AUTOSCAN=/ SO_AUTOQUIT=1 SO_PRIVATE_SUMMARY=1 NSUnbufferedIO=YES. SO_SNAPSHOT_DIR was absent. The app had its own 240-second deadline; the enclosing supervisor had 255 seconds. RSS used one bounded ps observation about every five seconds. No profiler or stack sample ran. The permitted sample at 150 seconds was not needed. No snapshots or cleanup ran. Two brief Sources UI operations and one focused retry occurred during enumeration; this was unprofiled, but not a no-input timing control.

Exact emitted phase points and final summary:

```text
scan phase: enumeration finished elapsed=51.512s
scan phase: diagnosis finished elapsed=56.219s
scan phase: results published elapsed=56.227s
UI heartbeat longest interval: 113.9 ms
scan finished: root=1061123371008 error=none cancelled=false files=4478551 dirs 1285046/1285046 elapsed=56.37s rate=22797 dirs/s coverage=partial gaps=303
collector: 0 items, Zero KB
```

All heartbeat-delay lines above 500 ms: NONE. No such line appears in root.log. The app exited 0 with a completed, uncancelled scan and published results. This is application-result evidence, not merely an outer runner exit. The supervisor also exited 0 without timeout.

Supervised launch-to-observed-exit wall time was 60.113 seconds. Five-second polling makes that an upper observation bound, not the precise process lifetime. The app's final scan elapsed time was 56.37 seconds. Sampled peak RSS was 1655422976 bytes, about 1.655 GB decimal. This is a sampled peak, not an exact kernel high-water mark. root-rss.json retains every observation. root-events.json retains observed log-arrival times; use the internal phase timestamps for phase boundaries.

Enumeration accounts for 51.512 seconds. The interval to diagnosis completion is 4.707 seconds; publication adds 0.008 seconds. Enumeration dominates this run. The diagnosis interval includes the work between those checkpoints and is not a pure classifier CPU measurement. No new measured source-discovery pause appeared. There is no root >120-second or heartbeat >500-ms failure to diagnose in this run.

Coverage remains partial with 303 gaps. Equal final directory counts do not prove full-drive access. Gap paths were not dumped. A sandbox_extension_issue_file_to_process warning appeared at launch, followed by error=none and successful completion. The 56.37-second result meets this run's duration goal, but does not prove a controlled speedup over the prior 140.13-second run. Filesystem warmth, host load and contents can differ.

## Final integrity and limits

Sample disk retained the same nine relative file names, sizes, mtimes and SHA-256 hashes before and after, totaling 52428800 bytes. fixture-before.json equals fixture-after.json. Original HEAD and clean status are unchanged. All 55 archived production/test source files match cbdeeb9. final-audit-result.json reports zero remaining owned PIDs. Build products, staging, NativeScoped and evidence remain. No user file cleanup ran.

Accept the full Debug suite, unsigned Release, actual source worker main=false, custom-folder selection retention across Refresh, Sources toggles and this single root duration/heartbeat result. Keep the one-millisecond in-flight AX observation and unforced concurrency cases outside the claim. No PR, watch, release or source change was made.
