<!-- SPDX-License-Identifier: MIT -->
# Motorola Edge 30 (dubai): bring-up notes

## Identity captured on 2026-11-07

- ADB and fastboot captures were read-only only: `dubai`, Motorola Edge 30, SKU `XT2203-1`, 8 GB RAM, and 128 GB UFS.
- The Android cmdline and fastboot `primary-display` agree on **CSOT NT37701** `1080x2400_655_dsc_cmd_v1`. Do not use the Tianma DTB.
- Current slot `_b`; bootloader unlocked (`flashing_unlocked`), ABL fastboot (`is-userspace: no`). Authorized Android↔fastboot reboots were performed, with no slot change or flash.
- Both slots have retry 6 and `slot-successful=yes`, but `_a` also has `slot-unbootable=yes`: do not treat it as a working fallback.
- Installed system: LineageOS 23.2 nightly, build date 2026-05-29. The matching package is no longer listed by the official portal and its direct URL returns 404: a matching recovery is not yet available.
- The private capture is outside the repository. Android does not allow `dmesg` or `pstore` for the ADB user; `/proc/last_kmsg` does not exist.
- Sizes read via fastboot: `boot_a/b` and `vendor_boot_a/b` 96 MiB, `dtbo_a/b` 24 MiB, `vbmeta_a/b` 64 KiB, `super` 0x214000000, `userdata` 0x1b166fb000.
- **First GCC boot:** `fastboot boot` was accepted, but the device returned to fastboot after about 3 s with no shell/gadget; flags and retries were unchanged. No second attempt with the same image.

## Current choices

- Kernel: `sc7280-mainline/linux`, tag `v7.2.9-sc7280`, commit `0ccea71930dbc8e32344a41be96944db4215c3c3`.
- Base configuration: the one published with `linux-postmarketos-qcom-sc7280` 7.2.9-r3.
- First initramfs: entirely in RAM, storage forced read-only, no mount or `switch_root`.
- Proprietary firmware: not included in the artifacts and not versioned.

## Evidence from sources, not hardware tests

The common DTS enables several subsystems. An `okay` node shows only the intent of the port, not that the phone works. The CSOT/Tianma variants share the common DTS but set different compatibles and initialization sequences in the NT37701 driver.

The pmaports package creates a 24 MiB `dtbo.img` that is entirely zero. That is a fact about the existing port, not permission to write `dtbo`: no empty DTBO image is produced or proposed for the first RAM-only test.
