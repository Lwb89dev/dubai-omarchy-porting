<!-- SPDX-License-Identifier: MIT -->
# Technical state of the port

Updated: 2026-11-08.

## Current state

- **Phase:** Alpha 0, Alpha 1, and Alpha 2 reached on the owner's CSOT device through the temporary RNDIS/NBD setup. Current packages completed clean firstboot; Hyprland, GPU, touch, Wi-Fi, PipeWire, microphone, and audible speaker playback have been exercised. Beta power, modem, and stability gates remain open.
- **Port commit:** branch `main` published at `https://github.com/Lwb89dev/dubai-omarchy-porting`; read the local revision with `git rev-parse HEAD`.
- **Omarchy Mobile:** `cd90d193ac5b4056f877a96f6ec748d0998021c4`.
- **Kernel:** 7.2.9, tag `v7.2.9-sc7280`, commit `0ccea71930dbc8e32344a41be96944db4215c3c3`.
- **Arch Linux ARM:** rootfs `2026.11.08` with stable LLVM modules; SHA-256, smoke test, clean RNDIS/NBD firstboot, pacman, and SSH passed.
- **Configurations:** separate GCC and LLVM fragments on top of pmaports 7.2.9-r3. All five speaker/camera/battery patches are on the running kernel; S32 audio, S5KJN1 selection and battery charge telemetry have passed on hardware. RNDIS is the working NBD transport.

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

## Hardware and blockers

- The Android DTBO must be replaced by the empty pmaports DTBO to boot mainline; vbmeta was not modified.
- Slot `_a` is marked unbootable; `_b` holds the test initramfs and the backup is verified.
- Clean boot, firstboot, Dropbear/ACM cleanup, UFW, Hyprland, GPU, and touch pass without the earlier manual repairs.
- ACM/kmsg disproved the initial S32-crash hypothesis: NCM repeatedly stalled NBD requests while the kernel and ACM stayed alive. RNDIS completed the same rootfs boot and audio tests without stalls. The final S32 mask and Q6 mapping patches produced a clearly audible 10-second tone at 50%.
- The V4L2 monitor receives `ENOMEM` opening `/dev/video0` and leaves the shared WirePlumber event queue stuck before the libcamera hooks. `omamobile-device-dubai` 0.1.0-5 disables only `monitor.v4l2`; libcamera creates both video sources and PipeWire audio still passes.
- GStreamer/PipeWire camera capture passes on both sensors with normal autolinking and native RGBA caps. The earlier no-link capture used `autoconnect=false`, which intentionally excludes the stream from WirePlumber linking.
- Bluetooth starts without a public address. The device package derives a stable local address from `machine-id`; pairing/A2DP pass. The first udev attempt ran before firmware setup completed and left the controller unconfigured; manual address setup plus power-on recovered it. The revised retrying helper needs a future boot test.
- Modem, suspend, sensors, and camera image quality/calibration are not qualified.
- Proprietary firmware is not published; the NBD artifacts and captures are local only.

## Risks

Shared `userdata`, AVB, an unbootable slot A, and incomplete hardware qualification. The NBD strategy avoids Android storage writes beyond the already authorized boot_b/dtbo_b test, both covered by backups; a future NBD failure can still interrupt the running Linux rootfs.

## Next step

Verify the revised Bluetooth helper on a future authorized boot and resolve UPower's charging-state override. Camera calibration, suspend, modem and persistent installation remain later gates.
