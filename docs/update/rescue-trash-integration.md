# Tracked Trash integration

Outcome: Cleanup List moves retain the actual Trash destinations for one batch. The dock opens a separate review with no selection. Its second confirmation keeps Cancel as the default. Only this batch can authorize permanent finishing.

The view model freezes scanning and mutation during review and finishing. Source, selected source, root, revision and operation ID must still match. Rescanning, switching cached scans or starting a new cleanup revokes the prior operation. Successful moves are pruned even if destination tracking is unavailable. Tracking limits do not stop a recoverable move that passed the existing live preflight.

Moved bytes use the scanned allocated footprint, not the directory inode size. They are not a promise of reclaimed space. Held and failed outcomes remain separate. No file paths or names enter analytics.

Status: source integration only. All 72 Linux tool tests pass. Linux cannot compile SwiftUI or exercise Finder Trash. The path-based permanent-removal race flagged by the module author remains under review. Native build, tracked real-Trash fixture checks, keyboard review, independent risk review and both external CI lanes remain required.

The first native compile on `b1b8a12` stopped at the selection filter in RescueWorkspaceModel. The outer item now has an explicit name, so the inner kept-item closure does not refer to an anonymous argument from the wrong scope. The safety-gate tests also inject the temporary Trash adapter, including tests expected to reject before moving. Existing wrapper checks remove only disposable fixture files or pass missing fixture paths. No tests ran in that first attempt.


The next source revision wires VerifiedTrashRemoval into the tracked adapter. It acquires entries through directory descriptors and a private, journalled staging folder, verifies the old manifest and avoids recursive path removal. A typed partial failure stays held, and its recovery folder remains available in later reviews. No recovery map grants fresh deletion authority. Stop after current item cancels the remaining batch. These are source changes awaiting native proof, not a claim that POSIX eliminates hostile same-user mutation.

Risk fixes also revalidate the source before an over-budget untracked move, probe Xcode state again for each relevant item after validation, and publish a new capacity measurement after finishing. The original R1–R5 report remains preserved. The replacement mechanism needs its own source and native checks.
