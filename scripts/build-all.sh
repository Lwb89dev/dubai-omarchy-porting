#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

if [[ ${1:-} == --help ]]; then
    cat <<'EOF'
Usage: scripts/build-all.sh

Build the patched LLVM kernel, RNDIS initramfs and Arch/Omarchy rootfs offline.
No phone, adb, fastboot or internal-storage operation is performed.

Environment:
  JOBS=N                    Parallel kernel build jobs (default: host CPU count)
  BUILD_ROOTFS=0|1          Build the rootfs (default: 1)
  PANEL=csot|tianma         Also build a panel-specific, untested boot image
  USB_NET_FUNCTION=rndis|ncm (default: rndis)
  NBD_SERVER=ADDRESS        Add an NBD root server to the initramfs
  SSH_PUBLIC_KEY=FILE.pub   Authorize only this public key in the initramfs
  FIRMWARE_DIR=DIR          linux-firmware directory containing Adreno SQE/GMU
  DUBAI_ZAP_FIRMWARE=FILE   Owner's dubai-specific a660_zap.mbn

FIRMWARE_DIR and DUBAI_ZAP_FIRMWARE must be supplied together. Proprietary
firmware is copied only into ignored build artifacts, never into Git.
EOF
    exit 0
elif (($#)); then
    echo "Usage: scripts/build-all.sh [--help]" >&2
    exit 2
fi

export KERNEL_OUT=${KERNEL_OUT:-$ROOT/out/kernel-llvm}
export INITRAMFS_OUT=${INITRAMFS_OUT:-$ROOT/out/initramfs-llvm}
export IMAGE_OUT=${IMAGE_OUT:-$ROOT/out/images-llvm}
export USB_NET_FUNCTION=${USB_NET_FUNCTION:-rndis}
export JOBS=${JOBS:-$(nproc)}
BUILD_ROOTFS=${BUILD_ROOTFS:-1}
[[ $BUILD_ROOTFS == 0 || $BUILD_ROOTFS == 1 ]] || {
    echo "BUILD_ROOTFS must be 0 or 1" >&2
    exit 2
}
if [[ -n ${FIRMWARE_DIR:-} || -n ${DUBAI_ZAP_FIRMWARE:-} ]]; then
    [[ -n ${FIRMWARE_DIR:-} && -n ${DUBAI_ZAP_FIRMWARE:-} ]] || {
        echo "FIRMWARE_DIR and DUBAI_ZAP_FIRMWARE must be supplied together" >&2
        exit 2
    }
fi

mkdir -p "$ROOT/out/logs"
exec > >(tee "$ROOT/out/logs/build-all.log") 2>&1

run() {
    printf '\n==> %s\n' "$*"
    "$@"
}

run tests/static.sh
run scripts/fetch-sources.sh

source_tree=$ROOT/sources/linux-sc7280
worktree=$ROOT/work/kernel-one-stop
revision=$(git -C "$source_tree" rev-parse HEAD)
if [[ ! -e $worktree ]]; then
    run git -C "$source_tree" worktree add --detach "$worktree" "$revision"
fi
[[ $(git -C "$worktree" rev-parse HEAD) == "$revision" ]] || {
    echo "$worktree is not at the pinned source revision $revision" >&2
    exit 1
}
mapfile -t patches < <(printf '%s\n' "$ROOT"/kernel/patches/*.patch | sort)
state=$ROOT/work/kernel-one-stop.state
diff_hash=$(cat "${patches[@]}" | sha256sum)
if [[ -f $state && $(cat "$state") == "revision=$revision diff=${diff_hash%% *}" && \
    -z $(git -C "$worktree" status --porcelain) ]]; then
    echo "Kernel worktree matches the pinned revision and patch set"
else
    # The patch set or the pinned revision changed since the last build;
    # the worktree is disposable, so reset it and re-apply deterministically.
    echo "Re-syncing kernel worktree with $revision plus ${#patches[@]} patch(es)"
    run git -C "$worktree" reset --hard "$revision"
    run git -C "$worktree" clean -fdx
    for patch in "${patches[@]}"; do
        run git -C "$worktree" apply "$patch"
    done
    printf 'revision=%s diff=%s\n' "$revision" "${diff_hash%% *}" >"$state"
fi

run docker build -f docker/Dockerfile.kernel -t dubai-kernel-builder:24.04 docker
run docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp -e JOBS -e LLVM=1 \
    -e KERNEL_SRC="$worktree" -e KERNEL_OUT \
    -v "$ROOT:$ROOT" -w "$ROOT" dubai-kernel-builder:24.04 scripts/build-kernel.sh
run scripts/validate-dtbs.sh
run scripts/build-initramfs.sh
run scripts/verify-images.sh

if [[ $BUILD_ROOTFS == 1 ]]; then
    run scripts/build-rootfs.sh --build
fi
if [[ -n ${PANEL:-} ]]; then
    run scripts/fetch-boot-tools.sh
    run scripts/build-images.sh
fi

printf '\nOffline build completed. Kernel: %s\nInitramfs: %s\n' \
    "$KERNEL_OUT" "$INITRAMFS_OUT"
[[ $BUILD_ROOTFS == 0 ]] || printf 'Rootfs: %s\n' "$ROOT/work/omarchy-dubai/out/dubai"
[[ -z ${PANEL:-} ]] || printf 'Untested %s boot image: %s\n' "$PANEL" "$IMAGE_OUT"
echo "No device was accessed; no boot or flash is authorized by this build"
