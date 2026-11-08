# Wide-folder input diagnosis

Outcome: remove the measured wide-folder input stall, then repeat the same
native workload. The implementation and its qualification remain open.

Proof: native main-thread samples, heartbeat logs, input timestamps, AX
responses and RSS from the same 100,000-file folder before and after the fix.

Constraints: preserve all children, selection, focus, drag and cleanup checks.
Do not turn the 120-second local-drive scan goal into a timeout.

## Baseline

An Opus native investigation used exact `c590e06`, version 0.2.0 build 12,
on an Apple M1 Max, 10 cores, 32 GB, macOS 27.0.1 (26A434). Both binaries
used the qualification bundle ID. The warm-cache fixture had 100,000 files,
two directories and 409.6 MB allocated. No source edit or build ran during
the investigation. Sampling adds overhead; these are diagnosis measurements.

The fixture root has one direct child. The map's direct-child threshold took
the main-thread path, then its recursive layout fully sorted that child's
100,000 entries. Debug heartbeat maxima were 834.7, 1341.7 and 1183.2 ms.
Two usable Debug samples placed 699 of 1066 and 656 of 833 busy samples in
`refreshMap`. The Release heartbeat maximum was 195.7 ms.

Pressing End changed selection at once, then `ScrollViewProxy.scrollTo(id)`
searched the lazy row IDs and built row views along the way. Debug stayed in
that path for more than 38 seconds. Release took about 30.6–32 seconds.
RSS rose from 152–155 MB at ready to 1.47–2.28 GB after End.

The stack was `ScrollViewProxy.scrollTo` → `ForEachState.firstOffset` →
`AGSubgraphCreate2` / `browserRow`. Idle AX replies took 67–145 ms. Replies
during the blocked scroll failed after about 1.56 seconds. Accessibility
frames were about 1% of the samples. The earlier claim of slow idle AX was
wrong: that probe ran while the prior End lookup was still blocked.

## Proposed proof after the fix

Repeat three Debug and three Release runs with the same fixture and driver.
Check that End selects and reveals the last file, then Home, arrows and Page
Down still work. Require no row-ID walk in the stack, input busy time below
one second, AX reply below 200 ms, RSS below 300 MB after End and heartbeat
below 500 ms. Report every result, including failures. These limits qualify
this workload; they do not prove local-drive population p99 or a UI score.

## Native UI status

The preceding Opus run passed all 86 Debug tests and Release. It confirmed
the repaired browser keys, map keys, Review layering and narrow-window names.
It found an action result that wrongly included an unrelated Rescue hold,
Sparkle activity during XCTest, and the wide-folder stall above. Source fixes
for the first two are integrated; their native recheck is pending.

The latest native scores remain 7 for hierarchy, type, spacing, navigation,
map/list and window/state; 6 for color, scan feedback and cleanup; and 5 for
keyboard/accessibility. Color, feedback and accessibility have proof gaps.
No area has reached 9. VoiceOver, real contrast and motion settings, scan
cancel and several small-window review states still need native checks.

## Evidence and safety

The full private native report and raw samples remain on the Mac at
`/tmp/tessera-c590-qual/perf/REPORT.md`. No captures were taken in this profile.
Earlier UI captures contain real source labels and stay unpublished.

One driver revision posted Command-Q after a failed front-app check. The
recipient could not be proved. The two apps seen frontmost kept their original
process start times. The driver was fixed before the later runs; future input
must target the owned PID and stop if its front check fails. No global quit
shortcut is needed for cleanup: stop only the tracked process group.

The original checkout stayed clean at `a538b8d`. The production preference
file's hash, size and mtime stayed equal. Created qualification preferences
were backed up and removed. No owned process remained.
