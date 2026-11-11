<!-- SPDX-License-Identifier: MIT -->
# Technical state of the port

Updated: 2026-11-11.

## Current state

- **Phase:** Alpha 0, Alpha 1, and Alpha 2 reached on the owner's CSOT device. The 2026-11-11 session re-verified the full chain end to end: temporary `fastboot boot` of the telemetry image, automatic RNDIS/NBD bring-up, SSH, Hyprland UI, Wi-Fi, PipeWire speaker, battery telemetry, and the Bluetooth boot automation. Beta power, modem, and stability gates remain open.
- **Port commit:** branch `main` published at `https://github.com/Lwb89dev/dubai-omarchy-porting`; read the local revision with `git rev-parse HEAD`.
- **Omarchy Mobile:** `cd90d193ac5b4056f877a96f6ec748d0998021c4`.
- **Kernel:** 7.2.9, tag `v7.2.9-sc7280`, commit `0ccea71930dbc8e32344a41be96944db4215c3c3`.
- **Arch Linux ARM:** rootfs `2026.11.08` lineage, now served as `work/rootfs-dubai-live.qcow2` over the flattened `work/rootfs-dubai-s32-q6-flat.img`; SHA-256, smoke test, RNDIS/NBD firstboot, pacman, and SSH passed.
- **Configurations:** separate GCC and LLVM fragments on top of pmaports 7.2.9-r3. All five speaker/camera/battery patches are on the running kernel; the `kimi-dubai` SSH key is authorized beside the owner's key in the served image.

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
| Battery/charging | **Telemetry pass; state partial** | Charge/full/energy and V×I rate are now real and POWER_NOW is hidden; UPower still reports discharging while the kernel reports charging |
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
- The Arch rootfs has no getty on `ttyGS0`; the ACM console answers only in the rescue initramfs, so serial access to the running system is unavailable.
- UPower energy telemetry is real, but its charging-state override still reports discharging while sysfs reports Charging; the open fix is the current-sign convention.
- Modem, suspend, sensors, and camera image quality/calibration are not qualified.
- Proprietary firmware is not published; the NBD artifacts and captures are local only.

## Risks

Shared `userdata`, AVB, an unbootable slot A, and incomplete hardware qualification. The NBD strategy avoids Android storage writes beyond the already authorized boot_b/dtbo_b test, both covered by backups; a future NBD failure can still interrupt the running Linux rootfs. Hard resets silently consume slot retries until ABL reports both slots unbootable; keep `set_active b` in the runbook and prefer `reboot -f bootloader` from the shell over long-press resets.

## Next step

Resolve UPower's charging-state override (negative-current convention while `qcom_battmgr` reports Charging). Camera calibration, suspend, modem and persistent installation remain later gates.
