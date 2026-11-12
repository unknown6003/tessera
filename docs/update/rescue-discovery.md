# Rescue discovery implementation

Outcome: discover managed disk files and owner stores, split broad review roots,
and rank measured allocated footprints by size. This unit changes only
`Tessera/Engine/CleanupSuggestions.swift`, `TesseraTests/EngineTests.swift`, and
this note in the shared `codex/rescue-redesign` workspace.

Proof: thirteen new public-interface regression tests are in the existing
`EngineTests.swift` target. Native execution is pending on Mac. Linux source
inspection and `git diff --check` passed. No Swift compiler or `xcodebuild` is
available on this host. No native tests, performance samples, or product
qualification are claimed.

Constraints: no filesystem reads in classification, hydration, owner commands,
user-drive scans, child agents, checkout changes, commits, installs or releases.
The parent owns combined native proof and independent risk review. The source
pass here is a self-review, not an independent review.

## Interfaces and compatibility

- `CleanupClassifier.classify(root:ownerState:coverageComplete:shouldStop:)`
  keeps its signature. It now classifies the source itself, including a regular
  disk file or an exact category root.
- `CleanupRecommendation.init` adds optional `measuredPhysicalBytes` for the
  classifier to pass its local footprint. Existing direct callers keep the
  node-allocation default. The scan tree itself is not mutated.
- `CleanupClassifier.ruleVersion` is `rescue-2026-11-11.1`.
- All old category IDs remain in `CleanupCatalog.all`. Docker now gets
  `owner.docker` rather than `owner.virtualdisk`. Generic VM disks keep
  `owner.virtualdisk`.
- New protected IDs are `owner.docker`, `owner.orbstack`, `owner.simulators`,
  `owner.photos`, `owner.media`, `owner.mail`, `owner.snapshots`, and
  `owner.archives`. New review ID `user.largefiles` covers unclassified large
  files and packages.
- `protectedCategory(for:)` keeps protected ancestor precedence. An outer
  protected store owns a child whose name looks like another disk or cache.
  `protectedCategory(atNormalizedPath:name:)` remains available to live preflight.
- `hasProtectedDescendant` and `hasOpaqueDescendant` accept an optional
  `shouldStop` closure. Existing calls remain valid. An interrupted safety walk
  returns true and classification discards the interrupted report.
- `CleanupReport.groups` and stored `rankedRecommendations` sort by descending
  allocated bytes, then category ID, path and name. Risk is only a final
  deterministic tie for otherwise identical records. Groups still separate
  different risks within a category for old callers. Their IDs stay compatible.
- Ranking is computed once at report construction. Group totals are cached.
  `safeGroups`, `reviewGroups`, `protectedGroups`, `safeNodes`, and
  `safeTotalBytes` remain available. Input `recommendations` retain input order.

## Discovery and counting

The rules now run on files as well as directories. Docker.raw and Docker.qcow2
get Docker ownership. Generic qcow, qcow2, vmdk, vdi, vhd and vhdx files, and
pvm, utm and vmwarevm bundles, stay protected. OrbStack discovery covers the
`.orbstack` store, including its data.img. The classifier does not treat the
`~/OrbStack` view as a second backing-store recommendation.

Owner rules also cover CoreSimulator, Photos and media-library suffixes, Mail,
Xcode archives, and named snapshot stores. Existing backup, cloud, profile,
communication and Trash rules remain protected. Snapshot-store rows represent
only their scanned allocation. They do not enumerate APFS snapshots.

Caches and Downloads become child review scopes. Known descendants get their
specific categories, even through an otherwise unknown child folder. Unknown
files and folders remain in the broad review category. A folder without a
specific descendant can stay one review unit. The broad parent is omitted when
its children are represented. Specific matches remain whole units and subsume
their children. This produces no ancestor/descendant overlap from classification.

Packages stay whole discovery items. The metadata pass may inspect their
already assembled nodes for coverage gaps, but it does not expose internal
cleanup categories. Cloud-only, mounted-volume, aggregate and Hidden Space
nodes never become file recommendations. Their bytes are subtracted from a
represented parent footprint, so a simulator image and its synthetic mounted
view do not count twice within one owner row. Opaque descendants split broad
review fallbacks or hold generated candidates. No backing image and mounted view is
added as two recommendations by traversing a synthetic boundary.

Unclassified files and packages at least 1,073,741,824 allocated bytes get a
review prompt. This matches the existing Large & Old lens default of 1 GiB at
any age. It makes no age, junk, safety or recoverable-space claim. Smaller
unclassified files outside the broad review scopes remain outside Rescue.

## Coverage and action limits

Gap paths are indexed once. A gap equal to, above, or below a candidate holds
that generated candidate in review. A sibling gap or an unrelated synthetic
boundary does not demote it. Prefix siblings such as DerivedData-other do not
overlap DerivedData. Gaps on the source and its attached ancestors are included.

The legacy `coverageComplete: false` flag without any located gap or known
boundary remains conservative and demotes generated items. A true flag cannot
override a relevant recorded gap. If the caller knows the source is unreadable,
it must keep its blocked coverage and scan state; classification cannot verify
readability without I/O. Missing, mismatched, non-directory or package identity
cannot make a generated rule safe. Active or unknown Xcode ownership still
holds it in review.

Classification never proves live freshness or removal permission. Existing
staging and final deletion preflight must still check current identity, owner,
permissions, relevant gaps, protected descendants and live contents. No deletion
code or ViewModel code was changed in this unit.

Hidden Space guidance now calls it unaccounted usage, explicitly says it is not
measured snapshot reclaim, and points to Disk Utility or Time Machine. It is
not a byte-bearing snapshot recommendation or a promise of free space.

## Work bounds

The metadata index and discovery use iterative walks. They hold at most work
proportional to assembled nodes and gap paths, plus path strings. Metadata
inside packages is read from memory only. Specific matched subtrees are not
rescanned once per ancestor. Descendant safety walks run only for emitted
safe-rule candidates, whose subtrees do not overlap.

For N nodes, G gap paths and R recommendations, tree work is linear in the
visited tree and path lengths with a fixed rule count. Gap sorting costs
O(G log G). A candidate overlap check uses ancestor lookups plus O(log G)
search, rather than scanning every gap. Report ordering costs O(R log R) once.
There is no arbitrary row cap that silently drops a known measured finding.
Cancellation is checked in walks, child-enqueue loops and gap insertion.
Standard-library sorts finish before cancellation can be observed again.

These are source bounds, not a timing or memory benchmark. The new wide fixture
has 20,000 items and 2,000 unrelated gaps. The parent must still run native
performance qualification. No p99 claim is made.

## Native regressions to run

`RescueDiscoveryTests` is a suite appended to `EngineTests.swift`, so it needs
no project-file registration. Its thirteen tests are:

| Test | Public behavior |
| --- | --- |
| `fileBackedDisks` | Regular managed disks, direct file source, allocated totals |
| `ownerCategories` | Owner-specific precedence, nested source paths, prefix boundaries |
| `cacheSplit` | Homebrew, other cache data, nested installer split |
| `downloadsSplit` | Installers, personal files, Photos, no overlap |
| `exactSourceRoot` | Exact generated source, owner and identity gates, wrong type/path |
| `noOverlap` | One node_modules container, nested bytes subsumed |
| `rankedOrder` | Large protected item first, stable category and path ties |
| `relevantCoverage` | Relevant/unrelated/ancestor gaps and unlocated failure |
| `opaqueBoundaries` | Packages, cloud-only data, mounts, protected and opaque descendants |
| `ownerFootprintExcludesBoundaries` | Backing image counts once; mounted usage excluded without tree mutation |
| `unclassifiedLargeFiles` | Inclusive allocated threshold, any age, review only |
| `hiddenSpaceGuidance` | Residual guidance without measured snapshot recommendation |
| `wideDirectory` | All 20,000 items once, 2,000 gaps, cancellation discards partial work |

Two existing Engine tests changed only the approved behavior: an unrelated gap
no longer demotes DerivedData, and `.docker` has Docker-specific ownership.
The old protected-descendant cases in `ScanRegressionTests` were inspected and
left intact. Their expectations still require generated parents containing
protected descendants to stay in review.

On Mac, run the full Debug test suite, including existing scan and removal
regressions. A focused command is:

```sh
xcodebuild -project Tessera.xcodeproj -scheme Tessera -configuration Debug \
  -destination platform=macOS -only-testing:TesseraTests/RescueDiscoveryTests test
```

Run it with the native host deadline supervisor. The full suite is still
required for combined integration. Linux did not run this command.
