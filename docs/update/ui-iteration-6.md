# Tessera UI iteration 6

Outcome: show keyboard focus on every Tessera-styled button.

Proof: reproduce the missing Rescan ring with the actual Theme in a native
probe. Then test the shared Button-level binding in the app, including all
four styles, disabled controls and confirmation Cancel behavior.

Constraints: retain native Button activation and Tab order. Keep control
metrics, hover, press, labels, shortcuts and removal guards. Do not add a
second focus target or change the system accent. Automated runs send no
production analytics.

## Native diagnosis

The prior product capture has AX keyboard focus on Rescan but no visible ring.
A small AppKit and SwiftUI probe compiled the entire retained Theme with two
temporary log statements. Removing those statements reproduced the Theme
bytes exactly. Its only stub supplies FileNode fields for unrelated icon and
color helpers.

AX focus, a binding on the actual Button and Space activation agreed. The
style child's `isFocused` stayed false. Removing the native focus suppression
restored a purple system ring. Extra clearance did not restore the custom
ring. The cause is the focus observation in that ButtonStyle child, rather
than clipping or a false AX focus report.

The baseline control failed its visible-focus assertion. The candidate used
a Button-level FocusState binding and passed. Focused Rescan changed from
zero to 1,476 cyan pixels. The two-button probe kept two Tab stops through
two cycles and activated Rescan once with Space. This proves the native
candidate, not the integrated app or all 64 callers.

Private Mac evidence: `/tmp/tessera-focus-diag-1794221117/REPORT.md`.
The report records two bootstrap supervision violations. Later commands and
probe processes had tracked deadlines and cleanup. Production Tessera and
its preferences were preserved. No product file changed during diagnosis.

## Change

One modifier now applies the style, binds focus on the Button, suppresses the
native focus effect and draws the cyan outline. Each of the four existing
styles supplies its corner radius. The shared control metrics still set the
flat styles' size. Icon and plain styles keep their existing radius.

All 64 former caller pairs now use `tesseraButtonStyle`. Two pairs previously
set an inherited style on a row of buttons. Those now apply the modifier to
each of their five Buttons, giving 67 individual call sites. A caller cannot request a
Tessera style through that method while forgetting its focus indication.
The old child-environment overlays are removed. Map and source-row focus
remain separate, as do native text-field and system-dialog focus effects.

## Qualification still required

Source diff checking passes. The complete migration still needs native
compilation, the regular tests and Release. Actual product checks must show
one cyan ring at the keyboard-focused control, no ring at an inactive or
disabled control, unchanged Tab order and one Space activation.

Check flat Rescan, a prominent action, an icon and an interactive link. Check
the Review sheet and both confirmation Cancel paths with the same cleanup
snapshot guards. No user file needs to be removed for these checks.

Final source review and both exact-head external CI lanes remain required.
No new UI score or release qualification follows from the probe alone.

## Initial source review

Separate Standards, Spec and Risk reads each found the same two group callers.
The parent verified the changed receiving views were HStacks and moved the
modifier to each Button. Shared control size, font and foreground settings
remain on the rows. The reviewers retained no other finding. These were
separate Codex source reads, not independent model-family or native proof.

The native check must tab through the selected-item bar and Details actions,
showing a ring around each individual control. The performance diagnosis is
complete. Product UI and build validation run separately from that diagnosis.

## Performance evidence carried forward

Native CI for `7050f2a` passed all 94 tests, Release and all 400 complete trials.
The final heartbeat gate rejected two intervals, 899.018291 ms in mixed20k-074
and 608.9445 ms in wide100k-006. The parent authenticated that failed report.
Replaying the installed check against its retained inputs reproduces the exact
error. The baseline check passes separately, but the real failed path raises
before reaching it. No baseline or limit changed.

Two later instrumented headless campaigns retained all 800 trials with correct
counts and zero coverage gaps. Their maximum heartbeats were 129.488375 and
147.325458 ms. They did not reproduce the rejection. The largest observed
intervals overlap publication and substantial main-thread CPU. Timer-to-task
handoff added less than 1 ms in those intervals. No stack trigger fired.
These results do not identify the cause of the original two breaches and do
not qualify the source for release. No latency fix is claimed here.

Private evidence: `/tmp/tessera-test-diagnosis-53096/report.md` and
`/tmp/tessera-heartbeat-diag-61603/report.md` on the Mac. Temporary diagnostic
instrumentation was reverted. The second task checked the exact production
preference path and preserved its fresh baseline. The first task's 1,717-byte
preference claim was actually the LaunchAgent, so it is not production-state
evidence. The baseline and LaunchAgent remained unchanged in both tasks.

The focus candidate still needs its own exact-head native and web CI reports.
