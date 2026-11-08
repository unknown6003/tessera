# Native qualification

The app uses SwiftUI, Swift and a small C bulk reader. Design research and source
reviews ran in parallel. Final integration and native checks ran in sequence.

## Measured behavior

The actual Release app at `5836a68` finished a root scan and cleanup classification
in 96.69 seconds on an M1 Max with 32 GiB RAM. It saw 4,469,000 files and 1,285,196
directories. Sampled peak RSS was 1,648,885,760 bytes. The measured main-actor
heartbeat was 120.8 ms. That run did not log its coverage-gap count. It does not
prove full access to the drive or a universal two-minute bound.

The prior Release run at `f80598c` finished in 132.56 seconds. The live filesystem,
metadata cache and host load changed between runs. This is duration evidence,
not an isolated percentage speedup. Profiling found repeated lowercase work in
the cleanup rule loop. The next revision computes the lowercase name once per
node.

An alternating warm fixture trial compared `301cb25` with `f80598c`. Both found
124,581 files and 455 directories, with no coverage gaps. Median peak RSS fell
from 61,538,304 to 50,003,968 bytes, or 18.74 percent. The total-time ranges
overlapped. See [the full measurement history](benchmark-history.json), including
failed runs and separate engine-only timings.

## Native tests and real input

`163c245` passed all 69 Debug tests and an unsigned Release build with Xcode 27.2
and Swift 6.4.2 on macOS 27.0.1. The suite covers wide and deep trees, long Unicode
names, fresh nested changes, identity checks, cancellation and removal safety.
The read-lease regression proves that cleanup stays blocked until a cancelled
background reader actually returns.

The native nine-file fixture has distinct known contents totalling 50 MiB.
Browse by Type, Big & Old Files, Search and Duplicates returned its expected
results. A real drag added Media from the chart to the Cleanup List. Review
opened with its full path and contents on three successive openings. Both native
confirmation dialogs opened and their Cancel buttons worked. No final removal
button was pressed in that UI pass. Hashes, sizes and modification times stayed
unchanged.

Command-Control-I opened Details once. Full keyboard focus, Escape dismissal,
rapid query cancellation and Finder-driven source replacement remain unproved
through native input. Frontmost-process guards refused some key events; changing
an AX text value did not update the SwiftUI query. These transport limits are not
counted as successful checks or as proved product failures.

## Actual window images

These images come from the owning macOS window at `163c245`, including its native
toolbar and sheets. Sources were hidden through the actual toolbar before
capture. Only disposable fixture paths appear. The UI source is unchanged by
the later resource-fork, measurement and automation fixes.

![Explore with a selected Media folder and its details](screenshots/explore-details.webp)

![Review with the exact path and allocated size](screenshots/cleanup-review.webp)

![The native Move to Trash confirmation](screenshots/trash-confirmation.webp)

Each WebP is 1200 by 788 pixels, derived from a 2560 by 1680 compositor capture.
The original images and raw native logs remain on the linked Mac under
`/tmp/tessera-native-verification.1GZiGk/at163c245`.

## Final gates

`163c245` saved all seven finite layout variants but did not autoquit within its
120-second deadline. `fd1d84e` creates the output folder and dismisses the Review
sheet before termination. That narrow fix passed at `298201d`. All seven images were saved and the app
exited 0 in 8.813 seconds. The final log reported `attachedSheet=false`.

The PR review then found two valid defects. `298201d` uses data-fork logical size
in both the bulk scan and removal identity. It also refreshes the Rescue plan
from the post-cleanup measurement, so capacity and target text use the same
sample as verification. The capacity checks passed. The resource-fork regression still failed because
Foundation fileAllocatedSize excluded the resource fork. The scan and lstat both
reported 20,480 allocated bytes; Foundation totalFileAllocatedSize also reported
20,480. Commit `0fcd162` uses that total in the live identity. Its native check
remains required.

Final CI, release signing, the signed launch smoke test, Sparkle signature and
published asset checks remain gates. No release is claimed by this document.

The root app run at `298201d` completed in 134.52 seconds and reported partial
coverage with 303 gaps. Sampled peak RSS was 1,650,032,640 bytes. Its longest
heartbeat interval was 4,093.7 ms. The app completed, but that run did not meet
the two-minute target or prove continuous UI response. Native profiling remains
a gate for that unresolved cost. The old 96.69-second result stays historical.

`0fcd162` passed all 70 native tests, including actual resource-fork removal,
the capacity checks and 125,036 live identity comparisons with no mismatch.
CI at `7fb8386` also passed 70 tests, 350 stress test executions, a Release build,
scanner/rescan checks and the web checks. Two optional review services skipped
their checks. Both retained PR findings are resolved.

The profiled `0fcd162` root run reached its 240-second deadline. It used 28 sample
sessions, so its time is not an unprofiled comparison. Late worker stacks show
Foundation substring search in rule matching and protected-descendant checks.
One main-thread sample shows synchronous source discovery. The final count,
coverage and heartbeat were not emitted before timeout. The [full report](native/0fcd162.md)
retains those limits.

`7319f83` adds ASCII literal matching while retaining Foundation behavior for
Unicode, empty strings and embedded NUL. Rule order and predicates stay the
same. A separate source read checked pointer lifetimes, Unicode fallback and
protected rule order. Two new regressions compare matching and protected-owner
boundaries. Native equivalence and duration checks remain required.
