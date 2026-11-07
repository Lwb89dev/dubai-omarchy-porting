<!-- SPDX-License-Identifier: MIT -->
# Omarchy Mobile on the Motorola Edge 30 (dubai)

Native AArch64 port based on mainline Linux, the existing Motorola Linux port, Arch Linux ARM, and the Omarchy Mobile shell. It does not use Android as a runtime, and it does not use proot, chroot, or Termux.

**Current state: audit and offline builds. No boot or hardware test has been performed.** No image present here is approved for flashing. The CSOT/Tianma panel and bootloader support for `fastboot boot` must be verified on the device.

## Goals and limits

- Kernel `7.2.9-sc7280` pinned in `sources.lock`; device trees specific to CSOT and Tianma.
- First initramfs entirely in RAM: shell, logs, USB NCM/ACM, and Dropbear; every SCSI/UFS disk is read-only.
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
