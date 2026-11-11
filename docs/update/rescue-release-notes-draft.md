# Rescue redesign release notes draft

Planned version: 0.2.3, build 15. Not published or qualified yet. Use these notes
only after the final candidate passes native acceptance and both external lanes.

- Rescue lists the largest storage consumers first. App-managed stores show
  their owner and management steps alongside files you can review.
- Open a group to inspect names, sizes, paths and effects before choosing files.
  Nothing starts selected. Kept items stay in an inspectable exclusion list.
- Returning from an owner opened through Rescue triggers one fresh check.
  Missing apps offer a Finder route and Retry.
- An optional goal measures additional free space on the same drive. Moved
  bytes and space still in Trash do not count as recovered space.
- After a Trash move, review only that operation's tracked items for a separate
  permanent-removal step. Changed or unverified items stay held. Other Trash
  items stay untouched, and failures retain an inspection route.

Allocated footprint is not a promise of recovered space. Partial coverage stays
visible. Tests and benchmarks stay outside production analytics.
