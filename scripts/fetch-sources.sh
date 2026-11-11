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
    fetch_one() {
        if [[ ! -d $dest/.git ]]; then
            git clone --filter=blob:none --no-checkout "$url" "$dest"
        fi
        git -C "$dest" fetch --depth 1 origin "$revision"
        local actual
        actual=$(git -C "$dest" rev-parse FETCH_HEAD)
        [[ $actual == "$revision" ]] || { echo "$name: fetched $actual, expected $revision" >&2; return 1; }
        if [[ $(git -C "$dest" rev-parse HEAD 2>/dev/null || true) != "$revision" ]]; then
            git -C "$dest" checkout --detach "$revision"
        fi
    }
    fetched=0
    for attempt in 1 2 3; do
        if fetch_one; then
            fetched=1
            break
        fi
        echo "$name: attempt $attempt failed; retrying" >&2
        sleep 5
    done
    if [[ $fetched != 1 ]]; then
        # Large filtered clones can hit server-side pack errors on fresh
        # runners; fall back to a complete single-pack snapshot.
        echo "$name: falling back to a full depth-1 clone" >&2
        rm -rf "$dest"
        git clone --depth 1 --no-checkout "$url" "$dest"
        git -C "$dest" fetch --depth 1 origin "$revision"
        actual=$(git -C "$dest" rev-parse FETCH_HEAD)
        [[ $actual == "$revision" ]] || { echo "$name: fetched $actual, expected $revision" >&2; exit 1; }
        git -C "$dest" checkout --detach "$revision"
    fi
    echo "$name $revision ($reference)"
done < sources.lock
