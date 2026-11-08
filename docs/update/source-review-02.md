# Nonvisual source review

Three independent Codex contexts reviewed `87f00b9..035c059`. The scope was
analytics, scan state, release policy and qualification code. Opus owns the
separate UI design and score reviews.

## Standards

One retained finding. The p99 report lacked hardware and cache-state context
required by AGENTS.md. The report now requires hardware, OS, memory, workload
and cache-state metadata. CI writes it beside raw samples. Trial IDs must match
the requested campaign exactly. A missing cohort cannot pass silently.

## Spec

Three retained findings. Two duplicate the metadata issue above and the host
issue below. The third was unused update-outcome analytics. Updater status and
post-install detection now emit fixed outcomes without Sparkle error text.

## Risk

Three retained findings:

- SDK custom request headers cover ingestion only, but remote configuration
  uses a separate assets host. The consent generation is now a session header
  too. A native regression checks all four EU/US host paths without network
  traffic. Actual SDK traffic still needs a dedicated Tessera project.
- The native crash handler outlives SDK shutdown. It can leave a crash report
  from an opted-out interval. A new consent period now purges that exact native
  report before SDK setup. A purge failure blocks setup. Normal enabled launches
  keep reports from the same consent period. An owned-file regression checks the
  exact cache path and preservation of another app's report. Real crash lifecycle
  qualification remains open.
- A bounded command could exit successfully while leaving children running.
  Its owned process group is now stopped on every exit path. A child that tries
  to write after its leader exits is stopped in the regression. The deadline
  path is also checked.

All findings were checked against the pinned SDK source or reproduced locally.
Ten Python checks pass. New native regressions still require CI. This review
does not qualify the UI, live analytics, local-drive population p99 or a release.

A follow-up source pass at `703e023` found a missing shell continuation in
the CI tool-test step. It is fixed. The exact CI step now runs successfully
under Bash, including all ten Python tests. The pass retained no other failure
in that pinned scope.

The next source revision also removes the analytics-only filesystem probe
before scanning. Source telemetry now reads the cached kernel mount table with
`MNT_NOWAIT`. It reports verified local drives as `local_unknown`, since cached
mount flags do not prove whether the hardware is internal. It does not add a
network metadata request or a detached worker to the scan path. The scanner
still performs its own required filesystem reads.

New consent also requires successful deletion of this project's SDK storage
before setup, so a failed opt-out erase cannot reuse the old queue or ID.
Normal enabled launches retain the same consent period. All these native paths
still need the new CI and live SDK checks.

## Always-on policy delta, 9f16d6d

Three independent native Codex source reads covered `c0f1872..9f16d6d` on
Standards, Spec and Risk. The latest user instruction makes anonymous
collection part of every normal configured run, without an opt-out. Tests and
benchmarks stay excluded. The token is public; private control access stays in
the vault and CI secret.

Standards retained no finding. Spec found one stale web heading, "You choose
diagnostics", above the new always-on text. Source inspection confirmed it;
the heading now reads "Anonymous diagnostics". Risk retained no finding.
Settings' temporary old setter was excluded because the Opus writer owned its
replacement. That change is now integrated in `a18a0b5`. These source reads do
not prove native default collection or live ingestion. The later real-SDK wire
probe and symbol-upload changes need their own validation.

## SDK and server setup delta, c590e06

Three further independent native Codex reads covered `a18a0b5..c590e06` on
Standards, Spec and Risk. All 13 changed files were covered; no untracked file
was present. No retained source finding remained. The saved resources clearly
mark survey and experiment qualification as open. The wire probe, live symbol
upload and SDK behavior still require macOS execution. Sixteen tool tests pass,
including symbol identity, wrong-project and release-series failure paths.

A separate whole-site claim search found historical no-telemetry and silent
network claims outside the prior changed lines. The current privacy copy now
states anonymous diagnostics are enabled. It also removes stale unsigned-build
and unverified competitor-price claims. These are copy corrections; no new
privacy behavior is inferred from them.

The Opus process-local accessibility proposal `c927cd2` was not integrated. It
used guessed underscored SwiftUI keys. The writer reverted it in `959606c`;
that tree equals parent `c590e06`. Native qualification must test public system
accessibility behavior and restore any temporary changes.

## Local release and metric delta, 76ef824

Three independent Codex passes reviewed `c590e06..76ef824` on Standards, Spec
and Risk. They retained no finding after source checks. This covers the local
release upload gate, vault-to-CLI aliases, the matching negative tests, always-on
project rule, site claim corrections, and both seven-day experiment metrics.
The app Swift source is unchanged from `c590e06`. All 17 tool tests pass.
Native SDK, symbol ingestion and UI results remain separate runtime gates.
