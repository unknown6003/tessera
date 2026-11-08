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
