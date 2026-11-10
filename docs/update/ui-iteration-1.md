# Tessera UI iteration 1

Base: `5726194`. Scope: `Tessera/Views/**`, `Tessera/TesseraApp.swift`,
`Tessera/Assets.xcassets/AccentColor.colorset/**` and this note.

Inputs: `/tmp/tessera-opus-visual-research/report.md` (items 1–9) and
`/tmp/tessera-opus-flow-research/flow-audit.md` (UI items).

Status: source changed, not compiled, not run. Linux has no Swift toolchain.
No area is rescored here. Every score stays as the review teams left it
until a native run proves the change.

## Changes

| Item | Change | Files |
|---|---|---|
| Visual 1, T3 | `AccentColor` set to `#1BE6FF`. Rescan is a flat button, not `.bordered`. | `AccentColor.colorset`, `ContentView.swift` |
| Visual 2 | Each top-level branch keeps one palette colour at every depth. Depth steps use fixed opaque sRGB mixes toward `Theme.bg` (0, 12, 22, 30, 36 %), precomputed once. Wedges under 1° use `aggregateColor`. Synthetic kinds keep their fixed neutrals. | `Theme.swift`, `SunburstChart.swift` |
| Visual 3, N2 | Largest items: up to 8 rows with an 8 pt dot in the wedge colour, a "Smaller items (n)" row with its total, and "Show all" (bounded to 200 rows). Built from `largestChildren(limit:)` on folder or revision change only. | `ContentView.swift` |
| Visual 4 | Header shows the scan name and status, not the path. Full path only in Details and the review sheet. Breadcrumb ancestors were already buttons; the home button now has a label. | `ContentView.swift` |
| Visual 5, T1 | Sizes use system type with `.monospacedDigit()`. Details size is `.title2` semibold. Map centre shows the total at 0.30 of the hub radius (minimum 15 pt) above the name. | `InspectorView.swift`, `SunburstChart.swift` |
| Visual 6, N3 | Details: full-width "Add to Cleanup List", then "Open on Map" and "Reveal in Finder". When added: checkmark and "In Cleanup List" in `mutedForeground`. The bottom bar shows only while Details is not inline, with name and size, no path. | `InspectorView.swift`, `ContentView.swift` |
| Visual 7 | "Review List…" is flat and disabled while the list is empty. It fills cyan only when the list has items. | `CollectorDock.swift` |
| Visual 8, W1 | Review sheet: 640 wide, list height follows content up to 300 pt, then scrolls. Count and total stay pinned in the footer. Rows show name, risk and owner tags, one middle-truncated path, size. Tool sheets are 500 pt tall. | `CollectorDock.swift`, `CleanupActionBar.swift` |
| Visual 9, C3, T2 | Confirmations now attach to the review sheet. Cancel keeps the sheet open with the same rows. Title: "Move N items (size) to Trash?". Body: two sentences. Risk mix and capacity goal show only when the review started in Rescue. Cancel has `.defaultAction` in both dialogs. | `CollectorDock.swift`, `ContentView.swift` |
| K1 | Map is focusable. Left/Right: siblings. Down: first child ring. Up: parent, or zoom out. Return: open folder. Escape: clear selection. VoiceOver gets one element per wedge in the two inner rings: "name, size, N% of parent", with select and Open actions. | `SunburstChart.swift` |
| N1 | Selection outline: 5 pt `bg` halo under a 2.5 pt white line, drawn after all fills. | `SunburstChart.swift` |
| N3 colour | Details badge no longer uses `hashValue` (random per launch). It uses a stable neutral. | `InspectorView.swift` |
| N4 | Toolbar "Search" button with ⌘F. Tools menu shows its text label. ⌘↓ opens, ⌘⌫ adds the selection. | `CleanupActionBar.swift`, `ContentView.swift` |
| A1 | Content and toolbar are disabled and hidden from VoiceOver while the Full Disk Access card shows. The card has the modal trait. Escape triggers "Not Now". | `ContentView.swift` |
| A2 | The hidden global Escape button is gone. Map and list use `onExitCommand`. | `ContentView.swift`, `SunburstChart.swift` |
| C4 | After a removal, the dock shows "Moved N items (size) to Trash. H held, F failed." from `vm.rescueVerification`. "Show Trash" only for Trash moves with at least one moved item. No Undo: Tessera has no safe restore API. | `CollectorDock.swift` |
| C5 | The dock shows `vm.collectorNotice` and posts it as a VoiceOver announcement. | `CollectorDock.swift` |
| W2 | When the sidebar source differs from the scan on screen, the subtitle says so and the button reads "Scan <source>". Chosen folders persist as local paths (max 12) in `DebugAutomation.defaults`. | `ContentView.swift`, `Sidebar.swift` |
| R1 | Rescue row: name, risk tag, size, one reason line. Path, sizes, owner, side effect and proof move into one "Details" disclosure. | `CleanupSuggestionsView.swift` |
| Settings | `Settings { AnalyticsSettingsView() }` scene. | `TesseraApp.swift` |

Preserved: `RemovalSnapshot` identity checks, `snapshotIsCurrent` before and
after the async hop, busy state, `beginTrashConfirmation` and
`cancelTrashConfirmation`, cached sources, the `Tessera.captureState` hook
(the "confirm" state now opens the review with its dialog shown).

## Dependencies on the primary

The patch does not compile alone. It needs:

1. `Tessera/Analytics/AnalyticsSettingsView.swift` with `AnalyticsSettingsView()`.
2. `ScanViewModel.collectorNotice: String?` (published). The UI only reads it.
3. Build setting `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor`
   in `project.yml`, or `NSAccentColorName` in `Info.plist`. Without it,
   AppKit focus rings and alert defaults keep the system accent.

Not used: `lastRemovalSummary`. `rescueVerification` already carries the
moved, held and failed paths and the removal method.

Analytics hooks (no integration exists at `5726194`, so none are compiled):
record a screen on `appMode` change in `ContentView` (`.explore`, `.rescue`),
on tool sheet open in `CleanupActionBar.presentedTool`, and on review sheet
open in `ContentView.openReview`. Send no names or paths.

## Not done

- C1, C2 and `zoomOut` restoring the child: view-model work, owned by the primary.
- Undo of a Trash move: no safe restore API.
- Space or ⌘Y Quick Look.
- Map single-click delay from the double-tap gesture.
- Percent column in the list (percent is in the VoiceOver label of map wedges).
- `List(selection:)` for sources and for the largest items list.
- Compact Details as an inline panel below 1100 pt (still a popover).
- Increase Contrast handling and measured contrast ratios.
- Legend rank can differ from wedge rank when two children have equal size:
  `largestChildren` keeps child order on ties, `sorted` does not promise it.

## Native acceptance checklist

Run on a Mac after the primary integrates. Record captures per item.

1. Build passes with Swift 6 and no new warnings in owned files.
2. System accent Pink, then Graphite: Explore, review and confirmation show no pink or grey focus ring or default button.
3. Sample capture: every child ring is in its parent's hue family. Pixel-sample each list dot against its wedge.
4. Outside the review sheet, a full path appears at most once per state.
5. Map centre total is the largest text in the window at 1240x800.
6. At most one filled cyan control per capture. Empty list: "Review List…" is not filled.
7. Review sheet with 1 item: at most one row of empty space. With 50 items: list scrolls, total stays visible. At 820x600 the footer buttons are not clipped. Same for each tool sheet.
8. Explore confirmation: two body sentences, no goal text. Rescue confirmation: goal text present. Return triggers Cancel. Cancel returns to the review with the same rows and total.
9. Keyboard only: Tab to the map, arrows move selection, Return opens, ⌘↑ goes up, ⌘⌫ adds, ⇧⌘L reviews, confirm, Trash. Focus visible at every step.
10. VoiceOver (Accessibility Inspector): map lists wedges with name, size and percent; legend rows; review rows; result bar; refusal notice is announced.
11. Escape in the search field clears only the field. Escape on the map clears the selection.
12. Full Disk Access card: Tab and VoiceOver stay inside it.
13. Select another source with a scan on screen: subtitle and button name both sources. Add a folder, relaunch, folder is still listed.
14. Successful Trash move and a partial failure: result bar counts match `rescueVerification`; "Show Trash" opens Trash; permanent delete shows no "Show Trash".
15. Reduce Motion on: no sweep or hover animation on the map or buttons.
16. Rescue: 10 rows fit in a 700 pt window height.
17. Wide folder (10,000+ children): no stall when opening it or toggling "Show all".
