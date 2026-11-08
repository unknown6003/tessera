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

The second Opus implementation failed twice before edits with the Claude rate
limit. Native Opus work failed with `503 auth_unavailable`, then the rate limit.
The first implementation and its locked child workspace remain preserved.

The next CI campaign requests 400 full pipelines, 100 each for mixed 20,000
files, a 100,000-file folder, a 420-level tree and 2,000 long Unicode names.
Its report requires the exact case inventory and hardware, workload, cache
and coverage data. It qualifies only those warm-cache runner cohorts. Broader
local-drive and device p99 remains unproved.

The official PostHog SDK and anonymous boundary compile, but the Tessera
project token is still empty. The private control-key card timed out without
a reply. Another app's ingest key was not reused. Live ingestion, dashboards,
flag and survey setup, and dSYM upload remain blocked on dedicated access.
The SDK cannot provide macOS replay or built-in macOS survey UI. The fixed
native rating flow is the supported survey route.
