# Rescue redesign specification

Status: confirmed for implementation on 11 November 2026. The consumed decision is recorded in design-confirmation-response.json.
Base main: 65e272109ad906810ff3b8a3d01d217cd1fb1934, which contains the released 0.2.2 changes.
This file records the agreed design. Product implementation and native qualification are tracked in docs/update/rescue-review-triage.md.

Outcome: people can find the largest storage consumers, understand their next action, and recover usable space without guessing which files are disposable.
Proof: native fixture flows, keyboard and VoiceOver checks, captured states, release CI, and direct comprehension checks. Agent scores and desk research are not user-study results.
Constraints: keep Tessera's name, flat dark interface and cyan accent. Releases stay 0.x.x. Preserve privacy, current identity, owner, protected-path and busy checks. Healthy local scans continue past 120 seconds; p99 completion within that time is a goal, not a timeout.

## Owner decisions

Three replies were consumed. Exact values and submission times are in round-1-response.json, round-2-response.json and round-3-response.json.

- Lead with biggest useful actions. Adapt one screen for everyday and developer Macs.
- Include large app-managed stores, with a route to their owner.
- Use one list, ordered by storage footprint rather than risk tier. Inspect group items before staging.
- Open group review in the main content area. Back restores the results and position.
- Remember kept items, with an inspectable exclusion list.
- Automatically refresh after returning from an owner opened through Tessera.
- Offer a separate, operation-scoped permanent-removal step after a Trash move.
- Show known results with visible coverage gaps. Hold unverified actions.
- Make the optional goal an additional amount of GB.

The details below are the implementation interpretation confirmed by the owner. The three earlier answers are preserved separately.

## 1. Main screen

Keep Explore and Rescue in the existing flat window. Rescue opens directly to results when a scan exists. Before a scan, show one Scan action. Do not force a capacity goal or onboarding form before discovery.

Use a compact header: source, checked time, Available for use, Free now, and an optional Set a space goal action. Explain the two capacity figures in detail on demand. Both cover the drive containing the source; scanned file totals cover the source only.

Below it, show one ranked list. Each row contains:

- A plain name and known owner.
- Storage used, labelled as allocated footprint where measured.
- A short reason to review it and the consequence of removal or eviction.
- One clear next action: Review files, Review options, Open owner, or another verified owner-specific route.
- A Keep action and an inspectable full path in detail.

Sort known allocated footprints largest first, with a stable tie order. An unknown value stays unknown; put unmeasured findings in a labelled section after measured rows. Do not manufacture zero or a recovery estimate. Never label a whole managed store disposable because it is large.

Offer All, Files to review and Managed by apps filters. Keep counts and exclusions visible. Search operates locally and sends no search text. Avoid a second overview dashboard, safe-first section stack, repeated totals, or a fixed 75% goal.

## 2. Discovery and counting

Discovery must identify files as well as directories. Split useful child categories under broad parents instead of stopping all traversal at Caches or Downloads. Maintain bounded work, cancellation, package and owner boundaries, and a non-overlapping representation. Do not solve shadowing by blindly recursing into every package or cloud object.

Cover these consumer families through measured discovery, review or owner guidance:

1. Xcode build data and installed simulator storage.
2. Docker and OrbStack stores.
3. VM bundles and disk files.
4. iOS device backups.
5. Photos and media libraries.
6. Messages and Mail stores.
7. App caches.
8. Package caches and project build artifacts.
9. Downloads and installers.
10. Local cloud copies.
11. Trash.
12. Snapshots, purgeable space and unaccounted usage.

The coverage-and-hogs.md matrix records the source evidence and management limits. A family is not automatically a direct-delete category. Use exact supported owner routes, and say when the route or measurement is unavailable. Do not invent typical savings or scan a user's drive to fill the mock data.

Do not add parents and children, backing images and mounted views, or remote logical data and local residency into the same total. Hard links and APFS shared blocks make allocated size different from exclusive recovery. Hidden Space is a residual, not a measured snapshot total. Purgeable capacity must not be added again to a capacity value that includes it.

## 3. Group review

Open the group in the main content area, with Back to Rescue, its scope, count and storage used. Show individual items, owner information, reason, effect and full path on demand. Keep name, size, sorting and selection stable as detail opens.

Nothing starts selected. Support explicit multi-selection and Select all within the visible, eligible review scope. The action says how many items and bytes it will stage. Protected or uncertain items stay unselectable and explain their next route. A parent checkbox must not silently select hidden protected descendants.

Add chosen items to the existing Cleanup List. Back retains the list position and user selection, but revalidates before staging or removal. Any source, scan revision, owner or identity change invalidates stale action snapshots. Do not mix objects from two scan revisions.

Use the existing bounded list approach for large groups. Avoid row-ID scans, repeated full sorting and eager construction of 100,000 row views.

## 4. Managed stores and return refresh

The detail view explains the store, owner, storage footprint, data at risk, and the supported management route. Open the owner or a specific supported settings route. A fallback explains the steps and can reveal the item; it does not show a dead Owner handoff label.

Do not execute destructive Docker, snapshot, VM or cloud commands merely because the user opens the row. Generic deletion is not cloud eviction. A local cloud action must use a supported provider mechanism without hydrating remote data.

Record a pending handoff only after opening the owner through this flow. When Tessera becomes active after that handoff, start one automatic fresh check of the same source. Do not rescan on every ordinary app switch. Coalesce repeated returns, respect the scan/removal busy lock, and discard a pending return if the source changed.

Show Checking and keep the previous result labelled with its checked time until a new result publishes. Cancellation preserves that prior result. A failed launch or failed check explains the issue and offers Retry. An owner returning does not by itself prove a cleanup occurred.

## 5. Kept items

Remember explicit Keep choices locally. Show excluded count, a Show excluded view, and Restore suggestion. Do not send exclusion paths or object identities to analytics.

Match an exclusion to the intended object and source identity, not only a reused name or path. A replacement object must not inherit the old object's exclusion. A kept container is not a blanket ignore rule for unrelated categories or volumes. Explain any exclusion whose object cannot be resolved. Revalidate any restored candidate before action.

The HTML demo keeps its exclusions in memory only. Persistence and source matching require product tests.

## 6. Review, Trash, and permanent removal

Keep the current Cleanup List snapshot review, full paths and explicit Move to Trash confirmation. Cancel returns to the same review. Report moved, held and failed counts from that action, without an unrelated Rescue recommendation count or stale notice hiding the result.

After the move, show both the move result and a separate capacity reading. Do not mark a goal reached from staged or moved bytes.

Offer Finish these Trash items as a separate step. It must:

- Include only items that this specific operation successfully moved to Trash and can still identify there.
- Show the exact current items and scope before a second confirmation. Say permanent removal cannot be undone. Cancel is the initial focus.
- Revalidate the current volume, identity, location, owner/protection rules and relevant content state. Restored, replaced, changed, missing or otherwise unverified objects are held or reported; they are not retargeted.
- Exclude all unrelated Trash contents. Never fall back to Empty Trash, delete an original path, or follow a replacement link.
- Report removed, held and failed items separately, then measure capacity again. Keep failed items inspectable and do not claim all allocated bytes were recovered.

If the operation's identity tracking is lost, disable the in-app permanent step and provide a safe Finder route. Restoring a manifest across launches must pass the same checks; absent proof, do not resume permanent removal after relaunch. Native implementation and risk review must establish this boundary before shipping it.

## 7. Partial results and goals

A partial scan can show verified known items with one concise coverage notice and an inspectable missing-area list. Do not label it complete. Relevant unreadable areas, protected descendants, owner activity and stale identity can still hold a candidate. A readable sibling is not automatically blocked solely because an unrelated area is missing. Keep discovery confidence separate from removal permission.

The optional goal asks for additional free GB. Establish a same-volume Free now baseline when it is set, then show the measured change and checked time. Keep Available for use separately labelled. Other app writes and system work can affect the change; do not attribute the whole change to Tessera.

Unknown or failed capacity reads keep the goal unverified. A later loss of free space updates its status. Staged bytes, owner disk limits, and Trash bytes do not advance measured progress.

## 8. Native behavior and delivery proof

Support 820x600 minimum content constraints and wide windows without overlapping sheets, clipped primary controls, or a large gap between related panels. Keep focus visible, selection stable and name paths readable on demand. Respect Increase Contrast and Reduce Motion.

Verify the whole keyboard path, including group Back, explicit selection, Cleanup List review, both confirmations and Cancel. VoiceOver must expose item, size, owner, selected state, action, result and held reason. Test actual narration; AX labels alone are not proof.

Required regression fixtures include VM disk-file discovery, nested categories, non-overlapping totals, owner stores, absent owners, cloud-only data, gaps outside and inside a candidate, stale scans, replaced identities, changed Trash files and folders, wrong-operation Trash items, missing manifests and source changes. Test empty, scanning, cancelled, permission, partial, failure and post-action states.

Retest the 100,000-item browser and deep paths through the closest native interface. Preserve every sample and the existing performance gates. Report sample counts, hardware, workload, cache state and coverage for performance claims. Keep UI checks and native performance CI from competing on the same Mac.

Use only anonymous allowed action classes and outcomes for new flow analytics. Do not send paths, names, contents, search text, account names, local exclusion identities or raw error text. Automated tests and benchmarks stay outside production telemetry.

Run source review, native tests and captures. Both external CI lanes must qualify the exact clean release commit outside GitHub Actions. Then sign, verify the update feed and artifact, and ship 0.x.x updates. Do not claim a 9/10 score or usability success without its evidence.

## Design evidence limits

The reference review checked 12 claims and four public threads. The engine audit checked source and test assertions, not a new native run. Anonymous usage has 12 allowed events from one ID in the checked 30-day window, with no cleanup events. No new recruited interviews or usability study has taken place. The flow demo uses synthetic data and performs no real I/O. These are design inputs, not product qualification.
