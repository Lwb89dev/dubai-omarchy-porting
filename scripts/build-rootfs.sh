#!/bin/bash
# SPDX-License-Identifier: MIT
# Stage this port over an unchanged Omarchy Mobile checkout, then use its builders.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
UPSTREAM=$ROOT/sources/omarchy-mobile
STAGE=$ROOT/work/omarchy-dubai
COMMIT=cd90d193ac5b4056f877a96f6ec748d0998021c4
MODE=${1:---prepare-only}

[[ -d $UPSTREAM/.git ]] || { echo "Run scripts/fetch-sources.sh first" >&2; exit 1; }
if [[ ! -d $STAGE/.git ]]; then
    mkdir -p "$ROOT/work"
    # A --shared clone cannot lazy-fetch missing blobs from the upstream's
    # promisor remote, which breaks fresh CI checkouts of a blobless source.
    git clone --no-checkout "$UPSTREAM" "$STAGE"
fi
git -C "$STAGE" checkout --detach "$COMMIT"
rm -rf "$STAGE/device/dubai" "$STAGE/packages/libcamera" \
    "$STAGE/packages/omamobile-device-dubai" "$STAGE/packages/omamobile-ucm-dubai"
cp -a "$ROOT/device/dubai" "$STAGE/device/dubai"
cp -a "$ROOT/packages/libcamera" "$STAGE/packages/libcamera"
cp -a "$ROOT/packages/omamobile-device-dubai" "$STAGE/packages/omamobile-device-dubai"
cp -a "$ROOT/packages/omamobile-ucm-dubai" "$STAGE/packages/omamobile-ucm-dubai"
cp "$ROOT/rootfs/packages.base" "$ROOT/rootfs/packages.omamobile" "$STAGE/rootfs/"
echo "Prepared $STAGE at Omarchy Mobile $COMMIT"
[[ $MODE == --prepare-only ]] && exit 0
[[ $MODE == --build ]] || { echo "Usage: $0 [--prepare-only|--build]" >&2; exit 2; }
mkdir -p "$ROOT/out/rootfs/logs"
exec > >(tee "$ROOT/out/rootfs/logs/build.log") 2>&1

export KERNEL_OUT=${KERNEL_OUT:-$ROOT/out/kernel}
[[ -f $KERNEL_OUT/modules-7.2.9-dubai+.tar.zst ]] || {
    echo "Build the kernel and modules first" >&2; exit 1;
}
export OMARCHY_KEYRING_DIR=${OMARCHY_KEYRING_DIR:-$ROOT/work/omarchy-keyring/usr/share/pacman/keyrings}
if [[ ! -f $OMARCHY_KEYRING_DIR/omarchy.gpg ]]; then
    keypkg=$ROOT/work/omarchy-keyring.pkg.tar.zst
    curl -fsSL --retry 3 -o "$keypkg" \
        https://pkgs.omarchy.org/stable/aarch64/omarchy-keyring-20251027-1-any.pkg.tar.zst
    echo 'cce48c07cfc2b97e198df1bc81705db2921685032fe39f18b4ddfd84264b5967  '"$keypkg" | sha256sum -c --quiet
    mkdir -p "$ROOT/work/omarchy-keyring"
    bsdtar -xf "$keypkg" -C "$ROOT/work/omarchy-keyring"
fi
cd "$STAGE"
[[ -f keys/dubai/public.asc ]] || tools/local-key-init dubai
mkdir -p work/published
python3 -I "$ROOT/scripts/fetch-published-selective.py" work/published
"$ROOT/scripts/fetch-hyprland-deps.sh"
tools/build-packages --local dubai --import work/published --import "$ROOT/work/omarchy-edge-deps"

# Remove Pixel Mali/Mesa and unused camera/fingerprint builds. Keep the
# signed Hyprland 0.57.1/aquamarine 0.16 pair fetched from Omarchy edge.
# Keep generic libcamera/libcamera-ipa until the local split packages replace
# them: their mutual dependencies must remain downloadable during the build.
python3 - <<'PY'
import pathlib, subprocess
repo = pathlib.Path('out/dubai/repo/aarch64')
for package in repo.glob('*.pkg.tar.*'):
    if package.name.endswith('.sig'):
        continue
    info = subprocess.check_output(['bsdtar', '-xOf', str(package), '.PKGINFO'], text=True)
    name = next(x.split(' = ', 1)[1] for x in info.splitlines() if x.startswith('pkgname = '))
    if name in {'mesa', 'vulkan-panfrost', 'vulkan-mesa-implicit-layers', 'hyprpm',
                'gst-plugin-libcamera', 'python-libcamera', 'libfprint'}:
        package.unlink()
        package.with_name(package.name + '.sig').unlink(missing_ok=True)
PY
tools/build-packages --local dubai packages/libcamera packages/omamobile-device-dubai packages/omamobile-ucm-dubai
tools/build-rootfs --local dubai --channel local
