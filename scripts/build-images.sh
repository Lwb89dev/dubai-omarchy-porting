#!/bin/bash
# SPDX-License-Identifier: MIT
# Build an explicitly panel-specific, untested image. This script never flashes.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
KERNEL_OUT=${KERNEL_OUT:-$ROOT/out/kernel}
INITRAMFS=${INITRAMFS:-$ROOT/out/initramfs/initramfs-dubai.cpio.gz}
OUT=${IMAGE_OUT:-$ROOT/out/images}
PANEL=${PANEL:-}
MKBOOTIMG=${MKBOOTIMG:-$ROOT/work/toolchain/mkbootimg/mkbootimg.py}

[[ $PANEL == csot || $PANEL == tianma ]] || {
    echo "Refusing to select a panel: set PANEL=csot or PANEL=tianma from the bootloader Panel string or Android cmdline" >&2
    exit 2
}
[[ -f $MKBOOTIMG ]] || { echo "Missing pinned AOSP mkbootimg.py at $MKBOOTIMG" >&2; exit 1; }
[[ -f $INITRAMFS ]] || { echo "Build scripts/build-initramfs.sh first" >&2; exit 1; }
kernel=$KERNEL_OUT/arch/arm64/boot/Image.gz
dtb=$KERNEL_OUT/arch/arm64/boot/dts/qcom/sm7325-motorola-dubai-$PANEL.dtb
[[ -s $kernel && -s $dtb ]] || { echo "Build the kernel and DTBs first" >&2; exit 1; }

mkdir -p "$OUT/logs"
exec > >(tee "$OUT/logs/build-$PANEL.log") 2>&1
image=$OUT/boot-dubai-$PANEL-UNTESTED.img
python3 "$MKBOOTIMG" \
    --header_version 2 --pagesize 4096 --base 0x00000000 \
    --kernel_offset 0x00008000 --ramdisk_offset 0x01000000 \
    --tags_offset 0x00000100 --dtb_offset 0x01f00000 \
    --kernel "$kernel" --ramdisk "$INITRAMFS" --dtb "$dtb" \
    --cmdline "earlycon console=ttyMSM0,115200n8 console=tty0 panic=10" \
    --os_patch_level 2026-06-26 --output "$image"
printf '%s\n' \
    "UNTESTED AND NOT APPROVED FOR FLASH" \
    "Panel: $PANEL" \
    "fastboot boot support on this device: unknown" \
    "This file records no hardware validation." >"$OUT/NOT-FOR-FLASH-$PANEL"
(cd "$OUT" && sha256sum "${image##*/}" >"SHA256SUMS-$PANEL")
echo "Built $image; no device was accessed and no boot support is claimed"
