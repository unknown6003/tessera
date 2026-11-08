# Tessera 0.2 iteration

Outcome: keep releases in 0.x.x, meet a measured local-drive p99 scan goal of
120 seconds, add anonymous PostHog features, and improve the UI through Opus
reference reviews and scored native flows.

Proof: release policy regression checks; complete local-drive scan samples with
hardware, cache state, coverage and sample count; inspected analytics payloads
and live ingestion; native captures and real input paths; scored comparisons
against the same reference rubric after each UI iteration.

Constraints: no 1.0 milestone without Ammar's explicit instruction. A healthy
scan may continue past 120 seconds. Cloud and remote drives form separate
performance cohorts. Preserve deletion identity, owner, protected-path and
coverage checks. No disk names, paths, content or user identifiers in analytics.

## Ownership

- Parent owns release policy, analytics, scan instrumentation and integration.
- Opus reference team is read-only. It owns visual comparisons and score evidence.
- Opus flow team is read-only. It owns flow, accessibility and interaction evidence.
- UI implementation starts after the review teams return. Each writer receives
  exclusive source ownership in an isolated space. Integrate one commit at a time.

## Fixed review rubric

Score each app on the same 0–10 scale for visual hierarchy, type and readability,
spacing and density, color and contrast, navigation and discovery, map and list
clarity, first-run and scan feedback, cleanup safety and review flow, keyboard
and accessibility, and window adaptation and state consistency.

A 9 requires a clear primary task, no material fault in the reviewed states,
and direct evidence for the claim. An unseen or untested area stays unscored.
An agent's score is a design judgement, not a user-study result. Keep the rubric
fixed, list deductions and recheck them after changes. Target at least 9 in
every area; do not raise a score just to pass the target.

## Release correction

The published 1.0.0 release is now a withdrawn draft. The public latest route
returns 0.1.9. Its tag and assets remain preserved. The next source version is
0.2.0, build 12, above withdrawn build 11. Release scripts and CI reject non-0.x
versions without an environment-variable escape hatch.

## Open qualification

The first Opus implementation compiled and passed 78 native tests at `5ae7865`.
Its design changes have not had a fresh native score review. The initial
Opus scorecards and reference images are preserved in `opus-reviews/`.
No Tessera area is qualified at 9/10 yet.

The second Opus implementation recovered after provider failures. It is integrated
at `e9a2e5a`. Native qualification of `c0f1872` passed 83 tests and Release,
but found inactive list keys, list rows overlapping Review, and poor narrow
window names and map size. Opus fixes are integrated at `a18a0b5`; their native
recheck is running at exact app source `c590e06`.
No new score is justified yet.

All 400 warm-cache pipeline trials passed on the CI VM at the exact `02c6a34`
source tree. See `native/02c6a34/` for raw rows, provenance and cohort p99.
The widest cohort had a 7.10 second p99. The worst heartbeat gap was 819 ms.
This proves only those four runner workloads. Broader drive and device p99
and wide-folder UI responsiveness remain open.

Tessera now has a dedicated EU PostHog project, ID 340688, its own public ingest
token and a project-scoped control key in the shared vault. Normal configured
builds collect anonymous data without an opt-out, per Ammar's updated request.
Automated tests and benchmarks remain excluded. Thirteen server resources and the survey flag payload are verified. Live
ingestion, survey submission, experiment qualification, dSYM upload and a resolved
native stack still need proof. The SDK cannot provide
macOS replay or built-in macOS survey UI. The fixed native rating flow is the
supported survey route.
