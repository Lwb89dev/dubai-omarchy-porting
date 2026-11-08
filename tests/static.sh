#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
sh -n initramfs/init
for package in packages/*/PKGBUILD; do
    bash -n "$package"
done
for test in packages/*/test/all; do
    "$test"
done
for script in scripts/*.sh tests/*.sh; do
    bash -n "$script"
    shellcheck -x "$script"
done
PYTHONPYCACHEPREFIX="$ROOT/work/pycache" python3 -m py_compile scripts/*.py
if PANEL=invalid scripts/build-images.sh >/dev/null 2>&1; then
    echo "build-images accepted an unknown panel" >&2
    exit 1
fi
if scripts/build-images.sh >/dev/null 2>&1; then
    echo "build-images accepted an unspecified panel" >&2
    exit 1
fi
for forbidden in 'fastboot flash' 'fastboot -w' 'fastboot erase' 'fastboot set_active' 'flashing lock' 'dd if='; do
    if grep -R -F -- "$forbidden" scripts initramfs .github 2>/dev/null; then
        echo "Forbidden device-write command found: $forbidden" >&2
        exit 1
    fi
done
echo "Static checks passed; no device operation performed"
