# Release Tessera from owned hardware

Tessera releases stay in `0.x.x`. The latest public release is `0.2.2`,
build `14`, published on 10 November 2026. The Rescue redesign candidate is
`0.2.3`, build `15`. Native acceptance and exact-commit release gates are pending.
`0.2.0`, build `12`, was a candidate that was not published. Withdrawn `1.0.0`,
build `11`, stays a draft. A major version needs Ammar's explicit permission.
The public release stays latest until the new candidate passes all gates and
is published.

The publisher uses the existing Mac, installed Xcode, XcodeGen, Python 3.12+
and GitHub CLI auth. It uses no GitHub Actions runner, paid CI service or new
Apple membership. The Mac must be awake with its user session available.

## Stable signing and its limits

The app uses the same self-signed code certificate as `0.1.9`:

```text
SHA-1 da4569aa63dee7587d670dc4c685f128faacf4e5
identifier "com.abdwy.Tessera" and certificate root = H"da4569aa63dee7587d670dc4c685f128faacf4e5"
```

This pins the app's identity across builds for Full Disk Access continuity.
It does not grant Full Disk Access or prove an OS permission migration.
This is not Developer ID signing. The app and DMG are not notarized. Gatekeeper
can block a first install. Do not advertise notarization or Gatekeeper approval.

Signing uses the exact certificate fingerprint. It never substitutes ad-hoc,
Apple Development or another certificate. It does not set hardened runtime or
an explicit signing identifier. Sparkle must keep `org.sparkle-project.Sparkle`.
A self-signed identity lacks the shared Team ID needed for runtime library
validation. The publisher stops on signing failure. It never imports keys,
changes trust, uses `sudo` or unlocks a keychain.

The early signing probe timed out before the 0.2.2 release. That historical
probe does not establish the current keychain state. Qualify signing on the
exact new candidate through the publisher. Its stable identity, smoke, symbol
and Sparkle checks must pass again. Do not substitute a certificate or change
keychain access based only on an old timeout or `find-identity` listing.

## Qualify the exact source first

See [the owned CI runbook](ci/README.md) for installation, recipe hashes, report
signatures, host limits, baselines and stop commands. Review a recipe before
installation. A publisher-only change does not change that recipe hash, but
its full source commit still needs fresh successful native and web reports.

From the reviewed source on each host:

```sh
python3 -m ci.install --state "$HOME/.local/share/tessera-ci" \
  --lane native --key "$HOME/.local/share/tessera-ci/attestation.key"
```

Use `--lane web` on Linux. Install only when the recipe needs an update.
The shared private attestation file is 32 bytes, mode `600`. Do not print it.
For a working Git checkout, check the candidate from the clean source:

```sh
python3 -m ci.verify_release \
  --key "$HOME/.local/share/tessera-ci/attestation.key"
```

Both `Tessera CI / native` and `Tessera CI / web` must pass the full source
commit. Worktree mode uses clean HEAD. Archive mode uses the pinned revision.
The verifier checks HMAC reports, recipe, lane, step inventory, native cohort
counts and age. A missing or stale report stops release before builds, signing
or symbol upload. A new commit, even for docs, requires new full-commit proof.
`TESSERA_CI_KEY_FILE` selects another key path. It cannot skip the gate.

## Archive mode on the existing Mac

The Mac can run the publisher without a Git checkout. Ops supplies an owned
bare object repository and a clean `git archive` staging directory at the same
full commit. The original Mac checkout at `a538` stays intact. This mode needs
no new T3 space, worktree, index or fake `.git` directory. The publisher does
not fetch objects. Ops must make the pinned commit available first.

Run the publisher from that same archive. Both options are required together:

```sh
cd "$release_archive"
./release.sh --git-dir "$release_bare" --revision "$release_revision" \
  --posthog-cli "$symbol_tools/node_modules/.bin/posthog-cli" \
  --spm-cache "$HOME/.local/share/tessera-ci/spm-cache"
```

`release_archive` is the owned source staging directory. `release_bare` is its
owned bare object repository. `release_revision` must be the full lowercase
40-character commit SHA. Do not use a branch name, tag or short SHA. The
module and wrapper must come from that same pinned source archive.

Each gate proves that the object repository is bare, the object is a commit
and its full SHA resolves exactly. It then checks every source path against
`git ls-tree -rz --full-tree`. It compares file type, executable bits and the
Git SHA-1 blob hash, including the `blob N` header. Tracked symlinks must keep
their exact target text and stay inside the archive. It rejects missing or
extra files and directories, changed blobs, substituted symlinks, submodules
and unsafe paths. Git replacement refs cannot substitute another tree.
There are no ignored-file exceptions, including `.DS_Store` and `__pycache__`.

The wrapper uses Python `-B` and `PYTHONDONTWRITEBYTECODE=1`. This keeps imports
from adding bytecode to the archive. Keep source staging free of logs, keys,
build output and shell notes. Output stays in a separate private directory.
The publisher writes no Git HEAD, index, worktree or config and does not change
`core.bare` or set `GIT_WORK_TREE`.

After the archive matches, the shared `check_reports` helper checks both exact
CI reports with the source recipe hash and private attestation key. Every later
gate repeats the archive check and report checks. Build staging comes from
`git --git-dir "$release_bare" archive` at the pinned commit. The private
`source-archive-proof.json` records the revision, mode, manifest digest and
file counts, without source paths. It proves the archive match only. Successful
CI and build evidence remains in the final release proof.

For an archive candidate, keep both options when publishing reviewed assets:

```sh
cd "$release_archive"
./release.sh --git-dir "$release_bare" --revision "$release_revision" \
  --publish --artifacts /private/printed/tessera-release-output
```

Without the pair, the existing clean-HEAD worktree checks still apply. Archive
mode cannot skip CI. The earlier failed campaigns remain diagnostic history. Each new candidate
still needs its own successful reports from both external lanes. No earlier
release or focused test can qualify a different source commit.

## Keys and the pinned symbol tool

The stable signing private key stays in the existing Mac keychain. Sparkle's
existing `ed25519` account stays in that keychain too. The source public key is
`Tessera/Info.plist:SUPublicEDKey`. Do not export or regenerate either key.
The publisher discovers `generate_appcast` only in its resolved SPM artifact
cache. It sets only `CFFIXED_USER_HOME` to a new private home and checks that
Foundation resolves the generator cache inside it. It keeps the real `HOME`:
a private `HOME` empties the keychain search list, and the generator then
cannot find the `ed25519` key (`-25300`). It does not search unrelated user DerivedData folders.

The vault credential is `posthog-tessera`, used through
`$HOME/.local/bin/agent-access`. It supplies `POSTHOG_API_KEY`,
`POSTHOG_PROJECT_ID=340688` and `POSTHOG_API_ENDPOINT=https://eu.posthog.com`.
The existing symbol helper maps them to the CLI aliases. The private API key
never enters the build environment, plist, command arguments or release proof.
The upload child's output goes to `/dev/null` so CLI diagnostics cannot put the
key in logs. Failure still returns a nonzero status and stops the publisher.
Logs record the command's result, not the service's private error body.

Install the pinned CLI in an owned directory outside the checkout if needed:

```sh
symbol_tools="$(mktemp -d /tmp/tessera-symbol-tools.XXXXXX)"
python3 tools/run_bounded.py --timeout 180 --log "$symbol_tools/install.log" -- \
  npm install --prefix "$symbol_tools" --no-audit --no-fund --save-exact @posthog/cli@0.19.0
```

Pass `"$symbol_tools/node_modules/.bin/posthog-cli"`. The publisher checks the
package version, app/dSYM UUID match and successful real upload. It uses
`tools/upload_posthog_symbols.py` without source-file upload. Mock test success
is not upload proof. Live upload and PostHog service readback remain pending.

## Build a reviewable candidate

In worktree mode, run from the clean Mac checkout with both exact-commit CI
reports available. Use the paired options above for archive mode:

```sh
./release.sh --posthog-cli "$symbol_tools/node_modules/.bin/posthog-cli" \
  --spm-cache "$HOME/.local/share/tessera-ci/spm-cache"
```

The SPM cache option is optional and must point outside the checkout. No SDK
or toolchain is installed. The default command builds artifacts and performs
the mandatory symbol upload. It creates no GitHub tag or release.

`release.sh` gives the whole operation 2400 seconds. Each external command has
its own deadline, process group, log and PID file. The wrapper prints its log path. That log names the new
private output directory outside the checkout. It copies the pinned Git tree
there, generates the Xcode project there, builds unsigned Release, then signs.
Generated project files and products never dirty the release source.

The signed app scans only an owned nine-file, four-directory fixture. It must
exit `0` within 120 seconds, report the full scan with exact counts, complete
coverage and zero gaps, then publish cleanup classification. The fixture hashes
must stay unchanged. `SO_CI`, `SO_AUTOSCAN`, `SO_AUTOQUIT` and
`SO_PRIVATE_SUMMARY` keep this run out of analytics and the updater, without
app activation. This is a launch check, not p99 qualification.

The run uses a new empty `HOME` and `CFFIXED_USER_HOME`. It copies no keychain
or private app data. CFPreferences isolation with those overrides is not proved.
The publisher snapshots the production preference domain and its plist files
before and after, and stops on a change. It never restores those files over a
concurrent user's writes. A native run must prove that this guard works.

The DMG contains `Tessera.app` and an `Applications` symlink. The publisher
creates UDZO, runs `hdiutil verify`, generates a keychain-signed appcast and
verifies the Ed25519 signature with public CryptoKit against the source key.
It checks the one enclosure's URL, version, build and byte length. See
[Sparkle publishing](https://sparkle-project.org/documentation/publishing/)
and the [official generator source](https://github.com/sparkle-project/Sparkle/blob/2.x/generate_appcast/main.swift).

Review `release-proof.json` in the printed output. It records the commit,
recipe, CI report hashes, stable requirement, app/stage hashes, smoke result,
symbol UUIDs, public signature proof and four asset hashes. It contains no
private key or raw private path. Raw logs stay private beside it.

## Publish only after review

Once the concrete candidate and native results pass review, run:

```sh
./release.sh --publish --artifacts /private/printed/tessera-release-output
```

This command checks clean HEAD or the exact archive, then fresh CI again. It rechecks the signed
app, image, signature, smoke evidence and asset hashes. It creates an annotated
tag at the exact full commit, then a draft release. It uploads exactly:

- `Tessera.dmg`
- `Tessera-<candidate-version>.dmg`
- `appcast.xml`
- `SHA256SUMS`

Both DMGs have equal bytes. The appcast URL uses the versioned DMG. All four
remote assets must download with the expected sizes and SHA-256 values before
the publisher checks CI again and makes the draft public and latest.

An existing tag must be annotated at the same commit. An existing release must
be a draft with that exact tag and full target commit. Resume accepts an empty
draft or the full four-asset set only after byte checks. A partial, extra,
changed or public release stops for parent review. Nothing overwrites or
deletes remote assets. No failure path changes a prior release tag or edits its assets.

The app checks for updates every six hours. Its custom Sparkle driver reports
status in the app. It holds a pending relaunch while the app's busy barrier is
set, including scan and staged cleanup work, then installs when that barrier
clears. Do not promise that every OS or installation path can never prompt.

## Stop and retain owned work

To stop an active publisher, send `TERM` to its wrapper's PID. The wrapper log
has a sibling `.pid` file for the owned group. Each active external command
also has a `.log.pid` file. The publisher handles `TERM` by unwinding its active
command and stopping that owned group. Never use a process-name-wide kill.
For the path printed by the wrapper, stop its owned release process with:

```sh
kill -TERM "$(cat /tmp/tessera-release-wrapper-PRINTED/release.log.pid)"
```

Replace `PRINTED` with that run's unique suffix. A deadline is a failure.
Keep the private output for diagnosis and review.
The publisher does not delete output or shared cache directories.

Stop the Mac CI timer with
`launchctl bootout gui/$(id -u)/com.abdwy.tessera-ci.native`.
Stop Linux with `systemctl --user disable --now tessera-ci-web.timer`, then
`systemctl --user stop tessera-ci-web.service`.

The [pipeline proof checklist](docs/update/release-pipeline.md) lists the native
gates still required before release. Linux tests do not prove a Mac compile,
keychain access, successful signing, service upload or an installed update.
