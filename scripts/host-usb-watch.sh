#!/bin/bash
# SPDX-License-Identifier: MIT
# Host-side watcher for the dubai rescue session:
# 1. when the dubai-rescue USB gadget enumerates, bind the 172.16.42.2/24
#    profile (with the source-specific rescue table) to its interface;
# 2. once the address is up, start the persistent qemu-nbd server if absent.
set -u

REPO=/home/antona89/Documents/vscode/porting-motorola-omarchy/dubai-omarchy-porting
QEMU_NBD="$REPO/work/toolchain-qemu/usr/bin/qemu-nbd"
OVERLAY="$REPO/work/rootfs-dubai-live.qcow2"
LIBDIR="$REPO/work/toolchain-qemu/usr/lib/x86_64-linux-gnu"

iface_for_serial() {
    local path p
    for path in /sys/class/net/*; do
        p=$(realpath "$path/device" 2>/dev/null) || continue
        while [[ $p == /sys/devices/* ]]; do
            if [[ -r $p/serial ]] && [[ $(<"$p/serial") == dubai-rescue ]]; then
                basename "$path"
                return 0
            fi
            p=$(dirname "$p")
        done
    done
    return 1
}

start_nbd_server() {
    pgrep -x qemu-nbd >/dev/null && return 0
    echo "watcher: avvio qemu-nbd su $OVERLAY" >&2
    LD_LIBRARY_PATH="$LIBDIR" setsid nohup "$QEMU_NBD" --format=qcow2 \
        --persistent --shared=2 --aio=threads --cache=none \
        --bind=172.16.42.2 --port=10809 --export-name=omamobile \
        "$OVERLAY" >"$REPO/work/qemu-nbd.log" 2>&1 < /dev/null &
}

while true; do
    if iface=$(iface_for_serial); then
        if ! ip -brief addr show "$iface" 2>/dev/null | grep -q 172.16.42.2; then
            echo "watcher: $iface enumerato (dubai-rescue), attivo profilo" >&2
            nmcli connection up dubai-rescue-usb ifname "$iface" >&2 2>&1 || true
        fi
        if ip -brief addr show "$iface" 2>/dev/null | grep -q 172.16.42.2; then
            start_nbd_server
        fi
    fi
    sleep 1
done
