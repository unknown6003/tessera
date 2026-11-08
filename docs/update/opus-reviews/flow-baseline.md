# Tessera flow and accessibility audit (read-only)

Commit 5726194, worktree codex-tessera-2. Opus flow team. Design review, not a user study.

## Evidence and limits

- Seen: three staged captures in docs/update/screenshots (explore-details, cleanup-review, trash-confirmation), all at 1200x788. Saved DaisyDisk captures daisydisk-review.png and daisydisk-result.png.
- Read: TesseraApp, ContentView, ScanViewModel (scan, cancel, zoom, collector, removal), Sidebar, CollectorDock (dock and review sheet), InspectorView, CleanupActionBar, CleanupSuggestionsView, SunburstChart, FileSearchView (part).
- Primary sources: DaisyDisk deletion guide (web.daisydiskapp.com/guide/4/en/DeletingFiles). Apple Mac keyboard shortcuts (support.apple.com/en-us/102650). The Apple HIG Searching page did not render through fetch, so I used no claims from it.
- Not proved: any native input, VoiceOver, focus order, reduced motion, resizing, scan progress, permissions, errors or success states. No capture exists for empty state, first scan, scan progress, Rescue, tools, compact width or errors. Those areas stay unscored. The source findings below are risks until native proof confirms them.

## Rubric scores

Scale 0-10, fixed rubric from docs/update/next-iteration.md. "—" means unscored because I saw no state. The source note gives the risk I found.

| Area | Tessera | DaisyDisk (docs + 2 captures) | Finder (docs only) |
|---|---|---|---|
| 1 Visual hierarchy | 6 | 8 | — |
| 2 Type and readability | 6 | 7 | — |
| 3 Spacing and density | 6 | 8 | — |
| 4 Color and contrast | 5 | 8 | — |
| 5 Navigation and discovery | 5 | 7 | — |
| 6 Map and list clarity | 5 | 8 | — |
| 7 First-run and scan feedback | — (source design is good, cancel is lossy) | 7 (inline per-source scan and Cancel seen) | — |
| 8 Cleanup safety and review | 5 | 6 | — |
| 9 Keyboard and accessibility | — (source risk high, cap 4 until fixed) | — (documents only ⌘⌫ to collect) | 9 for documented keyboard model |
| 10 Window adaptation and state | — (source risks) | — | — |

No Tessera area reaches 9. The reason is concrete defects in the reviewed states plus missing proof, not polish.

### Tessera deductions

1. Visual hierarchy 6. The map leads, which is good. The selected path shows three times: header subtitle, Details, and footer bar. Footer actions (Open, Reveal, Added) repeat the Details actions (Reveal, Add to list). The Largest items list sits in the top right with empty space under it.
2. Type 6. List rows use caption size. Sizes use `.monospacedDigit()` in the list but full monospaced design in Details (InspectorView.swift `.system(.title3, design: .monospaced)`). The trash alert body has seven sentences and no line breaks.
3. Spacing 6. Review sheet is fixed 700x620 (CollectorDock.swift:240). With one item, about 60% of it is empty. The map leaves a wide empty left band.
4. Color 5. The Details icon color comes from `node.name.hashValue` (InspectorView.swift iconCircleColor). Swift randomizes hashValue per launch, so it does not match the map. In the capture, Media is orange on the map and cyan in Details. The selection outline is the cyan accent (SunburstChart.swift:226), but the palette also has cyan wedges. In the capture I cannot see the selection on the map. The focus ring on Rescan and Cancel is pink, while the accent is cyan.
5. Navigation 5. Search, duplicates, apps, types and old files hide behind an icon-only wrench menu (CleanupActionBar). There is no ⌘F. Details starts hidden (`showInspector = false`). `zoomOut()` selects the parent, not the folder you came from, so the user loses their place.
6. Map and list 5. The list shows only 5 items (`largestChildren(limit: 5)`), with no share percentage and no color key that links rows to wedges. DaisyDisk shows a color dot per row plus free and hidden space. The map is one accessibility element with no children (SunburstChart.swift:169), so VoiceOver cannot reach a wedge.
8. Cleanup safety 5. Strong parts: exact paths, a stale-snapshot check before every action, Trash by default, and permanent delete in a separate confirmed menu. Faults:
   - Every fresh scan calls `stageSafeCleanup()` (ScanViewModel.swift ~245) and fills the Cleanup List with no user action. Rescue copy says "Add only what you want" and "Nothing is added automatically". No test covers this behavior.
   - The review sheet closes before the confirm dialog opens (`queueReviewAction` then `finishReview`). Cancel returns to the main window, not the list.
   - The confirm text adds the Rescue capacity goal in Explore ("Goal: under 75% used, 248.67 GB free" on a 52 MB folder) or "No capacity target is available."
   - After success, Explore shows no result. The moved, held and failed counts appear only in Rescue (verificationCard). There is no Undo and no link to Trash.
   - `addToCollector` silently refuses protected paths and descendants of listed items. The button gives no reason.
   - On partial failure only the first raw error appears in an alert.

### Source risks in unscored areas

7. Scan feedback. ScanningView shows phase, files, folders, mapped bytes, elapsed time, current path, and Cancel with ⌘. — that matches the design direction. But `startScan` clears `rootNode` at the start and Cancel leaves the empty state with only "Scan stopped". The previous result is in the cache but not shown. A rescan of the same source deletes its cache entry.
9. Keyboard and accessibility.
   - The map cannot take focus and has no arrow-key or VoiceOver navigation.
   - Missing standard keys: ⌘F search, Space or ⌘Y Quick Look, ⌘↓ open, ⌘⌫ add to list (DaisyDisk's documented key), ⌘Z.
   - Escape is bound by a hidden zero-size button for the whole window (ContentView.swift:701). It may take Escape from text fields and popovers.
   - The Full Disk Access overlay is a ZStack, not a sheet, and has no modal trait. Controls behind it may stay reachable by Tab and VoiceOver.
   - The dock's accessibility label is "Cleanup List drop target". Drag is a custom gesture with no keyboard equivalent on the map. The context menu and buttons exist.
   - The single-tap and double-tap gestures on the map make a single click wait for the double-click timeout.
   - Reduced motion is handled in the map, buttons and ContentView transactions. That is good, but unproved at runtime.
   - The app forces dark mode (`.preferredColorScheme(.dark)`). Increase Contrast and Reduce Transparency have no handling.
10. Window and state.
   - Minimum window is 820x600. The review sheet is 620 tall and tool sheets are 680 tall, so both are taller than the minimum window.
   - Picking a source in the sidebar keeps the old scan on screen. The header shows the old name, the sidebar marks the new source, and the button changes to "Scan source".
   - Chosen folders live in `@State` and do not persist between launches.
   - The sidebar is a set of buttons, not a List, so arrow keys do not move through sources the way Finder's sidebar does.
   - Below 1100 pt, Details moves into a 320x500 popover.

## Flow inventory

Severity: S1 blocks or risks data, S2 major friction, S3 polish.

| Flow | Trigger and screens | Friction | Evidence | Sev | Exact improvement |
|---|---|---|---|---|---|
| Empty and first scan | Launch, then sidebar default source, then empty state with "Scan X" | Two steps after Choose Folder. Folder list is lost on relaunch | ContentView emptyContent, Sidebar fileImporter, `customFolders` @State | S2 | Choose Folder starts the scan at once. Persist chosen folders in defaults (bookmark). |
| Permissions | FDA overlay on launch, then "Not Now"; root scan with empty tree sets needsFullDiskAccess | Overlay is not modal for keyboard and VoiceOver | ContentView FullDiskAccessOnboarding | S2 | Present as `.sheet`, or add `.accessibilityAddTraits(.isModal)` and block focus behind it. Keep "Choose a folder instead" as a second button. |
| Source refresh and picker | Sidebar rows, refresh icon, mount notifications | Selection and displayed scan disagree; no arrow keys; refresh has no visible busy state | Sidebar.swift sectionView, ContentView sourceHeader | S2 | Use `List(selection:)`. When the selected source is not the displayed scan, show a bar: "Showing <old>. Scan <new>" with the Scan button. Show a small spinner while refreshing. |
| Scan progress, cancel, finish | Scan, then ScanningView, then "Preparing results", then map | Cancel throws away the previous result | ScanViewModel startScan, cancelScan | S1 | Keep the previous tree until the new one publishes. On Cancel, restore it and show "Scan stopped. Showing results from <time>." |
| Map select, drill, back | Click, double-click, hub click, ⌘↑, breadcrumb | Selection hard to see; back loses place; click delay | SunburstChart 110-125, 226; ScanViewModel zoomOut | S2 | Selection: 2 pt white outline plus 1 pt dark inner stroke on every wedge color. zoomOut selects the previous child. Handle the double click through `NSEvent.clickCount` so a single click selects at once. |
| Largest list | Right column, 5 rows, chevron opens | Too short; no color link; arrows need focus | ContentView largestItems | S2 | Show all children of the current folder in a scrolling `List(selection:)` with a color dot that matches the wedge, size, and percent. Return or ⌘↓ opens, ⌘↑ goes up. |
| Details | Toolbar button, ⌃⌘I, hidden by default | Color mismatch; path repeated; label "Add to list" vs footer "Added" | InspectorView, ContentView selectedItemBar | S2 | Use the wedge color from the layout. Remove the footer bar or Details actions, keeping one set. Use one label set: "Add to Cleanup List" / "In Cleanup List" / "Remove". |
| Collector drag, review, remove | Drag to dock, context menu, buttons, ⇧⌘L, sheet with minus icons | Auto-staging; silent refusal; no remove in Explore | ScanViewModel stageSafeCleanup, addToCollector | S1 | Do not stage after a scan. Rescue offers "Add all safe" (already exists). When an add is refused, show the reason inline ("Protected system folder" / "Already covered by <parent>"). |
| Confirm cancel | Review, Move to Trash…, dialog, Cancel | Review sheet is gone after Cancel | ContentView queueReviewAction, finishReview | S2 | Present the confirm from inside the sheet. On Cancel, keep the sheet open with the same list. |
| Confirm success | Dialog, Move to Trash, progress in header and dock | No result in Explore; no Undo | ContentView performTrash, CollectorDock | S2 | After removal, show a result bar in the dock: "Moved 3 items, 16.8 MB, to Trash. 0 held, 0 failed." Buttons: "Show in Trash", "Undo" (Put Back via file manager for moved items). Keep it until dismissed. |
| Confirm text | Trash dialog | Off-topic goal sentence; dense | ContentView pendingTrashTargetSummary | S3 | Explore: "Move 1 item (16.8 MB) to Trash? You can put it back from Trash. Space is freed when you empty Trash." Add the goal line only when the user started from Rescue. |
| Rescue safe, review, protected | Rescue tab, groups, row toggles, Proof disclosures | Rows have 7 text lines; free-vs-used goal wording mixed | CleanupSuggestionsView recommendationRow, measurementCard | S2 | Row: name, size, one reason line, risk tag. Path, owner, side effect and proof go in a disclosure. Use one goal phrase: "Keep at least N% free." |
| File tools | Wrench menu, five 720x680 sheets | Hidden; no ⌘F; sheets taller than minimum window | CleanupActionBar | S2 | Add a toolbar search field bound to ⌘F that opens Search Files. Give the menu a text label "Tools". Make sheets `idealHeight` with `maxHeight` set to window height minus 80. |
| Responsive windows | 820 to wide, sidebar, inspector, popover | Sheets taller than window; compact Details is a popover | ContentView 47-120, CollectorDock 240 | S2 | Sheets use flexible height. Below 1100 pt, Details goes below the list as an inline panel instead of a popover. Run native captures at 820x600, 1100x700 and 1600x1000. |
| Keyboard, focus, VoiceOver | Hidden Esc button, list onMoveCommand | Map unreachable; global Escape | SunburstChart 169, ContentView 701 | S1 for accessibility | See spec K1-K6. |
| Errors and empty states | errorContent, "Review needed" alerts, empty review sheet | Raw first error only | ContentView performTrash | S3 | Show a per-item list of failures in the result bar with the reason category, not the raw error text. |

## Implementation spec

Each item needs native proof before its area can be rescored. Prove input with real keyboard and pointer events, VoiceOver with the Accessibility Inspector, and layout with captures at the three window sizes.

### S1 (do first)

- C1 No auto-staging. Remove `stageSafeCleanup()` from the scan publish path. Accept: after a fresh scan the dock says "Drop a map item here" and `collector.isEmpty`. A unit test fails if a scan stages anything.
- C2 Lossless cancel. Keep the displayed tree until the new tree publishes. Accept: start a rescan, cancel, and the old map, selection and Cleanup List come back with "Scan stopped. Showing results from <time>." A unit test covers cancel during enumeration and during diagnosis.
- K1 Map keyboard and VoiceOver. Make the map focusable. Left and right move between siblings; down opens; up goes to the parent; Return opens; ⌘⌫ adds to the list. Expose wedges with `accessibilityChildren` (or `accessibilityRepresentation` as a list) labeled "<name>, <size>, <percent> of <parent>". Accept: Tab reaches the map, arrow keys change selection in the capture, and the Accessibility Inspector lists wedges.

### S2

- C3 Confirm inside review. The confirm dialog attaches to the sheet. Accept: Cancel leaves the sheet open with identical rows and total.
- C4 Result bar. After removal, the dock shows moved, held and failed counts and bytes, with "Show in Trash" and "Undo". Accept: capture of the success state and a partial-failure state. Undo restores items and rescans the parents.
- C5 Refusal reasons. `addToCollector` returns a reason enum. The UI shows it inline for 4 s and announces it to VoiceOver. Accept: adding /System and a child of a listed folder both show the reason.
- N1 Selection and back. The selection outline is visible on every palette color (white outer stroke and dark inner stroke). zoomOut selects the child you left. Accept: captures on cyan, orange and green wedges, and a back step keeps the child selected.
- N2 Full list. The list shows all children of the current folder in a `List(selection:)`, with a color dot that matches the wedge, size and percent. Accept: 20+ rows scroll, and the dot colors match the wedges in a capture.
- N3 One action set and one color source. Remove the footer duplicate or the Details duplicate. Details uses the wedge color from the layout. Accept: one Reveal and one Add control on screen; Details color equals the wedge color across two launches.
- N4 Search and tools. Add a toolbar search field and ⌘F; label the tools menu. Add Space for Quick Look, ⌘↓ open and ⌘↑ up in the list, as Finder documents. Accept: each shortcut works from map focus and from list focus in a native input run.
- W1 Sheet sizes. Review and tool sheets fit the 820x600 window. Accept: captures at 820x600 show the footer buttons without clipping.
- W2 Source state. Use a List for sources. When the selected source differs from the displayed scan, show a bar naming both. Persist chosen folders. Accept: capture of the mismatch state, and folders survive a relaunch.
- A1 Modal onboarding. The FDA prompt blocks focus behind it. Accept: Tab and VoiceOver stay inside the prompt.
- A2 Escape. Remove the hidden global Escape button. Handle Escape on the map and list with `onExitCommand`. Accept: Escape in the search field clears only the field.
- R1 Rescue rows. Show name, size, reason and risk; move the rest into a disclosure. Use one goal phrase. Accept: 10 rows fit in a 700 pt window height at the default size.

### S3

- T1 Type. One numeric style (`.monospacedDigit()` on system text) across list, Details, dock and sheet. List body at `.callout` or larger.
- T2 Confirm copy. Use the short Explore wording above. Add the goal line only when the user came from Rescue.
- T3 Focus ring. Use the cyan accent or the system focus color, not pink.
- T4 Contrast. Measure tertiary and secondary text on #0A0B0D and #101216 and record the ratios. Body text needs 4.5:1. Add handling for Increase Contrast.

## Target scores

These are not promised scores. Each area can reach 9 only after the listed items ship and native proof shows no material fault:

- Areas 1-4 need N3, T1, T3, T4, N1 and W1.
- Area 5 needs N1, N4 and W2.
- Area 6 needs N1, N2 and K1.
- Area 7 needs C2 plus captures of the empty, scanning, cancelled, partial and error states.
- Area 8 needs C1, C3, C4 and C5.
- Area 9 needs K1, N4, A1 and A2 plus a VoiceOver run.
- Area 10 needs W1, W2 and three-size captures.

Without native runtime proof, the honest result after implementation stays at "source fixed, unscored".
