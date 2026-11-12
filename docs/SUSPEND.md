<!-- SPDX-License-Identifier: MIT -->
# Dubai s2idle suspend analysis (M8)

Updated 2026-11-12 after the first live instrumented session on the CI
reference kernel (7.2.9-dubai+ #1, Landlock + PM_DEBUG).

## Confirmed facts (measured on hardware)

1. **s2idle entry and resume are reliable.** Every freeze enters and exits
   cleanly; uptime and the NBD link survive short sleeps.
2. **The premature ~0.6 s wake is USB gadget link traffic.** With the
   RNDIS/NBD gadget link up and an active host, the system wakes after
   0.6–0.8 s regardless of the RTC alarm length. With the gadget link
   administratively down (`ip link set usb0 down`), the system enters a
   sustained freeze — verified twice (the phone stayed asleep for minutes
   until a forced reboot).
3. **`HS-PHY not in L2` is a symptom, not the cause.** It appears at every
   suspend while the link is up and is absent with the link down.
4. **No other wake source wakes s2idle.** The RTC wakealarm
   (`/sys/class/rtc/rtc0/wakealarm`, absolute epoch — the `+N` relative
   syntax reads back garbage) and the PMIC power key both fail to wake the
   system from a sustained freeze. Both devices report `power/wakeup:
   enabled`, and the RTC interrupt fires at runtime (count 0 → 1 on a +3 s
   alarm), so PMIC→AP delivery works while running.
5. **rtcwake(1) segfaults on this rootfs** (util-linux); the matrix script
   programs the RTC alarm through sysfs and enters freeze via
   `/sys/power/state` instead.

## Working hypothesis

With the gadget link quiet the system reaches a sustained s2idle, but the
PMIC SPI interrupts (rtc, pwrkey, resin — all `spmi` edge IRQs) do not wake
the WFI-ing CPUs, while USB (dwc3) interrupts do. The QCOM PDC wakeup
controller present in some form on sc7280 (kodiak.dtsi carries
`qcom,sc7280-pdc`) has **no driver in this kernel tree** (no
drivers/soc/qcom/pdc.c, no irqchip PDC) and dubai/sm7325 DTS carries no pdc
node, so there is no evidence a PDC path is programming those interrupts as
wakeup sources at the always-on level. pmOS uses the same kernel base, so
either pmOS on dubai has the same gap (likely, undocumented) or something
in its userspace bring-up differs — to be checked against a pmOS boot.

## Consequences

- **M8 is not closable yet**: a phone that cannot be woken (pwrkey) after
  suspend is not usable, independent of the USB/NBD storage strategy.
- The storage question also remains: with the NBD link up the phone cannot
  stay asleep; a persistent install with an idle/host-suspended USB port
  would avoid the USB wakeups but still needs PMIC wake.

## Next diagnostic steps (in order)

1. Compare with postmarketOS on dubai: does suspend+resume actually work
   there (device wiki, or a pmOS USB boot test)? If pmOS suspends and wakes
   with pwrkey, diff the runtime state (which remoteprocs run, any PDC/
   TLMM wake config scripts).
2. Capture suspend-time IRQ state: with `pm_debug_messages=1`, freeze with
   the link down and dump `/sys/kernel/irq/<n>/{wakeup,disable_depth}` for
   the spmi/rtc/pwrkey IRQs before and after entry, plus the PM core's
   noirq log lines, to see whether the interrupts are being disabled at
   suspend.
3. Test whether `irq_set_irq_wake` on the spmi_arb parent SPI makes the
   child PMIC interrupts wake the system (kernel experiment; PDC driver
   absence makes this the likely fix area).
4. Re-run `scripts/device-suspend-tests.sh` once a wake source works, to
   measure real sleep duration vs the RTC alarm and then standby
   consumption on battery.

## Operational notes for future sessions

- Freeze without a working wake source bricks the session until a forced
  reboot (Power ~10 s) — always arm the RTC with an absolute epoch and
  confirm readback before entering freeze, and keep the USB link up unless
  someone can press buttons.
- The 2026-11-12 session also proved the BTF consistency rule:
  modules must come from the same build as the running kernel
  (`failed to validate module BTF: -22` otherwise); the CI artifact
  modules are installed into the live rootfs now.
