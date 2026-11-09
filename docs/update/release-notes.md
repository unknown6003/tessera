# Tessera 0.2.1

Keyboard, VoiceOver and Rescue fixes from native checks of 0.2.0.

- Tab skips hidden shortcut buttons. Launch focus goes to the source list,
  which is one Tab stop; arrow keys move the selection.
- The source list reads as one Sources control with the selected source and
  its place. Same-named sources are named by path. Decorative icons are hidden.
- A focused Tessera button scrolls into view. The focus ring hides while a
  sheet or alert covers the window.
- Rescue opens with a summary of what this scan found. Each group has a
  chevron button, an Add button on its title row, and scrolls its first rows
  into view when opened.
- Escape closes the Trash and delete alerts. Return still picks Cancel, so it
  never trashes or deletes. The Trash alert names what in the list needs review.
- A folder scanned from the Finder service, a restored session or automation
  gets a sidebar row.

# Tessera 0.2.0

Tessera has a new workspace and a scanner that streams large folders without
rereading them. Explore gives the disk map more room. Sources and item details
can be hidden. Rescue keeps the coverage report, exact paths and cleanup proof
in the main workspace.

- Scan status shows the current phase, elapsed time, observed counts and path.
  It no longer claims 99 percent when the amount of remaining work is unknown.
- Wide folders retain every batch. Long Unicode names keep their full paths.
  Rescans read fresh metadata, including changes below unchanged ancestors.
- Stalled cloud providers stop receiving more work in the current scan. Reader
  threads have a fixed bound. Unreadable paths stay visible as coverage gaps.
- Cleanup validates and removes items off the UI thread, then applies successful
  results in batches. Stale identities and protected paths stay held.
- The compact Cleanup List opens a full path review. Move to Trash is the
  default. Permanent deletion has a separate confirmation and accurate result.
- Per-file identity storage is compact. SwiftUI, Swift and the small Darwin C
  reader remain the app's implementation.

Scan time depends on the device, filesystem, permissions and provider state.
Partial coverage stays marked. This release does not promise a complete scan of
every possible drive in two minutes.

This release stays in the 0.x series. Anonymous PostHog diagnostics collect in normal
configured builds with no in-app off switch. Tests and benchmarks stay excluded. Scan times include outcomes above the 120-second local-drive
performance goal. That goal is not a scan timeout.
