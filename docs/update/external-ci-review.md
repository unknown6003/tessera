# External CI source review

Target `333bb6b0b952ed9d3470ab1a6b03791aa4a8029e` against
`57f5597dccee3469abb4674dc4086e9e718f0af4`. All 22 changed files reviewed.
Three independent Codex contexts ran Standards, Spec and Risk after the
free OpenCode reviews failed at their usage limit. No paid plan was added.

## Standards

No retained documented breach or meaningful smell.

## Spec

One accepted finding. Fixture creation owned its temporary root only after
setup returned. A disk error during setup could leave its files behind.
Report persistence also ran before cleanup, so a full disk could skip it.

The fix assigns ownership before setup and runs cleanup in `finally`, even
when the report cannot be written. Two fault-injection regressions cover
partial setup and failed report writes. The Python suite passes 31 tests.

## Risk

No retained material finding. The first two report writers could race to
create `ci-reports`. One job would fail closed and rerun on the next tick.
Create that report branch before starting both hosts to avoid the first-run
delay. This is a liveness limit, not a way to admit an unqualified release.

## Open proof

Timers are not installed and no signed live campaign is claimed yet. Both
lanes must run the exact final source. The legacy publisher and stale
release instructions remain separate work. The flat-toolbar native proof
is recorded in `ui-iteration-4.md`; its final one-line divider removal
requires a fresh build and capture.

## First installation

Linux rejected a quoted `WorkingDirectory=` value. The installer now writes
that path without shell quotes, with systemd percent escaping. State paths
with line breaks are refused. `systemd-analyze --user verify` then passed
and the web timer became active. This is service readiness, not a passing
CI job. The signed live campaigns still remain to be run.
