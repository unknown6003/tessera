#pragma once
#include <stdint.h>

// Object types (matching vnode_vtype)
#define BR_TYPE_REG  1  // regular file
#define BR_TYPE_DIR  2  // directory (real dir, not package)
#define BR_TYPE_LNK  5  // symbolic link

typedef struct {
    char     name[1024];    // entry name, NUL-terminated (overlong names are truncated to fit)
    uint32_t type;          // BR_TYPE_REG / BR_TYPE_DIR / BR_TYPE_LNK / 0
    uint32_t devid;         // device id (dev_t) — used to detect mount-point crossings
    uint32_t nlink;         // hard-link count (files only; 0 when unavailable)
    uint64_t inode;         // inode / file ID
    int64_t  alloc_size;    // on-disk allocated bytes (0 for directories)
} BREntry;

/// Scan `path` using getattrlistbulk.
/// Fills `entries` with up to `maxEntries` results.
/// Returns the number of entries written, or -1 on error (caller should fall back to readdir).
/// A return value equal to `maxEntries` may indicate truncation.
int br_scan_directory(const char *path, BREntry *entries, int maxEntries);
