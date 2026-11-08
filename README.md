<!-- SPDX-License-Identifier: MIT -->
# Omarchy Mobile on the Motorola Edge 30 (dubai)

Native AArch64 port based on mainline Linux, the existing Motorola Linux port, Arch Linux ARM, and the Omarchy Mobile shell. It does not use Android as a runtime, and it does not use proot, chroot, or Termux.

**Current state: Alpha 0, Alpha 1, and Alpha 2 reached on the owner's CSOT device through the temporary RNDIS/NBD setup.** Mainline Linux, Arch Linux ARM, systemd, pacman, SSH, accelerated Hyprland/Omarchy Mobile, touch, Wi-Fi, battery telemetry, PipeWire capture, and audible speaker playback have run on hardware. Camera integration, modem, power management, and long-term stability remain open; no daily-driver or general flashing compatibility is claimed.

## Goals and limits

- Kernel `7.2.9-sc7280` pinned in `sources.lock`; device trees specific to CSOT and Tianma.
- First initramfs entirely in RAM: shell, logs, selectable USB NCM/RNDIS plus ACM, and Dropbear; every SCSI/UFS disk is read-only. RNDIS is used for NBD qualification because NCM stalls under rootfs traffic.
- Arch Linux ARM rootfs built with the Omarchy Mobile container/QEMU infrastructure.
- The shell and hardware-independent packages are reused; no Pixel/Tensor drivers or modem stack.

## Offline build

```sh
scripts/fetch-sources.sh
scripts/build-kernel.sh
scripts/build-initramfs.sh
scripts/verify-images.sh
tests/static.sh
```

Artifacts and logs are in `out/`. Sources and downloads in `sources/` and `work/` are ignored by Git. `scripts/build-images.sh` requires an explicit panel variant, but a compiled image remains untested and does not authorize any flash.

Documentation: [audit](docs/AUDIT.md), [hardware matrix](docs/HARDWARE-MATRIX.md), [boot chain](docs/BOOT-CHAIN.md), [storage](docs/STORAGE-PLAN.md), [recovery](docs/RECOVERY-RUNBOOK.md), [build](docs/BUILD.md), and [roadmap](docs/ROADMAP.md).

`PROCESS.md` records the current technical state. `PROGRESS.md` is the chronological activity log.

## Safety

Do not run upstream `tools/install-phone` on this device. Do not format `userdata`: it is shared, and losing it is not undone by the A/B dual slot. Do not modify `super`, `persist`, modem/NV, calibrations, or `vbmeta`. Every temporary boot or write requires a specific runbook and explicit approval.
