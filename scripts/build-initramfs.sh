#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OUT=${INITRAMFS_OUT:-$ROOT/out/initramfs}
KERNEL_OUT=${KERNEL_OUT:-}
WORK=$ROOT/work/initramfs
DOWNLOADS=$ROOT/work/downloads/alpine
ALPINE_VERSION=3.24.2
ALPINE_SHA256=9bf70a7f18ea44094cbb5f70c58f9af129c8214745743db0e68e5502cc2ce773
TARBALL=$DOWNLOADS/alpine-minirootfs-$ALPINE_VERSION-aarch64.tar.gz
SSH_PUBLIC_KEY=${SSH_PUBLIC_KEY:-}
export SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-1781088000}

mkdir -p "$OUT/logs" "$DOWNLOADS"
exec > >(tee "$OUT/logs/build.log") 2>&1
if [[ ! -f $TARBALL ]]; then
    curl -fsSL --retry 3 -o "$TARBALL.part" \
        "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION%.*}/releases/aarch64/${TARBALL##*/}"
    mv "$TARBALL.part" "$TARBALL"
fi
echo "$ALPINE_SHA256  $TARBALL" | sha256sum -c --quiet

rm -rf "$WORK"
mkdir -p "$WORK/rootfs"
tar -xzf "$TARBALL" -C "$WORK/rootfs"
for package in $(python3 -I "$ROOT/sources/omarchy-mobile/tools/alpine-fetch.py" \
    "$ALPINE_VERSION" "$DOWNLOADS/apks" dropbear nbd-client); do
    tar -xzf "$package" -C "$WORK/rootfs" \
        --exclude='.PKGINFO' --exclude='.SIGN.*' --exclude='.*.sh' 2>/dev/null || true
done
sed -i 's/^root:[^:]*:/root::/' "$WORK/rootfs/etc/shadow"

if [[ -n $KERNEL_OUT ]]; then
    release=$(cat "$KERNEL_OUT/include/config/kernel.release")
    modules=$KERNEL_OUT/modules-$release.tar.zst
    [[ -f $modules ]] || { echo "Missing modules archive: $modules" >&2; exit 1; }
    mkdir -p "$WORK/rootfs/usr/lib/modules" "$WORK/rootfs/lib"
    tar --zstd -xf "$modules" -C "$WORK/rootfs/usr/lib/modules"
    ln -s ../usr/lib/modules "$WORK/rootfs/lib/modules"
    echo "Packed modules for $release"
fi

if [[ -n ${FIRMWARE_DIR:-} ]]; then
    for file in qcom/a660_sqe.fw qcom/a660_gmu.bin; do
        [[ -f $FIRMWARE_DIR/$file ]] || { echo "Missing firmware: $FIRMWARE_DIR/$file" >&2; exit 1; }
        install -D -m 0644 "$FIRMWARE_DIR/$file" "$WORK/rootfs/usr/lib/firmware/$file"
        sha256sum "$FIRMWARE_DIR/$file"
    done
    [[ -n ${DUBAI_ZAP_FIRMWARE:-} && -f $DUBAI_ZAP_FIRMWARE ]] || {
        echo "Set DUBAI_ZAP_FIRMWARE to the owner's dubai-specific a660_zap.mbn" >&2; exit 1;
    }
    install -D -m 0644 "$DUBAI_ZAP_FIRMWARE" \
        "$WORK/rootfs/usr/lib/firmware/qcom/sm7325/motorola/dubai/a660_zap.mbn"
    sha256sum "$DUBAI_ZAP_FIRMWARE"
fi

install -m 0755 "$ROOT/initramfs/init" "$WORK/rootfs/init"
if [[ -n $SSH_PUBLIC_KEY ]]; then
    [[ -f $SSH_PUBLIC_KEY && $SSH_PUBLIC_KEY == *.pub ]] || {
        echo "SSH_PUBLIC_KEY must name a public .pub key, never a private key" >&2; exit 1;
    }
    install -d -m 0700 "$WORK/rootfs/root/.ssh"
    install -m 0600 "$SSH_PUBLIC_KEY" "$WORK/rootfs/root/.ssh/authorized_keys"
else
    echo "No SSH key supplied: USB serial and local shell only"
fi
if [[ -n ${NBD_SERVER:-} ]]; then
    printf '%s\n' "$NBD_SERVER" >"$WORK/rootfs/etc/omamobile-nbd-server"
fi

[[ -x $WORK/rootfs/bin/busybox && -x $WORK/rootfs/usr/sbin/dropbear ]] || {
    echo "Incomplete initramfs root" >&2; exit 1;
}
find "$WORK/rootfs" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +
(
    cd "$WORK/rootfs"
    find . -print0 | sort -z | cpio --null -o --format=newc --reproducible --owner=0:0 2>/dev/null
) | gzip -9n >"$OUT/initramfs-dubai.cpio.gz"

printf '%s\n' "$ALPINE_VERSION" >"$OUT/ALPINE_VERSION"
(cd "$OUT" && sha256sum initramfs-dubai.cpio.gz >SHA256SUMS)
echo "Built RAM-only diagnostic initramfs; no device was accessed"
