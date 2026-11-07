#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

while IFS='|' read -r type name url revision reference checksum; do
    [[ -z $type || $type == \#* ]] && continue
    if [[ $type != git ]]; then
        [[ $type != archive ]] || echo "$name $revision (sha256 $checksum)"
        continue
    fi
    dest="sources/$name"
    if [[ ! -d $dest/.git ]]; then
        git clone --filter=blob:none --no-checkout "$url" "$dest"
    fi
    git -C "$dest" fetch --depth 1 origin "$revision"
    actual=$(git -C "$dest" rev-parse FETCH_HEAD)
    [[ $actual == "$revision" ]] || { echo "$name: fetched $actual, expected $revision" >&2; exit 1; }
    if [[ $(git -C "$dest" rev-parse HEAD 2>/dev/null || true) != "$revision" ]]; then
        git -C "$dest" checkout --detach "$revision"
    fi
    echo "$name $revision ($reference)"
done < sources.lock
