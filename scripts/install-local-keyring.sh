#!/bin/bash
# SPDX-License-Identifier: MIT
# Install the local repository's public key for firstboot's pacman-key --populate.
set -euo pipefail
[[ $# == 2 ]] || { echo "Usage: $0 ROOTFS PUBLIC_KEY" >&2; exit 2; }
rootfs=$1
public_key=$2
[[ -d $rootfs && -f $public_key ]] || { echo 'Missing rootfs or public key' >&2; exit 1; }
key_info=$(gpg --batch --with-colons --show-keys "$public_key")
[[ $(awk -F: '$1 == "pub" {n++} END {print n+0}' <<<"$key_info") == 1 ]] || {
    echo 'Expected exactly one public signing key' >&2; exit 1;
}
fingerprint=$(awk -F: '$1 == "pub" {want=1; next} want && $1 == "fpr" {print $10; exit}' <<<"$key_info")
[[ $fingerprint =~ ^[0-9A-F]{40}$ ]] || { echo 'Invalid signing key fingerprint' >&2; exit 1; }
keyring_dir=$rootfs/usr/share/pacman/keyrings
install -d -m 0755 "$keyring_dir"
gpg --batch --yes --dearmor --output "$keyring_dir/dubai-local.gpg" "$public_key"
printf '%s:6:\n' "$fingerprint" > "$keyring_dir/dubai-local-trusted"
chmod 0644 "$keyring_dir/dubai-local.gpg" "$keyring_dir/dubai-local-trusted"
