# Tracked Trash integration

Outcome: Cleanup List moves retain the actual Trash destinations for one batch. The dock opens a separate review with no selection. Its second confirmation keeps Cancel as the default. Only this batch can authorize permanent finishing.

The view model freezes scanning and mutation during review and finishing. Source, selected source, root, revision and operation ID must still match. Rescanning, switching cached scans or starting a new cleanup revokes the prior operation. Successful moves are pruned even if destination tracking is unavailable. Tracking limits do not stop a recoverable move that passed the existing live preflight.

Moved bytes use the scanned allocated footprint, not the directory inode size. They are not a promise of reclaimed space. Held and failed outcomes remain separate. No file paths or names enter analytics.

Status: source integration only. All 72 Linux tool tests pass. Linux cannot compile SwiftUI or exercise Finder Trash. The path-based permanent-removal race flagged by the module author remains under review. Native build, tracked real-Trash fixture checks, keyboard review, independent risk review and both external CI lanes remain required.
