#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail
shopt -s nullglob
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
IMG=${ROOTFS_IMAGE:-$ROOT/work/rootfs-dubai-2026.11.07.img}
CONF=${FIRSTBOOT_CONF:?Set FIRSTBOOT_CONF to the private firstboot configuration}
PUB=${SSH_PUBLIC_KEY:?Set SSH_PUBLIC_KEY to a public .pub key}
ZAP=${DUBAI_ZAP_FIRMWARE:?Set DUBAI_ZAP_FIRMWARE to the private dubai zap firmware}
ADSP_DIR=${DUBAI_ADSP_DIR:?Set DUBAI_ADSP_DIR to the private adsp firmware directory}
MODEM_DIR=${DUBAI_MODEM_DIR:?Set DUBAI_MODEM_DIR to the private modem firmware directory}
WPSS=${DUBAI_WPSS_FIRMWARE:?Set DUBAI_WPSS_FIRMWARE to the private wpss.mbn}
BOARD=${DUBAI_WIFI_BOARD:?Set DUBAI_WIFI_BOARD to the private WCN6750 board-2.bin}
AUDIO=${DUBAI_AUDIO_FIRMWARE:?Set DUBAI_AUDIO_FIRMWARE to the private aw88261_acf.bin}

for file in "$IMG" "$CONF" "$PUB" "$ZAP" "$WPSS" "$BOARD" "$AUDIO"; do
    [[ -f $file ]] || { echo "Missing file: $file" >&2; exit 1; }
    [[ $file != *[[:space:]]* ]] || { echo "Paths with whitespace are not supported: $file" >&2; exit 1; }
done
[[ $PUB == *.pub ]] || { echo "SSH_PUBLIC_KEY must be a public .pub key" >&2; exit 1; }
dumpe2fs -h "$IMG" >/dev/null 2>&1 || { echo "Not an ext filesystem: $IMG" >&2; exit 1; }
if fuser "$IMG" >/dev/null 2>&1; then
    echo "Image is in use; stop qemu-nbd before provisioning it" >&2
    exit 1
fi

commands=$(mktemp)
trap 'rm -f "$commands"' EXIT
ensure_dir() {
    if ! debugfs -R "stat $1" "$IMG" 2>/dev/null | grep -c '^Inode:' >/dev/null; then
        printf 'mkdir %s\n' "$1" >>"$commands"
    fi
}
queue_install() {
    local src=$1 dest=$2
    printf 'rm %s\nwrite %s %s\nsif %s mode 0100644\nsif %s uid 0\nsif %s gid 0\n' \
        "$dest" "$src" "$dest" "$dest" "$dest" "$dest" >>"$commands"
}
verify_file() {
    cmp -s <(debugfs -R "cat $2" "$IMG" 2>/dev/null) "$1"
}
for dir in /etc/omamobile /root/.ssh /usr/lib/firmware/qcom/sm7325 \
           /usr/lib/firmware/qcom/sm7325/motorola /usr/lib/firmware/qcom/sm7325/motorola/dubai \
           /usr/lib/firmware/ath11k/WCN6750/hw1.0; do
    ensure_dir "$dir"
done
cat >>"$commands" <<EOF
rm /etc/omamobile/firstboot.conf
write $CONF /etc/omamobile/firstboot.conf
sif /etc/omamobile/firstboot.conf mode 0100600
sif /etc/omamobile/firstboot.conf uid 0
sif /etc/omamobile/firstboot.conf gid 0
sif /root/.ssh mode 040700
sif /root/.ssh uid 0
sif /root/.ssh gid 0
rm /root/.ssh/authorized_keys
write $PUB /root/.ssh/authorized_keys
sif /root/.ssh/authorized_keys mode 0100600
sif /root/.ssh/authorized_keys uid 0
sif /root/.ssh/authorized_keys gid 0
EOF

sources=("$ZAP" "$WPSS" "$BOARD" "$AUDIO")
dests=(
    /usr/lib/firmware/qcom/sm7325/motorola/dubai/a660_zap.mbn
    /usr/lib/firmware/qcom/sm7325/motorola/dubai/wpss.mbn
    /usr/lib/firmware/ath11k/WCN6750/hw1.0/board-2.bin
    /usr/lib/firmware/qcom/sm7325/motorola/dubai/aw88261_acf.bin
)
for file in "$ADSP_DIR"/adsp.mbn "$ADSP_DIR"/adsp*.jsn; do
    [[ -f $file && $file != *[[:space:]]* ]] || { echo "Invalid ADSP firmware: $file" >&2; exit 1; }
    sources+=("$file")
    dests+=("/usr/lib/firmware/qcom/sm7325/motorola/dubai/${file##*/}")
done
for file in "$MODEM_DIR"/modem.mbn "$MODEM_DIR"/modem*.jsn \
            "$MODEM_DIR"/cdsp.mbn "$MODEM_DIR"/cdsp*.jsn \
            "$MODEM_DIR"/yupik_ipa_fws.mbn; do
    [[ -f $file && $file != *[[:space:]]* ]] || { echo "Invalid modem firmware: $file" >&2; exit 1; }
    sources+=("$file")
    dests+=("/usr/lib/firmware/qcom/sm7325/motorola/dubai/${file##*/}")
done
# Optional SensorPD registry: the FairBlobs hexagonfs tree (sensors/ and
# socinfo/ are installed; acdb/ and dsp/ stay excluded like on pmOS).
HEXAGONFS=${DUBAI_HEXAGONFS_DIR:-}
if [[ -n $HEXAGONFS ]]; then
    [[ -d $HEXAGONFS/sensors && -d $HEXAGONFS/socinfo ]] || {
        echo "DUBAI_HEXAGONFS_DIR must point at a hexagonfs tree with sensors/ and socinfo/" >&2
        exit 1
    }
    hexroot=/usr/share/qcom/sm7325/Motorola/dubai
    for dir in /usr/share/qcom /usr/share/qcom/sm7325 \
               /usr/share/qcom/sm7325/Motorola "$hexroot"; do
        ensure_dir "$dir"
    done
    while IFS= read -r file; do
        rel=${file#"$HEXAGONFS"/}
        [[ $file != *[[:space:]]* && $rel != *[[:space:]]* ]] || {
            echo "Paths with whitespace are not supported: $file" >&2; exit 1; }
        ensure_dir "$hexroot/$(dirname "$rel")"
        sources+=("$file")
        dests+=("$hexroot/$rel")
    done < <(find "$HEXAGONFS" -type f ! -path '*/acdb/*' ! -path '*/dsp/*' | sort)
fi
for i in "${!sources[@]}"; do
    queue_install "${sources[$i]}" "${dests[$i]}"
done
debugfs -w -f "$commands" "$IMG" >/dev/null 2>&1 || true

cmp -s <(debugfs -R 'cat /etc/omamobile/firstboot.conf' "$IMG" 2>/dev/null) "$CONF"
cmp -s <(debugfs -R 'cat /root/.ssh/authorized_keys' "$IMG" 2>/dev/null) "$PUB"
for i in "${!sources[@]}"; do
    verify_file "${sources[$i]}" "${dests[$i]}"
done
e2fsck -fn "$IMG" >/dev/null
printf 'NBD raw rootfs provisioned and ext4 verified; no device was accessed\n'
