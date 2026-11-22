<!-- SPDX-License-Identifier: MIT -->
# Technical state of the port

Updated: 2026-11-22.

## Current state

- **Phase:** Alpha 0, Alpha 1, and Alpha 2 reached on the owner's CSOT device. The 2026-11-22 session resolved the M8 PMIC-wake mystery in RAM-only rescue: four real `s2idle` freezes (6 s, 11 s with `usb0` down, 11 s with UDC unbound, 61 s) all woke cleanly on `pm8xxx_rtc_alarm` (`IRQ 115` via `spmi_pmic_arb` → PDC `hwirq 1` → GICv3), proving PMIC wakeup works. The 2026-11-12 failure was caused by two combined bugs: PMK8350's raw hardware RTC (`rtc0/since_epoch`, 1970) vs NTP `date +%s` (2026, arming the alarm 56 years ahead), plus NBD userspace deadlock when `usb0` was taken down (both fixed in `scripts/device-suspend-tests.sh`; see `docs/SUSPEND.md`). Subsequently booted the 2026-11-13 NBD recovery rootfs cleanly: battery/charging (`89%`, `Charging`, `4.255 V`, `+331 mA`, UPower `2.03 W`), temporary UPower `PowerOff` and masked sleep targets, Bluetooth boot power-on, Wi-Fi, Hyprland, ModemManager, and the sensor stack (accelerometer, light, live compass heading, and active autorotation service) all came up automatically on cold boot. Modem remains SIM-gated; `pmic_pwrkey` in-window wake and unplugged `aosd`/`cxsd` stay open for M8.
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
| Battery/charging | **Pass on device (2026-11-11)** | Patch 0006 negates the SM7325 battery current; sysfs reports +587 mA while charging and UPower reports `charging` with a real time-to-full and 1.3 W rate; discharge sign not testable while the rootfs is served over the same USB link |
| Suspend (s2idle) | **PMIC RTC wake pass in RAM rescue (2026-11-22); pwrkey & unplugged CXSD/AOSD open** | Four RAM-only freezes (6 s, 11 s `usb0` down, 11 s UDC unbound, 61 s) all woke cleanly on `pm8xxx_rtc_alarm` (`pm_wakeup_irq=115`, `suspend_stats/success=4, fail=0`). Root-caused 2026-11-12 failure to `rtc0/since_epoch` (1970) vs NTP `date +%s` (2026) mismatch and NBD deadlock on `usb0` down. `qcom_stats/{aosd,cxsd}` stayed 0 while USB was plugged in; in-window `pmic_pwrkey` wake and unplugged standby drain remain to verify |
| Modem (M9 first bring-up) | **Firmware boot and QMI transport pass; NV layer open (2026-11-11)** | MPSS remoteproc0 boots `modem.mbn` from the FairBlobs dubai-firmware pin, the glink IPCRTR channel binds `qcom_smd_qrtr`, AF_QIPCRTR sockets work, and qmicli reaches the modem on `qrtr://1`; every service client allocation then fails with QMI error 3 Internal because the rfs/NV layer (rmtfs serving the persist-derived rfs files, tqftpserv for readwrite items) is not installed yet; ModemManager 1.24 with libqrtr-glib is installed and running; SIM not yet probed |
| Modem (M9 rmtfs layer) | **Crash root-caused; write approval gate (2026-11-11)** | rmtfs 1.2, qrtr 1.2, and tqftpserv 1.2 built from AUR on the phone; rmtfs runs `-r -P -s` against modemst1/2 and tqftpserv serves `modem_pr` from its state dir; the modem then boot-loops with `dog_hal_common.c:177: DOG detects stalled initialization`, a watchdog reset from initialization stalled on the read-only EFS; read-only backups of modemst1/2 (3 MiB each) were taken to the NBD rootfs before any further step; rmtfs journal shows no served requests because the boot dies earlier |
| Modem (M9 services live) | **Telephony QMI services pass on qrtr://0; data port and SIM open (2026-11-11)** | With owner approval rmtfs runs writable `-P -s` and the modem boots without watchdog resets; `qrtr-lookup` lists the modem service table and the correct node is `qrtr://0` (the uim-selection script targets it; `qrtr://1` is a decoy endpoint); DMS returns the real IMEI and ESN from NV, UIM answers; both SIM slots report `no-atr-received`, so the physical card does not answer reset; ModemManager probes qrtr0 but refuses the modem for `Failed to find a net port`; the pmOS `msm-modem-wwan-port` DPM open-port (`bam-dmux` ep 1) fails with endpoint hangup and no `rmnet_ipa0` appears, so the data path stays open |
| Modem (M9 MM integration) | **ModemManager creates the qcom-soc modem; blocked only by the missing SIM (2026-11-11)** | Rebinding `1e40000.ipa` after installing `yupik_ipa_fws.mbn` fixed the boot-time ENOENT and created `rmnet_ipa0`; ModemManager then created the modem with two ports (qrtr0 + rmnet_ipa0) and reached the unlock check, failing with `GW primary session index unknown` — the expected no-SIM state since no UIM provisioning session can be selected without a card |
| Cameras | **Selection, streaming and gain helpers pass; quality partial** | S5KJN1 reports 8160×6144 correctly; libcamera 0.7.2-4.24 recognizes both gain models; captures and audio pass; calibration open |
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

M8: PMIC RTC wakeup from `s2idle` is now proven on hardware (4/4 in RAM rescue, `docs/SUSPEND.md`). Next M8 checks are an in-window `pmic_pwrkey` wake test and an unplugged RAM-only `s2idle` test to see if `qcom_stats/{aosd,cxsd}` enter deep SoC sleep without USB VBUS and measure battery standby drain. M9 resumes with a responsive physical SIM (`docs/TELEPHONY.md`). For sensors (`docs/SENSORS.md`), cold boot on the 2026-11-13 recovery image brought up accel, light, compass, and autorotation automatically; visual lock-screen behavior, calibration, and security review of the experimental daemon remain open. Camera calibration, a clean rootfs rebuild verifying the new `install-local-keyring.sh` hook, and persistent storage planning remain later gates.
