# Local stable-certificate publisher

Outcome: replace the old Developer ID, notarization and GitHub Actions release
assumptions with a finite local build and an explicit draft publisher.

Proof: Linux package failure controls and source review in this patch. Native
build, signing, smoke, live symbols and publication are not proved here.

Constraints: `0.x.x` only, exact certificate and Sparkle key, both exact-commit
external CI lanes, no trust changes, no user-drive scan, no remote overwrite.

## Changed path

`release.sh` runs `python3 -m ci.release` under a 2400-second guard. The default
builds a private candidate. `--publish --artifacts PATH` reuses a complete
candidate and performs fresh gates. No environment flag can disable CI,
signing, smoke, symbols or signature validation.

The release proof is plain JSON with public configuration and hashes. It is
not an independent signed attestation. Keep it and the whole output directory
private and owned. The publisher rechecks live CI and artifact bytes on reuse.
Its output is review evidence, not authority to skip the parent release review.

The symbol tool stays at `@posthog/cli@0.19.0`. Its subprocess output is
suppressed within the vault child to keep private credentials out of logs.
A nonzero upload still stops the publisher. Service-side receipt and symbol
readback must come from the native live proof, not a mocked unit test.

## Required native proof

1. Qualify the final full commit in both external lanes. Publisher-only changes
   leave the recipe hash intact, but do not inherit another commit's reports.
2. Probe exact certificate signing of an owned disposable binary, without trust
   edits. Record the actual result of `codesign`, not just `find-identity`.
3. Build a complete Release bundle on the existing Xcode toolchain. Require
   `com.abdwy.Tessera`, source version/build, public analytics configuration and
   Sparkle public key. Prove no private resources enter the app.
4. Sign with SHA-1 `da4569aa63dee7587d670dc4c685f128faacf4e5`. Check strict deep
   verification, the exact certificate-root designated requirement, runtime
   disabled and Sparkle's own identifier. A failed signing probe is a blocker.
5. Run the signed app on the owned nine-file fixture. Prove exit `0`, exact
   counts, final cleanup classification, full coverage, no gaps and no changed
   fixture or production preferences. Independently observe nonactivation and
   no analytics/updater traffic. `HOME`/`CFFIXED_USER_HOME` alone is not proof.
6. Upload the matching Release dSYM through `posthog-tessera`. Check the service
   has the expected UUIDs and release/build. Preserve only a redacted receipt.
7. Create and verify UDZO, and exercise `tools/verify_update.swift` with a real
   valid signature, wrong public key and altered archive. No Swift toolchain
   was available on Linux. A mock of this command proves only failure handling.
8. Review all four assets and the plain JSON proof. Confirm the DMGs are byte
   equal and the appcast URL, version, build, length and signature match.
9. Parent only: test draft upload/readback and complete-draft resume at the
   exact annotated tag. A partial draft requires review, never auto-deletion.
   Confirm the final public transition and installed update only when authorized.

## Linux checks

The full tool suite passed 49 tests under a 90-second process-group guard.
`bash -n release.sh`, Python compilation and `git diff --check` passed.
These checks include malformed appcast metadata, signature-command failure,
wrong public-key length, version/build rejection, unstable designated
requirements, missing or partial smoke completion, production preference
changes, missing symbol tooling, mismatched tags, public-release rejection,
partial drafts, remote byte and size failure, and stale CI after asset readback. Existing helper tests print
simulated upload success. No real symbol upload ran.

## Risk review

The source pass checks key substitution, runtime and nested identifiers,
missing scan completion, wrong counts, changed preference files, stale CI,
wrong tags, public release overwrite and draft asset changes. The Linux tests
exercise the rejection paths. No independent agent review ran, per scope.

GitHub has no transaction across tag creation, asset upload and publication.
The publisher keeps the release a draft through byte verification and checks
its tag, target and asset identities again before publication. A concurrent
operator can still race the final API request. Run one release operator at a
time. API/network failure can leave an annotated tag or private draft for review.

The publisher keeps outputs and logs. It never removes a checkout, shared
cache, user data or remote asset. The symbol command returns only success or
failure because its raw output is suppressed. Diagnose vault or service access
with a separate bounded, redacted parent probe if that step fails.
