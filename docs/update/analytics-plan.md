# Anonymous PostHog integration

Use the official Swift SDK, pinned to 3.93.6. Its macOS target supports events,
feature flags, experiments, logs and native exception tracking. Its built-in
session replay is compiled only for iOS. Built-in surveys are unavailable on
macOS. Do not claim that enabling an iOS flag adds either feature to macOS.

Sources checked on 8 November 2026:

- https://posthog.com/docs/libraries/ios
- https://posthog.com/docs/libraries/ios/configuration
- https://posthog.com/docs/libraries/ios/usage
- https://posthog.com/docs/error-tracking/installation/ios
- https://github.com/PostHog/posthog-ios/releases/tag/3.93.6
- PostHogConfig.swift at tag 3.93.6, platform guards around replay and surveys.

## Privacy boundary

Use a random anonymous install ID. Never identify a person or register person
properties. Disable GeoIP enrichment. Every event passes a typed allowlist
before it enters the SDK, then a final SDK before-send filter. Keep automated
runs and tests disabled by default. Provide a clear setting to stop collection
and erase the local queue and ID.

No names, paths, search text, contents, volume labels, account names, hardware
serials or raw error messages may enter any event, log or crash report. Keep
stack images and symbol paths out of crash payloads unless stripped to a safe
module name. Do not enable generic screen or element autocapture.

## Product and performance coverage

Track fixed screen names, scan start/phase/finish/cancel/failure, coverage state,
file and directory counts, elapsed milliseconds and source class. Local and
cloud/remote cohorts stay separate. Preserve outcomes over 120 seconds and
cancelled/failed samples. Do not call a small fixture cohort the population p99.

Track review, staging, removal start/finish/held/failure, tool use and update
outcomes. Send bucketed counts and bytes where exact values add no useful
diagnosis. Use fixed error codes, not exception text.

Use remote flags for low-risk presentation experiments only. Remote flags must
never change scan depth, protection, validation, owner checks or deletion policy.
Add native fixed-choice feedback surveys with explicit submission; no arbitrary
screen capture or free-text collection. PostHog's macOS replay limitation stays
visible in the capability report.

## Access

The existing local PostHog credential is an ingest token for another project.
Do not send Tessera data to it. A dedicated Tessera project token and control
API access are needed for live ingestion, dashboards, flags, surveys and dSYM
upload. The private input is the only route for a new personal API key.
