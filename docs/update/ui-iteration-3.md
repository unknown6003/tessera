# Tessera UI iteration 3: visual refinement

Base: `dfef72a` (child). Scope: `Tessera/Views/**` and this note. No change
to Engine, Model, ViewModel, Analytics, tests or config.

Input: an independent Opus visual review of private `c590e06` captures (11
faults). The full report is on the Mac and stays private; its captures show
real source names and are not published. This patch covers P1–P6, P8, P9,
P10 and P11. P7 follows in its own commit (see "P7: no repeated branch
hues" below).

Status: source changed, not compiled, not run. No rubric score. The fixed
rubric is unchanged.

## Changes

| Fault | Cause | Fix | Files |
|---|---|---|---|
| P1 Mauve focus ring (126,72,115; 2.87:1 on `bg`) on the sidebar Refresh button and the review sheet's Done | The `AccentColor` asset (`#1BE6FF`) and `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` already exist. macOS uses an app's accent only when the user's system accent is Multicolor; otherwise the system focus ring takes the user's accent. Refresh used Tessera's icon style with the system ring on. Both Done buttons used the default system style. | The four Tessera button styles draw their own 2 pt cyan focus ring from `EnvironmentValues.isFocused` (public, macOS 11). Every button that uses them turns the system effect off with `.focusEffectDisabled()` (public, macOS 14), all 60 call sites. Both Done buttons and the scan Cancel button now use the flat style. Text fields, pickers, the stepper and system alerts keep the system ring. No user default, global setting or private API. | `Theme.swift`, all `Views` files with these styles, `CollectorDock.swift`, `CleanupActionBar.swift`, `ContentView.swift` |
| P2 Sidebar capacity text 2.2:1; rows dimmed to 1.4:1 while scanning | `.tertiary` text on `surface`; `.disabled` on every source row during a scan | Capacity and header text use `Theme.mutedForeground` (6.71:1 on `surface`). During a scan or cleanup, source and add rows stop taking clicks (`allowsHitTesting(false)`) instead of `.disabled`, so text stays at full contrast. `selectSource`, the key handler and the add actions still refuse while busy. VoiceOver hints say the row is unavailable. | `Sidebar.swift` |
| P3 The scan root's name 3 times (header, breadcrumb, map centre) | Separate title row, breadcrumb row and hub label | One navigation row: home, ancestors in muted subheadline, the current folder in `title3` semibold with its size, one short status, and Rescan on the right. The scan root uses its source-list name ("iCloud Drive"). The map centre shows the size only. Every breadcrumb button and the compact ancestor menu stay. The status shows "Scanning", the source-mismatch notice, or the scan status. A 12 pt top inset aligns the column headers. Expected: content starts about 45 pt higher (old header plus breadcrumb about 102 pt, new about 56 pt). Native capture must confirm the 30 pt target. | `ContentView.swift`, `SunburstChart.swift` |
| P4 Three bottom rows (127 pt at 820) | Separate notice, result and selection bars above the dock | The refusal notice and the removal result now replace the hint line inside the Cleanup List row, with Show Trash and Dismiss in that row. The selection bar shows only while Details is not on screen, including the Items side of the narrow switch. Its hint shows only until the first selection in the window. At most two rows: selection bar and dock. | `CollectorDock.swift`, `ContentView.swift` |
| P5 "Macintos…" and "Check for u…" truncated | The capacity total repeated at the right of each disk row; the update row held version, separator and status | The repeated total is gone (the capacity line under the name keeps it). Names wrap to two lines with a tooltip. The update row shows "Version x" at rest, or one short state ("Checking…", "Update ready", "Update check failed"). The action name is in the tooltip, the VoiceOver hint and the app menu. | `Sidebar.swift` |
| P6 2 pt cyan border around the whole list and the selected source | Panel-level focus rings | No panel border. The focused row (the selection, or row 0 when nothing is selected) gets a stronger fill and a 1 pt cyan ring. The focused source gets a 1 pt ring. The map's system ring is replaced by a 1 pt cyan circle outside the rings. | `ContentView.swift`, `Sidebar.swift`, `SunburstChart.swift` |
| P8 "Details" and "In this folder" headers differ | `headline` vs `caption` | Both use caption semibold secondary with the header trait, on the same top inset. "Largest Items" is now "Largest items". | `InspectorView.swift`, `ContentView.swift` |
| P9 Large empty filled panels (152 pt list, 307 pt Details) | The list background filled the column; Details painted `bg` to full height | The list panel's height is `rows × pitch + 8` at most, so its fill ends with its rows. A spacer takes the rest. Details has no panel fill. | `ContentView.swift`, `InspectorView.swift` |
| P10 Capacity labels, header order, analytics claim | "available now" and "Free" did not say which macOS value they show; the saved case sat above the header; "Everything stays on this Mac" is false with always-on analytics | The headline shows `primaryBytes` as before. Its label is "Available for use" when `availableBytes` (macOS "available for important usage") exists, else "Free now". A note says macOS can reclaim caches and other purgeable files for "Available for use", and that "Free now" is the free space macOS reports. "Free now" shows as a second figure only when the headline is the larger value. A second note, shown always, says capacity figures cover the whole drive that holds the source, while logical and physical totals cover only the scanned source. (It needs no path test: `RescueMeasurement.volumePath` is the selected source path, not the mount point, so it always equals `RescuePlan.sourcePath`.) Measurements, goal and target maths are unchanged. Header first; the saved case is a compact banner under it; its path shows only when it differs from the header's. The available and target figures share `title2` semibold on one baseline. The line now reads "File analysis runs on this Mac." | `CleanupSuggestionsView.swift` |
| P11 "Preparing results" in the header and the body; raw counts | Both showed `scanStatus`; counts used `\(Int)` | The header says "Scanning"; the body shows the phase. Counts use `Int.formatted()` (locale grouping, 100,000). | `ContentView.swift` |

Measured on the sRGB values in `Theme.swift` (WCAG formula):

| Pair | Ratio |
|---|---|
| Muted text `#969BA4` on `surface` / `bg` / `elevated` | 6.71 / 7.05 / 6.30 |
| Old sidebar tertiary (75,77,80) on `surface` | 2.21 |
| Old mauve ring (126,72,115) on `bg` | 2.87 |
| Cyan focus ring on `bg` / `surface` | 12.95 / 12.33 |
| Foreground text on the focused-row fill (cyan 26 % over `surface`) | 9.06 |
| Muted text on the focused-row fill | 3.57, so selected rows use foreground for size and percent |
| Cyan 1 pt ring against the focused-row fill | 6.56 |

## Preserved

Breadcrumb navigation (home, every ancestor, the compact menu), the
source-mismatch notice, scan status, the `Tessera.captureState` hook, all
keyboard paths and focus visibility, drag from the map, Quick Look, the
windowed browser and its O(visible) bound, and every selection, source,
revision, identity, owner, protected, confirmation and busy gate. The
dock result still comes only from `lastRemovalSummary`.

## Limits

- System alerts and confirmation dialogs (AppKit) still use the user's
  system accent for their focus ring and default button. Tessera cannot
  restyle them with public API.
- `.focusEffectDisabled()` sits on each button. A new button with a Tessera
  style must add it too, or it shows the system ring.
- P7 is not fixed. VoiceOver, Increase Contrast and Reduce Motion are still
  unproved with the real system settings.
- Contrast ratios are computed from source colours, not sampled from
  captures.

## Native acceptance checklist

Use the same private fixture and window sizes as the review: 820x600,
1100x700, 1240x800. Keep captures private.

1. Swift 6 build, all tests and Release pass. No new warnings in owned files.
2. System accent set to a non-Multicolor colour (record which, restore
   after): Tab through the sidebar Refresh, Rescan, breadcrumb, review sheet
   Done and tool sheet Done. Each shows a cyan ring, none mauve. Text
   fields still show the system ring.
3. Sidebar idle and during a scan: sample the capacity text and a source
   name; both at least 4.5:1. Clicks on sources do nothing during the scan.
4. 1100x700 Explore: the root name appears once outside Details. Record the
   y of the first list row against the c590 capture (target 30 pt or more
   higher). The breadcrumb opens each ancestor; the compact menu appears in
   a narrow window.
5. 820x600 with a selection and a removal result: at most two bottom rows,
   total 90 pt or less. With Details on the Details side, no selection bar.
   After the first selection, clearing it hides the bar.
6. Sidebar at 210 pt: "Macintosh HD" in full or wrapped; the update row
   shows the version in full.
7. Focus the browser: no panel border; the focused row has the fill and a
   1 pt ring. Focus the map: a 1 pt circle, no system ring.
8. Details and "In this folder" headers: same style, same baseline (within
   1 pt) at 1240x800.
9. A folder with 3 children: the list panel ends after row 3 plus at most
   two row heights of space.
10. Rescue on a volume and on a folder: labels "Available for use" and "Free
    now" match `availableBytes` and `freeBytes`; both show the drive note
    ("Capacity figures cover the whole drive…"); the saved-case banner sits
    under the header; the path appears once.
11. Scan the wide fixture: the header says "Scanning", the body shows the
    phase, counts show grouping (100,000).
12. VoiceOver: breadcrumb buttons, the current folder header, the dock
    result and the update row read correctly.

## P7: no repeated branch hues

Base: `803f064`. Scope: `Theme.swift`, `SunburstChart.swift` and this note.
Status: source changed, not compiled, not run. No score.

Finding: the reviewer saw cyan and teal used twice in one folder (for
example Media, Many and Projects).

Source cause: `buildLayout` gave each top-ring wedge its rank as `palette`,
and `Theme.wedgeColor` read `palette % 7`. Rank 7 drew cyan again, rank 8
teal, and so on (`SunburstChart.swift` and `Theme.swift` at `803f064`).

Fix:

- Top ring: a branch gets its own hue only if its rank is below
  `Theme.branchPaletteCount` (7) and its share of the folder is at least
  `SunburstChart.branchHueMinimumShare` (3 %). Every other top-level branch
  gets `palette = nil`, the neutral grey.
- `Theme.wedgeColor` no longer wraps. An index outside the palette also
  returns grey, so no path can repeat a hue.
- Deeper rings inherit the branch's hue or grey unchanged, as before.
  Slivers under 1 degree stay grey.
- The browser dots and the Details badge already read the wedge palette
  through `MapSnapshot.color`, so they change with the map and need no
  edit.

Unchanged: wedge nodes, angles and geometry, the "Other" node and its
identity per snapshot, the top-60 selection and its "Other" sum, child order,
the full child list, synthetic-node colours, and the depth and Increase
Contrast colour tables.

Source check: a Python model of the rule (ranks in descending size, 0 to 80
children, 5,000 random cases) found no repeated hue, no hue past index 6,
and the hued branches were always the largest ranks. It models the rule,
not the Swift code.

Native colour checks:

1. Open a folder with more than 7 top-level items and one with items under
   3 %. Pixel-sample every top-ring wedge: each hue appears at most once;
   rank 8 and later, and branches under 3 %, are the grey `#3A3F47`
   (`#5A606A` with Increase Contrast on).
2. For one hued branch and one grey branch, sample a ring 2 and a ring 4
   wedge: each keeps its branch's hue family or grey.
3. In the browser and in Details, sample the dot and badge for a hued
   child, a grey child and an "Other" wedge: each matches its wedge.
4. Map order, angles and the "Other" size match a capture of the same
   folder from `803f064`. Only colours change.
5. `LayoutTests` and the full test suite pass.

## F5: browser focus after Details and layout changes

Base: `a19413a`. Scope: `ContentView.swift` and this note. Status: source
changed, not compiled, not run. No score.

Native finding (run `778`): after ⌃⌘I, accessibility focus landed on the
window's group, not the list. Keyboard-only use after the toggle was
unreliable.

Cause: the browser sits in different `if` branches depending on layout:
beside or under the map, inside the narrow Items / Details switch or not,
and hidden while the switch shows Details. A change of branch gives the
browser a new view identity, so SwiftUI drops its `@FocusState`, and
nothing set focus again.

Fix (public SwiftUI and AppKit only, no timers):

- `BrowserHost` names the browser's place: stacked, inside the switch,
  visible. `changeBrowserHost` wraps every action that can change it: the
  Details toggle (⌃⌘I and the toolbar button), the Items / Details switch,
  the sidebar toggle (⌃⌘S) and the window-width update. It reads
  `browserFocused` before the change, while the old browser still exists.
- If Details replaces a focused browser, that is remembered. Returning to
  Items, or hiding Details, sets a one-shot request.
- If the browser moves to a new container while visible (a resize across a
  breakpoint, the sidebar, the Details column) and it had focus, it sets the
  same request.
- If the place does not change, nothing is recorded, so an ordinary resize
  never moves focus.
- The browser's `onAppear` honours the request once, only when Tessera's
  main window is key (`NSApp.keyWindow`), with no attached sheet, no
  `NSPanel` (Quick Look) key, no `NSText` first responder (a text field
  editing), no review sheet, no Quick Look URL, no removal and no
  onboarding. The request is dropped when the browser gains focus by other
  means or the user leaves Explore.

Boundary: if focus was on a Details button and Details is hidden in a wide
window, the browser does not move, so no request is made and focus stays
where AppKit puts it. Tessera has no focus binding for Details' buttons, so
it cannot tell that case from focus on the map or the sidebar. The fix does
not guess there.

Native checks:

1. 1000x700: click a browser row, press ⌃⌘I (Details shows in the switch),
   then ⌃⌘I again. The browser has focus: ↓ moves the selection, and the
   Accessibility Inspector shows focus in the list.
2. Same, but switch with the Items / Details control instead of ⌃⌘I.
3. Browser focused at 1240x800, resize to 900 (the browser moves into the
   switch or below the map): focus stays in the browser.
4. Map focused (or a sidebar source) at 1240x800, resize to 900: focus does
   not jump to the browser.
5. Quick Look open, or the review sheet open, during a resize or ⌃⌘I: focus
   stays in the panel or sheet.
6. ⌃⌘S with the browser focused: the browser keeps focus.

## CI compile fix: split the ContentView body

Base: `2cb7d85`. Scope: `ContentView.swift` and this note.

CI failure at `e2a23dc` (Xcode 26.6, SDK 26.5, Swift 6):
`ContentView.swift:188:13: the compiler is unable to type-check this
expression in reasonable time`. Line 188 was the `quickLookKeyMonitor = nil`
assignment inside `body`'s `.onDisappear` closure. The cause is the length
of `body`'s single modifier chain, which the visual round made longer, not
that assignment.

Fix, with no change in behaviour and no type erasure:

- `body` is now five nested stage functions, each a short chain that
  type-checks on its own: `withWindowChrome` (frame, geometry, backgrounds,
  tint, toolbar, overlays, transaction), `withStateHandlers`,
  `withAnalyticsHandlers`, `withPresentation` (review sheet, error alert)
  and `withLifecycle` (appear, notifications, scan reset). They nest in the
  original modifier order, so every `onChange` keeps its place.
- The toolbar is a `@ToolbarContentBuilder` property.
- `uninstallQuickLookKeyMonitor()` replaces the `onDisappear` closure.
- `recordReviewScreen(_:)` and `handleCaptureState(_:)` replace two inline
  closures. The capture hook's guards and states are unchanged.
- The browser row's fill colour is a typed constant instead of a nested
  ternary inside `.background`.

Source check: a count of modifier calls before and after matches (the one
apparent difference is `.onDisappear { }` becoming
`.onDisappear(perform:)`). Brackets balance. No compiler limit was raised.

Native check: the CI build and the full test suite must pass with Xcode
26.6. If another expression times out, the log names its line.
