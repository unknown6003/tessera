#pragma once
#include <stdint.h>

// Object types (matching vnode_vtype)
#define BR_TYPE_REG  1  // regular file
#define BR_TYPE_DIR  2  // directory (real dir, not package)
#define BR_TYPE_LNK  5  // symbolic link

typedef struct {
    char     name[256];     // entry name, NUL-terminated (NAME_MAX is 255 on APFS/HFS+; overlong names clamp to fit)
    uint32_t type;          // BR_TYPE_REG / BR_TYPE_DIR / BR_TYPE_LNK / 0
    uint32_t devid;         // device id (dev_t) — used to detect mount-point crossings
    uint32_t nlink;         // hard-link count (files only; 0 when unavailable)
    uint64_t inode;         // inode / file ID
    int64_t  alloc_size;    // on-disk allocated bytes (0 for directories)
    uint32_t flags;         // st_flags (UF_*/SF_* incl. SF_DATALESS); 0 when unavailable
    int64_t  mod_time;      // ATTR_CMN_MODTIME tv_sec — directory content-version for incremental re-scan
} BREntry;

// Opt-in per-syscall timing (single-threaded benchmark only — the accumulators
// are plain globals and race if multiple threads scan with timing enabled).
// Production leaves timing disabled, so the timed paths cost nothing. Accessed
// via functions so Swift's strict-concurrency checker stays happy.
void br_set_timing(int enabled); // also resets the accumulators when enabling
uint64_t br_get_open_ns(void);
uint64_t br_get_bulk_ns(void);
uint64_t br_get_close_ns(void);

/// Scan `path` using getattrlistbulk.
/// Fills `entries` with up to `maxEntries` results.
/// `readbuf`/`readbuf_len` is a caller-owned scratch buffer for the kernel
/// listing (reused across directories so there is no per-call allocation); it
/// must be at least a few KB — 256 KB or more is recommended for few syscalls.
/// Returns the number of entries written, or -1 on error (caller should fall back to readdir).
/// A return value equal to `maxEntries` may indicate truncation.
int br_scan_directory(const char *path, BREntry *entries, int maxEntries,
                      void *readbuf, int readbuf_len);
