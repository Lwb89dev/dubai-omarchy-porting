/* SPDX-License-Identifier: GPL-3.0-or-later */
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include "hexagonrpcd/hexagonfs.h"
extern struct hexagonfs_dirent *construct_root_dir(const char *, const char *);
int main(int argc, char **argv)
{
 struct hexagonfs_fd *fds[HEXAGONFS_MAX_FD] = {0};
 const char *base = "/mnt/vendor/persist/sensors/registry";
 char path[256], dest[256], buf[8] = {0};
 int root, fd;
 if (argc != 2) return 1;
 root = hexagonfs_open_root(fds, construct_root_dir(argv[1], "adsp"));
 if (root < 0) return 2;
 snprintf(path, sizeof(path), "%s/test.tmp", base);
 snprintf(dest, sizeof(dest), "%s/registry/test.out", base);
 fd = hexagonfs_create(fds, root, root, path, O_CREAT | O_TRUNC);
 if (fd < 0 || hexagonfs_write(fds, fd, 3, "ok\n") != 3 || hexagonfs_close(fds, fd)) return 3;
 if (hexagonfs_rename(fds, root, root, path, dest)) return 4;
 fd = hexagonfs_openat(fds, root, root, dest);
 if (fd < 0 || hexagonfs_read(fds, fd, sizeof(buf), buf) != 3 || memcmp(buf, "ok\n", 3) || hexagonfs_close(fds, fd)) return 5;
 if (hexagonfs_unlink(fds, root, root, dest)) return 6;
 snprintf(path, sizeof(path), "%s/escape-test", base);
 fd = hexagonfs_create(fds, root, root, path, O_TRUNC);
 if (fd >= 0) return 7;
 puts("registry create, write, rename, read, unlink and symlink escape checks passed");
 return 0;
}
