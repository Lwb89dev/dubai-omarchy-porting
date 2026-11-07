#!/bin/bash
# SPDX-License-Identifier: MIT
# Resolve ALARM's current Hyprland dependency skew with two signed Omarchy builds.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OUT=$ROOT/work/omarchy-edge-deps
KEYRING=$ROOT/work/omarchy-keyring/usr/share/pacman/keyrings/omarchy.gpg
KBX=$ROOT/work/omarchy-keyring.kbx
mkdir -p "$OUT"
[[ -f $KEYRING ]] || { echo "Prepare the Omarchy keyring with build-rootfs.sh first" >&2; exit 1; }
GNUPGHOME=$ROOT/work/gnupg-keyring-import
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"
export GNUPGHOME
gpg --batch --quiet --no-default-keyring --keyring "$KBX" --import "$KEYRING" 2>/dev/null

fetch() {
    local file=$1 sha=$2
    if [[ ! -f $OUT/$file ]] || ! (cd "$OUT" && echo "$sha  $file" | sha256sum -c --quiet); then
        curl -fsSL --retry 3 -o "$OUT/$file.part" "https://pkgs.omarchy.org/edge/aarch64/$file"
        mv "$OUT/$file.part" "$OUT/$file"
    fi
    curl -fsSL --retry 3 -o "$OUT/$file.sig" "https://pkgs.omarchy.org/edge/aarch64/$file.sig"
    (cd "$OUT" && echo "$sha  $file" | sha256sum -c --quiet)
    gpgv --keyring "$KBX" "$OUT/$file.sig" "$OUT/$file" >/dev/null 2>&1
    echo "verified $file"
}

fetch aquamarine-0.16.0-1.1-aarch64.pkg.tar.zst \
    997056ebc456afc2322cafc94382bf8bbc636b0c15b6c55c10c21eda28a22c7e
fetch hyprland-0.57.1-2-aarch64.pkg.tar.zst \
    3e8a17eecd26da3813bb731372da9f88060f3e04bb0f6fbad4a443a59249eece
