#!/bin/bash
# SPDX-License-Identifier: MIT
# Runs the docs/SUSPEND.md test matrix on the dubai device (Arch rootfs,
# as root) to root-cause the premature s2idle wake. Read-only except for
# transient state (Wi-Fi link, MPSS remoteproc, PM debug knobs), which the
# trap restores. Never masks the dwc3 IRQ: it carries the NBD rootfs.
# Not executed by this repository's CI; no device is accessed from here.
set -euo pipefail

DEST=${1:-}
if [[ -z $DEST ]]; then
    DEST=/var/tmp/dubai-suspend-tests-$(date +%Y%m%d-%H%M%S)
fi
[[ $DEST == /* ]] || { echo "Use an absolute output path" >&2; exit 2; }
mkdir -p "$DEST"
chmod 700 "$DEST"

[[ $EUID == 0 ]] || { echo "Run as root on the device" >&2; exit 2; }
grep -qw freeze /sys/power/state || { echo "/sys/power/state lacks freeze" >&2; exit 1; }

WIFI_IF=$(nmcli -t -f DEVICE,TYPE dev | awk -F: '$2=="wifi"{print $1; exit}')
USB_IF=$(ip -o -4 addr show | awk '/172\.16\.42\./ {print $2; exit}')
MPSS=/sys/class/remoteproc/remoteproc0/state

note() { printf '\n== %s\n' "$*" | tee -a "$DEST/console.log"; }

restore() {
    echo 0 > /sys/power/pm_debug_messages 2>/dev/null || true
    echo 0 > /sys/power/pm_print_times 2>/dev/null || true
    echo none > /sys/power/pm_test 2>/dev/null || true
    if [[ -z ${WIFI_WAS_DOWN:-} && -n $WIFI_IF ]]; then
        nmcli dev connect "$WIFI_IF" >/dev/null 2>&1 || true
    fi
    if [[ -z ${MPSS_WAS_DOWN:-} && -e $MPSS ]]; then
        echo start > "$MPSS" 2>/dev/null || true
    fi
}
trap restore EXIT

note "device: $(cat /sys/devices/soc0/machine 2>/dev/null || uname -m), kernel $(uname -r)"
note "wifi-if=$WIFI_IF usb-if=$USB_IF mpss=$MPSS"

if [[ ! -e /sys/power/pm_test ]]; then
    note "WARN: kernel lacks PM_DEBUG; rebuild with the current fragments before T4"
fi
echo 1 > /sys/power/pm_debug_messages 2>/dev/null || true
echo 1 > /sys/power/pm_print_times 2>/dev/null || true

snapshot() {
    local name=$1
    dmesg > "$DEST/$name-dmesg.txt"
    grep -E 'suspend|resume|dwc3|PM:' "$DEST/$name-dmesg.txt" | tail -40 > "$DEST/$name-pm.txt"
    sort -k5 -n -r /sys/kernel/debug/wakeup_sources | head -15 > "$DEST/$name-wakeup-sources.txt"
    cat /proc/interrupts > "$DEST/$name-interrupts.txt"
}

freeze_once() {
    local name=$1 secs=$2
    note "T: $name (freeze ${secs}s, $(date -Is))"
    sync
    if [[ -e /sys/class/rtc/rtc0/wakealarm ]]; then
        # rtcwake segfaults on this rootfs (util-linux); program the RTC
        # alarm by hand and enter freeze through sysfs.
        echo 0 > /sys/class/rtc/rtc0/wakealarm
        echo "+$secs" > /sys/class/rtc/rtc0/wakealarm || note "T: $name wakealarm refused"
        if ! echo freeze > /sys/power/state; then
            note "T: $name freeze entry refused"
        fi
    elif ! rtcwake -m freeze -s "$secs" >>"$DEST/console.log" 2>&1; then
        note "T: $name rtcwake FAILED (rc=$?)"
    fi
    snapshot "$name"
}

note "T0 baseline: 20 s freeze with pm_debug_messages on"
freeze_once t0-baseline 20

note "T1 Wi-Fi down, then 20 s freeze"
if [[ -n $WIFI_IF ]]; then
    nmcli dev disconnect "$WIFI_IF" >/dev/null 2>&1 || ip link set "$WIFI_IF" down
    WIFI_WAS_DOWN=1
else
    note "T1 skipped: no Wi-Fi interface found"
fi
freeze_once t1-wifi-down 20

note "T2 MPSS stop, then 20 s freeze"
if [[ -e $MPSS && $(cat "$MPSS") == running ]]; then
    echo stop > "$MPSS"
    MPSS_WAS_DOWN=1
    freeze_once t2-mpss-down 20
else
    note "T2 skipped: remoteproc0 not running"
fi

note "T3 stall host link TX, 20 s freeze, then remove qdisc"
if [[ -n $USB_IF ]] && tc qdisc help 2>/dev/null | grep -q netem; then
    tc qdisc add dev "$USB_IF" root netem delay 30s
    freeze_once t3-host-stalled 20
    tc qdisc del dev "$USB_IF" root
elif [[ -n $USB_IF ]]; then
    note "T3: netem qdisc unavailable in this kernel; stalling TX via link down"
    ip link set "$USB_IF" down
    freeze_once t3-host-stalled 20
    ip link set "$USB_IF" up
else
    note "T3 skipped: no gadget interface found"
fi

note "T4 pm_test bisect (core -> devices -> platform -> processors), 5 s each"
for level in core devices platform processors; do
    echo "$level" > /sys/power/pm_test 2>/dev/null || { note "T4: pm_test=$level unsupported"; continue; }
    freeze_once "t4-pmtest-$level" 5
done
echo none > /sys/power/pm_test

note "T5 manual: mask candidate IRQs one at a time from /proc/interrupts"
note "    (goodix/berlin, pmic_resin, spmi) with: echo 0 > /sys/kernel/irq/<n>/enabled"
note "    then re-run: rtcwake -m freeze -s 20"
note "    NEVER mask the dwc3 IRQ: it carries the NBD rootfs."
freeze_once t5-shim 20

note "done; results in $DEST"
printf 'Suspend test bundle: %s\n' "$DEST"
