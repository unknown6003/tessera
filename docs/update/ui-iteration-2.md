# Tessera UI iteration 2

Base: `02c6a34`. Scope: `Tessera/Views/**`, `Tessera/TesseraApp.swift`,
`Tessera/Analytics/AnalyticsSettingsView.swift`, the `AccentColor` asset and
this note.

Status: source changed, not compiled, not run. Linux has no Swift toolchain.
No rubric area is rescored. Every score stays as the Opus baselines left it
until a native run proves the change.

Native evidence at the base (from the parent, not from this change): 83 native
tests and the Release build passed at `02c6a34`. 400 full-pipeline warm-cache
runs on a 7 GiB Mac runner passed with complete counts and coverage. Worst
wide 100k p99 was 7.103 s. Longest main-thread heartbeat was 818.6 ms. Its
cause was not profiled. This note does not claim a cause.

## Changes

| Item | Change | Files |
|---|---|---|
| 1 Sort | The map, the child browser and Details read one order: `FileNode.largestFirst` (size, then name bytes). `MapSnapshot.children` is `sortedChildren`; `buildLayout` already used it. Equal sizes now rank the same in every place. | `SunburstChart.swift`, `ContentView.swift` |
| 2 Child browser | "Largest items" (8 rows, "Show all" capped at 200) is gone. "In this folder" is a `List(selection:)` of every child: dot, name, percent, size. Arrows move. Return or double-click opens a folder. Space is Quick Look. Escape clears. A context menu has Open, Quick Look, Add, Reveal. Folders with more than 5,000 children build their snapshot off the main actor through `vm.readTree`; the result is dropped unless the folder and `treeRevision` still match. The header shows "Sorting…" until then. A read refused during a removal runs again when the removal ends. | `ContentView.swift` |
| 3 Colour | `MapSnapshot` is built once per folder and revision. It holds the wedges, the sorted children and an id index. `color(for:)` returns the wedge colour at any depth: a node deeper than the outer ring takes its drawn ancestor's colour; a node folded into "Other" or a sliver takes the aggregate neutral. The map, the browser dots and the Details badge all call it. The "Other" nodes are minted once per snapshot, so a selected "Other" keeps its identity through redraws and resizes. | `SunburstChart.swift`, `ContentView.swift`, `InspectorView.swift` |
| 4 Click | The count-2 tap gesture is gone. One tap handler reads `NSApp.currentEvent?.clickCount`: click 1 selects at once, click 2 opens a folder, click 3 does nothing. The drag gesture is unchanged. Quick Look uses SwiftUI `quickLookPreview` (QuickLook framework), from Space on the map or browser, ⌘Y, or the browser menu. Synthetic nodes are skipped. | `SunburstChart.swift`, `ContentView.swift` |
| 5 Compact Details | Below 1100 pt, Details is an inline 230 pt panel under the map and browser, not a popover. It is in the normal focus order. | `ContentView.swift` |
| 5 Contrast | Increase Contrast switches the ring table to depth mixes 0, 6, 12, 16, 20 % and lighter neutrals. Browser dots get a 1 pt light ring. Measured on `#0A0B0D` (sRGB, WCAG formula): muted text `#969BA4` is 7.05:1 on `bg` and 6.30:1 on `elevated`; danger text 5.92:1 or more. Default rings: weakest is violet at depth 4, 2.90:1. High contrast rings: weakest is 3.95:1. Aggregate neutral: 1.86:1 default, 3.11:1 high contrast. Hidden space 3.95:1 and cloud 4.09:1 in high contrast. The default neutrals stay below 3:1 by design (DaisyDisk-style grey). | `Theme.swift`, `SunburstChart.swift`, `InspectorView.swift`, `ContentView.swift` |
| 5 Motion | The sweep-in runs once per folder and is skipped under Reduce Motion. Window resizes never restart it. | `SunburstChart.swift` |
| 6 Result | The dock result uses `rescueVerification` only when its moved count, failed count and method match `lastRemovalSummary`. Otherwise it shows the summary counts alone, without bytes. Held items now show the warning icon. No Undo. | `CollectorDock.swift` |
| 7 Settings | Replaced in round 2 (see below). The round 1 opt-out switch no longer exists. | `AnalyticsSettingsView.swift` |
| 8 Analytics | `Analytics.screen`: `explore` or `rescue` on mode change, `review` when the review sheet opens, a fixed tool name when a tool sheet opens, back to the mode screen on close. Events: `cleanup review opened` (item count), `tool opened` (fixed tool name), `permission prompted` when the Full Disk Access card shows, `permission dismissed` on Not Now. `compactLegend` sets the stacked browser height to 4 or 8 rows. It changes nothing else. No names, paths, search text, raw errors, network events or frame callbacks. | `ContentView.swift`, `CleanupActionBar.swift` |

Preserved: `RemovalSnapshot` identity checks, `snapshotIsCurrent` before and
after the async hop, confirmation inside the review sheet, the busy locks on
sidebar, chart, browser and dock, `addToCollector` gates, and the
`Tessera.captureState` hook. `DebugAutomation` still calls the old
`SunburstChart(root:contentRevision:…)` initializer; an extension keeps it
and builds its own snapshot.

## Not done

- Sources as a `List(selection:)` with arrow keys. Not reached in this time
  budget. Sidebar focus order is unchanged.
- The map's own layout still builds on the main actor for folders up to
  5,000 children. Its cost on deep trees is not measured.
- A 100,000-row SwiftUI `List` builds its id list on the main actor. Its cost
  is not measured.
- Undo of a Trash move: no safe restore API.
- Parent-owned: no auto-staging after a scan, cancel restores the previous
  result, `zoomOut` restores the child context, `collectorNotice` wording.

## Native acceptance checklist

Run on a Mac. Record a capture or a log line per item.

1. Build passes with Swift 6. No new warnings in owned files. `LayoutTests`
   pass with `buildLayout` now `nonisolated`.
2. Two children of equal size: map wedge order, browser order and Details
   order match.
3. Wide folder (100,000 children): opening it shows "Sorting…", the window
   keeps responding, and the browser then lists every child. Rescan during
   the sort: no stale rows appear.
4. Pixel-sample a browser dot, its wedge and the Details badge for a top
   ring item, a ring 3 item, a ring 6 item and an "Other" wedge. All match.
5. Single click on a wedge selects with no delay. Double click on a folder
   opens it. Drag a wedge to the dock still adds it.
6. Space on the map and in the browser opens Quick Look; Space again closes
   it. ⌘Y works. Nothing opens for "Other" or Hidden Space.
7. At 1000x700, ⌃⌘I shows Details inline. Tab reaches its buttons.
8. Increase Contrast on: rings, neutrals and dots match the ratios above.
9. Reduce Motion on: no sweep, no hover scale.
10. Explore Trash move and a Rescue move: the result bar counts match the
    removal. Partial failure shows the warning icon and counts.
11. Settings: switch is off on a fresh profile. With no key it is disabled
    and says so. Rating shows only with the survey flag.
12. With a test key and the network gate logging, open Rescue, a tool, the
    review and the FDA card. Only the fixed screen and event names leave,
    with counts.
13. VoiceOver: browser rows read "name, size, percent of this folder,
    folder". Details reads in focus order.
14. Keyboard only: Tab to browser, arrows, Return opens, ⌘↑ goes up, ⌘⌫ adds,
    ⇧⌘L reviews.

## Round 2: native bug fixes

Base: `9f16d6d` (parent: always-on anonymous collection, `setEnabled`
removed). Native run of `c0f1872` passed 83 tests and Release. Real input
found three bugs. Contact sheet: remote `/tmp/tessera-qual-c0f1872` (not on
this machine; the fixes follow the parent's written evidence).

Status: source changed, not compiled, not run. No rubric area is scored.

| Native bug | Cause in source | Fix | Files |
|---|---|---|---|
| Arrows and Return do nothing in the child list; a clicked row has no keyboard focus | The browser was an AppKit-backed `List` with a computed selection binding and SwiftUI key handlers layered on it. The click did not give the table first responder. | The browser is now a `ScrollView` + `LazyVStack`. The container is `.focusable` with a `@FocusState`. A click sets focus and selects in the same call. `onKeyPress` handles ↑ ↓ Home End Page Up Page Down Return Space; Escape clears. A 2 pt cyan ring shows focus. The selection scrolls into view. A click on the map now also gives the map focus. | `ContentView.swift`, `SunburstChart.swift` |
| List rows draw on top of the Review sheet at 1100x700 | The `List` table view drew outside SwiftUI's layering. | No AppKit table remains in the browser. Rows are plain SwiftUI views. | `ContentView.swift` |
| 820 pt: names cut to "syn….bin" | A 207 pt column held dot, name, percent, size and chevron on one line. | Column is 230 to 320 pt. Below 290 pt, rows use two lines: the name wraps to two lines, size and percent go under it. Each row has the full name as a tooltip. | `ContentView.swift` |
| 1100 pt: Details shows "synt…ile.bin" | The Details name allowed two lines and child rows one line. | The Details name wraps to four lines and is selectable. Child rows wrap to two lines; their sizes keep a fixed width. | `InspectorView.swift` |
| 1000 pt: inline Details shrinks the map to about 140 pt | Round 1 put a 230 pt Details panel under the map. | Details is its own column only when the content width (window minus sidebar) is at least 980 pt. Otherwise the right column has an Items / Details switch, and the map keeps its size. ⌃⌘I opens the Details side of the switch. | `ContentView.swift` |

Also in round 2:

- Sources: the source list is one keyboard stop. ↑ ↓ move the selection
  across sections and show a cached scan at once, as a click does. Return
  scans a source that is not on screen; ⌘R still rescans the one on screen.
  A cyan ring marks the focused selection. The list scrolls to it. The
  existing busy gate blocks every key during a scan or removal.
- Settings: no switch. It shows "On for every normal run", or the exact
  reason nothing is sent (automated run, or no key). "What is sent" lists
  screens, scan fields, cleanup counts, tool names, crash addresses and the
  random ID, matching `ScanTelemetry.properties`, the cleanup events and
  `AnalyticsPolicy`. "Never sent" names the excluded data and says there is
  no screen recording or replay. The 1–5 rating stays optional, with no free
  text.
- Analytics order: every screen call goes through `Analytics.start()` first.
  `start` is idempotent, so the first Explore screen is kept even when the
  window appears before the app delegate starts analytics.

Preserved: `RemovalSnapshot` identity checks and `snapshotIsCurrent`,
confirmation inside the review sheet, `addToCollector` owner and protected
gates, source and revision gating on the off-main map build, busy locks,
and the `Tessera.captureState` hook (the "details" state now opens the
Details side of the switch in narrow windows).

## Rubric status

The user target is 9 or more in all ten areas, from native evidence. This
round has no native evidence, so every area stays unscored. Each area needs
at least the captures below from one build, scored against the fixed rubric
next to the Opus reference scores.

| Area | Native proof needed |
|---|---|
| 1 Visual hierarchy | Explore at 820x600, 1100x700, 1240x800, 1600x1000 |
| 2 Type and readability | Long-name fixture at 820 and 1100: browser and Details names readable |
| 3 Spacing and density | The same four sizes, with and without Details |
| 4 Color and contrast | Pixel samples: dot, wedge, Details badge; Increase Contrast captures |
| 5 Navigation and discovery | Keyboard run: sources, map, browser, breadcrumb, tools, ⌘F |
| 6 Map and list clarity | Wide folder (100,000 children): "Sorting…", then the full list |
| 7 First-run and scan feedback | Empty, scanning, cancelled, partial and error states |
| 8 Cleanup safety and review | Review at 1100x700 with no overlap; confirm, cancel, result bar |
| 9 Keyboard and accessibility | VoiceOver and keyboard-only Explore to Trash, focus visible each step |
| 10 Window adaptation and state | Live resize from 820 to 1600 with Details on; source switch states |

## Round 2 native acceptance checklist

Run on a Mac with the round 2 commit. Record a capture or log line each.

1. Swift 6 build and the 83 tests pass. No new warnings in owned files.
2. Click a browser row: the cyan ring appears. ↓ ↑ move one row, Page Down
   moves 10, End reaches the last row, Return opens a folder, Space opens
   Quick Look, Escape clears. Same after a click on the map, with arrows.
3. Double-click a browser folder opens it. A single click selects at once.
4. 1100x700, open Review: no browser row draws over the sheet. Repeat at
   820x600 and 1240x800.
5. 820x600 with the long-name fixture: browser names show in full or wrap
   to two lines; no name is cut to its first three letters.
6. 1100x700 and 1000x700 with Details on: the Items / Details switch shows,
   the map side matches the Details-off capture within 2 pt, and the
   Details name wraps.
7. 1240x800 with Details on: three columns; map at least 400 pt.
8. Sidebar: click a source, ↓ ↑ move across sections, a cached source shows
   at once, Return scans an unscanned one. Keys do nothing during a scan.
9. Wide folder: End in the browser reaches row 100,000 without a stall over
   one second. Record the heartbeat log.
10. Settings: a normal configured build shows "On for every normal run" and
    no switch. An `SO_` run shows "Not sending: automated run".
11. Network gate log on first launch: the first `$screen` is `explore`, sent
    after `tessera app opened`, with no names or paths.
12. VoiceOver: browser rows read "name, size, percent of this folder,
    folder" and offer Open and Quick Look. The source list reads "Sources".

## Round 4: removal result, source button, Quick Look

Base: `90f6626`, merged into the child with `--no-ff`. Scope:
`CollectorDock.swift`, `ContentView.swift`, `Sidebar.swift` and this note.
The round 3 accessibility override stays reverted (`959606c`). Increase
Contrast and Reduce Motion still need a native run with the real system
settings.

Native run of `c590e06`: 86 tests and Release passed, and the round 2
keyboard fixes worked with real input. The native report scored the areas
5 to 7. Its captures show private source names and stay unpublished. This
round has no native run and gives no score.

Status: source changed, not compiled, not run.

| Native finding | Cause | Fix | Files |
|---|---|---|---|
| F1: moving one item from Explore showed "1 held" when nothing was held | The dock borrowed `rescueVerification` when its counts matched. That record covers the whole Rescue plan, so its held list can include risk items the user never selected. | The dock reads only `lastRemovalSummary`, which the parent now scopes to the one action, with its own `id` and `movedBytes`. It never reads `rescueVerification`. Text: "Moved 1 item (16.8 MB allocated) to Trash." Held and failed counts appear only when this action held or failed something. The result shows whenever `lastRemovalSummary.id` is new, so a fast `isDeleting` change cannot hide it. Dismiss hides only that id. A source change hides the shown result. VoiceOver announces each new result. The Rescue workspace keeps its own full-plan verification. | `CollectorDock.swift` |
| The header button read "Scan com~apple~CloudDocs" | The button used the selected URL's last path component. | Fixed labels: "Scan" with no scan on screen, "Rescan" for the source on screen, "Scan Selected Source" when another source is selected. The source name moves to the title, the subtitle ("iCloud Drive is selected and not scanned yet."), the empty-state heading, the tooltip and the VoiceOver hint. Names come from the source list (`VolumeInfo.name`) through a binding from `Sidebar`. No new metadata read. | `ContentView.swift`, `Sidebar.swift` |
| A second ⌘Y did not close Quick Look | The Quick Look panel becomes the key window. The ⌘Y button lives in the main window, so it never saw the second press. Space and Escape work because the panel handles them. | A local `NSEvent` key monitor (public AppKit API) closes the preview on ⌘Y while one is open. It passes every other key through. It is removed when the window goes away. | `ContentView.swift` |

Not changed in this round:

- VoiceOver and Accessibility Inspector focus landing on the window or the
  header. Real VoiceOver is still untested, and the report names no cause.
  Changing focus order without a cause could break the keyboard path that
  now works.
- F2: the wide folder (100,000 children) shows 815 ms to `plan_ready`, 1.56
  s in accessibility calls and about 2 s for End. A separate native profile
  is measuring it. The browser, its `ForEach` and the map build are
  unchanged until that report names a cause.
- The breadcrumb and the map hub still show the scan root's on-disk name
  (for iCloud Drive, `com~apple~CloudDocs`). They name tree nodes, not
  sources.

Preserved: the selection, source, revision, identity, owner, protected and
confirmation gates, the busy locks, the dock's busy state, and the
always-on analytics in normal builds.

## Round 4 native acceptance checklist

1. Swift 6 build, 86 tests and Release pass. No new warnings in owned files.
2. Explore: add one item that has no Rescue risk and move it to Trash while
   the Rescue plan has unselected risk items. The dock reads "Moved 1 item
   (<size> allocated) to Trash." with no held count. The size matches the
   item's allocated size in Details before the move.
3. A removal that holds one item and fails one: the dock shows "1 held, 1
   failed." and the warning icon.
4. Two removals in a row: each one shows its own result. Dismiss, then a
   third removal: its result shows.
5. A very fast removal of one small file: the result still shows.
6. Switch source after a removal: the result hides. Rescue still shows its
   own verification card unchanged.
7. Select iCloud Drive with another scan on screen: the button reads "Scan
   Selected Source", the subtitle reads "iCloud Drive is selected and not
   scanned yet." No button shows `com~apple~CloudDocs`. Check the empty
   state, a chosen folder and an external volume as well.
8. Quick Look: ⌘Y opens, ⌘Y closes. Space and Escape still close. With no
   preview open, ⌘Y in the search field and in Settings does nothing new.
9. VoiceOver: a new removal result is announced once. The scan button's hint
   names the source.
10. Captures stay private; they show real source names.

### Round 4 follow-up (source review)

- Source names: `Sidebar` now observes the full `[URL: String]` lookup, not
  only the URL list, so a source renamed at the same URL updates the header,
  subtitle and hint. The lookup is built from the in-memory source list with
  `Dictionary(_:uniquingKeysWith:)`, so a repeated URL cannot trap. No file
  I/O.
- Quick Look monitor: Apple's declaration is
  `addLocalMonitorForEvents(matching:handler: @escaping (NSEvent) -> NSEvent?) -> Any?`
  (developer.apple.com, AppKit, NSEvent). The handler is not `@Sendable`,
  and AppKit calls it only for events sent through the app's own event loop.
  The state read and write now sit inside `MainActor.assumeIsolated`, which
  returns a `Bool`, and the handler returns the event or nil at once. The
  map's existing right-click monitor in `SunburstChart.swift` is outside
  this patch and unchanged.

Native checks added to the round 4 list:

11. Rename a mounted volume, or a chosen folder's source entry, while it is
    selected: the header and the button hint show the new name after the
    source list refreshes.
12. The Swift 6 build shows no isolation warning or error at the Quick Look
    monitor. ⌘Y opens and closes the preview as in check 8.

## Round 5: wide-folder causes from the native profile

Base: `8dc82f2`. Scope: `ContentView.swift`, `SunburstChart.swift` and this
note. Status: source changed, not compiled, not run. No score.

The native profile of `c590e06` measured two causes. The full report is
remote (`/tmp/tessera-c590-qual/perf/REPORT.md`). These fixes follow its
summary.

| Profile cause (c590) | Fix | Bound |
|---|---|---|
| 1. `refreshMap` checked only the folder's direct children. The fixture root has few children, so its map built on the main actor. `SunburstChart.buildLayout` then called `sortedChildren` in every folder it entered, including the 100,000-child folder one ring down (`SunburstChart.swift:691` at c590). Debug heartbeat 834 to 1342 ms, Release 196 ms. | `buildLayout` no longer sorts. `visibleChildren(of:parentSize:)` makes one pass over each folder's children: a child under the 0.4 % share goes to "Other"; a child at or above it is inserted into a list kept in `FileNode.largestFirst` order and capped at 60; whatever falls off the cap goes to "Other". `refreshMap` now asks `SunburstChart.layoutWork(of:exceeds:)`, which walks the same five rings of real folders and stops once it has counted 5,000 children. Above that, the map builds off the main actor through `vm.readTree`, with the same folder and revision gates as before. | Per folder: O(k) for k children, plus at most 60 comparisons for each child that passes the threshold. When sizes add up to the parent, at most 250 children pass. The check before a build costs O(5,000) at most. A main-actor build visits at most 5,000 children and sorts at most 5,000 direct children. |
| 2. The browser's `proxy.scrollTo(id)` made SwiftUI look up the row's offset by id in a 100,000-row `ForEach` (`ContentView.swift:430` and `:479` at c590). It created a subgraph per row up to the target. End blocked for over 38 s in Debug and 31 s in Release; memory grew from 160 MB to 1.5 to 2.3 GB. | The browser is now `WindowedRows`: every row has a fixed height (28 pt, or 58 pt for two-line rows). A spacer above and below holds the full height (count × pitch). Only rows in the visible rect plus 8 above and 8 below exist as views. Selection maps to an index through `MapSnapshot.childIndexOf` (a dictionary). Showing a row scrolls to `index × pitch` with `ScrollPosition.scrollTo(y:)`. `onScrollGeometryChange` reports the visible rect; the row window changes state only when it crosses a row boundary. | Views: O(visible rows + 16). Scroll to any row: O(1). No lookup by row id, no row created off screen, no paging. |

Correctness of cause 1: the old code sorted all children, kept those at or
above the threshold, and capped the list at 60. Because the threshold is on
size and `largestFirst` orders by size first, the kept children are a
prefix of the sorted order. The new pass keeps the first 60 of that prefix
in the same order. Every other child adds to "Other", so its sum is the same.
`largestFirst` is a strict order (size, then name bytes), so equal sizes
break the same way, and the palette rank, colours and "Other" identity per
snapshot do not change. A Python model of both algorithms matched in 3,000
random cases with many equal sizes and 0 to 2,000 children, including cases
where the parent size is less than the sum. That model is not the Swift
code. `LayoutTests` must still pass natively.

APIs, from Apple's documentation: `ScrollPosition`, `scrollTo(y:)`,
`scrollPosition(_:anchor:)`, `onScrollGeometryChange(for:of:action:)` and
`ScrollGeometry.visibleRect` are public and need macOS 15.0. The build
target is macOS 26.0. Apple notes that a point-based `ScrollPosition` does
not follow user scrolling, so the visible rect comes from
`onScrollGeometryChange`, not from the position binding.

Kept: two-line wrapped names in narrow columns (now at a fixed 58 pt, two
name lines plus the size line), click focus, all keys, double-click open,
the context menu, Quick Look, drag from the map, the selection, source,
revision, identity, owner, protected and confirmation gates. Every child
stays in the list; only rows off screen are not built.

Known limits:

- VoiceOver sees only the rows that exist (visible plus 16). The arrow,
  Home and End keys and VoiceOver scrolling reach every child. A
  VoiceOver run is still needed.
- Opening the 100,000-child folder itself still sorts its direct children
  once for the browser order. That runs off the main actor.
- `InspectorView` still runs `largestChildren(limit: 5)` on the main actor
  when the selection changes. It is one O(k) pass with no sort, outside this
  patch's files.
- A two-line row with a name that needs a third line shows two lines and a
  middle ellipsis; the full name is in the tooltip and in Details.

## Round 5 native checks (same workload, 3 Debug and 3 Release)

Before each run, check the driver: the build is from this commit, the
fixture is the same `fx-wide` tree with `Wide100k`, the cache state
matches the c590 profile, and `SO_` automation keeps analytics off.

1. Launch on the `fx-wide` root. Record the main-thread heartbeat and the
   time to `plan_ready`. No `sortedChildren` frames under `buildLayout` in
   the samples.
2. Open `Wide100k`. The header shows "Sorting…", then the full count. Record
   the heartbeat.
3. In the browser: click a row, press End. The last row is selected and
   visible. Record the time and resident memory before and after. Then Home,
   Page Down 20 times, ↑ and ↓.
4. Drag the scroll bar from top to bottom and back. No blank rows stay
   blank after the scroll stops. Record memory.
5. Resize from 1240 to 820 wide with the selection near row 50,000. Rows
   switch to two lines and the selection stays visible after one more key
   press.
6. The map: wedge order, colours and "Other" size match a c590 capture of
   the same folder.
7. Accessibility Inspector: the browser lists the visible rows, and AX
   calls stay under 200 ms while idle.
8. `LayoutTests` and the full test suite pass.

### Round 5 follow-up: keep the selection visible

Scope: `ContentView.swift` (`WindowedRows`) and this note. Not compiled.

Source review of `b689388` found that `WindowedRows` revealed the selected
row only when `selectedIndex` changed. A browser made after the selection
(for example Items, then Details, then Items) started at row 0. A pitch
change on resize recomputed the window but did not reveal the selection.

Now:

- On the first valid geometry of a new `WindowedRows`, the selection is
  revealed once. The flag sits in the non-rendering `Edges` box, so later
  geometry callbacks never scroll. A scroll therefore cannot trigger another.
- One `onChange` watches folder, selected index and pitch together, so one
  update makes one scroll:
  - New folder: offset 0, or the least offset from the top that shows the
    selection when the selection belongs to the new map.
  - Pitch change: recompute the row window, then reveal the selection.
  - Selection change: reveal it.
- Reveal scrolls the least distance, does nothing when the row is fully
  visible, and skips moves under 0.5 pt.

Bound: each reveal is O(1) arithmetic on `index × pitch`. Drawing stays
O(visible rows + 16).

Native checks added to round 5:

9. Select the last row of `Wide100k` with End. Switch to Details, then back
   to Items (narrow window): the last row is visible and selected.
10. With row 50,000 selected, resize from 1240 to 820 and back: the row stays
    visible after each resize with no key press.
11. Select a child, open it, then ⌘↑: the previous child is selected and
    visible in the parent's list.
12. Scroll by hand after a reveal: the list does not jump back to the
    selection.
