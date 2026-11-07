<!-- SPDX-License-Identifier: MIT -->
# Technical state of the port

Updated: 2026-11-07.

## Current state

- **Phase:** M0/M1 documented; M2/M3 complete; **M4 reached** with Arch/systemd/SSH/pacman over NBD; accelerated graphics, Hyprland, and touch for M5 verified in the snapshot. A clean boot and a complete firstboot remain to be verified.
- **Port commit:** branch `main` published at `https://github.com/Lwb89dev/dubai-omarchy-porting`; read the local revision with `git rev-parse HEAD`.
- **Omarchy Mobile:** `cd90d193ac5b4056f877a96f6ec748d0998021c4`.
- **Kernel:** 7.2.9, tag `v7.2.9-sc7280`, commit `0ccea71930dbc8e32344a41be96944db4215c3c3`.
- **Arch Linux ARM:** rootfs `2026.11.07` with LLVM modules; SHA-256 and smoke test passed.
- **Configurations:** separate GCC and LLVM fragments on top of pmaports 7.2.9-r3; no patches to the kernel sources.

## Builds and tests

| Activity | Result | Evidence |
|---|---|---|
| Source fetch | Pass | Checkouts and archives in `sources.lock` |
| ShellCheck/syntax | Pass | `tests/static.sh` |
| GCC and LLVM kernel builds | **Pass offline** | Image/Image.gz, both DTBs, 636 LLVM module entries, and SHA-256 |
| Initramfs build | **Pass** | RAM-only, reproducible; variants with modules, SSH, dubai firmware, and NBD |
| Arch/Omarchy GCC rootfs | **Pass offline** | Checksums and smoke test passed |
| Arch/Omarchy LLVM rootfs | **Pass offline** | Checksum, smoke test, and e2fsck of the NBD copy passed |
| Boot-chain backup | **Pass** | Eight original images, two matching SHA-256 reads |
| Mainline boot without an empty DTBO | **Fail** | GCC/LLVM/Nura return to fastboot; no shell |
| Mainline boot with an empty DTBO | **Pass M3** | Kernel 7.2.9-dubai+, CSOT model, ACM/NCM/SSH active |
| Arch NBD | **Pass M4** | systemd PID 1, ext4 on NBD, SSH and pacman working |
| Display/touch | **Pass in the snapshot** | Hyprland 1080×2400@144, DPMS wake, and Goodix multitouch verified |
| Storage guard | **Pass** | Every `sda`–`sdf` LUN read-only; no Android mount |
| Accelerated GPU | **Pass in the snapshot** | EGL Freedreno Adreno, OpenGL ES 3.2; a dubai-specific zap is required |
| LineageOS rollback | **Pass** | Original boot_b restored and boot completed before the DTBO test |

## Hardware and blockers

- The Android DTBO must be replaced by the empty pmaports DTBO to boot mainline; vbmeta was not modified.
- Slot `_a` is marked unbootable; `_b` currently holds the test initramfs and the backup is verified.
- A clean boot must still verify dropbear/ACM cleanup, UFW modules, and firstboot without manual intervention.
- Wi-Fi, audio, modem, battery/charging, suspend, and sensors are not qualified.
- Proprietary firmware is not published; the NBD artifacts are local only.

## Risks

Shared `userdata`, AVB, an unbootable slot A, and many drivers not yet tested. The NBD strategy avoids any write to internal storage beyond boot_b/dtbo_b, which are already covered by backups.

## Next step

Finish the rootfs with the new modules, provision only the private dubai zap, and repeat a clean NBD boot. Verify firstboot, UFW, SSH, Hyprland, GPU, and touch without manual intervention and without using `userdata`.
