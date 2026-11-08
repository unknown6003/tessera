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
| 7 Settings | One switch, off by default: "Share anonymous usage data". A "What is sent" section with three rows. Opt-out effects in one sentence. A native segmented 1–5 rating, only when sharing is on and the survey flag is live. No replay claim. | `AnalyticsSettingsView.swift` |
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
