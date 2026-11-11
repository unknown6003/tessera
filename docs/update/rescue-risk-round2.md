# Rescue risk review, round 2

11 November 2026. Independent Risk pass only. Target `b2a8d192c4b7d41e48ccbe230510322eac9208b6`; base and merge-base `65e272109ad906810ff3b8a3d01d217cd1fb1934`. HEAD matched target. No untracked files at pin.

Outcome: one retained P2 finding. Proof: changed source and a deterministic fixture recipe below. Constraints: no source edits, children, checkout changes, commits, network, builds or SDK use. Native validation remains pending. Read AGENTS.md, mandatory engineering rules/workflow/model guide, code-review, high-risk and unslop instructions.

## Risk

### P2: over-budget packages can move newly protected contents

`Tessera/Engine/DeletionService.swift:124–126`, reached through `Tessera/Engine/TrashOperation.swift:113–121`.

Trigger: prepare a clean `Example.app` containing `nested/deep`. During capture, create `nested/deep/keep.qcow2`, then exceed the capture budget. The package root itself has not changed. `ScanIdentity.current` labels it `.package`; the new fallback calls `revalidate`, which checks live descendants only for `.directory`. Root identity therefore passes and the adapter moves the package, including the new protected disk, to Trash.

Impact: protected owner data moves despite the promised live protection check. The move is recoverable and gains no finish record. This is the remaining package case of R2, not the already-fixed root-replacement case. Use `resourceType.isDirectory` for the live descendant gate and add the fixture below.

### Checked boundaries

R1's old recursive replacement path is superseded in source. Root acquisition verifies the acquired identity and full manifest; each leaf is acquired and checked again. Root, leaf and acquired-slot replacement fixtures assert survival. No recursive removal fallback remains. Final `fstatat`/`unlinkat` races, hostile same-UID changes and existing open handles remain explicit limits, not atomicity claims.

The owner probe has no demonstrated deadlock path: `offMain` runs the worker while the main actor awaits; both invalidation callers guard `isDeleting`. Finish checks cancellation between items. Source/root/revision gates remain at entry. Recovery failures block later deletion and retain an inspect-only Finder location. Unsupported cases stop. R3–R5 have source changes for fresh owner probes, partial issues and capacity reads. Native behavior is unproved. No new private-data telemetry path was found; kept identities and recovery journals stay local.

## Appendix: exact evidence

Captured the full diff once with:

```sh
git diff 65e272109ad906810ff3b8a3d01d217cd1fb1934..b2a8d192c4b7d41e48ccbe230510322eac9208b6
```

Captured diff SHA-256: `8e23329e9d0026e1971f08fda5136a1012a9371ed61122beee24fbe53234c5ba`.

`git log --oneline base..target`:

```text
b2a8d19 Acquire tracked Trash entries before verified permanent removal
1f44e66 Fix nested Rescue selection closure and isolate Trash test adapters
b1b8a12 Recheck Trash fallback authority and report held cleanup outcomes
b9e2baa Build ranked Rescue reviews and track cleanup Trash operations
33a06f8 Record the agreed Rescue redesign and research evidence
```

Scope: the 15 changed Swift app/test paths, related implementation/research contract and design documents, and prior R1–R5 report. Research URLs and API claims were not verified over the network. `git diff --check base..target` passed. No tests were run.

### Deterministic package regression to run on macOS

Use the existing disposable `TrashOperationTests.Fixture` adapter. Do not use Finder Trash. This recipe was source-checked, not executed or added to the suite.

```swift
let f = try Fixture()
defer { f.clean() }
let target = try f.prepare("Example.app", directory: true)
// prepare creates nested/deep/child and requires a ready preflight.
f.afterListing = { url in
    guard url == target.url else { return }
    f.afterListing = nil
    try Data([9]).write(to: url.appendingPathComponent("nested/deep/keep.qcow2"))
}
let outcome = DeletionService.performTracked(
    target, operation: TrashOperation(fileSystem: f, maximumEntries: 1))
// Required after correction:
#expect(outcome.error != nil)
#expect(FileManager.default.fileExists(atPath: target.url.path))
```

At this pin, the source path instead reaches `moveToTrash` and reports an untracked success. The fixture's root listing returns its existing `nested` child, then the hook inserts the protected file below an existing descendant. `capture` throws `.incomplete` at its child-count guard before walking descendants. No root entry, root mtime or root inode changes. `ScanIdentity.current` uses `BulkDirScanner.isPackageName`; `app` is in that extension set. `ScanIdentity.matches` permits the unchanged package root. The fallback's `.directory` comparison then skips the only live descendant scan. This is a testable check omission, not a claim that the ordinary final path race can be eliminated.

Production equivalent: a package with more than 10,000 children reaches the same budget branch while an owner adds protected contents below an existing subdirectory. Root replacement is unnecessary. The existing `budgetReplacement` test covers an ordinary folder replaced at its root and does not cover this case.

### Remaining proof and workspace boundary

Run native build and Trash suites, real disposable startup/external-volume Trash lookup, unsupported durability behavior, partial failures, owner transition, cancellation, capacity success/failure and recovery reveal. No native or release qualification is claimed.

A concurrent `docs/update/rescue-spec-review.md` appeared after pin. It was excluded from this committed review and left untouched. This pass writes only this report.
