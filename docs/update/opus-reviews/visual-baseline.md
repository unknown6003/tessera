# Tessera visual reference review, 2026-11-08

Read-only design research at worktree `codex-tessera-2`, commit `5726194`.
No repo edits. Artifacts live in this folder only.

## Method

- Viewed all three Tessera captures in `docs/update/screenshots` (decoded to `current/*.png`).
- Read `Tessera/Views/Theme.swift`, chart, inspector, collector and content view sources by grep.
- Fetched official pages with `curl` under `timeout` (40 s, 30 s max-time). Raw HTML is in `html/`.
- Viewed every downloaded reference image before citing it.
- Rubric: the fixed ten areas in `docs/update/next-iteration.md`. "U" means unscored because the area was not seen or not tested.

## Reference artifacts

| File | Source URL | Kind |
|---|---|---|
| refs/daisydisk-shots-ss.jpg | https://daisydiskapp.com/img/shots/shots-ss.jpg | Official product screenshot, staged marketing state, 800x600 |
| refs/daisydisk-card.jpg | https://daisydiskapp.com/img/card-2026-10-27-06-21-44.jpg | Marketing card, not app UI. Not scored |
| refs/daisydisk-shots-back.jpg | https://daisydiskapp.com/img/shots/shots-back.jpg | Page background asset. Not scored |
| repo: docs/research/.../daisydisk-review.png, daisydisk-result.png | Saved 2026-09-01 from daisydiskapp.com | Older official screenshots |
| refs/raycast-file-search.png | https://www.raycast.com/_next/image?url=%2F_next%2Fstatic%2Fimmutable%2Fmedia%2Ffile-search.1h2o4dmp-4j8e.png&w=3840&q=90 | Marketing crop of real UI, decorative background |
| refs/raycast-focus.png | same path, `focus.1ii6df8wrisc6.png` | Marketing crop of real UI |
| refs/things-2-today-mac.png | https://static.culturedcode.com/things/videos/2017-05-18-website-videos/2-today-mac.png | Official Mac screenshot, 2017 asset, light theme |
| refs/things-7-quickfind-mac.png | same folder, `7-quickfind-mac.png` | Official Mac screenshot, Quick Find state |
| refs/things-4-headings-mac.png | same folder, `4-headings-mac.png` | Downloaded, not used for scores |
| refs/things-hero.jpg | https://culturedcode.com/things/2024-01-20/images/meettheallnewthings2-io75.jpg | Perspective marketing hero. Not scored |

Linear was attempted. The homepage HTML had no static product screenshot (only an icon), and the OG image is a generated title card. Linear is not scored.

All reference evidence is official marketing imagery. No reference flow was run or tested.

## Score table

| Area | Tessera | DaisyDisk | Raycast | Things |
|---|---|---|---|---|
| 1 Visual hierarchy | 6 | 9 | 9 | 9 |
| 2 Type and readability | 6 | 8 | 9 | 9 |
| 3 Spacing and density | 6 | 8 | 9 | 9 |
| 4 Color and contrast | 5 | 9 | 8 | 9 |
| 5 Navigation and discovery | 6 (partial) | 8 | 8 | 9 |
| 6 Map and list clarity | 7 | 9 | 9 (list only) | 9 (list only) |
| 7 First-run and scan feedback | U | 7 | U | U |
| 8 Cleanup safety and review flow | 7 | U | n/a | n/a |
| 9 Keyboard and accessibility | U | U | U | U |
| 10 Window adaptation and state | U | U | U | U |

No Tessera area reaches 9. Four areas cannot be scored from current evidence.

## Tessera deductions

1. **Visual hierarchy, 6.** The map is the hero, which is right. The same full `/tmp/...` path appears three times in one state: header, inspector and bottom status row. The map center label is small (about 11 pt name, 9 pt size) next to a 300 pt map. DaisyDisk puts the total in the largest type on screen. The cyan "Review list…" fill is the brightest object and competes with the map. Rescan wears a pink focus ring.
2. **Type and readability, 6.** The inspector size uses `.system(.title3, design: .monospaced)` (`InspectorView.swift:76`). Its child sizes use monospaced caption (`:121`). It reads as a code font, not a number. Most labels are caption size. The disabled "Added" and "Add to list" labels are hard to read.
3. **Spacing and density, 6.** The largest-items list stops after five rows and leaves the right half of the canvas empty. The review sheet is about 470 pt tall for one row, so most of it is empty. Inspector "Reveal" and "Add to list" sit at opposite edges. The Open/Reveal/Added row at the bottom is far from the selection it acts on.
4. **Color and contrast, 5.** No `AccentColor` asset exists in `Assets.xcassets`. `.tint(Theme.electricBlue)` covers SwiftUI controls, but the capture shows the system accent (pink) on the Rescan focus ring, the alert's default "Move to Trash" button and the Cancel focus ring. That breaks the single-cyan rule. Child wedges can change hue from their parent: the orange inner wedge sits under a cyan outer ring. `wedgeColor` picks hue per node and only lowers opacity with depth (`Theme.swift`), so deep rings turn muddy rather than lighter. Inner and outer rings use the same seven hues, so the map reads as a rainbow, not as a tree.
5. **Navigation and discovery, 6, partial.** Explore/Rescue segments are clear. Tools hide behind an unlabeled wrench menu. The breadcrumb shows only the root. No back or forward control is visible. Only one Explore state was seen.
6. **Map and list clarity, 7.** Largest items show name, right-aligned size and a chevron. Every row has the same cyan folder icon, so nothing links a row to its wedge. DaisyDisk's legend uses the wedge color as the row marker. No "smaller items" row explains the rest.
7. **First-run and scan feedback, U.** Only "Scan complete" was seen.
8. **Cleanup safety and review flow, 7.** Strengths: exact paths, per-item removal, stable allocated total, recoverable-Trash note, separate confirmation, permanent delete kept in "More". Deductions: the confirmation is a five-line paragraph. It mixes the Rescue goal ("under 75% used, 248.67 GB free") into an Explore action on a 52 MB folder. The default button uses system pink, not `Theme.danger` or cyan. The review row shows no owner or risk state.
9. **Keyboard and accessibility, U.** Source has ⌘R, ⌘., ⌘↑, Esc, ⌃⌘S, ⌃⌘I, ⇧⌘L and accessibility labels in 8 view files. No input, VoiceOver, Increase Contrast or Reduce Motion run was observed.
10. **Window adaptation and state, U.** One size seen. Source minimum is 820x600 (`ContentView.swift:81`).

## Reference deductions

**DaisyDisk** (`refs/daisydisk-shots-ss.jpg`, saved September shots).
Center total is the largest text. The legend matches wedge colors with dots. Child rings keep the parent hue and step lightness. Tiny items turn grey. Deductions: sizes like "4    GB" align units with odd gaps (type 8). The legend leaves the lower right empty (spacing 8). Three blue legend dots are hard to tell apart. The source list is a separate window in older shots (navigation 8). Scan feedback (7) comes from an old source-list shot with a thin bar and small grey text. Cleanup flow is unscored: the collector and red Delete are visible, the review step was not.

**Raycast** (`refs/raycast-file-search.png`, `refs/raycast-focus.png`).
One input at the top, a section label, a single selected-row fill, and a metadata table with hairlines. One primary action sits in a bottom bar. Labels are right-aligned to their fields. Deductions: the crops sit on decorative red and green art, so color is 8. Discovery is 8 because the crop shows a back arrow but no shortcut hints. Keyboard is the product's known strength, but no shortcut was visible, so it stays U.

**Things** (`refs/things-2-today-mac.png`, `refs/things-7-quickfind-mac.png`).
Large title, two-line rows (title plus muted project), one blue accent, red only for "today" deadlines. Quick Find ranks results with counts. These are 2017 assets, light theme, and the window chrome is from an old macOS. Keyboard and resizing were not tested.

## Implementation brief, in priority order

Keep the names Tessera, Explore, Rescue and Cleanup List. Keep cyan `#1BE6FF`, the mark and the sunburst. No framework change. No change to deletion identity, owner, protected-path or coverage checks.

1. **Own the accent.** Add an `AccentColor` color set at `#1BE6FF` so focus rings and alert defaults stop following the system accent. Give the Trash confirm a cyan default for the recoverable action and `Theme.danger` only for permanent delete. Acceptance: with System Settings accent set to Pink, then Graphite, captures of Explore, Review and the confirmation show no pink or grey accent.
2. **Make the map a tree.** Child wedges inherit the top-level hue. Step lightness by depth with fixed sRGB mixes toward `Theme.bg` (for example 0, 12, 22, 30 percent), not opacity. Draw items under about 1 degree as `Theme.aggregateColor`. Acceptance: in the sample capture every child ring sits in its parent's hue family. No orange-under-cyan pairs.
3. **Turn Largest items into the legend.** Replace the folder icon with an 8 pt dot in the wedge color. Show up to 8 rows and a muted "Smaller items" row with its total. Right-align sizes with `.monospacedDigit()` in the system font. Put the selected item's name and size at the top in `.title3` semibold. Acceptance: each list row's dot color matches its wedge in a pixel sample.
4. **Show each path once.** Header: name plus a clickable breadcrumb (Sample disk › Media). Full path only in the inspector (selectable, middle truncation) and the review sheet. Move Open and Reveal into the inspector and remove the bottom status row. Acceptance: outside the review sheet, a full path string appears at most once per state.
5. **Fix number type.** Use `.title2.weight(.semibold).monospacedDigit()` for sizes. Keep `.monospaced()` for paths only. Map center: total at about 0.28 of the hole radius, semibold, with the name in caption below. Acceptance: no size value renders in a monospaced face. The center total is the largest text in the window.
6. **Tighten the inspector.** Stack "Add to Cleanup List" (outlined, full width) above "Reveal in Finder" (plain). When added, show a checkmark and "In Cleanup List" in secondary text at 4.5:1 or better. Acceptance: no disabled label below 4.5:1 on `Theme.bg`.
7. **One cyan fill per view.** "Review list…" stays bordered while the list is empty and turns cyan only when it holds items. Rescan stays plain. Acceptance: each capture shows at most one filled cyan control.
8. **Size the review sheet to its content.** Rows: icon, name, middle-truncated path, owner or risk tag, right-aligned size. Height grows with rows up to the window height, then scrolls. Footer: count and total on one line, a one-line Trash note, Cancel and Move to Trash. Acceptance: a one-item sheet has no more than one row height of empty space. A 50-item sheet scrolls with the total pinned.
9. **Shorten the confirmation.** Title: "Move 1 item (16.8 MB) to Trash?". Body: "You can restore it from Trash. Space returns when you empty Trash." Show the capacity goal only when the action starts in Rescue. Keep Cancel as the initial focus. Acceptance: Explore confirmation has at most two body sentences and no goal text.
10. **Capture the unscored states before rescoring.** Required native evidence: first run with no source, scan in progress (phase, elapsed time, counts, current path, Cancel), Rescue, the 820x600 minimum and a wide window, keyboard-only Explore to Trash with focus visible at every step, VoiceOver labels on map, list and sheet, Increase Contrast and Reduce Motion. Without these, areas 7, 9 and 10 stay unscored and the 9 target cannot be met.

## Limitations

- Every reference score comes from official marketing images. No reference app was installed or tested. Marketing states are staged, so they favor the reference.
- The Things screenshots are 2017 assets in light theme. DaisyDisk source-list and review shots date from earlier site versions saved on 2026-09-01.
- Linear has no usable static product screenshot from its homepage HTML. It is not scored.
- Tessera evidence is three captures at one window size, from one sample disk. Their exact capture build is not stated next to the images. Pink accent attribution comes from the capture plus a missing `AccentColor` asset; it has not been reproduced with a known system accent.
- Scores are a single-agent design judgement, not a user study. They do not prove aesthetic acceptance.
- `DESIGN.md` describes a web stack (shadcn/Radix). The app is SwiftUI. The brief follows the shared tokens, not the web component rules.
