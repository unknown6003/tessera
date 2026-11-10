# Native UI iteration 3

Outcome: qualify the UI, focus fixes and cleanup feedback without disturbing
the Mac's current user. Target `17d2a4d738ac2b8b9f037efec4af7c2128101ce3`,
tree `ca85b70c9debb6bfc8cb2c92166af4841f2b92cc`.

Proof: exact-source Debug tests, unsigned Release, private window captures,
guarded keyboard input, scoped AX actions and one warm wide-folder run.

Constraints: no production analytics, user cleanup, shared preference changes,
or global input to another app. Tests use a separate qualification identity.
Private captures contain real source labels and must stay on the Mac.

## Build gates

On the M1 Max, macOS 27.0.1 and Xcode 27.2, all 90 Debug tests passed and
unsigned Release built. The operation-scoped removal regression also proves
that an old duplicate-add notice is cleared. All 308 archived blobs match.
Source manifest SHA-256:
`8cc23623618cb119dbaa8811d5c12fbbddba166a8928dfdd159ea5014e5ae943`.

The Xcode 26.6 macOS app CI gate passed too. All six PR checks later completed
without a failing check. CodeRabbit skipped its review due to its star threshold.
Builds and tests do not prove the UI score.

## Native paths seen

One guarded HID window proved that toggling Details twice returns focus to the
browser, and that clicking Items does the same. Down then changed selection.
Other actions used AX, which is separate from real keyboard and mouse proof.

Passive pixel samples found seven unique branch hues, with all later branches
grey. All thirteen browser dots matched their wedges exactly. Ring inheritance
passed visual inspection; the Details badge was not sampled.

AX actions proved that a protected-item refusal is replaced by the next cleanup
result. Review showed the full owned path. Cancel kept Review and the file.
Confirm moved only the owned 1.5 MB file, with Show Trash and Dismiss visible.
The unrelated protected virtual disk stayed unchanged. A failed or held action
was not forced. The removed fixture file was restored and its manifest matched.

At widths 820, 1100, 1240 and 1600, no overlap was seen. The actual minimum
window height was 652 points. A result with Details took one bottom row of about
57 points. This does not prove the two-row Items case stays under 90 points.
The Details and browser headers shared a baseline at 1240 points.

One warm Release run on the same 100,000-file fixture completed in 0.72 seconds
with complete coverage. Longest heartbeat was 76.9 ms. RSS was 167,824 KB at
ready and 168,480 KB after selection. This is one regression sample, not p99.
End/Home timing was not repeated in this run.

## Fixed-rubric scores

These are one Opus design review's judgments, not a user study. Reference-image
hashes matched, but there was no fresh side-by-side reference review. Partial
means the named runtime evidence is incomplete. No area reaches nine.

| Area | Score | Main remaining deduction or evidence gap |
| --- | --- | --- |
| Visual hierarchy | 8 | Empty state has two Scan actions |
| Type and readability | 8 | Busy text contrast not sampled |
| Spacing and density | 7 | Rescue gap and repeated capacity label |
| Color and contrast | 7, partial | Real accent and Increase Contrast untested |
| Navigation and discovery | 7, partial | Breadcrumb and tools not exercised |
| Map and list clarity | 8 | Deeper ring and badge checks incomplete |
| First-run and scan feedback | Unscored | FDA and progress states not seen |
| Cleanup safety and review | 8 | AX only; failed and held outcomes not forced |
| Keyboard and accessibility | 6, partial | VoiceOver and remaining focus paths open |
| Window adaptation and state | 7, partial | Resize focus paths open |

## Limits and preservation

A person used the Mac during most of the run. The driver refused input unless
the owned PID was frontmost, the click belonged to its window, and the last
input was at least 0.8 seconds old. Wrong-target and active-user controls posted
zero events. No setting was changed and VoiceOver did not run.

The remaining paths need a quiet desktop: resize focus retention, map/sidebar
focus preservation, modal and other-window guards, keyboard review navigation,
real contrast/motion/accent settings with restore, and VoiceOver. FDA onboarding
was hidden because the test host inherited access. The quick fixture finished
before a scan-state capture. Error, tool and breadcrumb states remain open.

Production preferences retained the same hash, mtime and size. Owned new
qualification domains were removed. All nine preserved sample files matched.
The original Mac checkout remained clean at `a538b8d`; all owned PIDs exited.

Private Mac reports: `/tmp/tessera-17d2-qual/REPORT.md` and
`/tmp/tessera-17d2-ui/REPORT.md`. No private capture is copied into this repo.
