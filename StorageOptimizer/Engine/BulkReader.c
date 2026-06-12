#include "BulkReader.h"
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <sys/attr.h>
#include <sys/vnode.h>

#define BUFFER_SIZE (256 * 1024)

// Safe unaligned reads — getattrlistbulk packs data without guaranteed natural alignment
static inline uint32_t r32(const void *p) { uint32_t v; memcpy(&v, p, 4); return v; }
static inline uint64_t r64(const void *p) { uint64_t v; memcpy(&v, p, 8); return v; }
static inline int32_t  ri32(const void *p) { int32_t  v; memcpy(&v, p, 4); return v; }
static inline int64_t  ri64(const void *p) { int64_t  v; memcpy(&v, p, 8); return v; }

int br_scan_directory(const char *path, BREntry *out, int maxEntries) {
    int fd = open(path, O_RDONLY | O_DIRECTORY);
    if (fd < 0) return -1;

    struct attrlist alist;
    memset(&alist, 0, sizeof(alist));
    alist.bitmapcount = ATTR_BIT_MAP_COUNT;
    // Request returned-attrs first so we can defensively check which fields are present
    alist.commonattr = (attrgroup_t)(ATTR_CMN_RETURNED_ATTRS |
                                     ATTR_CMN_NAME           |
                                     ATTR_CMN_OBJTYPE        |
                                     ATTR_CMN_FILEID);
    alist.fileattr = (attrgroup_t)(ATTR_FILE_ALLOCSIZE);

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

            // Record layout:
            //  [0]  uint32_t length
            //  [4]  attribute_set_t returned = { commonattr, volattr, dirattr, fileattr, forkattr } (5 × uint32 = 20 bytes)
            //  [24] attributes in bitmap order (no insertion of padding between fields; all 4-byte aligned per HFS/APFS ABI)
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
                uint32_t copylen = (namelen > 1 && namelen <= sizeof(e.name)) ? namelen - 1 : 0;
                if (copylen > 0) {
                    memcpy(e.name, namedata, copylen);
                    e.name[copylen] = '\0';
                }
                field += 8;
            }

            // ATTR_CMN_OBJTYPE: uint32_t
            if (ret_common & ATTR_CMN_OBJTYPE) {
                e.type = r32(field);
                field += 4;
            }

            // ATTR_CMN_FILEID: uint64_t (8 bytes, but only 4-byte aligned in the buffer)
            if (ret_common & ATTR_CMN_FILEID) {
                e.inode = r64(field);
                field += 8;
            }

            // ATTR_FILE_ALLOCSIZE: int64_t (file attr section; not present for dirs)
            if ((ret_file & ATTR_FILE_ALLOCSIZE) && e.type != VDIR) {
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
