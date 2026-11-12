#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SRC=$ROOT/sources/linux-sc7280
OUT=${KERNEL_OUT:-$ROOT/out/kernel}
VENV=$ROOT/work/dtschema-venv
DTSCHEMA_VERSION=2026.9
ALLOWLIST=$ROOT/tests/dtschema-allowlist.txt
IMAGE=dubai-kernel-builder:24.04

# The CHECK_DTBS make step re-runs syncconfig and therefore needs the ARM64
# cross toolchain. Hosts without it (CI runners, fresh laptops) validate
# inside the kernel builder image instead.
if [[ ${DUBAI_DTBS_HOST:-0} != 1 ]] && ! command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
    echo "aarch64-linux-gnu-gcc not found; running dtschema validation inside $IMAGE"
    exec docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp \
        -e KERNEL_OUT -e KERNEL_SRC \
        -v "$ROOT:$ROOT" -w "$ROOT" \
        "$IMAGE" scripts/validate-dtbs.sh
fi

[[ -d $SRC ]] || { echo "Run scripts/fetch-sources.sh first" >&2; exit 1; }
[[ -f $ALLOWLIST ]] || { echo "Missing allowlist: $ALLOWLIST" >&2; exit 1; }
if ! "$VENV/bin/dt-validate" --version 2>/dev/null | grep -q "^$DTSCHEMA_VERSION\$"; then
    rm -rf "$VENV"
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install --disable-pip-version-check "dtschema==$DTSCHEMA_VERSION"
fi
mkdir -p "$OUT/logs"
export PATH="$VENV/bin:$PATH"

for panel in csot tianma; do
    log=$OUT/logs/dtbs-check-$panel.log
    if ! make -C "$SRC" O="$OUT" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
        CHECK_DTBS=y "qcom/sm7325-motorola-dubai-$panel.dtb" \
        >"$log" 2>&1; then
        echo "$panel: make failed; last log lines:" >&2
        tail -n 30 "$log" >&2
        exit 1
    fi
done

# dt-validate errors never fail the build (the kernel Makefile appends
# '|| true'), so gate on the parsed errors here: every dt-validate error
# block must be covered by the allowlist, and every allowlist entry must
# match at least one block, so fixed bindings cannot linger as allowances.
"$VENV/bin/python3" - "$ALLOWLIST" "$OUT/logs/dtbs-check-csot.log" "$OUT/logs/dtbs-check-tianma.log" <<'PY'
import re
import sys

allowlist_path, *logs = sys.argv[1:]
entries = []
for line in open(allowlist_path, encoding="utf-8"):
    line = line.strip()
    if line and not line.startswith("#"):
        entries.append(line)

prefix_re = re.compile(r"^\S*?sm7325-motorola-dubai-\w+\.dtb: ")
matched = {entry: 0 for entry in entries}
unexpected = []
total = 0
per_panel = {}
for log in logs:
    panel = re.search(r"dtbs-check-(\w+)\.log", log).group(1)
    blocks, current = [], None
    for line in open(log, encoding="utf-8", errors="replace"):
        if re.match(r"^\S.*\.dtb: ", line):
            current = [line]
            blocks.append(current)
        elif current is not None and line.startswith("\t"):
            current.append(line)
        elif current is not None:
            current = None
    per_panel[panel] = 0
    for block_lines in blocks:
        block = prefix_re.sub("", "".join(block_lines)).strip()
        if not block:
            continue
        total += 1
        per_panel[panel] += 1
        hit = [entry for entry in entries if entry in block]
        if hit:
            for entry in hit:
                matched[entry] += 1
        else:
            unexpected.append(f"[{panel}] {block}")

for panel, count in sorted(per_panel.items()):
    print(f"{panel}: {count} dtschema error(s)")
for block in unexpected:
    print("UNEXPECTED dtschema error:", file=sys.stderr)
    print(block, file=sys.stderr)
    print(file=sys.stderr)
stale = [entry for entry, count in matched.items() if count == 0]
for entry in stale:
    print(f"STALE allowlist entry (matched nothing): {entry}", file=sys.stderr)
if unexpected or stale:
    sys.exit(1)
print(f"dtschema validation passed: {total} known error(s), all allowlisted")
PY
