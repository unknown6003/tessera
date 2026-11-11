# Rescue release qualification

Current status: incomplete. No Rescue redesign release is published. The working version remains 0.2.2 build 14 until the next release candidate is prepared.

The full goal is the confirmed design in `docs/research/rescue-2026-11-11/design-spec.md`. A passing compiler, a source review or a mocked filesystem does not prove the whole flow. The release stays in 0.x.x.

| Requirement | Evidence so far | Required before release |
| --- | --- | --- |
| Largest-first discovery and 12 consumer families | Full Debug passed 157 tests at 9450be1; native fixture ranking and managed rows passed at 84df90d and 921afad | Exact release commit CI and remaining owner handoff checks |
| Group review, explicit selection, Back, exclusions | Native keyboard, explicit selection, filtered Select all, Keep/Restore and Back passed; staged-item regression passed at 9450be1 | Integrated focus recheck and native 100,000-item review |
| Owner routes, Retry, return refresh | Coordinator tests and source review | Verify installed app IDs and supported routes; native one-return refresh, failed owner, source change and busy cases |
| Additional-GB goal and capacity labels | Coordinator tests; old 75% confirmation text removed | Native same-volume capacity success/failure, negative change and post-action refresh |
| Recoverable moves and actual Trash destinations | Three real home-volume Finder Trash runs passed at 4f74c94; actual destinations and identity recorded | Exact release build and existing unsupported-volume holds remain enforced |
| Operation-scoped permanent finishing | Three public-adapter runs passed at 4f74c94; 31 Trash/helper tests passed; 921afad real UI removed only its owned item, sentinel preserved | Exact release gates; retain recovery fixtures and metadata-only limits |
| Confirmations and held results | Both native confirmations focused Cancel and cancelled on Return/Escape; review and files stayed; explicit confirmations succeeded | Combined-candidate acceptance and exact release tests |
| Window and appearance | 84df90d native captures and keyboard checks at 820x652, 1100x700 and 1600x900 passed; six focus/text repairs still under check | Captures at minimum, standard and wide sizes; sheets, long names and focus without overlap |
| Accessibility | Source labels, keyboard handling and contrast tokens | Real VoiceOver narration; Increase Contrast and Reduce Motion with restored settings; fixed ten-area rubric with reference evidence |
| Privacy and analytics | No new path-bearing analytics in reviewed changes; production policy unchanged | Automated-run exclusion and allowed new-flow payload checks; no names, paths, search, exclusion identity or raw errors sent |
| Release CI | Existing owned-hardware lanes and exact-head gates | Both signed reports for the final clean commit, full 400-trial campaign, unchanged limits and valid baseline comparison |
| Publication and updater | Existing 0.2.2 release infrastructure | Next 0.x version/build, signing and smoke, matching symbols, verified Sparkle feed and DMG, public asset readback and update path |

The latest completed Debug gate is abd0491: both Trash suites passed 30 tests and the full suite passed 154 tests in 12 suites. XcodeGen matched the committed project. The latest unsigned Release gate is 5e4c0f1, before the fresh-review policy and focus repairs. Real Finder Trash review passed at abd0491, but finishing stopped at a directory-open permission error. None of these results qualifies the final release commit.

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
The Add action posts its outcome as a high-priority accessibility announcement
after any guarded focus restoration, only while the current review and owning
key window remain valid. Native narration still must qualify these changes.

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
