#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SRC=${KERNEL_SRC:-$ROOT/sources/linux-sc7280}
OUT=${KERNEL_OUT:-$ROOT/out/kernel}
BASE_CONFIG=${BASE_CONFIG:-$ROOT/sources/pmaports/device/community/linux-postmarketos-qcom-sc7280/config-postmarketos-qcom-sc7280.aarch64}
JOBS=${JOBS:-$(nproc)}
export SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-1781088000}
make_args=(ARCH=arm64)
if [[ ${LLVM:-0} == 1 ]]; then
    FRAGMENT=${KERNEL_FRAGMENT:-$ROOT/device/dubai/kernel-llvm.config}
    make_args+=(LLVM=1)
else
    FRAGMENT=${KERNEL_FRAGMENT:-$ROOT/device/dubai/kernel.config}
    make_args+=(CROSS_COMPILE=aarch64-linux-gnu-)
fi

[[ -d $SRC && -f $BASE_CONFIG && -f $FRAGMENT ]] || { echo "Run scripts/fetch-sources.sh first" >&2; exit 1; }
mkdir -p "$OUT/logs"
exec > >(tee "$OUT/logs/build.log") 2>&1

echo "Kernel source: $(git -C "$SRC" rev-parse HEAD)"
echo "Output: $OUT"
echo "Toolchain: ${make_args[*]}"
cp "$BASE_CONFIG" "$OUT/.config"
"$SRC/scripts/kconfig/merge_config.sh" -m -O "$OUT" "$OUT/.config" "$FRAGMENT"
make -C "$SRC" O="$OUT" "${make_args[@]}" olddefconfig
cp "$OUT/.config" "$OUT/config.final"

make -C "$SRC" O="$OUT" "${make_args[@]}" \
    KBUILD_BUILD_TIMESTAMP="@$SOURCE_DATE_EPOCH" KBUILD_BUILD_USER=builder KBUILD_BUILD_HOST=localhost \
    -j"$JOBS" Image Image.gz dtbs modules

release=$(cat "$OUT/include/config/kernel.release")
[[ $release == 7.2.9-dubai+ ]] || { echo "Unexpected kernel release: $release" >&2; exit 1; }
rm -rf "$OUT/rootfs"
make -C "$SRC" O="$OUT" "${make_args[@]}" \
    INSTALL_MOD_PATH="$OUT/rootfs/usr" INSTALL_MOD_STRIP=1 modules_install
rm -f "$OUT/rootfs/usr/lib/modules/$release/build" "$OUT/rootfs/usr/lib/modules/$release/source"

tar --sort=name --mtime="@$SOURCE_DATE_EPOCH" --owner=0 --group=0 --numeric-owner \
    -C "$OUT/rootfs/usr/lib/modules" -cf "$OUT/modules-$release.tar" "$release"
zstd -q -f -T0 -19 --rm "$OUT/modules-$release.tar" -o "$OUT/modules-$release.tar.zst"

artifacts=(
    "$OUT/arch/arm64/boot/Image"
    "$OUT/arch/arm64/boot/Image.gz"
    "$OUT/config.final"
    "$OUT/arch/arm64/boot/dts/qcom/sm7325-motorola-dubai-csot.dtb"
    "$OUT/arch/arm64/boot/dts/qcom/sm7325-motorola-dubai-tianma.dtb"
    "$OUT/modules-$release.tar.zst"
)
for file in "${artifacts[@]}"; do [[ -s $file ]] || { echo "Missing artifact: $file" >&2; exit 1; }; done
(
    cd "$OUT"
    sha256sum "${artifacts[@]#$OUT/}" >SHA256SUMS
)
cp "$OUT/include/config/kernel.release" "$OUT/KERNEL_RELEASE"
echo "Built kernel $release and both dubai DTBs; no hardware test performed"
