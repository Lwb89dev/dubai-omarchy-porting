#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
DEST=$ROOT/work/toolchain/mkbootimg
mkdir -p "$DEST/gki"

fetch_b64() {
    local path=$1 sha=$2 url=$3 tmp="$DEST/.download"
    curl -fsSL --retry 3 "$url" | base64 -d >"$tmp"
    echo "$sha  $tmp" | sha256sum -c --quiet
    mv "$tmp" "$DEST/$path"
}

fetch_b64 mkbootimg.py \
    37d84b3d162e0bc62e36c1f4e1c63c85ea0caa9f29be023eb2f8efe006ad948c \
    'https://android.googlesource.com/platform/system/tools/mkbootimg/+/4a27dd13adf9846e12d585d6fe99a375ebb58396/mkbootimg.py?format=TEXT'
fetch_b64 gki/generate_gki_certificate.py \
    1bb1feec68a13da18d581aa2c631798f86f6bc10b55d587b2dd31446a0f8a203 \
    'https://android.googlesource.com/platform/system/tools/mkbootimg/+/4a27dd13adf9846e12d585d6fe99a375ebb58396/gki/generate_gki_certificate.py?format=TEXT'
python3 "$DEST/mkbootimg.py" --help >/dev/null
echo "Pinned AOSP mkbootimg tools ready in $DEST"
