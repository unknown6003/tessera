# Repeated timeout test isolation

Exact `c05278dd5b37188f61c05e9865dd19c444f247ee` failed the first real
external native CI job. The runner published a signed failure and stopped
before Release and performance qualification. The five test iterations had
one failure in `scanSkipsTimedOutDirectory`: gamma was zero bytes instead of
4096. Both healthy sibling files still existed on disk.

Private Mac evidence is in `/tmp/tessera-c052-ci/REPORT.md` and the follow-up
diagnosis report. No original checkout or user preference changed.

## Reproduction

The focused test failed gamma in 25 of 30 repeated runs in one process.
The full suite had two failed runs out of 465. Five fresh-process controls
all passed. Diagnostic traces showed gamma waiting for a helper permit,
expiring and entering the coverage-gap list. Parallel tests were not required.

The artificial slow reads retain their four global helper permits until
their 1.5-second sleeps end. The test's global 300 ms override routed every
local directory through those permits. Repeated runs exhausted them and put
healthy gamma on the same short deadline. This is test instrumentation
interference, not evidence that normal local scans use a 300 ms deadline.

## Fix

Read overrides are immutable members of one `DirectoryReadSession`, keyed
by exact path. Only the intended slow path enters the artificial deadline.
Healthy local siblings use the direct reader, even while abandoned helper
reads retain permits. The dataless test hook also belongs to its session.
There are no global delay, deadline or dataless overrides.

Finalization cancels the session so a late helper stops when its blocked
read or injected delay returns. Existing provider deadlines, helper bounds,
coverage gaps and cancellation checkpoints stay in force.

The original timeout and delay values are unchanged. The test now asserts
that the slow directory is the only gap. A new regression repeats that
whole scan twelve times in one process. It exercises the measured permit
exhaustion pattern rather than avoiding it through fresh processes.

## Qualification still required

The fix needs native compilation, the focused repeated control and all five
full-suite iterations. Then the external Release, rescan and 400-pipeline
campaign must run. No fixed-build pass or p99 result is claimed here.

The signing probe on an owned copy of `true` timed out after 15 seconds.
That does not establish whether the certificate is usable for the app.
No trust edit, private-key export or publication ran.
