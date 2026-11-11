<!-- SPDX-License-Identifier: MIT -->
# Technical state of the port

Updated: 2026-11-11 (second session).

## Current state

- **Phase:** Alpha 0, Alpha 1, and Alpha 2 reached on the owner's CSOT device. The 2026-11-11 sessions re-verified the full chain end to end and closed the UPower charging-state gate with kernel patch 0006: the phone now reports `state: charging` with a real time-to-full while charging. Beta power (suspend), modem, and stability gates remain open.
- **Port commit:** branch `main` published at `https://github.com/Lwb89dev/dubai-omarchy-porting`; read the local revision with `git rev-parse HEAD`.
- **Omarchy Mobile:** `cd90d193ac5b4056f877a96f6ec748d0998021c4`.
- **Kernel:** 7.2.9, tag `v7.2.9-sc7280`, commit `0ccea71930dbc8e32344a41be96944db4215c3c3`, plus six out-of-tree patches (S32 speaker pair, S5KJN1 selection, battmgr charge units, SM7325 POWER_NOW hiding, SM7325 current sign).
- **Arch Linux ARM:** rootfs `2026.11.08` lineage, served as `work/rootfs-dubai-live.qcow2` over the flattened and fsck-repaired `work/rootfs-dubai-live-flat2.img`; SHA-256, smoke test, RNDIS/NBD firstboot, pacman, and SSH passed.

## Builds and tests

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
| Suspend (s2idle) | **Entry/resume pass; sustained sleep blocked on device (2026-11-11)** | Five `freeze` suspends entered and exited cleanly with continuous uptime and a live NBD link; every sleep lasted about 0.7 s before an unregistered IRQ woke the system, `dwc3-qcom: port-1 HS-PHY not in L2` is the prime suspect while the gadget link to an active host exists; pwrkey wakeup_count stayed 0 and the RTC alarm never got to fire as a wake source; standby consumption not measurable in the NBD configuration |
| Cameras | **Selection, streaming and gain helpers pass; quality partial** | S5KJN1 reports 8160×6144 correctly; libcamera 0.7.2-4.24 recognizes both gain models; captures and audio pass; calibration open |
| qemu-nbd transport | **Pass with RNDIS; fail with NCM** | RNDIS passed 30 direct-I/O reads of 512 MiB over 39 minutes with no NBD/I/O errors; NCM previously stalled while ACM survived |
| LineageOS rollback | **Pass** | Original boot_b restored and boot completed before the DTBO test |
| Bluetooth boot automation | **Pass on device (2026-11-11)** | `omamobile-dubai-bluetooth-address@hci0` ran at boot; hci0 powered with a stable local address, no manual recovery |
| NBD/RNDIS load check | **Pass on device (2026-11-11)** | 6 direct-I/O reads of 512 MiB at ~30 MB/s, about 3 GiB total, no NBD stalls, blocked requests, or I/O errors in dmesg |

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

Root-cause the ~0.7-second s2idle wake (prime suspect: the dwc3 gadget link that cannot reach L2 while serving NBD to an active host; verify by suspending with the USB role switched or the link idle) before any standby-consumption claim. Then modem bring-up (M9: QRTR/QMI inventory and ModemManager). Rebuild the reference LLVM kernel with patch 0006 in CI when a runner is available. Camera calibration, sensors, and persistent installation remain later gates.
