<!-- SPDX-License-Identifier: MIT -->
# Technical state of the port

Updated: 2026-11-25.

## Current state

- **Phase:** Alpha 0, Alpha 1, and Alpha 2 reached on the owner's CSOT device, with major Beta milestones (M8 PMIC RTC + power-key wakeup, PSCI OSI cluster `S2` deep sleep, full-rootfs unplugged `s2idle`, `AW86224` haptics, `qcom-battmgr` discharge sign, and full M9 telephony/data/SMS/calls/GNSS) proven on hardware across 2026-11-22–2026-11-25:
  - **M8 (`s2idle`):** Ten real `s2idle` freezes across 2026-11-22 and 2026-11-23 all entered and exited cleanly (`suspend_stats/fail=0`), waking reliably on both `pm8xxx_rtc_alarm` (`IRQ 115`, including a true unplugged `VBUS = 0 uV` 26 s freeze) and physical `pmic_pwrkey` presses (`IRQ 116`, `slept=22s` inside a 300 s RTC window and `slept=3s` inside a 30 s window; `PM: Triggering wakeup from IRQ 116`). On 2026-11-24 on internal `/dev/sde27` (`19.286s` boot, `graphical.target` `3.143s`), unplugged full-rootfs testing exposed two blockers: (a) `upowerd` triggered `CriticalPowerAction=PowerOff` on unplug because `qcom-battmgr-bat` reported `capacity=2` (`voltage_ocv=3.460–3.688 V`, `charge_now=100180` uAh) despite `vbat_sns=4.10–4.23 V` (and `current_now` read positive `+224 mA -> +41.8 mA` while `status=Discharging`); (b) `99c000.serial/power/wakeup` (`IRQ 151`, `99c000.serial:wakeup`, `msmgpio 31 Edge`, Bluetooth UART7) immediately woke `s2idle` at `slept=0s`. With `99c000.serial/power/wakeup=disabled` (and `upower.service` runtime-masked), full-rootfs `s2idle` slept `11s` plugged (`usb0` down, `S2`) and **46 s physically unplugged** (`VBUS=0uV`, `slept=46s`, `pm_wakeup_irq=115`, `S2` `Usage: 5 -> 8, Rejected: 0`, `suspend_stats/fail=0`), during which `cdsp` (`+46.26 s`) and `modem` (`+46.26 s`) slept 100% of the freeze and `current_now` dropped `224 mA -> 41.8 mA`, while `adsp`, `wpss`, `aosd`, and `cxsd` stayed `0` (sensors/PipeWire and Wi-Fi active). `docs/SUSPEND.md`.
  - **M9 (Telephony, Data, SMS, Calls, GNSS):** With a physical SIM inserted and `persist:/rfs/msm/mpss` (`dhob.bin`, `shob.bin`, `datablock/*`, `cal_rfs/*`, `mot_rfs/imei_sv`) seeded read-only via `debugfs` into `/var/lib/tqftpserv` (all six UFS LUNs `ro=1`), the USIM reached `ready`, registered on 4G LTE / 5G NR (`FASTWEB`), passed ICMP ping and HTTPS over `qmapmux0.0` (`rmnet_ipa0`), stored incoming SMS via `omatel-agent`, streamed live GPS NMEA (`$GPGSV`), and passed two-way voice calls on both Earpiece and Speakerphone using `dummystreamhack`, `omamobile-ucm-dubai 0.1.0-3`, and `dubai-callaudiod` (`omamobile-device-dubai 0.1.0-11`; see `docs/TELEPHONY.md`). On 2026-11-23, `omamobile-device-dubai 0.1.0-11` and `omamobile-ucm-dubai 0.1.0-3` were built and installed onto `work/rootfs-dubai-2026.11.13-recovery.qcow2`, and `org.mobian_project.CallAudio` D-Bus profile switching was verified against PipeWire 1.6.11.
  - **M10/M11 (Omarchy Mobile UX, Sensors, Autorotation):** Cold boot on `work/rootfs-dubai-2026.11.13-recovery.qcow2` (`24.085s` total, `graphical.target` in `8.403s`) brought up Hyprland (`DSI-1` `1080x2400@144Hz`, Freedreno OpenGL 4.6 / GLES 3.2), battery/charging, Bluetooth (`02:00:CB:E4:DF:7E`), Wi-Fi, accelerometer, light (`263.33 lux`), live compass (`268.9°–355.4°`), `omamobile-autorotate.service`, and `serial-getty@ttyGS0.service`. Measured idle memory (`3437 MiB` used of `7367 MiB`) and Hyprland app launch-to-map latencies (`535–1189 ms` over NBD). Added `zram-generator 1.2.1-1` to `rootfs/packages.base` and `omamobile-device-dubai 0.1.0-12` `depends`, activating `3683 MiB` (`ram / 2`) `zstd` swap on `/dev/zram0` (priority `100`) from the existing `90-omarchy.conf`/`91-omamobile.conf` drop-ins and `99-omarchy-sysctl.conf` (`vm.swappiness=150`, `vm.page-cluster=0`).
  - **Internal `userdata` (`sde27`) persistent boot (2026-11-23):** With owner authorization (LineageOS expendable), cloned the verified recovery rootfs onto internal `/dev/sde27` (`userdata`, expanded to `107 GiB` ext4, `9.7 GiB` used) and booted via `fastboot boot` (`out/images-userdata/boot-dubai-csot-UNTESTED.img`, `22.088s` total, `graphical.target` `6.815s`) with fail-closed `UFS_RW=userdata` / `ROOT_DEVICE=userdata` in `initramfs/init` and `10-dubai-storage.rules` (`omamobile-device-dubai 0.1.0-13`). Whole-disk `/dev/sde` node is removed and masked (`MODE="0000"`), every other UFS disk/partition (`sda`–`sdd`, `sde1`–`sde26` incl. `persist`/`modemst1`/`modemst2`/`fsc`/`super`/`metadata`, and `sdf`) stays `ro=1`, ZRAM (`3.6 GiB` `zstd`) came up at cold boot, and all 4 remoteprocs, Wi-Fi, BT, sensors, ModemManager, and battery charging came up cleanly.
- **Port commit:** branch `main` published at `https://github.com/Lwb89dev/dubai-omarchy-porting` (gh authenticated as Lwb89dev with the `workflow` scope; CI green on run 43244056166).
- **Omarchy Mobile:** `cd90d193ac5b4056f877a96f6ec748d0998021c4`.
- **Kernel:** 7.2.9, tag `v7.2.9-sc7280`, commit `0ccea71930dbc8e32344a41be96944db4215c3c3`, plus seven out-of-tree patches (S32 speaker pair, S5KJN1 selection, battmgr charge units, SM7325 POWER_NOW hiding, SM7325 current sign, and the dt-bindings lpass-tx-macro SM7325 fix). The next reference build additionally enables CONFIG_SECURITY_LANDLOCK (pacman 7 sandbox) and CONFIG_PM_DEBUG/PM_SLEEP_DEBUG (suspend instrumentation); neither changes runtime paths by itself.
- **Arch Linux ARM:** rootfs `2026.11.08` lineage, served as `work/rootfs-dubai-live.qcow2` over the flattened and fsck-repaired `work/rootfs-dubai-live-flat2.img`; SHA-256, smoke test, RNDIS/NBD firstboot, pacman, and SSH passed.

## Builds and tests

2026-11-12 continuation: the phone was reachable over SSH and running the CI
kernel with systemd. The first on-device `libssc` build failed because
`/usr/bin/g-ir-scanner` was missing despite the introspection pkg-config
metadata being present. Added `gobject-introspection` to its build dependencies;
the corrected package built successfully on the phone as `libssc 0.4.4-2`.
makepkg warned that
`usr/lib/installed-tests/libssc/ssc-server` references `$srcdir`; investigate
the installed test before treating the package as release-ready. The build
dependencies were installed on the NBD rootfs. The NBD root filesystem had
889 MiB free before the attempt and 853 MiB after sensor builds. `tests/static.sh`
could not finish on this host because ShellCheck is unavailable.

On-device sensor test: installed `libssc 0.4.4-2`, `hexagonrpcd 0.4.0-1`
(both upstream Meson tests passed), and `iio-sensor-proxy 3.9-1` (package
skips upstream tests). The sensorspd daemon starts with the Dubai `-R`
drop-in; SSC service 400 appears on QRTR and `ssccli` allocates a client,
but reports the registry sensor unavailable. `monitor-sensor` reports no
accelerometer, light, proximity or compass. The daemon reports missing
`sns_reg_version` and rejects writes to it and `temp.json`: its 0.4.0
`apps_std_fopen_with_env()` explicitly rejects `w` and `a` modes. This is
evidence for a registry initialization problem, not proof of the sole cause.
The daemon maps a virtual registry to the firmware tree; the existing
`/mnt/vendor/persist` bind mount is backed by `/dev/nbd0` and is not the
Android persist partition. No Android partition was modified. Stopped the
proxy after the test because it repeatedly retried; the sensorspd daemon
remains enabled and running. Investigate a narrowly scoped writable virtual
registry backed by the Linux rootfs, including traversal confinement and
upstream compatibility, before another hardware test.

Follow-up read-only registry experiment: the virtual mapping exposed only
`.../registry/registry`, so the DSP's `../sns_reg_version` reached an
unmapped virtual parent. A disposable daemon mapped the parent from a copied
tree in `/tmp` and provided an empty version file. A host fixture test verified
both the parent path and an entry; on the phone the daemon built and its two
upstream tests passed. The missing-version read errors disappeared, but 1089
`temp.json` write requests were rejected in the short run and
`monitor-sensor` still found no sensors. The original daemon was restored;
the proxy was stopped (it needed SIGKILL after its stop timeout, and its
failed state was reset). No Android partition was touched. Experiment patch
and fixture test are in `tests/experiments/sensor-registry/`; they are not
installed or part of the package. Upstream issue 19 and draft PR 21 discuss
this interface; the draft simulates writes and is not a verified solution.

Writable experiment: built GPL-licensed FadyAckad/hexagonrpc branch
`sp11-sensors` at `40e50412812adce9dddc2be9a4510ebce05eef89` on-device;
all three upstream tests passed. It was run only as a transient service,
with `ProtectSystem=strict`, `ProtectHome=yes`, `NoNewPrivileges=yes`, and
write access limited to a copied registry in `/tmp`. A separate test exercised
create/write/rename/read/unlink and checked that a symlink to an outside
canary could not be opened for writing in the same sandbox. This is not a
complete security audit. SSC then supplied real readings: ambient light
190.744 lux and accelerometer Z around 9.77 m/s² at rest. The firmware reports
an all-zero mount matrix to libssc, which falls back to identity. The
experimental daemon was stopped and the original restored; no permanent
write-enabled daemon was installed. `iio-sensor-proxy` initially advertised
only light and compass because its 3.9 udev rule omits `ssc-accel`. Adding it
temporarily made the proxy report an accelerometer, though orientation stayed
undefined during the short monitor test. A repo rule now adds `ssc-accel`;
the package update has not been installed. Proxy readings/rotation and
restart persistence remain unverified; no daily-driver claim follows.

Startup-race follow-up: with the experimental writable registry and temporary
`ssc-accel` udev rule, `monitor-sensor --accel` after proxy discovery produced
a `face-down` tilt event. The 3.9 proxy exports D-Bus objects before SSC
discovery completes; immediate claims previously produced null array/device
assertions. Adapted Robin Snyders' startup-order patch (source attributed in
`packages/iio-sensor-proxy/startup-order.patch`): discovery and driver opening
precede D-Bus registration. With the temporary binary and an immediate client,
the accelerometer appeared and produced `face-down` without those assertions
in the captured journal. This is one startup, not a repeatability or rotation
test. Built `iio-sensor-proxy 3.9-2` on-device; all three available Meson tests
passed and the package now runs them in `check()`. Version 3.9-2 is installed
on the NBD rootfs, but the proxy is stopped because the writable daemon is
still experimental; the original hexagonrpcd service was restored. Persistent
setup, boot sequencing, physical rotation, and security review remained open.

Installed follow-up: `omamobile-device-dubai 0.1.0-10` now seeds a copy of the
firmware sensor registry under `/var/lib/dubai-hexagonrpc` without mounting
Android persist. The new `hexagonrpcd-dubai-experimental 0.5.0.r40e5041-1`
package replaces 0.4.0 on the NBD rootfs and uses the service mount sandbox;
`iio-sensor-proxy 3.9-2` is installed. Both experimental package and proxy
passed their three available Meson tests. On the live system stopping the
setup, daemon and proxy and starting the daemon brought up its required setup
unit; restarting the proxy yielded `face-down` tilt and 190.744 lux through
`monitor-sensor`. No reboot was attempted; physical rotation and cold-boot
persistence are not verified. See `docs/SENSORS.md` for rollback and limits.

Follow-up authorized temporary boot on 2026-11-12: bootloader identified
`dubai`, slot b was bootable with two retries; the checked NBD CSOT image
booted via `fastboot boot`. The NBD rootfs reached systemd, sensor setup,
hexagonrpcd and iio-sensor-proxy started automatically, and the copied registry
was present. After boot the proxy reported 162.048 lux and `face-down` tilt.
Initial missing registry-version and `sns_geomag_rv*.so` messages and the
firmware mount-matrix warning remain. This is one full boot, not repeated
boot, movement, compass or calibration qualification. USB enumeration had
transient errors before the connection stabilized.

Autorotation follow-up: the owner reported rotation was not working. The
Hyprland client was absent; installed `omamobile-autorotate-dubai 0.2.1-1`,
packaging the unmodified upstream Omarchy autorotation client without its
Pixel sensor backend, and enabled its user service. `monitor-sensor` reported
`normal`, `left-up`, and `right-up` on movement, and the owner confirmed that
the display rotates. The service is active and enabled; restart persistence,
touch alignment at each orientation and lock-screen behavior remain untested.

Follow-up after that boot: the autorotation service, sensor proxy and daemon
remain active, and Hyprland sees the Goodix touchscreen. Asked to test touch
in portrait and landscape, the owner reported that touch works. ModemManager,
rmtfs and tqftpserv were active and remoteproc0
running. ModemManager listed the Qualcomm modem but reported it failed;
`rmnet_ipa0` was present and down, and both UIM slots still returned
`no-atr-received`. Card presence and the reason for the failed response remain
unknown. The rootfs builder now stages and selects the SSC, patched proxy,
experimental daemon and autorotation packages; staging was checked in a
disposable worktree. A complete rootfs build has not been run: the current
host user has no Docker socket access and passwordless sudo is unavailable.
Proxy 3.9-3, with an explicit `libxml2` build dependency, was built and passed
three tests on the phone; the running rootfs still has 3.9-2. A stale Git
object-alternates path in the existing staged checkout was repaired to a
relative path after the workspace moved.

| Activity | Result | Evidence |
|---|---|---|
| Source fetch | Pass | Checkouts and archives in `sources.lock` |
| ShellCheck/syntax | Pass | `tests/static.sh` |
| GCC and LLVM kernel builds | **Pass offline** | Image/Image.gz, both DTBs, 636 LLVM module entries, and SHA-256 |
| Initramfs build | **Pass** | RAM-only, reproducible; variants with modules, SSH, dubai firmware, and NBD |
| Arch/Omarchy GCC rootfs | **Pass offline** | Checksums and smoke test passed |
| Arch/Omarchy LLVM rootfs | **Pass offline** | Checksum, smoke test, and e2fsck of the NBD copy passed |
| Device/UCM packages | **Pass on device** | `omamobile-device-dubai` 0.1.0-6 and `omamobile-ucm-dubai` 0.1.0-2 installed and exercised |
| Boot-chain backup | **Pass** | Eight original images, two matching SHA-256 reads |
| Mainline boot without an empty DTBO | **Fail** | GCC/LLVM/Nura return to fastboot; no shell |
| Mainline boot with an empty DTBO | **Pass M3** | Kernel 7.2.9-dubai+, CSOT model, ACM/NCM/SSH active |
| Arch RNDIS/NBD | **Pass on the current 2026.11.08 rootfs** | Clean firstboot, final device/UCM packages, systemd, SSH, pacman, UFW, Hyprland, GPU and PipeWire; no stuck requests during these tests |
| Display/touch | **Pass on device** | Hyprland 1080×2400 up to 144 Hz, DPMS wake, and Goodix multitouch verified |
| Storage guard | **Pass** | Every `sda`–`sdf` LUN read-only; no Android mount |
| Accelerated GPU | **Pass on device** | EGL Freedreno Adreno, OpenGL ES 3.2; a dubai-specific zap is required |
| Wi-Fi | **Pass on device** | WPSS/ath11k, WPA2, DHCP, DNS, Internet ping, and HTTPS; calibration fallback warning remains |
| Bluetooth | **Pass on device; boot automation partial** | Pairing/A2DP pass; the first udev helper raced firmware setup, runtime configuration was recovered, and the revised helper needs another boot test |
| Audio | **Pass on device** | UCM HiFi, PipeWire playback/capture and a clearly audible 10-second ALSA tone at 50%; backend S32_LE with Q6 mapping verified; playback also passes with libcamera nodes active |
| Battery/charging | **Verified without `0006` + UPower policy guard (`0.1.0-15`) (2026-11-25)** | Booted CI kernel `7b48084` (`0006` removed) on `/dev/sde27`: under PC USB `SDP` (`input_current_limit=100000`, `usb/current_now=385000`), `charge_now` net-discharged `114492 -> 114083` uAh while `current_now` read negative (`-281681 -> -264896` uA) and `upower -d` reported `state: discharging`, `0.693 W`, `warning-level: none` (`90-dubai-battery.conf`, `omamobile-device-dubai 0.1.0-15`). Off-mode/fastboot charging QBG `capacity=2%` desync remains documented |
| Suspend (s2idle) | **BT UART wakeup packaged (`0.1.0-14`) + isolation runs pass (2026-11-24); `aosd`/`cxsd` blocked on ADSP/cx** | `75-dubai-bluetooth.rules` (`99c000.serial/power/wakeup=disabled`) verified at cold boot (`bluetoothctl scan on` passes pre/post-wake). Isolated 31 s (`sensors`/`PipeWire` stopped) and 16 s (`a600000.usb=auto`, `rmmod ath11k_ahb`) unplugged `VBUS=0uV` freezes passed on `IRQ 115`, `S2` 100%, `cdsp`/`modem`/`wpss` sleeping, standby `current_now` down to `34.5 mA` (`4.293 V`). `adsp`/`aosd`/`cxsd` stay `0` (`docs/SUSPEND.md`) |
| Modem (M9 first bring-up) | **Firmware boot and QMI transport pass; NV layer open (2026-11-11)** | MPSS remoteproc0 boots `modem.mbn` from the FairBlobs dubai-firmware pin, the glink IPCRTR channel binds `qcom_smd_qrtr`, AF_QIPCRTR sockets work, and qmicli reaches the modem on `qrtr://1`; every service client allocation then fails with QMI error 3 Internal because the rfs/NV layer (rmtfs serving the persist-derived rfs files, tqftpserv for readwrite items) is not installed yet; ModemManager 1.24 with libqrtr-glib is installed and running; SIM not yet probed |
| Modem (M9 rmtfs layer) | **Crash root-caused; write approval gate (2026-11-11)** | rmtfs 1.2, qrtr 1.2, and tqftpserv 1.2 built from AUR on the phone; rmtfs runs `-r -P -s` against modemst1/2 and tqftpserv serves `modem_pr` from its state dir; the modem then boot-loops with `dog_hal_common.c:177: DOG detects stalled initialization`, a watchdog reset from initialization stalled on the read-only EFS; read-only backups of modemst1/2 (3 MiB each) were taken to the NBD rootfs before any further step; rmtfs journal shows no served requests because the boot dies earlier |
| Modem (M9 services live) | **Telephony QMI services pass on qrtr://0; data port and SIM open (2026-11-11)** | With owner approval rmtfs runs writable `-P -s` and the modem boots without watchdog resets; `qrtr-lookup` lists the modem service table and the correct node is `qrtr://0` (the uim-selection script targets it; `qrtr://1` is a decoy endpoint); DMS returns the real IMEI and ESN from NV, UIM answers; both SIM slots report `no-atr-received`, so the physical card does not answer reset; ModemManager probes qrtr0 but refuses the modem for `Failed to find a net port`; the pmOS `msm-modem-wwan-port` DPM open-port (`bam-dmux` ep 1) fails with endpoint hangup and no `rmnet_ipa0` appears, so the data path stays open |
| Modem (M9 MM integration) | **Pass on device with physical SIM (2026-11-22)** | Read-only `debugfs` seeding of `persist:/rfs/msm/mpss` (`dhob.bin`, `shob.bin`, `datablock/*`, `cal_rfs/*`, `mot_rfs/imei_sv`) into `/var/lib/tqftpserv` plus `--dms-set-operating-mode=online` brought Slot 1 USIM to `ready`, registered on 4G LTE / 5G NR (`FASTWEB`), connected `qmapmux0.0` (`rmnet_ipa0`) with working ping and HTTPS, received SMS in `omatel-agent`, streamed GPS NMEA via ModemManager, and passed two-way voice call audio on both Earpiece and Speakerphone via `dummystreamhack`, `omamobile-ucm-dubai 0.1.0-3`, and `dubai-callaudiod` (`omamobile-device-dubai 0.1.0-11`). All six UFS LUNs remained `ro=1` |
| Cameras | **Partial: `s5kjn1.yaml` + `0005-ipa-simple` packaged (`libcamera 0.7.2-4.25`); needs owner color check; 2/4 sensors unported** | Only `s5kjn1` (rear main, color) and `gc02m1b` (2 MP monochrome depth) exist in DTS (`ov50a`/`ov32b40` lack drivers in `sources/linux-sc7280`). `libcamera 0.7.2-4.25` installed on `/dev/sde27`: `wireplumber` loads `s5kjn1.yaml` and logs `gain 1-64 (1)` (`max_chroma_diff` `33 -> 130`). Owner visual confirmation of `omacam` in lit scene and missing sensor bring-up remain open |
| Haptics (`AW86224`) | **Pass on device at `0x58` (`0008` + updated `0009`); CI rebuild of `0x58` DTB pending (2026-11-25)** | Rescue `modprobe aw86927` at `4-005a` failed `-ENXIO`; `i2cdetect`/`i2cget` on `i2c-4` proved the chip responds at `0x58` (`CHIPID=0x00`, `EFRD9=0xb4`, matching downstream `aw862xx_i2c_addr=<0x58>`). Updated `0009` to `vibrator@58` (`reg = <0x58>`) and booted on `/dev/sde27`: `aw86927-haptics` (`input4`, `4-0058`) probed with `SYSER=0x00` and owner confirmed physical vibration on `FF_RUMBLE` (`GLBRD5=0x07`, returned to standby `0x00`) |
| qemu-nbd transport | **Pass with RNDIS; fail with NCM** | RNDIS passed 30 direct-I/O reads of 512 MiB over 39 minutes with no NBD/I/O errors; NCM previously stalled while ACM survived |
| LineageOS rollback | **Pass** | Original boot_b restored and boot completed before the DTBO test |
| Bluetooth boot automation | **Pass on device (2026-11-11)** | `omamobile-dubai-bluetooth-address@hci0` ran at boot; hci0 powered with a stable local address, no manual recovery |
| NBD/RNDIS load check | **Pass on device (2026-11-11)** | 6 direct-I/O reads of 512 MiB at ~30 MB/s, about 3 GiB total, no NBD stalls, blocked requests, or I/O errors in dmesg |
| dtschema validation | **Pass offline (2026-11-12)** | dtschema 2026.9 processed schema rebuilt host-side; 14 known findings per panel, all allowlisted in `tests/dtschema-allowlist.txt`; gating logic verified against real logs |
| Sensor stack packaging | **Pass offline (2026-11-12)** | `packages/libssc` (aarch64 port of the official Arch PKGBUILD, v0.4.4) and `packages/hexagonrpcd` (0.4.0 + Alpine systemd units + sysusers + dubai `-R` drop-in) pass static checks; the systemd-services patch applies cleanly to the 0.4.0 tarball; the FairBlobs hexagonfs tree checksum matches the pmOS pin |
| CI kernel job | **Pass (2026-11-12, run 43244056166)** | First fully green `offline-build`: static 5m59s; `build-all.sh` applies all seven patches on the disposable worktree, builds the LLVM kernel `7.2.9-dubai+` and both DTBs, dtschema 2026.9 gate passes (28 known errors, all allowlisted), initramfs and offline artifact verification pass, artifacts uploaded. Two fixes were needed along the way: `python3-dev` in the builder image for the in-container venv, and validating the DTBs against the patched worktree rather than the pristine tree |

## Hardware and blockers

- The Android DTBO must be replaced by the empty pmaports DTBO to boot mainline; vbmeta was not modified.
- Slot `_b` holds the test initramfs and the backup is verified. Forced reboots consume slot retries because the rescue never marks the slot successful; when both slots read `unbootable` and no slot is active, ABL shows a boot-failed screen and `fastboot boot` is rejected. The documented recovery is `fastboot set_active b` (selection only, no flash, owner-authorized on 2026-11-08 and 2026-11-11).
- The host firewall must allow the rescue subnet or NBD never starts: with a default-DROP input policy the phone's `nbd-client` SYN to `172.16.42.2:10809` is dropped, ICMP still passes, and the initramfs expires into the diagnostic shell with no visible attempt. `sudo ufw allow from 172.16.42.0/24 comment dubai-rescue`, documented in `docs/RECOVERY-RUNBOOK.md`.
- `scripts/host-usb-watch.sh` performs the whole host bring-up on enumeration: it binds `dubai-rescue-usb` to the interface whose USB serial is `dubai-rescue` and starts the persistent `qemu-nbd` server on `work/rootfs-dubai-live.qcow2` once `172.16.42.2` exists, so the 90-second client window is met from a clean host state.
- Shell access without the owner's private key was solved offline: stop the server, `qemu-img convert` the overlay to `work/rootfs-dubai-s32-q6-flat.img`, `e2fsck -fy`, inject the second key into `/home/antona89/.ssh/authorized_keys` with `debugfs` (mode 0600, uid/gid 1000), then serve a fresh `work/rootfs-dubai-live.qcow2`. The owner key is preserved.
- The Arch rootfs has no getty on `ttyGS0`; the ACM console answers only in the rescue initramfs, so serial access to the running system is unavailable. The rescue console may also stop consuming host input with a full ACM write buffer; do not rely on it for recovery.
- A rescue dropbear rejected a valid two-key `authorized_keys` on 2026-11-11 while the same key material worked in the rootfs sshd; the single-key rescue configuration of 2026-11-07/08 was never re-tested with two keys. If rescue SSH matters for a session, prefer a single-key initramfs or debug over ACM first.
- Remote reboot into the bootloader is unreliable on this device: `reboot -f bootloader` and `systemctl reboot bootloader` both fell through to a normal `_b` boot on 2026-11-11. Use `systemctl poweroff` and the physical Power+Volume Down combo to reach fastboot; each forced normal boot consumes a slot retry.
- Modem, suspend, sensors, and camera image quality/calibration are not qualified. The battery discharge current sign is untested because the USB link that serves the NBD rootfs is also the charging source; it follows the same downstream smb5 negation convention as the verified charging direction.
- Proprietary firmware is not published; the NBD artifacts and captures are local only.

## Risks

Shared `userdata`, AVB, an unbootable slot A, and incomplete hardware qualification. The NBD strategy avoids Android storage writes beyond the already authorized boot_b/dtbo_b test, both covered by backups; a future NBD failure can still interrupt the running Linux rootfs. Hard resets silently consume slot retries until ABL reports both slots unbootable; keep `set_active b` in the runbook and prefer `reboot -f bootloader` from the shell over long-press resets.

## Next step

On 2026-11-25, slot `_b` was reactivated (`set_active b`), `/dev/sde27` modules were synced to CI run `45469345310` (`7b48084`), `qcom-battmgr` negative discharge current without patch `0006` was verified live, `0009` was fixed from `0x5a` to `0x58` (`vibrator@58`), and `AW86224` physical vibration (`FF_RUMBLE`) was confirmed by the owner on `/dev/sde27`. Pending owner-gated actions and checks: (1) push `0009` (`vibrator@58`) + doc updates to GitHub to run `offline-build` CI for the clean `0x58` DTB artifacts; (2) download the new CI artifact, flash `boot_b` with the rebuilt CSOT `userdata` boot image (already owner-authorized for standalone `boot_b`), and run `dubai-qbootctl-mark-successful`; (3) owner live color check of `omacam` on a lit scene, plus decide whether `ov50a`/`ov32b40` camera bring-up and `81-libssc-motorola-dubai.rules` Z-axis check are needed before unmasking `sleep.target` / `omamobile-sleepd`; (4) clean rootfs rebuild validation in an environment with Docker socket access.
