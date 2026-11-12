<!-- SPDX-License-Identifier: MIT -->
# Dubai s2idle suspend analysis (M8)

State after the 2026-11-11 sessions: `freeze` (s2idle) entry and resume are
reliable — five `rtcwake -m freeze` runs entered and exited cleanly with
continuous uptime and a live NBD link. Every sleep still ended after
0.65–0.82 s regardless of the requested duration, so sustained sleep and
standby consumption remain unproven.

## What the kernel tells us

`dwc3_qcom_suspend()` (drivers/usb/dwc3/dwc3-qcom.c:349) logs
`port-1 HS-PHY not in L2` whenever `PWR_EVNT_IRQ_STAT` lacks
`PWR_EVNT_LPM_IN_L2` at suspend time. That check is informational: with the
RNDIS/NBD gadget link active, the host keeps the port out of L2, so the
message appears on every suspend. It proves the USB link was awake at entry;
it does not by itself prove the USB link caused the wake.

`/sys/kernel/debug/wakeup_sources` showed zero active counts for every
registered source after the wakes (including `pwrkey` and the RTC), so the
wake is either a PHY/IRQ-level event that is not accounted as a wakeup
source, or a source that re-arms itself.

## Candidate wake sources, ranked

1. **USB gadget link activity (dwc3).** The NBD rootfs shares the link with
   the host; host-side traffic (TCP ACKs, timer ticks in qemu-nbd or
   NetworkManager) reaches a PHY whose link never reached L2. Disabling the
   USB wakeup flag in one test did not change the 0.7 s wake, but the
   PHY-level interrupt path (`qcom_dwc3_resume_irq`) does not depend on the
   generic wakeup flag. *Test first.*
2. **Modem (MPSS) traffic.** MPSS was left running with rmtfs/tqftpserv
   attached; QRTR/SMD heartbeat traffic can raise glink interrupts in
   s2idle. postmarketOS suspends the modem PD as part of its low-power
   flow, which we have not replicated.
3. **Wi-Fi (ath11k).** The interface was up and associated; without a
   wowlan configuration the firmware may wake the host on RX. Dubai's
   calibration fallback warning means wowlan was never validated either.
4. **Touch/sensor IRQ noise.** Goodix and the PMIC keys are registered
   wakeup sources with zero counts — least likely.

The fixed ~0.7 s period (independent of the requested sleep length) points
at a periodic source: modem heartbeat or host link traffic are the best
fits; the RTC alarm is ruled out because 60 s requests also woke at 0.7 s.

## Runtime instrumentation (next reference kernel)

Both kernel fragments now enable `CONFIG_PM_DEBUG=y` and
`CONFIG_PM_SLEEP_DEBUG=y`, which unlock, without further rebuilds:

- `echo 1 > /sys/power/pm_debug_messages` — PM core logs device suspend
  and resume timing, and which device reports first on resume.
- `echo 1 > /sys/power/pm_print_times` — entry/exit latency per phase.
- `/sys/power/pm_test` — freeze devices at a chosen phase (none/core/
  processors/platform/devices) to bisect which phase releases the wake.

## Test matrix for the next device session

`scripts/device-suspend-tests.sh` automates T0–T3 and T5 below (run as
root on the device, output bundle in `/var/tmp/dubai-suspend-tests-*`);
T4 runs too when the kernel has PM_DEBUG. Each test restores the Wi-Fi
link and MPSS afterwards and never touches the dwc3 IRQ.

Run each test from a root shell while serving the NBD rootfs as usual, and
capture `dmesg -Tw` plus `/sys/kernel/debug/wakeup_sources` (sorted by
`active_count`) immediately after each wake.

| # | Action | Expected if the hypothesis holds |
|---|--------|----------------------------------|
| T0 | Baseline with `pm_debug_messages` + `pm_print_times` on, then `rtcwake -m freeze -s 20` | dmesg shows which device suspends last / resumes first, and any `noirq` wake report |
| T1 | `ip link set wld0 down` (kill Wi-Fi RX), then freeze 20 s | sleep sustains past 0.7 s → ath11k; re-enable wowlan patterns afterwards |
| T2 | Stop MPSS (`echo stop > /sys/class/remoteproc/remoteproc0/state`), freeze 20 s | sleep sustains → modem heartbeat; document the pmOS low-power modem flow as a prerequisite |
| T3 | From the host, stop the qemu-nbd server and all traffic generators (`nmcli` down the gadget profile is not possible — instead `tc qdisc add dev <if> root netem delay 10s` to stall TX), freeze 20 s | sleep sustains → host link traffic via dwc3 |
| T4 | `echo core > /sys/power/pm_test` then freeze | if wake persists even in pm_test=core, the source is outside device suspend (IRQ-level); bisect further with `devices`, `platform`, `processors` |
| T5 | If T0–T4 isolate nothing: mask IRQs one by one from `/proc/interrupts` candidates (goodix, pmic, dwc3) with a userspace freeze in between | the wake stops when the offending IRQ is masked |

Success criterion for closing M8 suspend: a 60 s `freeze` with Wi-Fi up and
the NBD link live lasts ≥ 55 s, resumes cleanly from the power button or
RTC, and `pm_print_times` shows stable entry/exit latencies. Only then
measure standby consumption (battery delta over a timed window on battery
power with the USB link in host-suspended state).

## Non-goals

Do not enable suspend-by-default in the device package before the success
criterion passes, and do not claim battery-life numbers from the NBD
configuration — the serving link is also the charging source, so discharge
measurements are impossible in this setup.
