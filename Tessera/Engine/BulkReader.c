#include "BulkReader.h"
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <sys/attr.h>
#include <sys/vnode.h>
#include <sys/stat.h>
#include <mach/mach_time.h>

// Opt-in per-syscall timing (see header). Off by default → zero overhead.
static int br_timing_enabled = 0;
static uint64_t br_open_ns = 0;
static uint64_t br_bulk_ns = 0;
static uint64_t br_close_ns = 0;
void br_set_timing(int enabled) {
    br_timing_enabled = enabled;
    if (enabled) { br_open_ns = 0; br_bulk_ns = 0; br_close_ns = 0; }
}
uint64_t br_get_open_ns(void)  { return br_open_ns; }
uint64_t br_get_bulk_ns(void)  { return br_bulk_ns; }
uint64_t br_get_close_ns(void) { return br_close_ns; }

static double br_timebase = 0.0;
static inline uint64_t br_now_ns(void) {
    if (br_timebase == 0.0) {
        mach_timebase_info_data_t tb; mach_timebase_info(&tb);
        br_timebase = (double)tb.numer / (double)tb.denom;
    }
    return (uint64_t)((double)mach_absolute_time() * br_timebase);
}

// Safe unaligned reads — getattrlistbulk packs data without guaranteed natural alignment
static inline uint32_t r32(const void *p) { uint32_t v; memcpy(&v, p, 4); return v; }
static inline uint64_t r64(const void *p) { uint64_t v; memcpy(&v, p, 8); return v; }
static inline int32_t  ri32(const void *p) { int32_t  v; memcpy(&v, p, 4); return v; }
static inline int64_t  ri64(const void *p) { int64_t  v; memcpy(&v, p, 8); return v; }

// Keep the single syscall for normal paths. Only paths beyond the kernel's
// full-path limit need component-relative opens; no process-wide chdir is used.
static int br_open_directory(const char *path) {
    const int flags = O_RDONLY | O_DIRECTORY | O_CLOEXEC;
    int fd = open(path, flags | O_NOFOLLOW);
    if (fd >= 0 || errno != ENAMETOOLONG) return fd;

    char *components = strdup(path);
    if (!components) return -1;
    fd = open(path[0] == '/' ? "/" : ".", flags);
    if (fd < 0) { free(components); return -1; }
    char *state = NULL;
    char *part = strtok_r(components, "/", &state);
    while (part) {
        char *next = strtok_r(NULL, "/", &state);
        // Match the direct open: ancestors may be symlinks (e.g. macOS /var),
        // but the directory being enumerated must never be a symlink.
        int child = openat(fd, part, flags | (next ? 0 : O_NOFOLLOW));
        int saved_errno = errno;
        close(fd);
        fd = child;
        if (fd < 0) { free(components); errno = saved_errno; return -1; }
        part = next;
    }
    free(components);
    return fd;
}

int br_directory_open(const char *path, BRDirectory *directory) {
    directory->remaining = 0;
    directory->offset = 0;
    uint64_t t0 = br_timing_enabled ? br_now_ns() : 0;
    directory->fd = br_open_directory(path);
    if (br_timing_enabled) br_open_ns += br_now_ns() - t0;
    return directory->fd < 0 ? -1 : 0;
}

void br_directory_close(BRDirectory *directory) {
    if (directory->fd < 0) return;
    uint64_t t0 = br_timing_enabled ? br_now_ns() : 0;
    close(directory->fd);
    directory->fd = -1;
    if (br_timing_enabled) br_close_ns += br_now_ns() - t0;
}

int br_directory_read(BRDirectory *directory, BREntry *out, int maxEntries,
                      void *readbuf, int readbuf_len) {
    if (directory->fd < 0 || !out || maxEntries <= 0 || !readbuf || readbuf_len < 24) return -1;
    struct attrlist alist;
    memset(&alist, 0, sizeof(alist));
    alist.bitmapcount = ATTR_BIT_MAP_COUNT;
    // Request returned-attrs first so we can defensively check which fields are present
    alist.commonattr = (attrgroup_t)(ATTR_CMN_RETURNED_ATTRS |
                                     ATTR_CMN_ERROR          |
                                     ATTR_CMN_NAME           |
                                     ATTR_CMN_DEVID          |
                                     ATTR_CMN_OBJTYPE        |
                                     ATTR_CMN_MODTIME        |
                                     ATTR_CMN_FLAGS          |
                                     ATTR_CMN_FILEID);
    alist.fileattr = (attrgroup_t)(ATTR_FILE_LINKCOUNT | ATTR_FILE_DATALENGTH |
                                   ATTR_FILE_ALLOCSIZE);

    // Caller-owned scratch buffer (reused across directories — no per-call malloc).
    char *buf = (char *)readbuf;

    int total = 0;

    while (total < maxEntries) {
        if (directory->remaining == 0) {
            uint64_t t0 = br_timing_enabled ? br_now_ns() : 0;
            int count = getattrlistbulk(directory->fd, &alist, buf, (size_t)readbuf_len, 0);
            if (br_timing_enabled) br_bulk_ns += br_now_ns() - t0;
            if (count < 0) return -1;
            if (count == 0) break;
            directory->remaining = count;
            directory->offset = 0;
        }
        const char *ptr = buf + directory->offset;
        while (directory->remaining > 0 && total < maxEntries) {
            const char *recstart = ptr;
            if (directory->offset < 0 || directory->offset > readbuf_len - 24) return -1;
            uint32_t reclen = r32(ptr);
            if (reclen < 24 || reclen > (uint32_t)(readbuf_len - directory->offset)) return -1;
            const char *recordEnd = recstart + reclen;
            directory->remaining -= 1;
            directory->offset += (int)reclen;

            // Record layout:
            //  [0]  uint32_t length
            //  [4]  attribute_set_t returned = { commonattr, volattr, dirattr, fileattr, forkattr } (5 × uint32 = 20 bytes)
            //  [24] attributes in bitmap order (4-byte aligned per HFS/APFS ABI)
            uint32_t ret_common = r32(ptr + 4);
            uint32_t ret_file   = r32(ptr + 16); // fileattr word of attribute_set_t

            const char *field = ptr + 24; // first attribute data
            if (ret_common & ATTR_CMN_ERROR) {
                if (recordEnd - field < 4 || r32(field) != 0) return -1;
                field += 4;
            }
            uint32_t required = ATTR_CMN_NAME | ATTR_CMN_DEVID | ATTR_CMN_OBJTYPE | ATTR_CMN_FILEID;
            if ((ret_common & required) != required) return -1;

            BREntry e;
            memset(&e, 0, sizeof(e));

            // ATTR_CMN_NAME: attrreference_t = { int32 offset, uint32 length } = 8 bytes
            // The name data is at field + offset (relative to the attrreference_t itself)
            if (ret_common & ATTR_CMN_NAME) {
                if (recordEnd - field < 8) return -1;
                int32_t  nameoff = ri32(field);
                uint32_t namelen = r32(field + 4);   // includes NUL
                if (nameoff < 0 || nameoff > recordEnd - field || namelen < 2 ||
                    namelen > sizeof(e.name) || namelen > (uint32_t)(recordEnd - field - nameoff)) return -1;
                const char *namedata = field + nameoff;
                if (namedata[namelen - 1] != '\0' || memchr(namedata, '\0', namelen - 1) ||
                    memchr(namedata, '/', namelen - 1)) return -1;
                memcpy(e.name, namedata, namelen);
                field += 8;
            }

            // ATTR_CMN_DEVID: dev_t (4 bytes)
            if (ret_common & ATTR_CMN_DEVID) {
                if (recordEnd - field < 4) return -1;
                e.devid = r32(field);
                field += 4;
            }

            // ATTR_CMN_OBJTYPE: uint32_t
            if (ret_common & ATTR_CMN_OBJTYPE) {
                if (recordEnd - field < 4) return -1;
                e.type = r32(field);
                field += 4;
            }

            // ATTR_CMN_MODTIME: struct timespec (tv_sec int64 + tv_nsec, 16 bytes).
            // Bit 0x400 sorts between OBJTYPE (0x8) and FLAGS (0x40000). Keep the
            // full timestamp as the directory's content version for incremental
            // re-scan (changes when entries are added/removed/renamed).
            if (ret_common & ATTR_CMN_MODTIME) {
                if (recordEnd - field < 16) return -1;
                int64_t sec  = ri64(field);
                int64_t nsec = ri64(field + 8);
                e.mod_time = sec * 1000000000LL + nsec;  // nanoseconds, for exact change detection
                field += 16;
            }

            // ATTR_CMN_FLAGS: uint32_t (st_flags, e.g. SF_DATALESS for online-only
            // cloud items). Parsed in ascending-bit order: after MODTIME (0x400),
            // before FILEID (0x2000000).
            if (ret_common & ATTR_CMN_FLAGS) {
                if (recordEnd - field < 4) return -1;
                e.flags = r32(field);
                field += 4;
            }

            // ATTR_CMN_FILEID: uint64_t (8 bytes, but only 4-byte aligned in the buffer)
            if (ret_common & ATTR_CMN_FILEID) {
                if (recordEnd - field < 8) return -1;
                e.inode = r64(field);
                field += 8;
            }

            // ATTR_FILE_LINKCOUNT: uint32_t (file attr section; not present for dirs)
            if (ret_file & ATTR_FILE_LINKCOUNT) {
                if (recordEnd - field < 4) return -1;
                e.nlink = r32(field);
                field += 4;
            }

            if (e.type == BR_TYPE_REG && !(ret_file & ATTR_FILE_ALLOCSIZE)) return -1;

            // ATTR_FILE_ALLOCSIZE: int64_t
            if (ret_file & ATTR_FILE_ALLOCSIZE) {
                if (recordEnd - field < 8) return -1;
                e.alloc_size = ri64(field);
                field += 8;
            }

            // Match lstat and URLResourceValues.fileSize: data fork only.
            // TOTALSIZE includes resource forks and would reject unchanged files.
            if (e.type == BR_TYPE_REG && !(ret_file & ATTR_FILE_DATALENGTH)) return -1;
            if (ret_file & ATTR_FILE_DATALENGTH) {
                if (recordEnd - field < 8) return -1;
                e.logical_size = ri64(field);
            }

            // Skip . and .. and unnamed entries
            if (e.name[0] == '\0') { ptr = recstart + reclen; continue; }
            if (e.name[0] == '.' &&
                (e.name[1] == '\0' || (e.name[1] == '.' && e.name[2] == '\0'))) {
                ptr = recstart + reclen;
                continue;
            }

            out[total++] = e;
            ptr = recstart + reclen;
        }
    }
    return total;
}

int br_scan_directory(const char *path, BREntry *out, int maxEntries,
                      void *readbuf, int readbuf_len) {
    BRDirectory directory;
    if (br_directory_open(path, &directory) != 0) return -1;
    int count = br_directory_read(&directory, out, maxEntries, readbuf, readbuf_len);
    br_directory_close(&directory);
    return count;
}
