#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
IMG=${ROOTFS_IMAGE:-$ROOT/work/rootfs-dubai-2026.11.07.img}
CONF=${FIRSTBOOT_CONF:?Set FIRSTBOOT_CONF to the private firstboot configuration}
PUB=${SSH_PUBLIC_KEY:?Set SSH_PUBLIC_KEY to a public .pub key}
ZAP=${DUBAI_ZAP_FIRMWARE:?Set DUBAI_ZAP_FIRMWARE to the private dubai zap firmware}

for file in "$IMG" "$CONF" "$PUB" "$ZAP"; do
    [[ -f $file ]] || { echo "Missing file: $file" >&2; exit 1; }
    [[ $file != *[[:space:]]* ]] || { echo "Paths with whitespace are not supported: $file" >&2; exit 1; }
done
[[ $PUB == *.pub ]] || { echo "SSH_PUBLIC_KEY must be a public .pub key" >&2; exit 1; }
dumpe2fs -h "$IMG" >/dev/null 2>&1 || { echo "Not an ext filesystem: $IMG" >&2; exit 1; }
if fuser "$IMG" >/dev/null 2>&1; then
    echo "Image is in use; stop qemu-nbd before provisioning it" >&2
    exit 1
fi

commands=$(mktemp)
trap 'rm -f "$commands"' EXIT
ensure_dir() {
    if ! debugfs -R "stat $1" "$IMG" 2>/dev/null | grep -c '^Inode:' >/dev/null; then
        printf 'mkdir %s\n' "$1" >>"$commands"
    fi
}
for dir in /etc/omamobile /root/.ssh /usr/lib/firmware/qcom/sm7325 \
           /usr/lib/firmware/qcom/sm7325/motorola /usr/lib/firmware/qcom/sm7325/motorola/dubai; do
    ensure_dir "$dir"
done
cat >>"$commands" <<EOF
rm /etc/omamobile/firstboot.conf
write $CONF /etc/omamobile/firstboot.conf
sif /etc/omamobile/firstboot.conf mode 0100600
sif /etc/omamobile/firstboot.conf uid 0
sif /etc/omamobile/firstboot.conf gid 0
sif /root/.ssh mode 040700
sif /root/.ssh uid 0
sif /root/.ssh gid 0
rm /root/.ssh/authorized_keys
write $PUB /root/.ssh/authorized_keys
sif /root/.ssh/authorized_keys mode 0100600
sif /root/.ssh/authorized_keys uid 0
sif /root/.ssh/authorized_keys gid 0
rm /usr/lib/firmware/qcom/sm7325/motorola/dubai/a660_zap.mbn
write $ZAP /usr/lib/firmware/qcom/sm7325/motorola/dubai/a660_zap.mbn
sif /usr/lib/firmware/qcom/sm7325/motorola/dubai/a660_zap.mbn mode 0100644
sif /usr/lib/firmware/qcom/sm7325/motorola/dubai/a660_zap.mbn uid 0
sif /usr/lib/firmware/qcom/sm7325/motorola/dubai/a660_zap.mbn gid 0
EOF
debugfs -w -f "$commands" "$IMG" >/dev/null 2>&1 || true

cmp -s <(debugfs -R 'cat /etc/omamobile/firstboot.conf' "$IMG" 2>/dev/null) "$CONF"
cmp -s <(debugfs -R 'cat /root/.ssh/authorized_keys' "$IMG" 2>/dev/null) "$PUB"
cmp -s <(debugfs -R 'cat /usr/lib/firmware/qcom/sm7325/motorola/dubai/a660_zap.mbn' "$IMG" 2>/dev/null) "$ZAP"
e2fsck -fn "$IMG" >/dev/null
printf 'NBD raw rootfs provisioned and ext4 verified; no device was accessed\n'
