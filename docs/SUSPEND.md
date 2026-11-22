<!-- SPDX-License-Identifier: MIT -->
# Dubai s2idle suspend analysis (M8)

Updated 2026-11-22 after RAM-only rescue `s2idle` testing on the CI
reference kernel (7.2.9-dubai+ #1, Landlock + PM_DEBUG).

## Confirmed facts (measured on hardware)

1. **s2idle entry and resume are reliable.** Every freeze enters and exits
   cleanly; uptime and the NBD link survive short sleeps.
2. **PMIC RTC wakeup from sustained `s2idle` works (2026-11-22).** In the
   RAM-only rescue initramfs (zero NBD traffic and zero NBD dependency),
   four consecutive `s2idle` freezes entered and exited cleanly with
   `suspend_stats/success=4, fail=0`:
   - 6 s with `usb0` up (`pm_wakeup_irq=115`, `pm8xxx_rtc_alarm`),
   - 11 s with `ip link set usb0 down` (`pm_wakeup_irq=115`),
   - 11 s with UDC `a600000.usb` unbound (`pm_wakeup_irq=115`),
   - 61 s control freeze (`pm_wakeup_irq=115`).
   This proves the PMIC → `spmi_pmic_arb` → PDC (`hwirq 1`) → GICv3 wakeup
   path is functional in mainline 7.2.9-dubai+.
3. **Why the 2026-11-12 tests appeared to show broken PMIC wake (two
   combined bugs, now root-caused):**
   - **PMK8350 RTC epoch mismatch:** `rtc-pm8xxx` keeps a raw hardware
     epoch (`rtc0/since_epoch` ≈ 247k–248k, Jan 1970) while NTP on the Arch
     rootfs advances `date +%s` to 2026 (`~1.795e9`). Writing
     `$(date +%s) + N` to `/sys/class/rtc/rtc0/wakealarm` therefore armed
     the hardware alarm **56 years in the future** so it never fired.
     `scripts/device-suspend-tests.sh` now computes the target from
     `/sys/class/rtc/rtc0/since_epoch`.
   - **NBD transport deadlock on `usb0` down:** `T3` in
     `scripts/device-suspend-tests.sh` took `usb0` down while `/` was
     mounted over `/dev/nbd0`, then called `note`/`sync`/`snapshot` before
     bringing `usb0` back up. Any userspace access to `/dev/nbd0` blocks in
     D-state once `usb0` is down, masking real kernel wakeups. `T3` now
     skips taking the interface down when `/` is backed by `/dev/nbd*`.
4. **The premature ~0.6 s wake on NBD is active USB gadget traffic.** With
   NBD traffic active on `usb0`, the system wakes after 0.6–0.8 s. In RAM
   rescue (idle `usb0`), it sleeps the full RTC duration without early USB
   wakeups.
5. **Deep SoC sleep (`qcom_stats/{aosd,cxsd}`) stayed 0 while USB was
   physically plugged in.** Even with `a600000.usb` unbound, `dwc3-qcom`
   logged `port-1 HS-PHY not in L2` and `aosd`/`cxsd`/`ddr` stayed `Count: 0`.
6. **rtcwake(1) segfaults on this rootfs** (util-linux); the matrix script
   programs the RTC alarm through sysfs (`rtc0/since_epoch + secs`) and
   enters freeze via `/sys/power/state` instead.
7. **Power-key (`pmic_pwrkey`, IRQ 116) wake during active `s2idle` still
   needs a timed confirmation.** IRQ 116 fires reliably at runtime (0 → 6 →
   12 on short presses) and `power/wakeup` is `enabled`, but in the two
   2026-11-22 RAM rescue attempts the press arrived just after the RTC
   fallback expired.

## Working hypothesis

Source inspection at kernel commit `0ccea71930dbc8e32344a41be96944db4215c3c3`
changes the proposed experiment: `drivers/spmi/spmi-pmic-arb.c` already
implements `qpnpint_irq_set_wake()` and calls `irq_set_irq_wake(bus->irq, on)`.
Dubai includes `sm7325.dtsi`, which includes `kodiak.dtsi`: the latter declares
the Qualcomm PDC and routes the SPMI arbiter through PDC hwirq 1. The driver is
`drivers/irqchip/qcom-pdc.c` and the running kernel reports `CONFIG_QCOM_PDC=y`.
On this boot sysfs identifies Linux IRQ 114 as PDC hwirq 1, and IRQs 115/116/117
as the RTC alarm, power key and resin PMIC children. Linux IRQ numbers are
runtime allocations and must be rediscovered after a boot. The PDC chip uses
`IRQCHIP_SKIP_SET_WAKE` and `IRQCHIP_ENABLE_WAKEUP_ON_SUSPEND`; propagation
alone does not prove that the wake path is armed and receives the interrupt
during s2idle. Do not add the same parent-wake call as a fix.

With the gadget link quiet the system reaches a sustained s2idle, but the
PMIC child interrupts (rtc, pwrkey, resin — SPMI edge IRQs) did not wake the
device in the recorded tests, while USB traffic did. The PDC is present and
the SPMI parent is routed through it; a defect in this path remains only a
hypothesis. The runtime `wakeup` attribute reads `disabled` for the parent
and children outside suspend; the driver callbacks set wake state during the
suspend sequence, so this observation alone does not prove a failure. Compare
the armed state during suspend and the behavior with postmarketOS.

### PM platform-test trace (2026-11-12)

Three `pm_test=platform` diagnostic cycles were run with the USB/NBD link
up. This mode resumes before the s2idle CPU sleep loop, so it does **not**
verify wake from sustained sleep. Function and kprobe traces show:

- On this boot, `irq_set_irq_wake(116, 1)` for the power key was followed by
  `irq_set_irq_wake(114, 1)` for its PDC parent; `irq_set_irq_wake(115, 1)`
  for the RTC was likewise followed by the same parent request. Matching
  disable calls appeared on resume.
- A separate return probe recorded four `qpnpint_irq_set_wake` returns of zero
  during a cycle; the entry-argument and return traces are separate runs.
- The PDC enable function also ran, but the function-only trace did not record
  its IRQ argument, so it cannot by itself identify which PDC line was enabled.

The first test's five-second debug delay ended early (about 0.28 s), consistent
with an intervening wake event; no source was attributed by these traces. The
results establish that the kernel makes and accepts the wake requests in this
diagnostic path, not that PMIC wake works after real s2idle. Trace files are in
the private capture directory `private-capture/2026-11-12/`. Test mode and
temporary probes were removed and `pm_test` returned to `none`.

## Consequences

- **M8 is unblocked at the kernel/PDC wake layer**, but not yet closed for
  daily-driver use:
  - `pmic_pwrkey` wake from active `s2idle` still needs an explicit in-window
    confirmation (now safe with a `since_epoch`-based RTC fallback).
  - True deep SoC sleep (`qcom_stats/{aosd,cxsd}` > 0) and battery standby
    drain must be measured with the USB cable physically unplugged (RAM-only
    test script first, then persistent storage once qualified).
  - On the NBD recovery rootfs, systemd sleep targets remain temporarily
    masked and UPower `CriticalPowerAction=PowerOff` stays set so NBD is
    not interrupted by an automatic suspend.

## Next diagnostic steps (in order)

1. Confirm `pmic_pwrkey` (IRQ 116) wake in RAM rescue with a generous
   `since_epoch` RTC fallback window (e.g. 180 s) so the press lands cleanly
   inside `s2idle`.
2. Run a RAM-only unplugged `s2idle` test (arm `since_epoch + 30`, unplug
   USB cable, wait 35 s, reconnect USB) and inspect `qcom_stats/{aosd,cxsd}`,
   `pm_genpd_summary`, and `pm_wakeup_irq` to determine whether unplugged
   `s2idle` enters CXSD/AOSD and whether PMIC RTC/pwrkey wakes from deep
   SoC sleep too.
3. Measure battery standby drain once unplugged `s2idle` is verified.

## Operational notes for future sessions

- Freeze without a working wake source bricks the session until a forced
  reboot (Power ~10 s) — always arm the RTC with an absolute epoch and
  confirm readback before entering freeze, and keep the USB link up unless
  someone can press buttons.
- The 2026-11-12 session also proved the BTF consistency rule:
  modules must come from the same build as the running kernel
  (`failed to validate module BTF: -22` otherwise); the CI artifact
  modules are installed into the live rootfs now.
