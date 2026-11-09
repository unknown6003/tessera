# CI outside GitHub Actions

Outcome: test every trusted Tessera PR and main commit on owned hardware, then
block release unless native and web checks pass that exact clean source.

Proof: a live job in each lane, signed reports in the `ci-reports` branch,
GitHub commit statuses and the local release verifier. A timer being active is
not proof that its job passed.

Constraints: no hosted CI bill, no fork code on a personal machine, no build
credentials in test environments, no production telemetry or user cleanup.
The Mac must be awake and its user session available. Sleeping hosts leave
checks pending and block release. Electricity and existing hardware are used.

## Two lanes

The Mac runs native CI. The existing Linux T3 host runs web CI. `launchd` and a
systemd user timer invoke finite jobs every five minutes. There is no agent or
model in the installed CI loop. Each timer has logs, a deadline and a stop
command. Jobs run one at a time per host and use private build staging, never
the restored checkout or a conversation worktree.

Native checks run the Python tool suite, release policy, XcodeGen, five native
test iterations, unsigned Release, serial and parallel scan benchmarks, rescan
correctness and 400 complete fixture pipelines. Each of four cohorts has 100
samples: mixed 20,000 files, wide 100,000 files, depth 420 and 2,000 long Unicode
names. Counts, coverage, source class, p99 and the UI heartbeat must qualify.
The 120-second goal does not truncate a healthy local scan. The harness and
job have separate safety deadlines; missing samples fail the job.

The first passing native job establishes a baseline on this host. Later jobs
also fail if cohort p99 grows by more than 50% and 500 ms. Hardware, OS,
Xcode, workload and cache conditions must match. Load is recorded. A changed
environment needs a reviewed baseline reset; the runner does not quietly
replace it. These are local synthetic cohorts, not population-wide p99 proof.

Web checks run formatting, lint, tests, production build, asset budgets and
three fresh mobile Chromium checks. The page must show its heading and a
visible download action, stay within the viewport, load within five seconds
and raise no JavaScript error. The browser and finite local test server stop
after each job.

`SO_CI` prevents the native host from taking activation. `TEST_RUNNER_SO_CI`
and `TEST_RUNNER_SO_CI_JOB` forward it into XCTest. Plain shell exports do
not reach that host. App and test bundle IDs, plus test preference domains,
contain the job ID. Only new domains in that exact namespace are removed.
Interactive UI and accessibility proof remains a separate release review.

The native LaunchAgent uses Standard scheduling, Nice 10 and low-priority I/O.
Explicit Background policy distorted heartbeat measurements in controlled
runs. The installer is part of the signed recipe. Metadata records its
configured scheduling policy; installation checks the live plist. Use the
installed service for native qualification. An explicitly backgrounded shell
run is diagnostic evidence. Policy changes require a reviewed baseline reset.


## Trust and evidence

Only PRs opened by `unknown6003` from `unknown6003/tessera`, and main, run
automatically. Forks and other authors are excluded. This is a personal,
trusted-source runner, not a sandbox for arbitrary public PRs. Build commands
receive no GitHub, cloud, analytics, signing or CI attestation credential.

The installed recipe lives outside the tested source. Its hash must match
the candidate's recipe; a recipe change requires review and reinstall. The
supervisor signs the report with a 32-byte private key shared only by the two
hosts and the release operator. It publishes no raw test logs, file paths or
private screenshots. Public reports contain step results, timings, hardware
class, toolchain and synthetic cohort metrics. Command logs and xcresults stay
on the runner.

GitHub statuses are `Tessera CI / native` and `Tessera CI / web`. Reports are
at `ci-reports:reports/<lane>/<commit>.json`. Release verifies the signature,
full commit, recipe, lane, required step inventory and age of both reports.
A failed, skipped, incomplete, changed or older-than-seven-day result blocks
release. Tests do not receive the private key. Existing GitHub CLI auth posts
statuses and reports; no token is in this repository.

## Install a reviewed revision

Python 3.12 or newer and GitHub CLI auth for this repository are required.
Native also needs the installed Xcode, XcodeGen and SPM cache. Web needs Node,
Corepack, an existing Chromium and Python Playwright 1.63.0. pnpm is pinned to
9.15.9 through Corepack; it does not use the broken global Mac shim.

On each host, use the same private 32-byte key file, mode 600. Keep it outside
the repo and pass only its path. Do not print or commit it.

```sh
python3 -m ci.install --state "$HOME/.local/share/tessera-ci" \
  --lane native --key /private/path/attestation.key
```

Use `--lane web` on Linux. The installer refuses an unrequested key rotation
and refuses to replace the recipe during a running job. It uses only user
services, without root or a new paid service. Verify readiness in `health.log`,
then require an actual signed successful job.

For a finite manual run from the installed recipe directory:

```sh
python3 tools/run_bounded.py --timeout 3900 --log /tmp/tessera-ci-manual.log -- \
  python3 -m ci.runner --state "$HOME/.local/share/tessera-ci" \
  --lane native --revision FULL_COMMIT_SHA
```

The revision must still be a trusted PR head or main. `--force` reruns that
revision. Completed failures are not retried in an endless loop. Preserve the
private job directory when diagnosing a failure. Generated DerivedData and
fixture files are removed after the run; logs, signed reports and xcresults
remain. Prune only completed owned job directories when retention is needed.

Stop the Mac timer with `launchctl bootout gui/$(id -u)/com.abdwy.tessera-ci.native`.
Stop Linux with `systemctl --user disable --now tessera-ci-web.timer`, then
`systemctl --user stop tessera-ci-web.service`. Stop actions are scoped to these
services. Do not signal other builds or apps.

## Release gate

`release.sh` calls `ci.verify_release` before any release work. Set
`TESSERA_CI_KEY_FILE` if the key is not at the default runner state path.
The existing stable certificate and Sparkle key remain mandatory. No 1.0
milestone, notarization or Developer ID claim follows from passing CI.

The old GitHub Actions CI, qualification and release workflows are removed.
The separate Pages deployment workflow only publishes the marketing site.
