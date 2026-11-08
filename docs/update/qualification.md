# Native qualification

Exact source `cbdeeb964f09b0e3827999d6498db7b76eb93e98` passes the native build,
test, scan-duration and responsiveness gates. This was an actual Release app
run on an Apple M1 Max with 32 GiB RAM, macOS 27.0.1, Xcode 27.2 and Swift 6.4.2.

## Actual root app result

| Measure | Result |
| --- | ---: |
| Enumeration finished | 51.512 s |
| Diagnosis finished | 56.219 s |
| Results published | 56.227 s |
| Final scan elapsed | 56.37 s |
| Final files | 4,478,551 |
| Final directories | 1,285,046 |
| Coverage gaps | 303 |
| Sampled peak RSS | 1,655,422,976 bytes |
| Longest main-actor heartbeat | 113.9 ms |
| Heartbeat intervals over 500 ms | 0 |

The app exited 0 with error=none and cancelled=false. Enumeration dominated
this run. Diagnosis and its surrounding checks took 4.707 seconds; publication
added 0.008 seconds. No profiler, stack sample, root screenshot or user cleanup
ran. Two Sources UI operations occurred during enumeration. RSS was sampled
about every five seconds, so this is not an exact kernel memory high-water mark.

Coverage is partial. The 303 gaps remain visible and held. Equal directory
counts do not prove full access. The result meets the two-minute goal on this
Mac for this run. It does not guarantee that every device, disk or provider can
finish a full scan in two minutes. Live contents, metadata cache and host load
changed between trials. Earlier 96.69, 134.52 and 140.13-second runs and a
profiled timeout stay in the [full history](benchmark-history.json).

## Tests and actual input

All 72 Debug tests in five suites passed. Unsigned Release built. The tests cover
wide folders across the old 8,192 boundary, tiny bulk batches, deep trees, full
Unicode names, fresh nested changes, identity checks, provider cancellation,
protection boundaries and removal. A resource-fork regression performs actual
permanent removal only in its disposable fixture. The read-lease regression
proves cleanup stays blocked until a cancelled background reader returns.

Actual Sidebar Refresh logged main=false, 0.001 seconds and six sources. The
native folder picker added an owned NativeScoped folder. It remained selected
after Refresh and Sources hide/show. Sources also hid and showed during the root
scan. The nine-file Sample disk kept the same names, sizes, times and hashes.

Earlier native input proved a real drag from the map into the Cleanup List,
three populated Review openings, correct results in four file tools, and both
Trash and permanent-delete confirmation Cancel paths. Seven finite layout
captures saved and autoquit. No final removal button was pressed in that UI pass.

The one-millisecond refresh finished before AX could observe its busy state.
Retention across completion passed; the exact in-flight state was not captured.
Concurrent custom additions and refresh saturation were not forced. Full keyboard
focus, Escape, rapid query cancellation and native Finder-driven source replacement
remain unproved through input. Guard-refused key events are not counted as passes
or as proved product failures.

## Controlled performance evidence

The full production classifier ran on one deterministic in-memory tree, with
three alternating warm processes per revision. Median CPU fell from 5.984602 to
0.528163 seconds, an 11.331-fold ratio. All six runs returned seven recommendations
with the same checksum across category, path, risk and logical and physical sizes.
This is classifier proof, not a whole-drive speed ratio. The [classifier report](native/7319f83.md)
describes the broad, protected, safe and Unicode branches.

An earlier alternating 124,581-file fixture trial reduced median peak RSS from
61,538,304 to 50,003,968 bytes, or 18.74 percent. Both revisions found 455
directories and no coverage gaps. Total-time ranges overlapped. A later live
identity audit checked all 125,036 fixture nodes with no mismatch.

## Actual window images

These are compositor pixels at `163c245`, including the native toolbar and sheets.
Sources were hidden through the actual toolbar. Only disposable fixture paths
appear. The later performance fixes retain this workspace design.

![Explore with Media selected and its details visible](screenshots/explore-details.webp)

![Review with the exact path and allocated size](screenshots/cleanup-review.webp)

![The native Move to Trash confirmation](screenshots/trash-confirmation.webp)

Each WebP is 1200 by 788 pixels, derived from a 2560 by 1680 compositor capture.
Originals and raw logs remain on the linked Mac. The [final native report](native/cbdeeb9.md)
records commands, input results, phase logs, signatures, cleanup and limits.
The unsigned executable SHA-256 was
`c076a63448a7af1cd0956185aa6cb174800c1db967df0862cc225d94f3c65562`.

## Review and release

Independent same-model Standards, Spec and Risk contexts reviewed every changed
path in `7fb8386..cbdeeb9`. None retained a finding. Both prior GitHub findings
have verified fixes and resolved threads. Native source files match the tested
commit. Final evidence-only descendants must retain those source bytes and pass
CI. Signing, signed launch smoke, Sparkle appcast and published asset checks run
through the tag-driven release route. This source report does not claim that a
release has been published.
