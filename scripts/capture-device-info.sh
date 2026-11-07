#!/bin/bash
# SPDX-License-Identifier: MIT
# Explicit read-only capture. Does not reboot, unlock, flash or change slots.
set -euo pipefail
MODE=${1:-}
DEST=${2:-}
[[ $MODE == android || $MODE == fastboot ]] || {
    echo "Usage: $0 android|fastboot PRIVATE_OUTPUT_DIR" >&2; exit 2;
}
[[ -n $DEST && $DEST == /* ]] || { echo "Use an absolute private output path outside this repository" >&2; exit 2; }
case "$DEST" in "$PWD"|"$PWD"/*) echo "Refusing repository-local capture" >&2; exit 2;; esac
mkdir -p "$DEST"
chmod 700 "$DEST"

if [[ $MODE == android ]]; then
    command -v adb >/dev/null
    adb devices
    adb shell 'getprop ro.product.device; getprop ro.product.model; getprop ro.build.version.release; getprop ro.build.fingerprint' >"$DEST/android-identity.txt"
    adb shell 'cat /proc/cmdline; cat /proc/device-tree/model 2>/dev/null || true; cat /proc/device-tree/compatible 2>/dev/null || true' >"$DEST/android-boot.txt"
    adb shell 'dmesg' >"$DEST/android-dmesg.txt" 2>"$DEST/android-dmesg.stderr" || true
else
    command -v fastboot >/dev/null
    fastboot devices
    fastboot getvar all >"$DEST/fastboot-getvar-all.txt" 2>&1
    for partition in boot_a boot_b vendor_boot_a vendor_boot_b dtbo_a dtbo_b vbmeta_a vbmeta_b super userdata; do
        fastboot getvar "partition-size:$partition"
    done >"$DEST/fastboot-partition-sizes.txt" 2>&1
fi
cat >"$DEST/README-PRIVATE" <<'EOF'
Private capture: may contain serial numbers, identifiers or network addresses.
Do not commit, upload or attach it. Record sanitized panel and slot facts separately.
No command in the capture script writes to the device.
EOF
echo "Private read-only capture written to $DEST; sanitize before sharing"
