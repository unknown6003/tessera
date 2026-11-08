# Tessera PostHog setup

Verified on 8 November 2026. Dedicated EU organization and project 340688.
The public ingest token is in the app plist. The project-scoped control key is
in the shared `posthog-tessera` vault and the `POSTHOG_TESSERA_API_KEY` Actions
secret. No private control key is in source, the app, or this report.

`resources.json` lists the 13 live server resources. `verified-resources.json`
records their read-back state and exact saved queries. Seven SQL queries ran
successfully before their insights were saved. The dashboard has eight insights,
including an ordered cleanup funnel. It separates local, cloud and remote scans.
It retains failure, cancellation, partial coverage, sample counts, versions and
cache state beside completion percentiles. Small samples do not prove p99 for
all drives. No test events or benchmark results were captured in the project.

The native 1–5 survey has an active Settings flag with matching survey and
question UUIDs. The SDK public flags request returned the expected payload.
The survey itself is draft pending native qualification. The presentation-only
browser experiment and its flag are draft and inactive. Its variants differ
only in four versus eight visible rows. It has no metrics yet and must not launch
before native review and a metric have been set. Scan and cleanup protections
are outside the flags.

Project settings read back IP anonymization on, generic autocapture off, native
exception collection available, and session recording off. Swift SDK 3.93.6
supports macOS events, logs, flags, experiments and native crashes. Its replay
and built-in survey UI are unavailable on macOS. The rating uses native controls.

## Collection policy

Normal configured builds always collect anonymous analytics. There is no user
switch, stored off preference or manual disable environment variable. SO_ and
XCTest runs stay excluded. Settings states what is sent. The payload allowlist
still excludes names, paths, contents, search text, accounts, hardware IDs and
raw errors. No person profile is created; IDs are random. GeoIP lookup is off.

The initial control script used an unsupported experiment `active` input. The
server rejected it without creating an experiment. Creating an inactive flag
first, then linking the draft experiment, passed. A generic Python flags probe
returned no client-only flags. The request with the real SDK user agent returned
the native survey flag and matching payload. These failed attempts are not
counted as passed verification.

## Remaining proof

- Native configured SDK wire test and automatic collection migration.
- Live ingestion without test or benchmark events in production analytics.
- Exact-release dSYM upload and a resolved native stack.
- Survey submission and presentation experiment qualification.

The official API references used were
[dashboard](https://posthog.com/docs/api/dashboards),
[insight](https://posthog.com/docs/api/insights),
[flag](https://posthog.com/docs/api/feature-flags),
[survey](https://posthog.com/docs/api/surveys), and
[experiment](https://posthog.com/docs/api/experiments).
The pinned CLI upload follows the official
[CLI documentation](https://github.com/PostHog/posthog/blob/master/cli/README.md).
