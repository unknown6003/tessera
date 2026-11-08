# Review record

Comparison base: saved release `f28bc079043dcfeb77e92fda4ac0958723bada39`.
The older restored main checkout stays intact.

## Standards

An independent source pass reviewed the combined change through `301cb25` against
the shared instructions and DESIGN.md. It found five primary buttons that used
the system filled style instead of Tessera's flat accent style. Commit `d3ec6b0`
fixed them. The primary agent checked the finding against the actual call sites.

The same pass noted repeated confirmation snapshot checks. This is a judgement
call, not a documented breach. The checks guard separate transitions from review
to confirmation and from confirmation to execution. They remain in place.

## Spec

A separate source pass found that permanent removal reused the Trash result text.
Commit `d3ec6b0` added the persisted removal method, matching result text and a
legacy decode check. The Risk pass independently found the same defect.

The language assessment was missing. It is now in language-decision.md. A rewrite
was conditional on a demonstrated gain. No cross-language benchmark was run.

The pass also found that combined native proof and major-release delivery were
unfinished. They remain release gates, not source-review passes.

## Risk

The first Risk pass covered filesystem actions, concurrency, coverage and the new
UI through `301cb25`. Its retained finding was the false Trash result above.

A fresh pass covered all 15 changed paths in `301cb25..2a9c99f`. It retained no
new defect. It checked compact identities, nil versus zero, maximum inode values,
ancestor replacement, cancellation, bulk fallback, saved result compatibility,
temporary-fixture capture guards and preference isolation. The primary agent
also checked these paths and the associated regressions.

The primary agent reviewed `2a9c99f..2edeace`. Largest-item rows now refresh on
root or selection identity and chart revision, instead of walking wide folders
on each hover update. An omitted inspector refresh hook was caught and fixed
before qualification. The remaining changes stamp version 1.0.0, build 11, and
correct stale comments. No deletion policy changed in this delta.

These were separate Codex contexts using the same model family. They can share
failure modes. Source review does not replace native execution or visual checks.

A focused completion audit at `3d68f81` found no source-proved fresh-scan deadlock.
It found that a cached-source switch cancelled the awaiting scan task but left
its detached diagnosis running. Commit `5438a72` cancels that task as well.
The generation guard already rejected its stale result. The fix stops its
cooperative classification loop sooner. Coverage and measurement still need
their native duration checked.

Native execution of `2a9c99f` found one stale assertion after the result wording
change. Commit `f80598c` updates it to the neutral "Removed" wording, disables
Sparkle during environment-driven automation, and selects an actual fixture
child for the details capture. The primary agent reviewed those small changes.

## Qualification

Native build, test, performance and screenshot evidence is recorded separately.
No release may be labelled qualified until the final source revision passes the
combined app checks. Keyboard and drag behavior need actual input proof; staged
capture states alone do not establish it.
