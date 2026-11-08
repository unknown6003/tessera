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

The final tool and review delta, `5836a68..a0626c4`, received separate Standards,
Spec and Risk reads. Standards retained no finding. Risk retained no finding
after checking actual callers. A proposed empty-cache case required keeping a
tool sheet mounted while another sheet removed files; normal navigation destroys
the tool first, so that candidate was dismissed.

Spec found one reachable loading-state defect. Finder can replace a scan while
the search tool remains selected. The cancelled search left its loading flag
set. Commit `163c245` clears loading and invalidates results on a tree revision
change or disappearance. The primary agent checked the fix against the Finder
service, the retained tool sheet and the old task's token guard.

The new read lease prevents cleanup from mutating a tree while a worker reads
it. Cancellation requests stop the worker; the lease lasts until it returns.
A native regression holds a worker behind a bounded semaphore, requests removal
and cancellation, then checks that no file changed and the lease ended.

The review sheet now uses its snapshot as the presentation item. This replaces
the separate Boolean and optional payload after a real first-open action showed
an empty sheet. Native first-open and repeat-open checks remain required.

Native build, test, performance and screenshot evidence is recorded separately.
No release may be labelled qualified until the final source revision passes the
combined app checks. Keyboard and drag behavior need actual input proof; staged
capture states alone do not establish it.

## PR findings

The GitHub Codex review of `5836a68` found two valid defects. The primary agent
checked both against the current source and Apple's attribute definitions.
`298201d` replaces all-fork logical size with data-fork length in the bulk record.
It keeps allocated size across all forks. The data-fork field follows allocated
size in bitmap order. A native resource-fork fixture checks identity, preflight
and disposable removal. Rescan and current identity use the same size metric.

The second finding was stale capacity text after cleanup. The final measurement
now replaces the plan measurement before the result is saved. Existing capacity
labels, target math and confirmation text all read that refreshed plan. The
regression checks both the live plan and saved case against verification.after.
The pure capacity check also changes total and available capacity together.

The primary reviewed the small `fd1d84e` automation delta. It creates the capture
directory, reports aggregate coverage and dismisses a lingering Review sheet
before automatic termination. No deletion policy or production navigation
changed. Native execution remains required for the teardown behavior.
