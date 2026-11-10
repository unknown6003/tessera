# Tessera UI iteration 4: one flat top plane, one scan action, compact density

Base: `acbbbaa` (child) — all of it cherry-picked into parent `17d2a4d`.
Scope: `Tessera/Views/ContentView.swift`,
`Tessera/Views/CleanupSuggestionsView.swift` and this note. No change to
Engine, Model, ViewModel, Analytics, tests or config.

Input: the user report "Fix UI issue with liquid glass usage in some areas
but not others… weird separation between topbar and rest", plus three small
pending items (duplicate Scan CTA, Rescue label repeat and gap, the
`tessera-compact-legend` draft flag that could not reach a real window).

Status: integrated through `04b3cf0`. All 90 native tests and unsigned
Release pass on Xcode 27.2. Native captures confirm the flat toolbar. No new
rubric score. See the proof and remaining limits below.

## Native proof at 04b3cf0

Private Mac report: `/tmp/tessera-04b3-ui/REPORT.md`. The Codex check ran
from 23:25 to 23:35 UTC on 8 November 2026. Input stopped at 23:32 UTC.
The Release binary SHA-256 is
`f38499bcf2762427c74c272ca3e2e7cfbde4ea72c0aeb4ef5fad2397ddeb827f`.

At 820, 1100 and 1240 pt, the toolbar, source header and body all sample as
`#0A0B0D` after conversion to sRGB. Both broad glass toolbar capsules are
gone. The native toolbar drag moves the window. Map dragging leaves the
window in place. Keyboard list navigation, folder opening, returning up,
Details, Review and confirmation Cancel passed. Cancel kept Review open.

One explicit one-point divider remained below the source header. The
follow-up removes that `Divider()` to finish the requested continuous
window. This one-line change still needs a fresh native build and capture.

The empty state exposes one Scan button. Starting an owned fixture from
that state with Command-R remains unproved because the test helper could
not enter its path in the native folder picker. No user drive was scanned.
Sources hide/show geometry, the compact flag, all sheet appearances and
the full accessibility checklist also remain open.

The separate `SO_CI=1` benchmark produced output, exited 0 in about 0.4 s
and never activated in the public NSWorkspace watcher. This proves the
background lifecycle path, not performance qualification. Production
preferences, 44 fixture files and the original checkout stayed unchanged.
All owned processes stopped. Captures stay private because of sidebar labels.

GitHub Actions CI was removed at the user's request. The new external Mac
lane uses installed Xcode 27.2. No new Xcode 26.6 result is claimed.

## 1. One flat top plane (primary)

Fault: macOS 26 draws a window toolbar with Liquid Glass by default. The
content, sidebar, header and sheet surfaces were already opaque flat token
fills (`Theme`, `GlassSurfaces`), so the floating frosted bar sat against
solid panels and read as a separate stunted plane.

Cause: nothing told the toolbar to do otherwise. `.windowStyle(.titleBar)`
with `.windowToolbarStyle(.unified)` kept the bar, and its background and
shared item glass stayed automatic.

Fix, public APIs only (`Tessera/Views/ContentView.swift`):

- `.toolbarBackground(Theme.bg, for: .windowToolbar)` — the bar paints the
  same `#0A0B0D` as the window, header and content (macOS 13+).
- `.toolbarBackgroundVisibility(.visible, for: .windowToolbar)` — the
  background always shows instead of following scroll edges (macOS 15+).
- `.sharedBackgroundVisibility(.hidden)` on each of the four
  `ToolbarItem`s — no glass pill behind Sources, the mode picker, the tools
  and Details (macOS 26.0+, the deployment target).

Unchanged, on purpose:

- `.windowToolbarStyle(.unified)`, `window.titlebarAppearsTransparent`,
  `isMovableByWindowBackground = false`, `isMovable = true`. The bar stays
  the native drag region and the traffic lights and its keyboard commands
  are untouched, so map wedge dragging never fights window dragging.
- Content, sidebar, source header, custom tool sheets and the review sheet
  keep their existing token surfaces; no text, colour or name changed.

Risk: `toolbarBackground` sets a preferred style that the container may
refuse in principle; the member docs name no macOS window-toolbar refusal.
Native capture must confirm the bar renders `#0A0B0D` with no frosted edge
or item pills. If it did refuse, the documented fallback is Apple's own
route: `.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)` plus a
window drag gesture (see "Customizing window styles and state-restoration
behavior in macOS"), which trades a working drag region for glass removal.

## 2. One visible scan action

Fault: the first-scan state showed two Scan buttons, the header row and the
empty state card. Error and Full Disk Access states kept the header Scan
alive next to "Try again" or "Open System Settings".

Fix (`ContentView.swift`): a new `showsHeaderScanButton` gate. The header
button shows only when a result is on screen (Rescan, including the
source-mismatch case's "Scan Selected Source") or when no source is chosen
(the disabled placeholder). It hides with an error, Full Disk Access, or an
empty state with a selected source, because those views own their body
action. The empty state's filled CTA now carries ⌘R itself, so ⌘R still
starts the scan in the state where the header button is hidden. After a
scan, the header Rescan with ⌘R is unchanged.

## 3. Rescue: no repeated label, tighter card

- The caption under the capacity bar repeated "Available for use" from the
  headline above it. The caption now shows only "Goal: under N% used",
  right-aligned as before. `ProgressView`'s accessibility label still names
  the figure. Capacity maths and both explanatory notes (purgeable wording,
  whole-drive versus scanned source) are unchanged.
- The measurement card's vertical side padding drops from 20 to 14 pt, so
  the gap around the card's bottom divider shrinks on both sides. Everything
  between the dividers keeps its `spacing 14`.

## 4. `tessera-compact-legend`: reachable, presentation-only density

Fault: the flag only changed `stackedBrowserHeight`, which needs a browser
column under 580 pt. That is unreachable: the 820 pt minimum minus the 211
pt sidebar leaves 609 pt. On and off, the flag changed nothing a user could
see.

Fix (`ContentView.swift`): with the flag on, single-line browser rows use a
compact 24 pt pitch instead of 28 pt, in every reachable window size.
Without the flag, nothing moves: 28 pt single-line, 58 pt two-line rows.
Two-line rows never use the compact pitch, so wrapped names keep one callout
line plus one caption line inside the same 58 pt. 24 pt holds one callout
line with the existing paddings, so no text clips or changes size.

Preserved: every child, order, colour and identity; the `WindowedRows`
windowing which is O(visible) in rows and O(1) in scroll offsets (the pitch
is already part of its reveal key, so a change re-windows correctly); the
selected row's reveal and keyboard paths; scanning, coverage and cleanup
protection. Only row height changes.

### Variant description for the flag server

`Analytics.swift` and `AnalyticsPolicy.swift` are unmodified, so the flag
server config supplies this:

- Key: `tessera-compact-legend`.
- Off, or any variant other than `compact`: default density. Single-line
  browser rows 28 pt, two-line rows 58 pt, stacked browser height 8 rows.
- Enabled with variant `compact`: compact density. Single-line browser rows
  24 pt; two-line rows stay 58 pt; the (unreachable) stacked branch sizes
  for 4 rows at the compact pitch. Layout, order, colours, selection and
  identity do not change with the variant.

## Preserved

Every busy, identity, owner, protected, coverage and revision guard; the
real modal Cancel returning to Review; the weak own-window refocus guard
and the Quick Look ⌘Y monitor; all keyboard paths including the new ⌘R
label; drag from the map; native window drag; the windowed browser bound;
the dock result from `lastRemovalSummary`; all analytics events and the
flag-sniffing allow-list (the view only reads `compactLegend`, which it
already did).

## Limits

- Sheets keep the macOS 26 sheet presentation; they already carry
  `.background(Theme.bg)`. No change was needed there.
- Linux source checks do not prove a native window. The proof above uses
  an unsigned qualification build, not the final signed release.
- If the compile splits over the added modifiers, the log line will name
  the spot; the stages already exist to absorb one more modifier.

## Native acceptance checklist

1. Swift 6 Debug build with all 90 tests, then unsigned Release, on the
   external Mac lane's Xcode 27.2. No new warnings in owned files.
2. Capture the real window including the title bar (macOS 27 box): the
   toolbar region samples `#0A0B0D` end to end with no frosted edge, no
   glass pill behind any item, and no seam against the source header or the
   sidebar column.
3. Traffic lights, title-bar window drag, and keyboard paths (⌃⌘S, ⌃⌘I,
   ⌘F, ⌘R, ⌘Y) still work. The map still drags wedges without moving the
   window.
4. First-scan state with a selected source: exactly one Scan button (the
   filled body CTA); ⌘R starts the scan from it. With no source chosen: the
   empty card only, plus the disabled header placeholder. Error and Full
   Disk Access states show one action each, no header scan button. With a
   result on screen or a mismatched source: the header Rescan / Scan
   Selected Source is the only scan button.
5. Rescue on a volume: "Available for use" appears once, not under the
   bar; the goal caption stays right-aligned; the two capacity notes are
   byte-identical to before; card spacing reads tighter without clipping.
6. Compact flag per the variant description above, captured in the same
   window: rows at 24 pt, order, colours, dot identity, scroll offsets and
   selection reveal correct; with the flag off, pixel-identical to a
   capture of `acbbbaa` at the same sizes.
7. The full test suite, including the windowed browser and rescue maths
   tests, passes unchanged.
