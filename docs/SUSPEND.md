<!-- SPDX-License-Identifier: MIT -->
# Dubai s2idle suspend analysis (M8)

Updated 2026-11-24 after full-rootfs unplugged `s2idle` testing on `/dev/sde27` and CI
reference kernel (7.2.9-dubai+ #1, Landlock + PM_DEBUG).

## Confirmed facts (measured on hardware)

1. **s2idle entry and resume are reliable.** Nine consecutive RAM-only
   `s2idle` freezes across 2026-11-22 and 2026-11-23 entered and exited
   cleanly with `suspend_stats/fail=0`.
2. **PMIC RTC (`IRQ 115`) and PMIC Power-Key (`IRQ 116`) wakeups from
   sustained `s2idle` both work (2026-11-22 & 2026-11-23).**
   - **RTC alarm (`pm8xxx_rtc_alarm`, `IRQ 115`):** Seven RAM-only `s2idle`
     freezes (6 s, 11 s `usb0` down, 11 s UDC unbound, 61 s, 121 s, and two
     6 s tests with `fb0` blanked and `usb_role=none`) slept their full
     programmed duration and woke cleanly with `pm_wakeup_irq=115`.
   - **Power key (`pmic_pwrkey`, `IRQ 116`, 2026-11-23):** With a 300 s
     `rtc0/since_epoch` safety fallback armed (`t1=959`, `alarm=1259`) and
     `usb0` down, a physical Power button press woke the device cleanly
     after **22 s** (`t2=981`, 278 s before the RTC fallback) with
     `pm_wakeup_irq=116`, `PM: Triggering wakeup from IRQ 116`, and
     `IRQ 116` incrementing `4 → 5, 1`. A second 30 s window also woke
     after **3 s** on `pm_wakeup_irq=116` (`IRQ 116: 9,1 → 10,2`).
   - This proves the full PMIC (`rtc` + `pon/pwrkey`) → `spmi_pmic_arb` →
     PDC (`hwirq 1`, `IRQ 114`) → GICv3 wakeup chain is functional in
     mainline `7.2.9-dubai+`.
3. **PSCI OSI APSS cluster reaches its deepest state `S2`
   (`cluster_sleep_llcc_off`, `0x4100b344`) on 100% of `s2idle` freezes
   (2026-11-23).**
   - `/sys/kernel/debug/pm_genpd/power-domain-cluster/idle_states`
     (`18200000.rsc`) recorded:
     - Runtime idle: `S0` (`cluster_sleep_apss_off`, `0x41000044`, 3,543
       entries, 26.4 s) and `S1` (`cluster_sleep_cx_ret`, `0x41001344`,
       34,056 entries, 749.0 s), with all 8 Kryo 670 cores using
       `little-rail-power-down` / `big-rail-power-down` (`0x40000004`).
     - System `s2idle`: **`S2` (`cluster_sleep_llcc_off`, `0x4100b344`)
       entered 5 out of 5 times (`Usage: 5, Rejected: 0, S2idle: 5`)**,
       confirming that `rpmh_rsc_pd_callback(GENPD_NOTIFY_PRE_OFF)` and
       `rpmh_flush()` succeed without rejection on every `s2idle` freeze.
4. **Why the 2026-11-12 tests appeared to show broken PMIC wake (two
   combined bugs, now root-caused):**
   - **PMK8350 RTC epoch mismatch:** `rtc-pm8xxx` keeps a raw hardware
     epoch (`rtc0/since_epoch`, Jan 1970) while NTP on the Arch rootfs
     advances `date +%s` to 2026 (`~1.795e9`). Writing `$(date +%s) + N` to
     `/sys/class/rtc/rtc0/wakealarm` therefore armed the hardware alarm
     **56 years in the future** so it never fired.
     `scripts/device-suspend-tests.sh` now computes the target from
     `/sys/class/rtc/rtc0/since_epoch`.
   - **NBD transport deadlock on `usb0` down:** `T3` in
     `scripts/device-suspend-tests.sh` took `usb0` down while `/` was
     mounted over `/dev/nbd0`, then called `note`/`sync`/`snapshot` before
     bringing `usb0` back up. Any userspace access to `/dev/nbd0` blocks in
     D-state once `usb0` is down, masking real kernel wakeups. `T3` now
     skips taking the interface down when `/` is backed by `/dev/nbd*`.
5. **The premature ~0.6 s wake on NBD is active USB gadget traffic.** With
   NBD traffic active on `usb0`, the system wakes after 0.6–0.8 s. In RAM
   rescue (idle or downed `usb0`), it sleeps the full programmed duration
   without early USB wakeups.
6. **Why `qcom_stats/{aosd,cxsd}` stayed 0 in RAM rescue while plugged in and unplugged
   (2026-11-23):**
   - Blanking `fb0` (`echo 4 > /sys/class/graphics/fb0/blank`) suspends
     `ae00000.display-subsystem`, `ae01000.display-controller`, and
     `ae94000.dsi`, dropping their `256` performance vote on `cx` to `0`.
   - In RAM rescue (even when physically unplugged with `VBUS_BEFORE=0uV`
     and `VBUS_AFTER=0uV`, `slept=26s`, `pm_wakeup_irq=115`, `S2` entered),
     two blockers still keep `cx` on: (a) `qcom-rpmhpd` (`18200000.rsc:power-controller`)
     retains `sync_state() pending` because `aa00000.video-codec` and the
     four remoteprocs (`adsp`, `cdsp`, `wpss`, `mpss`) are unbooted in
     initramfs, and (b) `a600000.usb` (`dwc3-qcom`) stays
     `runtime_status=active` (`role=device`, `port-1 HS-PHY not in L2`,
     vote `256` on `gcc_usb30_prim_gdsc` → `cx`).
   - On the full Arch/Omarchy rootfs (`work/rootfs-dubai-2026.11.13-recovery.qcow2`),
     all four remoteprocs (`modem`, `adsp`, `wpss`, `cdsp`) boot and
     `qcom-rpmhpd` `sync_state()` is **no longer pending**; `qcom_stats`
     confirms hardware sleep on `cdsp` (`Count: 120`), `modem` (`Count: 66`),
     and `wpss` (`Count: 3`), while `adsp` remains `0` (PipeWire/sensors active)
     and `a600000.usb` (`256`, NBD) + `99c000.serial` (`128`, BT UART7) hold
     `cx` active while USB NBD is connected.
7. **rtcwake(1) segfaults on this rootfs** (util-linux); the matrix script
   programs the RTC alarm through sysfs (`rtc0/since_epoch + secs`) and
   enters freeze via `/sys/power/state` instead. Upstream `omamobile-sleepd`
   is present on the rootfs (`omarchy-toggle omamobile-sleep on/off`) and
   automatically inhibits sleep while an SSH session is open, `Stay awake`
   is enabled, or a PipeWire sink is running.

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

- **M8 is proven at the PMIC/PDC wake layer (`IRQ 115` RTC + `IRQ 116`
  `pmic_pwrkey`), the PSCI OSI APSS cluster `S2` (`cluster_sleep_llcc_off`)
  layer, and full-rootfs `/dev/sde27` unplugged `s2idle` (46 s, `cdsp` +
  `modem` sleeping 100% of the freeze)**, with the following blockers/actions
  remaining before daily-driver enablement:
  - **Bluetooth UART7 wakeup (`IRQ 151`):** `99c000.serial/power/wakeup`
    (`msmgpio 31 Edge`) defaults to `enabled` and woke `s2idle` in `0 s`;
    disabling it persistently is now packaged in
    `omamobile-device-dubai 0.1.0-14` (`75-dubai-bluetooth.rules`), verified at
    cold boot with `bluetoothctl scan on` passing both before and after
    `s2idle` resume.
  - **ADSP/WPSS/USB isolation & chip-wide `aosd`/`cxsd`:**
    - `private-capture/2026-11-24/sde27-step2-isolated.log`: 31 s unplugged
      (`VBUS=0uV`) with `iio-sensor-proxy`, `hexagonrpcd`, and PipeWire stopped
      -> `slept=31s`, `pm_wakeup_irq=115`, `S2` `Usage: 1, Rejected: 0`,
      `cdsp`/`modem` ~30.8 s, `adsp`/`wpss`/`aosd`/`cxsd` = `0`.
    - `private-capture/2026-11-24/sde27-step2b-ath-usb.log`: 16 s unplugged
      with `a600000.usb/power/control=auto` (`suspended`, `cx` vote `0`),
      `rmmod ath11k_ahb` (`wpss` `11 -> 13` on unload, stayed `13` in freeze),
      and sensors/PipeWire stopped -> `slept=16s`, `pm_wakeup_irq=115`,
      `S2` `Usage: 2`, `cdsp`/`modem` +15.74 s, standby `current_now` dropped to
      `34485` uA at `4.293 V`; `adsp`, `aosd`, and `cxsd` stayed `0` (ADSP and
      `cx` remain voted active by audio/`pmic_glink` and `99c000.serial`).
    - Leaving `a600000.usb/power/control=auto` blocks USB re-enumeration on
      cable replug (keep `on` default); Hyprland 0.57 requires
      `hyprctl eval 'hl.dsp.dpms("on")'` after blanking.
  - **UPower / `qcom-battmgr` SOC hazard & `0006` removal:** raw ADSP
    `BATT_CURR_NOW` already uses Linux sign (`0006` caused `Discharging` to
    read positive). Removed `kernel/patches/0006-qcom-battmgr-sm7325-current-sign.patch`
    (pending CI kernel rebuild) and packaged `90-dubai-battery.conf`
    (`UsePercentageForPolicy=false`) in `omamobile-device-dubai 0.1.0-15`, so
    `upower -d` reports `warning-level: none` while `time_to_empty > 0`
    even when off-mode/fastboot charging leaves QBG `capacity=2%`.

## Next diagnostic steps (in order)

1. *(Done 2026-11-25)* Booted CI kernel `7b48084` (`0006` removed) on `/dev/sde27`: confirmed `qcom-battmgr-bat` `current_now` reads negative (`-281681 -> -264896` uA) while `charge_now` net-discharges (`114492 -> 114083` uAh under PC USB `SDP` `limit=100000`) and `upower -d` reports `discharging`, `warning-level: none`.
2. *(Checked 2026-11-26)* On standalone `8954580` `/dev/sde27`, `lpass_aon` (`3380000`) and `lpass_core` (`3900000`) are `status = "reserved"` (owned by ADSP firmware) and `lpass_audiocc` uses `qcom,qcm6490-lpassaudiocc` without `power-domains`; `pm_genpd_summary` shows `hlos1_vote_mmnoc_mmu_tbu_{sf0,hf0,hf1}_gdsc` `on` (with TBUs `suspended`), `disp_cc_mdss_core_gdsc` `on` (`ae00000.display-subsystem` `suspended`), `99c000.serial` active (`128` vote on `cx` at runtime), and `pmic_glink` (`altmode`, `power-supply`, `ucsi`) + `q6*` audio services attached to ADSP (`3700000.remoteproc`). Next step once battery is charged: test `s2idle` with `pmic_glink` / `q6*` unloaded and inspect suspend-time `cx` voters so `adsp`, `aosd`, and `cxsd` can sleep.
3. *(Analyzed offline 2026-11-26)* Kernel source + `cold-boot-full-audit.log` inspection traced why `disp_cc_mdss_core_gdsc`, `hlos1_vote_mmnoc_mmu_tbu_{sf0,hf0,hf1}_gdsc`, `gcc_ufs_phy_gdsc`, and `gcc_usb30_prim_gdsc` remain stuck `on` even when their consumers are `suspended`: `gcc-sc7280` (`100000.clock-controller`), `gpu_cc-sc7280` (`3d90000.clock-controller`), and `disp_cc-sc7280` (`af00000.clock-controller`) keep `sync_state()` pending indefinitely due to `chosen:framebuffer` (`CONFIG_DRM_SIMPLEDRM`/`CONFIG_SYSFB_SIMPLEFB`/`CONFIG_FB_SIMPLE` all unset) and `3d6a000.gmu` (looked up via `of_find_device_by_node()` in `a6xx_gmu_init()` with no bound `platform_driver`). Under strict `fw_devlink.sync_state`, `of_genpd_sync_state()` never runs and `genpd->stay_on` stays `true` (`drivers/pmdomain/core.c`). Added `CONFIG_FW_DEVLINK_SYNC_STATE_TIMEOUT=y` to `device/dubai/kernel{,-llvm}.config` (`CONFIG_DRIVER_DEFERRED_PROBE_TIMEOUT=10` is already enabled) and prepared an offline `8954580` test boot image with `fw_devlink.sync_state=timeout` in cmdline (`out/images-userdata-8954580-syncstate/boot-dubai-csot-UNTESTED.img`) to verify GDSC power-off and `cxsd`/`aosd`/`adsp` behavior on hardware once connected.
4. *(Live diagnostic + patch `0013` on 2026-11-26)* Live inspection over Wi-Fi SSH (`192.168.1.164`) confirmed: (a) stopping `iio-sensor-proxy`, `hexagonrpcd-adsp-sensorspd`, `pipewire`, and `wireplumber` leaves `qcom_stats/adsp` at `Count: 0` while `LPASS_HW_MACRO` and `LPASS_HW_DCODEC` (`q6afe-clocks.c`) stay enabled by `lpass-rx-macro.c`, `lpass-tx-macro.c`, and `lpass-va-macro.c` (`va_macro` still held refcount `1` on `3370000.codec` even when `3370000.codec` reported `runtime_status=suspended`, and removing `rx_macro`/`tx_macro` dropped refcounts `3 -> 1`); `lpass-{rx,tx,va}-macro.c` enable `macro`/`dcodec` in `_probe()` and never disable them in `runtime_suspend()` or define `SYSTEM_SLEEP_PM_OPS`. (b) `rfkill block bluetooth` immediately transitions `99c000.serial` to `runtime_status=suspended` and drops `gcc_qupv3_wrap0_s7_clk` `clk_enable_count` to `0`. Added and LLVM-compiled `kernel/patches/0013-ASoC-codecs-lpass-macro-drop-clock-votes-on-suspend.patch` (`macro`/`dcodec` runtime suspend/resume + `pm_runtime_force_suspend`/`resume` + suspended-safe `_remove()`); next hardware step is booting the rebuilt kernel with `fw_devlink.sync_state=timeout` + `0013` and testing `s2idle` with `rfkill block bluetooth` (and unplugged `VBUS=0`) to measure `qcom_stats/{adsp,aosd,cxsd}`.

## Operational notes for future sessions

- Freeze without a working wake source bricks the session until a forced
  reboot (Power ~10 s) — always arm the RTC with an absolute epoch and
  confirm readback before entering freeze, and keep the USB link up unless
  someone can press buttons.
- The 2026-11-12 session also proved the BTF consistency rule:
  modules must come from the same build as the running kernel
  (`failed to validate module BTF: -22` otherwise); the CI artifact
  modules are installed into the live rootfs now.
