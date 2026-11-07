<!-- SPDX-License-Identifier: MIT -->
# Storage and rootfs plan

## Fundamental rule

`userdata` is shared between A and B. Writing or reformatting it deletes data and configuration used by LineageOS on either slot. The presence of a second Android system does not preserve that content.

The first initramfs sets every disk and every `/dev/sd*` partition read-only, repeatedly, with no allowlist. It does not mount Android filesystems, does not create device-mapper devices, does not open `super`, does not resize filesystems, and does not run `switch_root`.

## Options

| Option | Preserves LineageOS | Data risk | Performance/complexity | Recovery and updates | State |
|---|---|---|---|---|---|
| A. Rootfs in RAM/initramfs | Yes | No write expected | Limited RAM, non-persistent system | Reboot is enough; an update is a new image | **Chosen for M3**; boot not tested |
| B. Rootfs on external USB | Potentially yes | Low for UFS, but selection mistakes remain possible | USB 2.0 in the current DTS; power and OTG role still to verify | External device is replaceable; persistent updates on the media | Future; host mode and USB boot not demonstrated |
| C. Rootfs in a dedicated internal partition/image | Only if space is found without altering data | High: GPT, `super`, or `userdata` may be involved | Better performance, complex layout | Requires a specific backup, rollback, and update plan | Not authorized; no layout proposed as safe |
| D. Rootfs on `userdata`, replacing Android | No | **Data destruction** | Simple, by inheriting the Pixel builder | Slot A does not restore the data; recovery requires reinstall/reset | Excluded from the early phases; only a future explicit decision |

## Recommended sequence

1. RAM diagnostics, with no modem firmware and no storage mount.
2. Read-only inventory of the UFS LUNs and GPT names, after the guard is verified.
3. Arch rootfs in RAM, or possibly on external USB, only after the host role is tested.
4. Consider internal storage only with a complete map of physical/logical partitions, readable backups, and a recovery plan.
5. Do not use the inactive slot as proof that an installation is reversible.

## Backup

A useful backup requires read-only access to the block devices, which is normally unavailable from Android without root. Do not assume that `adb`, fastboot, or fastbootd can read arbitrary partitions. If the privilege is not verified, the backup is "not available", not simulated.

Boot images and NV/calibration partitions contain sensitive or phone-specific data. Keep them outside the repository, with restricted access and SHA-256; not in issues, CI, or releases. A backup that was not verified with a second read/checksum is not declared valid.
