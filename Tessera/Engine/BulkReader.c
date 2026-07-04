#include "BulkReader.h"
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
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

int br_scan_directory(const char *path, BREntry *out, int maxEntries,
                      void *readbuf, int readbuf_len) {
    if (!readbuf || readbuf_len <= 0) return -1;
    uint64_t _t0 = br_timing_enabled ? br_now_ns() : 0;
    int fd = open(path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW);
    if (br_timing_enabled) br_open_ns += br_now_ns() - _t0;
    if (fd < 0) return -1;

    struct attrlist alist;
    memset(&alist, 0, sizeof(alist));
    alist.bitmapcount = ATTR_BIT_MAP_COUNT;
    // Request returned-attrs first so we can defensively check which fields are present
    alist.commonattr = (attrgroup_t)(ATTR_CMN_RETURNED_ATTRS |
                                     ATTR_CMN_NAME           |
                                     ATTR_CMN_DEVID          |
                                     ATTR_CMN_OBJTYPE        |
                                     ATTR_CMN_MODTIME        |
                                     ATTR_CMN_FLAGS          |
                                     ATTR_CMN_FILEID);
    alist.fileattr = (attrgroup_t)(ATTR_FILE_LINKCOUNT | ATTR_FILE_ALLOCSIZE);

    // Caller-owned scratch buffer (reused across directories — no per-call malloc).
    char *buf = (char *)readbuf;

    int total = 0;

    while (total < maxEntries) {
        uint64_t _b0 = br_timing_enabled ? br_now_ns() : 0;
        int count = getattrlistbulk(fd, &alist, buf, (size_t)readbuf_len, 0);
        if (br_timing_enabled) br_bulk_ns += br_now_ns() - _b0;
        if (count <= 0) break;

        const char *ptr = buf;
        for (int i = 0; i < count && total < maxEntries; i++) {
            const char *recstart = ptr;
            uint32_t reclen = r32(ptr);

            // Bounds-validate the record before reading any of its fields:
            // a malformed/short record could otherwise read past the buffer, and
            // reclen == 0 would loop forever on `ptr = recstart + reclen`.
            if (reclen < 24 || recstart + reclen > buf + readbuf_len) break;

            // Record layout:
            //  [0]  uint32_t length
            //  [4]  attribute_set_t returned = { commonattr, volattr, dirattr, fileattr, forkattr } (5 × uint32 = 20 bytes)
            //  [24] attributes in bitmap order (4-byte aligned per HFS/APFS ABI)
            uint32_t ret_common = r32(ptr + 4);
            uint32_t ret_file   = r32(ptr + 16); // fileattr word of attribute_set_t

            const char *field = ptr + 24; // first attribute data

            BREntry e;
            memset(&e, 0, sizeof(e));

            // ATTR_CMN_NAME: attrreference_t = { int32 offset, uint32 length } = 8 bytes
            // The name data is at field + offset (relative to the attrreference_t itself)
            if (ret_common & ATTR_CMN_NAME) {
                int32_t  nameoff = ri32(field);
                uint32_t namelen = r32(field + 4);   // includes NUL
                const char *namedata = field + nameoff;
                // Clamp overlong names instead of dropping them — dropping the name
                // would silently discard the whole subtree rooted at this entry.
                uint32_t copylen = (namelen > 1) ? namelen - 1 : 0;
                if (copylen > sizeof(e.name) - 1) copylen = sizeof(e.name) - 1;
                // Validate the name reference lies fully within the buffer; on any
                // violation leave the name empty (the record is then skipped below).
                if (copylen > 0 &&
                    nameoff >= 0 &&
                    namedata >= buf && namedata < buf + readbuf_len &&
                    namedata + copylen <= buf + readbuf_len) {
                    memcpy(e.name, namedata, copylen);
                    e.name[copylen] = '\0';
                }
                field += 8;
            }

            // ATTR_CMN_DEVID: dev_t (4 bytes)
            if (ret_common & ATTR_CMN_DEVID) {
                e.devid = r32(field);
                field += 4;
            }

            // ATTR_CMN_OBJTYPE: uint32_t
            if (ret_common & ATTR_CMN_OBJTYPE) {
                e.type = r32(field);
                field += 4;
            }

            // ATTR_CMN_MODTIME: struct timespec (tv_sec int64 + tv_nsec, 16 bytes).
            // Bit 0x400 sorts between OBJTYPE (0x8) and FLAGS (0x40000). We keep the
            // seconds only — it's the directory's content version for incremental
            // re-scan (changes when entries are added/removed/renamed).
            if (ret_common & ATTR_CMN_MODTIME) {
                int64_t sec  = ri64(field);
                int64_t nsec = ri64(field + 8);
                e.mod_time = sec * 1000000000LL + nsec;  // nanoseconds, for exact change detection
                field += 16;
            }

            // ATTR_CMN_FLAGS: uint32_t (st_flags, e.g. SF_DATALESS for online-only
            // cloud items). Parsed in ascending-bit order: after MODTIME (0x400),
            // before FILEID (0x2000000).
            if (ret_common & ATTR_CMN_FLAGS) {
                e.flags = r32(field);
                field += 4;
            }

            // ATTR_CMN_FILEID: uint64_t (8 bytes, but only 4-byte aligned in the buffer)
            if (ret_common & ATTR_CMN_FILEID) {
                e.inode = r64(field);
                field += 8;
            }

            // ATTR_FILE_LINKCOUNT: uint32_t (file attr section; not present for dirs)
            if (ret_file & ATTR_FILE_LINKCOUNT) {
                e.nlink = r32(field);
                field += 4;
            }

            // ATTR_FILE_ALLOCSIZE: int64_t
            if (ret_file & ATTR_FILE_ALLOCSIZE) {
                e.alloc_size = ri64(field);
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

    uint64_t _c0 = br_timing_enabled ? br_now_ns() : 0;
    close(fd);
    if (br_timing_enabled) br_close_ns += br_now_ns() - _c0;
    return total;
}
