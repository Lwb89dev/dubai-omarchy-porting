#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SRC=$ROOT/sources/linux-sc7280
OUT=${KERNEL_OUT:-$ROOT/out/kernel}
VENV=$ROOT/work/dtschema-venv
DTSCHEMA_VERSION=2026.9

if [[ ! -x $VENV/bin/dt-validate ]]; then
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install --disable-pip-version-check "dtschema==$DTSCHEMA_VERSION"
fi
mkdir -p "$OUT/logs"
export PATH="$VENV/bin:$PATH"
for panel in csot tianma; do
    make -C "$SRC" O="$OUT" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
        CHECK_DTBS=y "qcom/sm7325-motorola-dubai-$panel.dtb" \
        >"$OUT/logs/dtbs-check-$panel.log" 2>&1
    echo "$panel: dtbs_check passed (dtschema $DTSCHEMA_VERSION)"
done
