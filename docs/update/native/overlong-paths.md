# Real directory paths beyond the kernel path limit

The original deep-tree requirement includes actual filesystem paths, not only
an in-memory tree. The 2,000-node regression checks URL assembly and size
propagation. The CI depth420 fixture uses short names and stays below macOS
PATH_MAX. Neither covered this case.

## Native red proof

An owned 80-level fixture was created with descriptor-relative mkdir/open/stat.
The existing staged native C bridge found one file and 4,096 allocated bytes,
against two files and 12,288 allocated bytes. Its first failed directory path
was 1,027 bytes, with errno 63, ENAMETOOLONG; 22 listings failed. The deep
sentinel was readable through openat/fstat but not full-path open/lstat.

Private Mac evidence: `/tmp/tessera-depth-proof-97k0fjnp/report.md`,
`result.json`, and `repro.py`. The app hash matched, but app launch was skipped
because its qualification preference domain already existed. This proves the
native bridge failure, not a full serial or parallel app result. No source,
user preferences, original checkout or user files changed. The fixture was
removed through parent descriptors.

## Change

The C bridge retains one open syscall for ordinary paths. On ENAMETOOLONG
only, it walks components with openat. It holds at most two descriptors,
closes each parent, and never changes the process working directory. Ancestor
symlinks retain ordinary open semantics, including macOS /var. The final
component still uses O_NOFOLLOW. Other errors do not trigger this fallback.

The readdir fallback now opens the same directory descriptor, transfers it to
fdopendir, and reads entry metadata through fstatat with AT_SYMLINK_NOFOLLOW.
A failed entry still creates an explicit coverage gap; a listing error still
fails the listing. Cancellation still closes the owned descriptor. No path
identity or cleanup validation is relaxed.

Root device lookup also uses that descriptor after an overlong-path lstat
failure. Serial scans no longer label a successfully enumerated empty folder
unreadable from a second full-path Foundation query.

The regression creates 80 real levels and an empty deep child, plus two
sentinels. It checks bulk counts and bytes, coverage, direct fallback metadata,
a selected deep root, and refusal to enumerate a final symlink. Cleanup uses
retained parent descriptors, including on failed test preconditions.

## Proof limits

The exact C open helper compiled with warnings as errors on Linux. It opened
a 4,981-byte path, rejected a final symlink and a missing child, and leaked no
descriptor over 100 opens. This is a helper check, not macOS qualification.
The new Swift test and full serial/parallel native results still need to run.
Normal-drive p99 and the existing four cohorts remain separate measurements.
