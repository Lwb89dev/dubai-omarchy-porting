<!-- SPDX-License-Identifier: MIT -->
# Technical state of the port

Updated: 2026-11-07.

## Current state

- **Phase:** Alpha 0 and Alpha 1 reached; M5 graphics/touch and M6 Wi-Fi verified on CSOT hardware. The Alpha 2 software audio path now passes through PipeWire; speaker audibility and a clean boot from the rebuilt rootfs remain to be confirmed.
- **Port commit:** branch `main` published at `https://github.com/Lwb89dev/dubai-omarchy-porting`; read the local revision with `git rev-parse HEAD`.
- **Omarchy Mobile:** `cd90d193ac5b4056f877a96f6ec748d0998021c4`.
- **Kernel:** 7.2.9, tag `v7.2.9-sc7280`, commit `0ccea71930dbc8e32344a41be96944db4215c3c3`.
- **Arch Linux ARM:** rootfs `2026.11.07` with LLVM modules; SHA-256, smoke test, clean firstboot, pacman, and SSH passed.
- **Configurations:** separate GCC and LLVM fragments on top of pmaports 7.2.9-r3. The S32 speaker test uses `kernel/patches/0001-sm8250-dubai-s32-speaker.patch` in an isolated worktree; it is not yet hardware-verified.

## Builds and tests

| Activity | Result | Evidence |
|---|---|---|
| Source fetch | Pass | Checkouts and archives in `sources.lock` |
| ShellCheck/syntax | Pass | `tests/static.sh` |
| GCC and LLVM kernel builds | **Pass offline** | Image/Image.gz, both DTBs, 636 LLVM module entries, and SHA-256 |
| Initramfs build | **Pass** | RAM-only, reproducible; variants with modules, SSH, dubai firmware, and NBD |
| Arch/Omarchy GCC rootfs | **Pass offline** | Checksums and smoke test passed |
| Arch/Omarchy LLVM rootfs | **Pass offline** | Checksum, smoke test, and e2fsck of the NBD copy passed |
| Device/UCM packages | **Pass on device** | `omamobile-device-dubai` 0.1.0-3 and `omamobile-ucm-dubai` 0.1.0-2 installed and exercised |
| Boot-chain backup | **Pass** | Eight original images, two matching SHA-256 reads |
| Mainline boot without an empty DTBO | **Fail** | GCC/LLVM/Nura return to fastboot; no shell |
| Mainline boot with an empty DTBO | **Pass M3** | Kernel 7.2.9-dubai+, CSOT model, ACM/NCM/SSH active |
| Arch NBD | **Pass in the current boot** | Clean firstboot, systemd, SSH and pacman; threaded/no-cache server had no stuck requests during setup and audio tests |
| Display/touch | **Pass on device** | Hyprland 1080×2400 up to 144 Hz, DPMS wake, and Goodix multitouch verified |
| Storage guard | **Pass** | Every `sda`–`sdf` LUN read-only; no Android mount |
| Accelerated GPU | **Pass on device** | EGL Freedreno Adreno, OpenGL ES 3.2; a dubai-specific zap is required |
| Wi-Fi | **Pass on device** | WPSS/ath11k, WPA2, DHCP, DNS, Internet ping, and HTTPS; calibration fallback warning remains |
| Bluetooth | **Detected only** | hci0 firmware loads; pairing and A2DP not tested |
| Audio | **Pass software path** | UCM HiFi, direct ALSA, PipeWire playback and microphone capture pass; video enumeration must be disabled for now; audible quality not confirmed |
| Battery/charging | **Partial** | Real capacity/status/voltage/current/temperature and USB charging; UPower energy/rate incorrect |
| Cameras | **Partial, WirePlumber disabled** | Two sensors detected and CMA permissions fixed; their WirePlumber enumeration blocks audio linking; debayer, metadata, and calibration open |
| qemu-nbd threaded/no-cache | **Partial** | Full firstboot and audio work initially passed, but a later stuck write recurred; extended stability remains open |
| LineageOS rollback | **Pass** | Original boot_b restored and boot completed before the DTBO test |

## Hardware and blockers

- The Android DTBO must be replaced by the empty pmaports DTBO to boot mainline; vbmeta was not modified.
- Slot `_a` is marked unbootable; `_b` holds the test initramfs and the backup is verified.
- Clean boot, firstboot, Dropbear/ACM cleanup, UFW, Hyprland, GPU, and touch pass without the earlier manual repairs.
- The current raw NBD artifact predates the source package list: it lacked the UCM package and device package updates. Rebuild it before the next clean-boot test; the running snapshot has been fixed manually through the signed local packages.
- WirePlumber video enumeration queues but never completes the audio stream's node event. `omamobile-device-dubai` 0.1.0-3 disables `hardware.video-capture`; this does not disable kernel camera drivers or direct libcamera access.
- Modem, suspend, sensors, Bluetooth pairing/A2DP, and camera capture are not qualified.
- Proprietary firmware is not published; the NBD artifacts and captures are local only.

## Risks

Shared `userdata`, AVB, an unbootable slot A, and incomplete hardware qualification. The NBD strategy avoids Android storage writes beyond the already authorized boot_b/dtbo_b test, both covered by backups; a future NBD failure can still interrupt the running Linux rootfs.

## Next step

Rebuild the rootfs from the current package lists, provision all private firmware, and repeat a clean NBD boot without manual package installation. Confirm that the test tone is audible, then investigate the WirePlumber camera event stall before re-enabling video enumeration. Bluetooth and modem tests remain separate gates.
