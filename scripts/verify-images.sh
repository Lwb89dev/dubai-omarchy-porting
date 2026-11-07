#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
KERNEL_OUT=${KERNEL_OUT:-$ROOT/out/kernel}
INITRAMFS_OUT=${INITRAMFS_OUT:-$ROOT/out/initramfs}
DT_PYTHON=${DT_PYTHON:-$ROOT/work/dtschema-venv/bin/python}
[[ -x $DT_PYTHON ]] || DT_PYTHON=python3

check_file() { [[ -s $1 ]] || { echo "missing or empty: $1" >&2; exit 1; }; }
check_file "$KERNEL_OUT/arch/arm64/boot/Image"
check_file "$KERNEL_OUT/arch/arm64/boot/Image.gz"
check_file "$KERNEL_OUT/config.final"
check_file "$INITRAMFS_OUT/initramfs-dubai.cpio.gz"

"$DT_PYTHON" - "$KERNEL_OUT" <<'PY'
import libfdt, pathlib, sys
out = pathlib.Path(sys.argv[1])
image = (out / 'arch/arm64/boot/Image').read_bytes()
assert image[56:60] == b'ARM\x64', 'not an ARM64 Linux Image'
print(f'ARM64 Image: valid header, {len(image)} bytes')
for panel in ('csot', 'tianma'):
    path = out / f'arch/arm64/boot/dts/qcom/sm7325-motorola-dubai-{panel}.dtb'
    fdt = libfdt.Fdt(path.read_bytes())
    assert fdt.getprop(0, 'compatible').as_stringlist() == ['motorola,dubai', 'qcom,sm7325']
    node = fdt.path_offset('/soc@0/display-subsystem@ae00000/dsi@ae94000/panel@0')
    compatibles = fdt.getprop(node, 'compatible').as_stringlist()
    assert f'{panel},nt37701-dubai' in compatibles
    print(f'{panel} DTB: board and panel compatible verified')
PY

release=$(cat "$KERNEL_OUT/include/config/kernel.release")
tar --zstd -tf "$KERNEL_OUT/modules-$release.tar.zst" | python3 -c '
import sys
names = sys.stdin.read().splitlines()
required = ("panel-novatek-nt37701.ko", "goodix_berlin_core.ko", "goodix_berlin_spi.ko")
for module in required:
    assert any(x.endswith("/" + module) or x.endswith("/" + module + ".zst") for x in names), module
print(f"Modules archive: {len(names)} entries; panel and touch modules verified")
'

gzip -t "$INITRAMFS_OUT/initramfs-dubai.cpio.gz"
gzip -dc "$INITRAMFS_OUT/initramfs-dubai.cpio.gz" | cpio -t 2>/dev/null | grep -x 'init' >/dev/null
stage=$ROOT/work/initramfs/rootfs
if [[ -x $stage/bin/busybox ]] && command -v qemu-aarch64-static >/dev/null; then
    qemu-aarch64-static -L "$stage" "$stage/bin/busybox" true
    echo "initramfs: archive valid; AArch64 BusyBox executed under QEMU"
fi
if [[ -f $stage/etc/omamobile-nbd-server ]]; then
    [[ -L $stage/lib/modules && -x $stage/usr/sbin/nbd-client ]]
    [[ -s $stage/usr/lib/firmware/qcom/a660_sqe.fw ]]
    [[ -s $stage/usr/lib/firmware/qcom/a660_gmu.bin ]]
    [[ -s $stage/usr/lib/firmware/qcom/sm7325/motorola/dubai/a660_zap.mbn ]]
    echo "NBD initramfs: modules link, client and Adreno firmware verified"
fi
[[ -f $KERNEL_OUT/SHA256SUMS ]] && (cd "$KERNEL_OUT" && sha256sum -c SHA256SUMS)
[[ -f $INITRAMFS_OUT/SHA256SUMS ]] && (cd "$INITRAMFS_OUT" && sha256sum -c SHA256SUMS)
echo "Offline artifact verification passed; this is not a hardware boot test"
