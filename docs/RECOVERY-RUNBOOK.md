<!-- SPDX-License-Identifier: MIT -->
# Recovery runbook — Motorola dubai

This document records operations already performed with authorization and the associated rollback. Installing Arch on `userdata` stays out of scope; the current strategy uses NBD without writing internal storage.

## State and backup

- XT2203-1/dubai, 8 GB RAM, 128 GB UFS, CSOT NT37701, LineageOS 23.2 from 2026-05-29, slot `_b`.
- Slot `_a` is marked unbootable; do not use it as a fallback.
- Private backup verified with two SHA-256 reads: boot, vendor_boot, dtbo, and vbmeta of both slots.
- Sizes: boot/vendor_boot 96 MiB, dtbo 24 MiB, vbmeta 64 KiB.

## Test results

| Test | Result |
|---|---|
| `fastboot boot` GCC/LLVM/Nura, header v2 | Return to fastboot after about 3 s |
| `fastboot boot` of the official LineageOS image | Android booted; command validated |
| Flash of mainline boot_b only | Boot failed; boot_b rollback succeeded and LineageOS booted |
| Flash of LLVM boot_b plus an empty dtbo_b | **Mainline booted**, ACM/NCM/SSH shell, UFS read-only |

The empty pmaports DTBO is therefore required. Do not modify vbmeta: it was not needed in the successful tests.

## Full rollback to the original images

Assign the serial locally without publishing it, and verify the checksums before restoring:

```sh
export FASTBOOT_SERIAL=<motorola-serial>
export PRIVATE_BACKUP=<private-backup-directory>
fastboot -s "$FASTBOOT_SERIAL" getvar product
fastboot -s "$FASTBOOT_SERIAL" flash boot_b "$PRIVATE_BACKUP/boot_b.img"
fastboot -s "$FASTBOOT_SERIAL" flash dtbo_b "$PRIVATE_BACKUP/dtbo_b.img"
fastboot -s "$FASTBOOT_SERIAL" reboot
```

Expected: LineageOS `_b` fully booted. This rollback was already verified for boot_b after the first flash. Do not change the slot, do not write vendor_boot/vbmeta, and do not use images from a different nightly.

## Fastboot access

From Android: `adb -s "$FASTBOOT_SERIAL" reboot bootloader`. From the initramfs the `bootloader` and `fastboot` reasons were ignored; use Power+Volume Down until fastboot. Always verify `product=dubai` and the serial before any write.

## Rootfs without an internal installation

The Arch/Omarchy rootfs is decompressed on the PC and served through a persistent qcow2 overlay. Writes stay on the PC; the Motorola does not mount `userdata`, `super`, or other Android partitions. The explicit overlay survives a server restart, and two allowed clients prevent a stale connection from a previous boot from blocking the next one.

```sh
qemu-img create -f qcow2 -F raw \
  -b "$PWD/work/rootfs-dubai-2026.11.07.img" work/rootfs-dubai-overlay.qcow2
qemu-nbd --format=qcow2 --persistent --shared=2 --aio=threads --cache=none \
  --bind=172.16.42.2 --port=10809 \
  --export-name=omamobile work/rootfs-dubai-overlay.qcow2
```

The NBD initramfs loads the client only if `/etc/omamobile-nbd-server` is present. It waits up to 90 seconds for the host network, rejects an NBD device with zero capacity, and on error stays in the diagnostic shell without trying alternate mounts. The server must stay persistent, because a client reboot would otherwise stop it.

After every enumeration, configure the host address before the retry expires. The interface name changes on every boot; walk from its udev path to the parent USB device and require `serial=dubai-rescue`. `PRODUCT=1d6b/104/*` is a generic gadget ID and is not enough when another Linux device is also connected. Do not use the previous name or the USB interface list alone. If another gadget shares `172.16.42.0/24`, add the source-specific route documented in `docs/BUILD.md` and use `BindAddress=172.16.42.2` for SSH; otherwise replies can use the wrong interface.

If ABL has exhausted the retries and marks `_b` unbootable, verify `product=dubai`, `running-bl-slot=_b/_b`, and the images, then `fastboot -s "$FASTBOOT_SERIAL" set_active b` restores only the test slot. Never use `_a` as a fallback.

## Stop conditions and symptoms

- Identity/slot inconsistent, or checksum missing: stop before writing.
- Return to fastboot after a new test: roll back only the partitions that were modified.
- Kernel up without a display: collect SSH/ACM and dmesg; do not change the DTS, kernel, and bootloader together.
- Any UFS LUN that is not read-only: stop, and do not mount it.
- No erase, wipe, lock, or writes to super/userdata, modem/NV, or calibrations. `set_active b` only in the case documented above, never on other slots or devices.
