# Rescue analytics evidence

Existing analytics can confirm that the app has sent events. This sample cannot guide Rescue layout, priority, or cleanup flow decisions. The last 30 days contain **12 allowed events from 1 anonymous ID**, including **2 Rescue and 2 Explore screen events**. No cleanup stage, review, start, or completion event appears. An ID is not a proven human. The data could include the owner or a manual check.

## Scope and proof

- Outcome: determine whether existing anonymous analytics can inform Rescue decisions.
- Proof: inspect the event policy and callers, then run an aggregate-only HogQL query against project `340688`.
- Constraints: read-only research in `codex/rescue-research`, source commit `65e272109ad906810ff3b8a3d01d217cd1fb1934`. Only this report is written in the repo. No app launch, drive scan, child agent, product edit, commit, owner question, or paid resource creation.

Required shared engineering, investigation, writing, research, and global-access rules were read. The explicit request to work alone takes precedence over the research skill's delegation step. This Markdown report is for the parent research task. It makes no layout choice.

## Query outcome

The approved credential metadata matched HTTPS host `eu.posthog.com` and project `340688`. No credential or injected environment value was printed. The client used `agent-access run --timeout 60 posthog-tessera -- python3 /tmp/tessera-rescue-analytics-query.py` after reading both help screens.

| Item | Evidence |
| --- | --- |
| Endpoint | `POST https://eu.posthog.com/api/projects/340688/query/` |
| Window | `2026-10-12 15:16:14 UTC` inclusive to `2026-11-11 15:16:14 UTC` exclusive |
| Request body | `{"query":{"kind":"HogQLQuery","query":"<exact SQL below>"},"refresh":"blocking"}` |
| HTTP outcomes | Three query POSTs, all HTTP 200. No access failure, reauthentication, or key change. |
| Local result checks | First two responses were rejected locally because numeric aggregate columns could be null. The third accepted null values without treating them as zero. All three used the same SQL and fixed window. |
| Response times | 0.567, 0.175, and 0.174 seconds, measured by the client |
| Final response | 9 aggregate rows, including the total row. `is_cached = true`. |
| Bounds | TLS connection 10 seconds, socket read 40 seconds, client runner 60 seconds, outer GNU timeout 65 seconds with TERM then KILL after 3 seconds. Response read capped at 2 MB. No redirects or proxy destinations used. |

PostHog documents query POSTs and the `HogQLQuery` body in its [SQL API guide](https://posthog.com/docs/sql). These requests read event aggregates. No events, flags, projects, keys, surveys, or settings were changed. No raw response error text, person rows, identifiers, paths, or survey answers were fetched into the report.

## Counts

All 12 events have `application = 'Tessera'`. The total covers only the event names allowed by the inspected policy. It is not a count of unknown or legacy event names in the project.

| Event or screen | Events | Distinct anonymous IDs | Recorded outcome |
| --- | ---: | ---: | --- |
| All allowed events | 12 | 1 | Mixed |
| `$screen`, `rescue` | 2 | 1 | Not recorded |
| `$screen`, `explore` | 2 | 1 | Not recorded |
| `$feature_flag_called` | 2 | 1 | Not recorded |
| `tessera app opened` | 1 | 1 | Not recorded |
| `tessera scan started` | 1 | 1 | `complete` |
| `tessera scan phase finished` | 2 | 1 | `complete` |
| `tessera scan completed` | 1 | 1 | `partial` |
| `tessera update completed` | 1 | 1 | `installed` |
| `tessera cleanup staged` | 0 | 0 | No rows |
| `tessera cleanup review opened` | 0 | 0 | No rows |
| `tessera cleanup started` | 0 | 0 | No rows |
| `tessera cleanup completed` | 0 | 0 | No rows |

Every other allowed event and screen has zero matching rows. Distinct counts overlap and must not be added. No cleanup method, outcome, moved, held, failed, or item total is available. Null sums on non-cleanup rows mean no value, not zero cleanup work. The total row's four numeric zeros are SQL placeholders, not measured cleanup totals.

## What the current code records

- [AnalyticsPolicy.swift](../../../Tessera/Analytics/AnalyticsPolicy.swift#L5) allows the 16 named `tessera` events listed in the SQL, plus `$screen`, `$feature_flag_called`, `$exception`, `survey shown`, `survey sent`, and `survey dismissed`. An allowed name does not prove a caller emits it.
- [Analytics.swift](../../../Tessera/Analytics/Analytics.swift#L261) sends `$screen_name` with `$screen` and suppresses consecutive calls for the same screen. [ContentView.swift](../../../Tessera/Views/ContentView.swift#L643) maps app mode to `rescue` or `explore`, and records `review` on review presentation. Counts measure recorded screen changes, not sessions or time spent.
- [ScanViewModel.swift](../../../Tessera/ViewModel/ScanViewModel.swift#L540) sends cleanup staged with the current collector count after an accepted addition. This is a list-size snapshot. Its sum would not count unique added files. [ContentView.swift](../../../Tessera/Views/ContentView.swift#L272) sends cleanup review opened with snapshot item count.
- [ScanViewModel.swift](../../../Tessera/ViewModel/ScanViewModel.swift#L980) sends cleanup started with target count and `trash` or `permanent`. Completion at line 1035 adds `moved`, `held`, `failed`, duration, and `complete` or `partial`. Busy or empty-target guards run before the start event. Failures before completion can leave a start without a completion event. These shared cleanup events have no Rescue or Explore mode property, category choice, cleanup-operation ID, or verified reclaimed-space value.
- [ScanTelemetry.swift](../../../Tessera/Analytics/ScanTelemetry.swift#L28) records source class, scope, outcome, cache state, duration, enumeration and diagnosis time, file and directory counts, schema version, provider reads, coverage, and optional gap count. [ScanViewModel.swift](../../../Tessera/ViewModel/ScanViewModel.swift#L209) uses `complete` on scan started, so that value does not prove a completed scan. The one completed scan has outcome `partial`. No performance percentile is claimed here.
- [AnalyticsPolicy.swift](../../../Tessera/Analytics/AnalyticsPolicy.swift#L100) rebuilds properties from allowed fields. It drops file names, paths, search text, and raw error text. [Analytics.swift](../../../Tessera/Analytics/Analytics.swift#L65) disables person profiles and automatic screen and lifecycle capture, requires UUID-shaped anonymous IDs, and sets bounded queues and retries. Survey values are numeric ratings; no survey values were queried here.

## Evidence limits and use

The app suppresses external services when any environment key starts with `SO_` or `XCTest`, through [AppRunPolicy](../../../Tessera/DebugAutomation.swift#L4) and [Analytics.isSuppressed](../../../Tessera/Analytics/Analytics.swift#L203). This excludes correctly marked tests and benchmark drivers in the inspected version. The query has no separate automation filter because the policy retains no automation marker. It cannot prove that older builds or unmarked manual automation followed that rule. This research emitted no app telemetry.

No event sampling is configured in the inspected capture code, and the SQL uses `count()` and `uniqExact` with no SAMPLE clause. The API did not return a non-null sampling field to this client. Server sampling, retention settings, deployment coverage, ingestion loss, and the active build distribution were not checked. The result limit is 1000 rows; only 9 rows returned, far below that cap. The final response was cached. New events after the fixed upper bound are outside the query.

Configured builds, SDK setup, network delivery, queue limits, shutdown, policy filtering, and version coverage affect what reaches the project. The code alone cannot prove all installs report. One ID can cover many sessions, and reinstall or storage changes can change IDs. The sample is too small to establish audience size, feature demand, category preferences, trust, cleanup success rates, or the cause of partial coverage.

These are aggregate event counts, not a per-user funnel. No conversion or drop-off rate is inferred from them. A proper ordered funnel needs explicit identity, time-order and window semantics, duplicate and repeat handling, and a justified way to attribute cleanup to Rescue. Although event timestamps and anonymous IDs can support some ordered analysis, this query does not retain a sequence, and there are no cleanup events to analyze. No ordered funnel was run.

Use the result to record the present evidence gap. It does not select a layout or settle the parent's pending owner answers. Further design claims need direct research or a larger, verified sample with the required instrumentation.

## Exact HogQL

The query maps unexpected property strings to `not_set_or_other` and returns aggregate counts only. `current_application_tag_events` checks the current application tag without excluding older matching event names.

```sql
SELECT
  event,
  CASE WHEN event = '$screen' AND properties.$screen_name IN ('explore','rescue','review','settings','search','duplicates','bigOld','byKind','uninstaller','hiddenSpace') THEN properties.$screen_name ELSE 'not_set_or_other' END AS screen,
  CASE WHEN properties.outcome IN ('complete','partial','held','failed','cancelled','superseded','installed','installing','up_to_date') THEN properties.outcome ELSE 'not_set_or_other' END AS outcome,
  CASE WHEN properties.method IN ('trash','permanent') THEN properties.method ELSE 'not_set_or_other' END AS method,
  count() AS events,
  uniqExact(distinct_id) AS distinct_anonymous_ids,
  sum(toFloat64OrZero(toString(properties.items))) AS items_sum,
  sum(toFloat64OrZero(toString(properties.moved))) AS moved_sum,
  sum(toFloat64OrZero(toString(properties.held))) AS held_sum,
  sum(toFloat64OrZero(toString(properties.failed))) AS failed_sum,
  countIf(properties.application = 'Tessera') AS current_application_tag_events
FROM events
WHERE timestamp >= toDateTime('2026-10-12 15:16:14', 'UTC') AND timestamp < toDateTime('2026-11-11 15:16:14', 'UTC') AND event IN ('tessera app opened', 'tessera app closed', 'tessera scan started', 'tessera scan phase finished', 'tessera scan completed', 'tessera scan cancelled', 'tessera scan failed', 'tessera cleanup staged', 'tessera cleanup review opened', 'tessera cleanup started', 'tessera cleanup completed', 'tessera tool opened', 'tessera tool completed', 'tessera permission prompted', 'tessera permission dismissed', 'tessera update completed', '$screen', '$feature_flag_called', '$exception', 'survey shown', 'survey sent', 'survey dismissed')
GROUP BY event, screen, outcome, method
UNION ALL
SELECT '__total_allowed_events__', 'all', 'all', 'all', count(), uniqExact(distinct_id), 0, 0, 0, 0, countIf(properties.application = 'Tessera')
FROM events
WHERE timestamp >= toDateTime('2026-10-12 15:16:14', 'UTC') AND timestamp < toDateTime('2026-11-11 15:16:14', 'UTC') AND event IN ('tessera app opened', 'tessera app closed', 'tessera scan started', 'tessera scan phase finished', 'tessera scan completed', 'tessera scan cancelled', 'tessera scan failed', 'tessera cleanup staged', 'tessera cleanup review opened', 'tessera cleanup started', 'tessera cleanup completed', 'tessera tool opened', 'tessera tool completed', 'tessera permission prompted', 'tessera permission dismissed', 'tessera update completed', '$screen', '$feature_flag_called', '$exception', 'survey shown', 'survey sent', 'survey dismissed')
LIMIT 1000
```
