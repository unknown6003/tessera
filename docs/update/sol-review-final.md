# Final Sol review

Outcome: publish a qualified 0.2 release with accurate coverage telemetry,
working native survey results and readable deep scan roots.

Proof: the real SDK transport probe, computed Rescue coverage fixtures and the
existing overlong-filesystem regression extended through `ScanViewModel`.

Constraints: no private payload fields, no weaker removal checks, no scan
timeout at 120 seconds, and both external CI lanes on the final commit.

## Round 1

Base: `fdae45dbc8c57846017454a263fe2474ea9ed70f`.
Target: `fab26f4de1d1ca5b95b6c44ba99dbd9bb7465743`.
Reviewer: Codex `gpt-6.1-sol`, high effort. Usage was not exposed.
All 108 changed paths were accounted for. Verdict: changes.

| ID | Severity | Checked finding | Change |
| --- | --- | --- | --- |
| S1 | should | Zero enumeration gaps incorrectly implied complete coverage, despite hidden, cloud or cross-volume boundaries. | Pass the computed Rescue coverage state to telemetry. Keep the enumeration-gap count separate. The qualification harness also requires complete computed coverage. |
| S2 | should | UUID formatting uppercased server survey and question IDs. | Use lowercase IDs for shown and sent events and the question response key. Extend the real SDK transport test to inspect their exact values. |
| S3 | should | A full-path readability check could reject a successful descriptor-based scan beyond `PATH_MAX`. | Carry the root listing result in scan progress. Use it for Rescue coverage and the permission prompt. Extend the existing real deep-tree test through the view model, including an empty deep root. |

The parent verified each source path. PostHog builds the response property from
the question ID and filters events by the exact survey ID. See its
[survey query and response helpers](https://github.com/PostHog/posthog/blob/dcf2ddf1a31475a6312ba8e1ece2b38cabdc7fe9/frontend/src/scenes/surveys/utils.ts).

The root-read result adds no field to each file node. A failed or abandoned root
read remains false. Child gaps still make coverage partial. Live identity and
owner checks before removal are unchanged.

## Qualification status

The native control retained the new test seams and restored the three old
behaviors. All three selected tests failed, with ten issues. The fixed source
then ran 93 tests. Computed coverage and both deep-root view-model cases passed.
The SDK wire test failed because an expected survey event was absent after
eight seconds. Its result did not identify which event was missing.

A focused wire probe passed with the same batch setting and all assertions
intact. A controlled upload-overlap probe then reproduced the batch race. The
one-event test override started the scan upload before the surveys were queued.
Overlapping flushes returned while that upload was in flight. The queue's next
timer was outside the test's eight-second wait. Only the scan reached the wire,
and the required survey assertion failed after 8.269 seconds. This proves the
mechanism, not the exact order in the earlier failed run.

The test now uses the production batch setting by removing that override. All
required wire assertions remain. Five focused repetitions passed. The full
native suite then passed all 93 tests in 14.371 seconds, including the exact
lowercase survey IDs, response key and rating. Temporary probe instrumentation
is absent from the final source. Production preferences, the running user app
and all nine Sample files were preserved. The test job removed its own
preferences and DerivedData.

The private Mac evidence roots are `/private/tmp/tessera-native-f2d8acddafbc`
and `/var/folders/kx/cw4tm9h12ll8r6j6y61s_7xr0000gn/T/tessera-flush-recheck-xedozlb8`.

The native UI check also found an ungrouped `100000 items` label. The shared
item-count formatter now uses the locale's number format. This small display
change still needs the final native build.

The signed CI evidence for `fab26f4` covers the earlier source. A new commit must
pass both external lanes before publication. No release is approved by these
source fixes alone. Round 2 will review only these fixes and the three open IDs.

## Round 2

Codex `gpt-6.1-sol` with high reasoning effort approved the staged fixes.
S1, S2 and S3 are resolved. The reviewer found no new Standards, Spec or Risk
issue and accepted the count formatter. Usage was not exposed. This round
checked only the changed code and open findings. It did not rerun native tests.

The final commit still requires both external CI lanes before publication.
