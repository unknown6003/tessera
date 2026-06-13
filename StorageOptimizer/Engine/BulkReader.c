#include "BulkReader.h"
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <sys/attr.h>
#include <sys/vnode.h>
#include <sys/stat.h>

#define BUFFER_SIZE (256 * 1024)

// Safe unaligned reads — getattrlistbulk packs data without guaranteed natural alignment
static inline uint32_t r32(const void *p) { uint32_t v; memcpy(&v, p, 4); return v; }
static inline uint64_t r64(const void *p) { uint64_t v; memcpy(&v, p, 8); return v; }
static inline int32_t  ri32(const void *p) { int32_t  v; memcpy(&v, p, 4); return v; }
static inline int64_t  ri64(const void *p) { int64_t  v; memcpy(&v, p, 8); return v; }

int br_scan_directory(const char *path, BREntry *out, int maxEntries) {
    int fd = open(path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW);
    if (fd < 0) return -1;

    struct attrlist alist;
    memset(&alist, 0, sizeof(alist));
    alist.bitmapcount = ATTR_BIT_MAP_COUNT;
    // Request returned-attrs first so we can defensively check which fields are present
    alist.commonattr = (attrgroup_t)(ATTR_CMN_RETURNED_ATTRS |
                                     ATTR_CMN_NAME           |
                                     ATTR_CMN_DEVID          |
                                     ATTR_CMN_OBJTYPE        |
                                     ATTR_CMN_FLAGS          |
                                     ATTR_CMN_FILEID);
    alist.fileattr = (attrgroup_t)(ATTR_FILE_LINKCOUNT | ATTR_FILE_ALLOCSIZE);

    char *buf = (char *)malloc(BUFFER_SIZE);
    if (!buf) { close(fd); return -1; }

    int total = 0;

    while (total < maxEntries) {
        int count = getattrlistbulk(fd, &alist, buf, BUFFER_SIZE, 0);
        if (count <= 0) break;

        const char *ptr = buf;
        for (int i = 0; i < count && total < maxEntries; i++) {
            const char *recstart = ptr;
            uint32_t reclen = r32(ptr);

            // Bounds-validate the record before reading any of its fields:
            // a malformed/short record could otherwise read past the buffer, and
            // reclen == 0 would loop forever on `ptr = recstart + reclen`.
            if (reclen < 24 || recstart + reclen > buf + BUFFER_SIZE) break;

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
                    namedata >= buf && namedata < buf + BUFFER_SIZE &&
                    namedata + copylen <= buf + BUFFER_SIZE) {
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

            // ATTR_CMN_FLAGS: uint32_t (st_flags, e.g. SF_DATALESS for online-only
            // cloud items). Parsed in ascending-bit order: after OBJTYPE (0x8),
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

    free(buf);
    close(fd);
    return total;
}
