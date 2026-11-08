<!-- SPDX-License-Identifier: MIT -->
# Omarchy Mobile on the Motorola Edge 30 (dubai)

Native AArch64 port based on mainline Linux, the existing Motorola Linux port, Arch Linux ARM, and the Omarchy Mobile shell. It does not use Android as a runtime, and it does not use proot, chroot, or Termux.

**Current state: Alpha 0, Alpha 1, and Alpha 2 reached on the owner's CSOT device through the temporary RNDIS/NBD setup.** Mainline Linux, Arch Linux ARM, systemd, pacman, SSH, accelerated Hyprland/Omarchy Mobile, touch, Wi-Fi, Bluetooth/A2DP, camera streaming, battery telemetry, PipeWire capture, and audible speaker playback have run on hardware. Camera calibration, modem, power management, and long-term stability remain open; no daily-driver or general flashing compatibility is claimed.

## Goals and limits

- Kernel `7.2.9-sc7280` pinned in `sources.lock`; device trees specific to CSOT and Tianma.
- First initramfs entirely in RAM: shell, logs, selectable USB NCM/RNDIS plus ACM, and Dropbear; every SCSI/UFS disk is read-only. RNDIS is used for NBD qualification because NCM stalls under rootfs traffic.
- Arch Linux ARM rootfs built with the Omarchy Mobile container/QEMU infrastructure.
- The shell and hardware-independent packages are reused; no Pixel/Tensor drivers or modem stack.

## Offline build

Install the host prerequisites from [the build guide](docs/BUILD.md), then run the complete build with one command:

```sh
scripts/build-all.sh
```

This runs static checks, fetches the pinned sources, applies every port patch in a dedicated worktree, builds the LLVM kernel and RNDIS initramfs, validates both DTBs, builds the Arch/Omarchy rootfs, and verifies the artifacts. It never accesses the phone. Use `BUILD_ROOTFS=0 scripts/build-all.sh` for only the kernel and initramfs.

For the current NBD/CSOT variant, provide the private firmware and public SSH key explicitly:

```sh
PANEL=csot FIRMWARE_DIR=/usr/lib/firmware \
  DUBAI_ZAP_FIRMWARE=/private/path/a660_zap.mbn \
  SSH_PUBLIC_KEY="$HOME/.ssh/id_ed25519.pub" \
  NBD_SERVER=172.16.42.2 scripts/build-all.sh
```

Artifacts and logs are in `out/`; the rootfs is published by the builder under `work/omarchy-dubai/out/dubai/`. Sources, downloads, firmware and other files in `sources/` and `work/` are ignored by Git. A compiled image remains untested and does not authorize any boot or flash. Run `scripts/build-all.sh --help` for all options.

Documentation: [audit](docs/AUDIT.md), [hardware matrix](docs/HARDWARE-MATRIX.md), [boot chain](docs/BOOT-CHAIN.md), [storage](docs/STORAGE-PLAN.md), [recovery](docs/RECOVERY-RUNBOOK.md), [build](docs/BUILD.md), and [roadmap](docs/ROADMAP.md).

`PROCESS.md` records the current technical state. `PROGRESS.md` is the chronological activity log.

## Safety

Do not run upstream `tools/install-phone` on this device. Do not format `userdata`: it is shared, and losing it is not undone by the A/B dual slot. Do not modify `super`, `persist`, modem/NV, calibrations, or `vbmeta`. Every temporary boot or write requires a specific runbook and explicit approval.
