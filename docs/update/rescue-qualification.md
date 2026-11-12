# Rescue release qualification

Current status: incomplete. No Rescue redesign release is published. The candidate is 0.2.3 build 15. The public release remains 0.2.2 build 14.

Owner scope update, 12 November: VoiceOver testing and narration are no longer release gates. The confirmed specification records the change. Historical narration results below remain evidence only; no further VoiceOver work is required. The experimental staging announcement was removed. Ordinary keyboard and cleanup safety checks remain in scope.

The full goal is the confirmed design in `docs/research/rescue-2026-11-11/design-spec.md`. A passing compiler, a source review or a mocked filesystem does not prove the whole flow. The release stays in 0.x.x.

| Requirement | Evidence so far | Required before release |
| --- | --- | --- |
| Largest-first discovery and 12 consumer families | Core patch passed 160 native tests; native fixture ranking and managed rows passed at 84df90d and 921afad | Exact release commit CI |
| Group review, explicit selection, Back, exclusions | Native keyboard, filtered Select all, Keep/Restore and Back passed. bfac606 exercised a 100,000-item review, search, End/Home, Select all/Clear and staging one item | Post-stage Tab/Space passed on the matching Views source. Earlier large-review observations are not p99 or staging-all proof |
| Owner routes, Retry, return refresh | Installed bundle IDs checked. Native bfac606 Finder handoff refreshed once; ordinary switching and missing UTM did not refresh. Native coordinator tests cover source changes and busy deferral | Native Checking again and Cancel retention passed; exact release commit CI remains required |
| Additional-GB goal and capacity labels | Native keyboard set a 1 GB goal; staged bytes did not advance it. Native coordinator tests cover negative, unknown and changed-volume readings | Exact release tests and post-action capacity check; no allocated-byte recovery claim |
| Recoverable moves and actual Trash destinations | Three real home-volume Finder Trash runs passed at 4f74c94; actual destinations and identity recorded | Exact release build and existing unsupported-volume holds remain enforced |
| Operation-scoped permanent finishing | Three public-adapter runs passed at 4f74c94; 921afad real UI removed only its owned item, sentinel preserved. Current private VM probe also passed root move, no-tree Finish and capacity reread with its unrelated sentinel intact | Final native preservation report and exact release gates; retain recovery fixtures and metadata-only limits |
| Confirmations and held results | Both native confirmations focused Cancel and cancelled on Return/Escape; review and files stayed; explicit confirmations succeeded | Combined-candidate acceptance and exact release tests |
| Window and appearance | Native captures passed at 820x652, 1100x700 and 1600x900. dde90cb proved initial Back/goal focus and Settings-already-key guard | Current keyboard delta and exact release checks |
| Keyboard and settings | Initial focus and Cancel checks passed. Contrast was enabled and restored with a cyan outline under accent 6. Motion settings were read back and restored; source disables press scaling when Reduce Motion is on | Post-stage Tab/Space passed. List arrows/Space were not repeated in that run; earlier native list checks remain separate. No VoiceOver or narration gate |
| Privacy and analytics | No new path-bearing analytics in reviewed changes; production policy unchanged | Automated-run exclusion and allowed new-flow payload checks; no names, paths, search, exclusion identity or raw errors sent |
| Release CI | Existing owned-hardware lanes and exact-head gates | Both signed reports for the final clean commit, full 400-trial campaign, unchanged limits and valid baseline comparison |
| Publication and updater | Existing 0.2.2 release infrastructure | Next 0.x version/build, signing and smoke, matching symbols, verified Sparkle feed and DMG, public asset readback and update path |

The completed core release-fix gate passed 160 Debug tests and unsigned universal Release. The current combined native run also reports 160 tests and universal Release passed, with the Theme actor warnings gone; its final report confirms preservation of production state and all nine Sample files. The final ordinary keyboard sequence and visible refresh/Cancel were not completed because the Mac was in use. Earlier abd0491/5e4c0f1 gates and their directory-open failure remain historical evidence below. No earlier source or mocked adapter qualifies the final release commit.

The first attempted diagnosis after reconnecting read the earlier evidence but ran no loop and proved no cause. Later focused runs below established the path, metadata and directory-open failures. The initial read-only attempt is neither a successful diagnosis nor an external blocker.

Record new evidence with its exact source hash. Preserve failed runs and all performance samples. Use fresh production-state baselines for each Mac run. No agent score is a recruited user study, and no area receives 9/10 without its own native evidence.

## Tracked Trash diagnosis, 12 November

The minimal native loop at 1f44e66 reproduced `subset` and `budgetReplacement`.
Foundation resolved the temporary path to `/var`, leaving a symlink that the
ancestor guard correctly rejected. `realpath` kept `/private/var`. The replacement
hook also missed its target because URL equality distinguished a trailing slash.
The native private-copy patch passed both focused tests. Its evidence is retained
at `/Users/abdwy/.local/share/tessera-trash-diag-nov12/`, including red.log,
green3.log, instrumentation.diff and fix.patch.

The branch now uses physical paths for tracking and path comparison in that hook.
Both disposable test fixtures also retain the physical temporary root. Symlink,
identity, volume and protected-path checks remain in place. The full Trash suites,
the newer descriptor helper and the full current suite still need native proof.

## Descriptor helper boundary, 12 November

At 0f3b392 both Trash suites compiled. The first run passed 16 of 28 tests and
failed 12. The first rejecting guard was the helper's parent-URL equality:
Foundation retained a trailing slash on one parent URL. A private-copy change
comparing the standardized paths passed all 28 tests with no other source change.
The branch now contains that change. No no-follow, identity or manifest check was
removed. Evidence is retained at
`/Users/abdwy/.local/share/tessera-qual-0f3b392-nov12/`.

The same run generated the missing Xcode project entries. The returned 15,223-byte
patch has SHA-256 `97d7918b7fa8563beef69731b0c4871fb929207c14433ff25e54bd54dc9b93f7`.
It was checked and applied without manual project edits. Full Debug, unsigned
Release and the production Finder Trash lookup remain unqualified.

## Passing native build gate at 84df90d

Exact revision: `84df90d2516411e9ce70afdf58a231d1e920d0b0`.
All 372 archive files matched Git blobs. XcodeGen 2.45.4 reproduced the committed
project without a diff. Both Trash suites passed 28/28; full Debug passed 152/152
in 12 suites; unsigned Release succeeded. Each command exited 0. The new owner
staging and permanent-removal checks ran in that full suite. The retained app is
still labelled 0.2.2 because the candidate version has not been bumped.

Private evidence: `/Users/abdwy/.local/share/tessera-qual-84df90d-nov12/`.
The report, commands.jsonl, both xcresults, test-name inventory, source manifest,
logs and before/after state snapshots remain there. Test automation excluded
analytics and the updater. Production preferences, process and original checkout
were preserved; all owned processes stopped. This is build/test proof only.
The real Finder Trash path, native UI/accessibility, exact final CI lanes and
publication remain separate gates. Local tooling also passed 72 tests and the
release-series validator on 12 November. Mock symbol-upload output is not live
symbol receipt or publication proof.

## Real Trash metadata race, 12 November

The production adapter probe at 84df90d moved two owned items successfully in
three focused runs, but review held both. macOS changed only the moved root's
ctime a few milliseconds after FileManager returned. Full manifest equality
correctly rejected the stale capture. The actual home Trash lookup had no alias.
Permanent removal was never reached. Owned items were restored by recorded
identity; production state and unrelated Trash stayed untouched.

Evidence: `/Users/abdwy/.local/share/tessera-native-trash-84df90d-ce8bb23d6598/`.
The superseded 5e4c0f1 patch waited for 20 ms of stable moved-root metadata before
capturing its manifest, with a 250 ms bound. Every probe still requires the original object's
identity, owner, mode, flags, size, blocks and mtime. A changed or unsettled item
gets no permanent-removal authority. Review and finish retain full ctime equality.
This runs after a successful move off the UI thread; it is not a scan timeout.
A disposable regression simulates the late metadata write and checks that a
ctime-only change after review remains held. Native red/green, the real Trash
probe and the full suite still need to qualify this new code.

## Replace the timing assumption with a review snapshot

The 5e4c0f1 native run passed the deterministic red/green fixture, all 153 tests
and unsigned Release. Its real Trash probe still held both moved roots: another
ctime-only update arrived 28–33 ms after the move, past the 20 ms quiet window.
Evidence remains at
`/Users/abdwy/.local/share/tessera-native-5e4c0f1-1393f633cc3d/`.
Increasing that wait would not prove completion of system metadata work.

The wait is now removed. A fresh review may accept only a ctime difference on
the moved root while its identity, mode, owner, flags, links, size, blocks and
mtime still match. Descendant states must match exactly. That review's complete
manifest stays private inside the operation and is bound to its one-use token.
Finish compares it exactly, including root ctime, then passes that same manifest
to the descriptor helper. A later root change stays held until another fresh
review. Root contents, permissions and descendant metadata remain regression
cases. Native proof and a fresh Risk review must qualify this policy before
release. This remains metadata validation, not a content-hash guarantee against
a hostile same-user writer who can restore timestamps.

## Native UI pass and focused repairs

The 84df90d UI pass used the exact retained Release app and a synthetic 15-file
fixture across nine families. Ranked rows, main-area review, no initial selection,
local search, Keep/Restore, Back position and selection, arrow/Home/End/Space keys,
Cleanup List review, Cancel as initial focus, Return/Escape cancellation, separate
capacity figures and additional-GB progress all passed. Layout was checked at
820x652, 1100x700 and 1600x900. The actual minimum window height is 652. No Trash
confirmation was accepted. Select all was present but not exercised. No 100k group,
VoiceOver or system accessibility setting was tested. Private report and captures:
`/tmp/tessera-84df-ui/REPORT.md`.

Six confirmed polish defects now have source repairs awaiting native checks:
new group focus goes to Back, keyboard staging returns focus to the rows, the GB
editor requests focus, kept-item narration uses singular/plural, unchanged goal
progress says it has not changed, and the row browser uses its cyan focus mark
without the native system ring. Asynchronous staging focus restoration checks the
exact owning key window, modal state, current review and current focus intent.

The reported seventh issue was checked against AX frames and pixels. The sidebar
content was scrolled 64 pt above its 380 pt viewport; the header did not overlap
it. A 15 pt background gap separated the header from the partially visible row.
This is normal clipping by a scroll viewport, not a layout defect. No sidebar
change was made. The sanitized 1100x700 capture was transferred and hash-checked:
`8ef5cf46ecec96492cc6d145cc0628b3463e8e6642918ab0adb63540fc8063c6`.


## Fresh review passes; real Trash descriptor open fails

At `abd049135af8bd80f2c8800d7ec1738217e6f8eb`, all 372 archive files matched.
XcodeGen made no change. Both Trash suites passed 30/30 and full Debug passed
154/154 in 12 suites. The controlled red test rejected a root ctime change when
the fresh-review allowance was disabled. A separate Risk review found no blocking
issue in that allowance or its private one-use manifest binding.

The first real Finder Trash probe moved both owned items and reviewed them
without holds. Their complete review manifests still matched immediately before
finish. Finish failed before removing any entry, with EPERM while opening the
Trash directory for reading. A narrow probe in the same test host opened every
ancestor successfully, rejected `O_RDONLY` on `.Trash`, and accepted `O_SEARCH`.
This establishes the failing open mode. It does not prove what permissions the
signed production app receives or whether a search-only descriptor supports all
required durability operations. A separate probe will check those operations
before a product change. The remaining real-Trash repetitions were not run.

Private evidence:
`/Users/abdwy/.local/share/tessera-native-abd0491-a1cf1b1a2288/`.
All owned Trash items were restored from their recorded destinations after
identity checks. No Trash listing or Empty Trash ran. Production state remained
unchanged and all job processes stopped. Release remains unqualified.

The separate Spec review of `abd0491..921afad` found no mismatch in the six UI
repairs. Native focus timing and the actual keyboard paths still need proof.


## Search-only container access

A narrow probe reproduced EPERM for the read-only Trash open from a child of
XCTest. The shell control could open it, so shell success alone was insufficient.
In that failing host context, a search-only Trash descriptor passed every required
operation: stat, filesystem checks, no-follow lookup, creation of a new private
staging folder, exclusive rename, exact-name unlink, fsync and F_FULLFSYNC. The
journal was durable before acquisition. Only the owned staging folder was read
for the helper's directory-name check. Private fixture controls also passed.
Evidence: `/Users/abdwy/.local/share/tessera-search-fd-514275e22ca0/`.

The helper now opens absolute directory ancestors and the Trash container with
`O_SEARCH | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC`. It never lists those directories.
Read-only access remains required for staging and reviewed item directories that
it must enumerate. All identity, owner, device, volume, manifest, exclusive-rename
and durability checks remain. The new regression denies listing access to both
a fixture ancestor and its Trash container, while permitting traversal and changes.
Native red/green, both suites and the public real-Trash adapter must qualify this
patch. A probe is not full-flow proof.

The native probe's final leftover check used a shell glob for its own prefix.
That enumerated Trash names, contrary to its brief. It read no item content and
changed nothing. Future cleanup checks must use the exact recorded names only.


## Search-only patch passes the real adapter

Exact `4f74c947468528a9d97ff7bd940d8a7df0835554` passed 155 Debug tests,
31 Trash/helper tests and unsigned universal Release. XcodeGen matched the
372-file archive. The read-only red control failed the new permission fixture
with EACCES before mutation. The restored search-only version passed.

Three actual Finder Trash runs each moved A and B, opened an unheld fresh
review, removed A alone, reviewed again, then removed B. The unrelated U sentinel
retained its identity and bytes throughout and was restored from its recorded
Trash destination. All 18 compared manifest entries matched after review and
before finishing. The public production removal helper ran from the CI test
host. No Trash listing, glob, count or Empty Trash ran. Production state stayed
unchanged. Evidence:
`/Users/abdwy/.local/share/tessera-native-4f74c94-aad72241d208/`.
A separate Risk review found no introduced issue in the descriptor change.

## UI acceptance and live counts

The 921afad native app passed both actual cleanup confirmations, initial Cancel
focus, Return/Escape cancellation, explicit Trash and permanent removal, and
unrelated sentinel preservation. Four UI repairs passed. Initial group focus
and initial goal-field focus failed, landing on toolbar controls. Their cause
is under a separate native timing probe. Evidence: `/tmp/tessera-921a-ui/`.
The run did not locate the nine Sample files, so that preservation claim is
unverified for this run. It also attempted an unnecessary bounded name search;
future runs must check only the known exact sample root.

Two count defects now have source repairs awaiting native red/green. Staged
items remain inspectable but are excluded from group selection and Add totals,
including a collected ancestor. Returning an item from the Cleanup List restores
eligibility. After successful removal, the VM rebuilds recommendations from its
pruned tree off the main thread, then publishes the updated report and plan.
This removes deleted rows and updates parent footprints without claiming a new
disk scan. Capacity is read separately and measured goal progress remains based
on Free now. New fixtures cover both transitions.


The count delta's Risk pass retained no finding. Its Spec pass found repeated
collector scans: each queued VM notification rebuilt the final collected-ID set.
The live observer now coalesces notifications into one deferred MainActor refresh
per synchronous burst. It reads values after publication and keeps the existing
source, revision and owner-return checks. A production-VM batch staging probe
must verify this correction; fake-host tests do not establish its cost.


## Proved initial-focus repair

The private 921afad trace established two distinct failures. Review `onAppear`
and `.task` ran before its window callback, so the guarded Back request did not
run. The callback arrived about 20 ms later. The goal field had the correct key
window, but SwiftUI dropped the focus write in its `onAppear`.

The integrated repair requests Back once, in the first window-attachment callback,
with the existing own-window, sheet, text-editor and current-review checks. The
goal button sets its focus binding in the same update that inserts the editor.
There is no delay, timer or retry. Native clean Release checks passed Back focus,
Tab to Search without bouncing, and Space then 1 then Return setting a 1 GB goal
without a mouse click. Settings remained key when opened shortly after attachment;
Settings already key at attachment and a second main window remain separate checks.
Evidence: `/tmp/tessera-921a-diag/`. The private native patch used the same two
behavior changes; the combined repository candidate still needs its full build
and native acceptance checks.

The count repair at 9450be1 passed controlled red/green for both new regressions
and all 157 Debug tests in 12 suites. Evidence:
`/Users/abdwy/.local/share/tessera-native-9450be1-a42120b906db/`.
The later observer-coalescing delta has a separate production-VM probe in flight.


## Production observer cost and final delta review

At 5e01a64, a private native probe used the real ScanViewModel and the live
workspace observer. It staged 1,000 virtual nodes through rescueStage, the same
host method used by group staging. Both versions emitted 3,000 VM notifications.
The old observer ran 3,000 workspace callbacks and read 3,000,000 collected entries.
The coalesced observer ran once and read 1,000 entries. The controlled red failed
only the two callback-cost assertions; green passed. Both public count regressions
also passed again after instrumentation was removed and source hashes restored.
Evidence: `/Users/abdwy/.local/share/tessera-native-5e01a64-a63df1617636/`.

This is a notification-cost proof, not a duration or p99 claim. It did not drive
stageSelection with a live group or establish linear total staging cost. Existing
per-item collector checks still scan the collector. The combined candidate needs
its separate native large-review check and external performance campaign.

Separate Standards and Spec rechecks of 9450be1..dde90cb retained no findings.
They verified deferred coalescing, weak coordinator lifetime, first-attachment
focus guards and explicit goal focus. Native combined acceptance remains separate.


## Prepared large group and owner lookup

The next UI fixture contains exactly 100,000 one-byte ordinary files named
review000000.dmg through review099999.dmg, with 409,600,000 allocated bytes.
A fresh inventory verified every name, regular-file type, single link and unique
inode. This prepares the native group review; it is not a UI or speed result.
Private fixture and manifest:
`/Users/abdwy/.local/share/tessera-rescue-large-20261111T231405Z-59929/`.
Manifest SHA-256:
`1d5fc5691dc121890984ec8baed32d176e69f3136f5541a8d2b81910c4bfa608`.

Read-only NSWorkspace lookups found exact bundle-ID matches for Docker, Xcode,
Photos, Mail, Disk Utility, Messages and Finder. OrbStack and UTM were absent.
Their existing missing-owner fallback still needs its native check. No owner app
was launched during inventory. The prep report checked a truncated Sample path,
so it does not establish preservation of the intended nine Sample disk files.


## Integrated focus, build and first actual VoiceOver pass

At dde90cb all 157 Debug tests passed in the correctly isolated test host, and
unsigned universal Release succeeded. A prior malformed-bundle-ID run is not
used as evidence. Native keys proved both initial-focus repairs, no initial
selection, Tab to Search without bouncing, and Settings already key before a
background review attached. The second-main-window case was not driven because
there is no public New Window command.

Actual VoiceOver started through System Settings and its caption panel supplied
spoken text for item, size, unselected and selected states, Add action, held
reason and Cleanup List review. Owner text and the Added result were not captured
as speech. The item label now includes its owner and allocated-size wording.
An experimental staging announcement was added after this pass. It was later
removed when Ammar ended VoiceOver testing and removed narration as a gate.

Increase Contrast and Reduce Motion were enabled, read back and restored to the
fresh baseline. A cyan row outline was captured with contrast on under accent 6.
The motion transition itself was not inspected. All nine Sample disk files and
all 14 owned fixture files matched before and after; production process and
preferences were preserved. Sixteen job domains and two owned Application Support
folders were removed. Raw captures remain private. Evidence:
`/tmp/tessera-dde9-ui/REPORT.md`.

The report called the unchanged two-item group after staging stale. That is
expected: staging does not remove its allocated footprint. The separate removal
regression verifies that the group shrinks after an actual removal. The Release
log's 13 warnings still need classification before final qualification.

## Final release review, round 1

Sol retained three Spec findings on bfac606. Standards and Risk retained none.
The fixes are prepared, with native proof pending:

- New removal results leave the legacy capacity target unset. Result text no
  longer grades that target, including when an older saved case is displayed.
  The optional additional-GB goal remains owned by the workspace coordinator.
- ContentView keeps the previous Rescue result during a same-source refresh.
  First discovery and a different-source scan still use the scan screen. A
  regression checks source identity, the retained timestamp and Cancel. Native
  window evidence must separately prove the Checking again state is visible.
- Successful removal of the scanned root clears the tree and its cached scan.
  The rebuilt report is empty. The result, source identity and tracked Trash
  operation remain available, and the dock can show them without a scan tree.
  A disposable-root regression checks the tree, recommendations and result.

The native red control uses the old VM and result-status implementation with
the new tests. It retains only the new source-display predicate so the test
file compiles. That predicate is not used by the three red removal cases.
Full Debug, unsigned Release, the next Sol round, final native acceptance and
both exact-head external CI lanes remain required before publication.

## Large review and remaining narration failure

The bfac606 native pass built unsigned universal Release and verified all 372
source blobs. Actual VoiceOver spoke the new owner label, selected state and
Add action. It did not speak the Added result in three attempts. The text was
on screen, and focus returned to the rows. This does not prove whether the
announcement was skipped or replaced. A later candidate used AppKit's
window-targeted announcement. That experiment was removed under the owner
scope update above. Evidence:
`/tmp/tessera-bfac-ui/REPORT.md`.

The same run verified the owned 100,000-file group. End, Home, single-item
staging, search, Select all and Clear worked. Only 17 rows appeared in AX at
each tested size. Opening and reopening took 5.60 and 4.90 seconds in single
observations; peak sampled RSS was 584 MB. These are not p99 results. The
scanning heartbeat does not measure review responsiveness. Back restored group
focus and selection but not the review's End scroll position.

Finder return started exactly one refresh; a later ordinary app switch started
none. Missing UTM showed steps and Retry without arming a refresh. Empty and
partial states passed. Cancel was exercised through AX. Reduce Motion was
restored, but 200 ms captures did not establish transition behavior.

The pass also found that the list's Space handler can consume a key meant for
a Tab-focused row button. Each row button now has its own focus value, so the
list handler can distinguish those targets. This repair still needs native
red/green proof. Managed-store guidance now warns that the fresh check clears
the Cleanup List and calls the app a management route rather than claiming it
owns every row. The three existing Theme main-actor warnings have a scoped
actor-isolation repair awaiting compilation. No warning fix is claimed yet.

The Mac relay became unreachable after this report. A headless red/green job
was already running on the earlier release-fix patch. Keep that task and its
evidence separate from the later row-focus and warning changes. A new native
announcement probe could not start. That work is now cancelled. Remaining
keyboard/refresh checks and both exact-head CI lanes still gate publication.

Finishing a tracked operation now attempts a fresh capacity read even when the
removed source was the scan root and no tree remains. A missing source keeps
capacity unknown and the goal unverified. The root-removal native follow-up must
exercise this branch through the VM and the real tracked operation, including
continued access to Finish and the unrelated-item sentinel.

## Release-fix test results received before the final report

The native task's recorded xcresult summaries establish that the earlier
39a9f6b6 patch passed all 12 removal regressions and all 160 Debug tests in
12 suites, with zero failures or skips. The source manifest matched after both
runs. The red control compiled and failed only the seven intended assertions
across three tests: legacy status, new and saved requested bytes, and the stale
root and recommendations. The recorded full-Debug command exited 0.

Evidence is under `/tmp/tessera-sol-test-20261112024653-35630/evidence/` on the
Mac. The final report now also confirms unsigned universal Release passed,
matching app/dSYM UUIDs, preserved production state and all nine sample files,
and cleanup of only the job's own domains and build output. The report is
`/tmp/tessera-sol-test-20261112024653-35630/REPORT.md`.
These results do not cover the later row-button focus bindings, actor
annotations, source-path normalization, AppKit announcement or no-tree Finish
capacity read. They do not qualify the current commit for release.

## Combined candidate gate and scope closure, 12 November

Private evidence: `/tmp/tessera-c75d-test-20261112031222-60206/REPORT.md`.
The 24,119-byte patch on bfac606 had SHA-256
`7fd0aead027d99927908dc66bd7eb3591f2a625a2fc0eabdebdf5103ed5b59db`.
All 372 base blobs matched. XcodeGen produced no project change. Debug passed
160/160 tests, and unsigned universal Release succeeded. Theme actor warnings
are gone. The retained binary and dSYM UUIDs match.

The private public-VM probe moved the scanned root to actual Finder Trash,
cleared the tree and recommendations, retained the tracked operation, and
finished only that root and its child. Its unrelated sentinel stayed intact
and was restored from its exact recorded destination. The checked time
advanced without a tree. This does not prove reclaimed bytes.

Tab then Space on the first row selected that row. The Mac then became busy,
so the guard blocked later input. The post-stage second-row Space/Return and
visible same-source Checking/Cancel paths remain unverified in this run.
The view-model refresh regression and reviewed rendering guards are the
available evidence for that change. No further interactive run is started
while the Mac is in use.

All nine Sample files, production PID and preferences stayed unchanged. The
agent removed its own 13 preference files and build caches; no owned process
remains. After this run, the owner removed narration from scope and the
experimental announcement block was deleted. Version metadata is 0.2.3/15.
Both external CI lanes must still qualify the final clean commit.

## Exact-head native p99 rejection at 36e80ff

The native report for `36e80ff42baf515034ac4466647e3790e84d9da1`
authenticates but does not pass the release verifier. All 160 tests, unsigned
universal Release and all 12 command steps passed. All 400 trials completed
with matching counts and no coverage gaps. The heartbeat gate passed; its
maximum was 318.6 ms. The p99 regression gate rejected `unicode2k` first.
`wide100k` also exceeds both regression conditions.

| Cohort | Samples | Current p99 ms | Baseline p99 ms | Increase ms | Regression gate |
| --- | ---: | ---: | ---: | ---: | --- |
| deep420 | 100 | 439.6 | 402.5 | 37 | Pass |
| mixed20k | 100 | 599.0 | 374.2 | 225 | Pass |
| unicode2k | 100 | 1212.1 | 408.5 | 804 | Fail |
| wide100k | 100 | 1132.6 | 549.2 | 583 | Fail |

These are nearest-rank p99 values for warm synthetic fixtures on this M1 Max,
32 GB, macOS 27.0.1, Xcode 27.2 host under the installed Standard/Nice 10/low-I/O
recipe. Baseline metadata matches. This is not a population performance claim.
The current minimums for the two failed cohorts also exceed the baseline p99.
The analyzer reproduced its saved output byte for byte. The exact installed
gate replay on retained inputs raises `Full-pipeline p99 regressed in unicode2k`.
Private evidence: `/tmp/tessera-diag-36e80ff.S06Z/`. No sample, threshold or
baseline changed, and the completed failure was not retried.

A separate old/current/old comparison used existing hashed binaries, one owned
2,000-file Unicode fixture, and ten trials per run. Median whole-trial times
were 292/1115/289 ms. Diagnosis medians were 28/848/32 ms; enumeration medians
were 52/46/46 ms. Every count matched. These are medians from a diagnostic
comparison, not p99 or CI qualification. Private evidence:
`/tmp/tessera-perfab-36e80ff.Edp1uQ/`. No UI ran with this comparison.

The proposed change reuses category matches from the existing coverage pass.
It keeps file discovery, protection, package boundaries and rule order. Its native tests and controlled comparison are recorded below. Exact-head
external qualification remains required.

## One-pass classifier candidate proof

The patch reuses category matches from the coverage pass instead of repeating
rule matching and lowercase path assembly in discovery. The native patch has
SHA-256 `2c93869bcd82feaa0dd42b35617aaf7e8e2da0d9b024c216c5f8ce5d65c2b4ef`;
`CleanupSuggestions.swift` is
`4ec071fa077792772b8de4b986e71ab7d0c9d4c3180a39256710d28b20b3a076`.
Sol round 3 approved this source delta with no Standards, Spec or Risk findings.

The private archive matched all 372 base blobs and XcodeGen produced no project
change. Debug passed 160/160 tests with no failures or skips. Unsigned universal
Release succeeded. Evidence: `/tmp/tessera-clsfy-36e80ff.B3gpaw/`.

A current/patched/current diagnostic comparison used five trials per cohort
per run, 30 trials total, on identical warm synthetic Unicode-2k and wide-100k
fixtures. All counts matched, coverage gaps were zero, and no heartbeat exceeded
500 ms. Diagnosis medians changed from 839–869 to 436 ms for Unicode and from
705–720 to 377 ms for wide. Patched whole-trial medians were 703 and 766 ms.
These are diagnostic medians, not p99 qualification. This M1 Max host had load
averages about 22–25 during the comparison.

The native report mistakenly used baseline p99 values (408/549 ms) as absolute
limits and concluded the patch would fail. The actual reviewed gate rejects
only when both `after > before * 1.5` and `after - before > 500` hold. The
medians above do not trip that condition. Five samples do not establish what
the full campaign will do; both external lanes must qualify the next exact
clean commit. No baseline, threshold, fixture or sample requirement changed.

## External qualification at a7420c8 and corrected native paths

Both reports for `a7420c8d0187b0b3472ad591a9c5d52074bacbb2` passed HMAC,
recipe and exact-revision checks. Native passed 160 tests, universal Release
and all 400 trials. Every cohort has 100 complete samples with matching counts,
zero coverage gaps and no heartbeat over 500 ms. The unchanged baseline
regression gate passed. Warm synthetic p99 values on the same M1 Max/macOS
27.0.1/Xcode 27.2 host were deep 443.3 ms, mixed 462.7 ms, Unicode 805.2 ms and
wide 834.5 ms. These are this host's cohort results, not population p99.

The corrected UI run at `/tmp/tessera-pr5-ui2-kqSB/` used the retained 36e80ff
app after verifying its Views sources match a7420c8. It ran only after CI
stopped and held the runner lock during one quiet 38-second input window.
AX staged the first cache item. Two real Tabs reached the second row's select
button, and real Space selected it while the first stayed in the Cleanup List.
Focus returned to the review scroll area. List arrows/Space were not repeated:
the driver rejected AXScrollArea as a list target and sent no keys.

In Rescue, an AX Rescan kept the old group and checked time while showing
Checking again. A guarded HID click on Cancel changed the text to Scan stopped,
showing previous results; the same group and checked time remained. The scan
did not publish a second result. Existing legacy scripts had missed Rescue mode,
read labels instead of AXValue, and lost target-miss exit codes through tee.
The private corrected driver verifies focus before each action and spaces keys.

All nine Sample files, production process/preferences, existing CI domain bytes
and the original checkout matched fresh baselines. Created automation domains
were backed up and removed. No owned process or runner lock remains.

## Three retained state findings

GitHub review identified three intended-use bugs still present at a7420c8:
a mixed managed category could use its largest item's owner route for another
app's item; finishing tracked Trash left the old Trash-move verification and
saved case; and a goal could read an unscanned selected source while another
report remained displayed. Parent fixes and three regression declarations
(including all/partial Finish parameters) are prepared. Sol round 4 approved
all six changed files with zero Standards, Spec or Risk findings. Controlled
native proof passed for this exact six-file patch, SHA-256
`4b941b82ef6fcb9080748161121f2ba70ef7a674c065e5f149d511fc60aed5ce`.
RED compiled and failed all three focused tests on 22 intended assertions.
GREEN passed the three focused tests, including both Finish parameters, all
163 Debug tests and unsigned universal Release. XcodeGen left the project
unchanged. Evidence: `/tmp/tessera-g123-test-20261112042231-17100/REPORT.md`.
Production state and all nine Sample files matched fresh snapshots. Own
processes, test domains and rebuildable caches were cleaned up. The tests prove
model behavior, not rendered owner text or the reveal button in the app.
Both external lanes must qualify the final commit. No new narration work is required.
