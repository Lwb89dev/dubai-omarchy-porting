#include <stdio.h>
#include <string.h>
#include "hexagonrpcd/hexagonfs.h"
extern struct hexagonfs_dirent *construct_root_dir(const char *, const char *);
int main(int argc, char **argv) {
 struct hexagonfs_fd *fds[HEXAGONFS_MAX_FD] = {0};
 struct hexagonfs_dirent *tree;
 int root, fd; char buf[16] = {0};
 if (argc != 2) return 1;
 tree = construct_root_dir(argv[1], "adsp");
 root = hexagonfs_open_root(fds, tree);
 if (root < 0) return 2;
 fd = hexagonfs_openat(fds, root, root, "/mnt/vendor/persist/sensors/registry/registry/../sns_reg_version");
 if (fd < 0 || hexagonfs_read(fds, fd, sizeof(buf), buf) != 2 || memcmp(buf, "9\n", 2)) return 3;
 hexagonfs_close(fds, fd);
 fd = hexagonfs_openat(fds, root, root, "/mnt/vendor/persist/sensors/registry/registry/example");
 if (fd < 0 || hexagonfs_read(fds, fd, sizeof(buf), buf) != 3 || memcmp(buf, "ok\n", 3)) return 4;
 hexagonfs_close(fds, fd);
 puts("registry parent and entry are readable through DSP paths");
 return 0;
}
