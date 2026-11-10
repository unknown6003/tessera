# Tessera UI iteration 5

Outcome: give shallow folder maps the full chart area while keeping clicks and
drag targets aligned with the drawn rings. Remove the repeated Search Files
heading inside its sheet.

Proof: a radial selection regression for one through five rings, the existing
midpoint tests, native captures at narrow and wide sizes, and actual map input.

Constraints: keep the five-ring depth limit, folder angles, byte totals, colors,
selection identity and cleanup guards. Do not change the virtual folder browser
or scanner. Automated proof sends no production analytics.

## Measured starting point

The native retry used the retained `bd1b47c` app, whose UI source matches
`fab26f4`. Four widths showed a continuous flat toolbar, header and body with
no final header divider. Both cleanup confirmation cancels kept Review open.
The new disposable Trash file was restored with the same hash. End and Home
worked on 100,000 children. Several focus guards also passed.

The scorecard remained below nine in every area. Its ten scores were 8, 8, 7,
7 partial, 8 partial, 8, 7 partial, 8, 7 partial and 8 partial. VoiceOver speech,
contrast pixels, motion behavior, some source focus paths and prompt scan
cancellation were unproved. The test's wrong Cancel label and blocked input
are procedure failures, not evidence of product defects.

The shareable native capture shows a small map in a large empty region. Source
inspection explains it. Geometry always divides the radius into five rings,
even when the layout has two. With the 17% hub, two rings occupy only 50.2% of
the available radius. One ring occupies 33.6%. Five-ring maps already use the
whole radius.

Private Mac evidence: `/tmp/tessera-fab26-retry-1794213978/REPORT.md`.
Raw captures with source labels remain private. The shareable whole-window
capture hid Sources before capture and shows only the owned fixture.

## Change

Each map snapshot stores its rendered ring count once. Drawing and hit testing
use the same radial-span calculation with that count. The outermost rendered
ring now reaches the chart radius at every depth. Five-ring geometry stays the
same. Hover and drag use the same hit test as clicks.

The only caller of FileSearchView already supplies the sheet title. Removing
its repeated internal heading leaves the instruction and search field first.

The first native recheck still showed a large gap before the list at 1600 pt.
The chart width is bounded by its height beside the list. The pair centers together.
This removes unused horizontal chart margins from between the rings and list.
The stacked layout, browser width, row heights and focus-host branches stay the
same. A second native run checked this container adjustment separately.

## Qualification

Independent Standards and Spec reads found no issue in the three source files
or this note. Both used Codex `gpt-6.1-sol` after the preferred providers hit
their limits. These are separate source reads, not separate model-family proof.
Neither reran native tests or assigned a new UI score. No destructive operation,
privacy boundary or shared mutable state changed in this patch, so no additional
Risk pass was required for these hunks.

The native radius control ran one test and failed eight assertions. At one
through four rings, the old geometry left a short radius and missed the visible
rim target. Five rings stayed valid. Green passed all 94 tests and unsigned
Release. The three source hashes match the tested patch exactly.

Native captures at 820, 1100 and 1600 pt show the two-ring map reaching about
99% of the chart diameter after drawing insets. One- and five-ring views also
rendered. Rim clicks selected the matching file, double-click and Command-Up
navigated, arrows changed selection, and a rim drag staged the expected owned
file. Search Files showed one title. No deletion ran.

Spacing rose from 7 to 8 in that scoped design review. Map/list clarity,
hierarchy and readability stayed at 8. No area reached 9. The reference was the
preserved official DaisyDisk image, which proves only its pictured appearance.

The first test filter ran zero tests and was rejected. A bundle suffix could
overlap with existing CI, so the accepted run repeated under a new patch-hash
namespace. Ambiguous earlier domains were preserved. An input helper initially
misreported a partial key post; its later posts checked source PID as well as
owned window, executable, front app and idle state. These limits are recorded
in `/tmp/tessera-recheck-bootstrap-1794217635/REPORT.md` on the Mac.

Production preferences, the running production app, the original checkout and
all older fixtures were preserved. Accepted job preferences and DerivedData
were removed. The app and symbols remain private for the next check.

The later grouping run passed all 94 tests and unsigned Release. Its four
source hashes and full patch hash matched this workspace. On the same four-file
fixture, the visible map-to-list gap fell from 35 to 27 pt at 820 pt, from 139
to 28.5 pt at 1100 pt, and from 293 to 32.5 pt at 1600 pt. Disk diameter stayed
within one Retina pixel, or 0.5 pt, of the radius-only build. Parent inspection
of the neutral whole-window capture confirms the closer group and flat window.

Rim selection, folder double-click, Command-Up, list Up and Down, a staging
drag, narrow Details focus restore and the single Search title passed. Sources
visible at the narrow width has AX bounds proof only. Four synthetic rows do
not qualify crowded-folder behavior. The scoped design scores stayed at 8.

The grouping report records an initial unguarded read and a partial key post.
The helper reported that partial post, released only its owned key and used a
longer idle gap thereafter. Production preferences, PID 96976, the original
checkout and 9,464 prior fixture and evidence files were preserved. Only new
job preferences and DerivedData were removed.

Private Mac report: `/tmp/tessera-container-recheck-1794219073/REPORT.md`.
Report SHA256: `27331a552bab410944484a01b84eb17b8441bc4ecdb73f7cee185b615252ee54`.
Neutral 1100x700 WebP SHA256:
`0b40e59adaaa43603819f4e9e24f073295e54547189c601555b2a2d49f999690`.

## Final source review

One Sol round approved the full four-file behavior diff against `ea92ba4`.
Codex `gpt-6.1-sol` with high reasoning effort checked the callers, surrounding
code, this note, both native reports and the capture. Standards and Spec had
no findings. The reviewer verified all four source hashes but did not rerun
native tests. Usage was not exposed. The behavior diff stayed at 68 additions
and 20 deletions. No finding was fixed or declined in this round.

The signed external reports for `ea92ba4` cover the preceding commit, not this
patch. Both external lanes remain required on the final commit before publication.
