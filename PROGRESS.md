<!-- SPDX-License-Identifier: MIT -->
# Progress log

## 2026-11-06 — Start and reconnaissance

- Started the first M0 cycle without connecting or modifying the device.
- Checked the host tools: Git, GCC/Clang, the AArch64 cross-compiler, Docker, QEMU user-mode, and ShellCheck are present; 32 CPUs and about 393 GiB free.
- Confirmed from the LineageOS documentation the supported XT2203-1 variant and the reference hardware SM7325-AE / Adreno 642L.
- Analyzed the postmarketOS installation gist: the bootloader reports the panel variant; the historical flow modifies `vbmeta`, `dtbo`, `boot`, and `userdata`. Those operations will not be performed and are not the first-boot runbook.
- Started fetching the upstream repositories and pinning their commits in `sources.lock`.

**State:** reconnaissance in progress; no hardware test performed.

## 2026-11-06 — Audit, design, and first builds

- Cloned and pinned Omarchy Mobile, pmaports, the SC7280 kernel, and the LineageOS references; created `sources.lock`.
- Identified `linux-postmarketos-qcom-sc7280` 7.2.9-r3 and the tag `v7.2.9-sc7280`.
- Checked the CSOT/Tianma differences in the DTS files and in the NT37701 driver sequences.
- Checked that the board DTS is upstream since Torvalds v7.3-rc6, while the NT37701 driver and other parts of the port remain outside the upstream tree that was considered.
- Created `AUDIT.md`, `HARDWARE-MATRIX.md`, `BOOT-CHAIN.md`, `STORAGE-PLAN.md`, `RECOVERY-RUNBOOK.md`, `ROADMAP.md`, and `BUILD.md`.
- Implemented fetch, kernel build, initramfs, a panel-specific image that must not be flashed, checks, read-only capture, and offline CI.
- Created a RAM-only initramfs with storage entirely read-only, no switch_root, and no automatic panic.
- Initramfs build **succeeded**; AArch64 BusyBox ran under QEMU and the cpio content was verified.
- ShellCheck and static tests **succeeded**; verified that build-images rejects a build without a valid panel.
- The first kernel attempt failed because the `vmlinuz` target does not exist; removed the wrong target, kept the log, and restarted the build.
- Created `omamobile-device-dubai` with no blobs or active hardware services, and successfully prepared the Arch/Omarchy builder staging without modifying the upstream checkout.

**State:** kernel build in progress; no hardware test, no write to the device.

## 2026-11-06 — M2/M3 completed offline

- Kernel build **succeeded**: `7.2.9-dubai+`, `Image` of 33,831,424 bytes, `Image.gz`, both DTBs, and the module archive.
- Fixed, in a targeted way, the nonexistent kernel target, the release check, and the `usr/lib/modules` path; added `kmod` for `depmod`.
- `dtbs_check` **passed** for CSOT and Tianma with dtschema 2026.9.
- Verified the board/panel compatibles through libfdt and every artifact SHA-256.
- Two consecutive initramfs builds produced SHA-256 `674d8a2ae04e3c7cd4c6ac3f851d8d5b84411c425f82ec921c65e9fff643c1f9`: reproducibility check passed.
- Checked the ALARM databases: replaced `iptables-nft` with `iptables` and `linux-firmware-qca` with `linux-firmware-atheros`, which contains the ath11k/WCN6750 paths.
- Prepared offline CI and initialized the local Git repository `main`; no remote repository was created.
- Started the full Arch/Omarchy rootfs build with the upstream builder in staging.

**State:** M2 and M3 completed offline only; no hardware boot performed or claimed.

## 2026-11-06 — Rootfs and final checks in progress

- Repeated the final kernel/initramfs check successfully: 631 entries in the module tarball, including NT37701 and Goodix Berlin; the manifest now uses portable relative paths.
- `fetch-sources.sh` succeeded on all six pinned Git repositories.
- Fetched and verified the two pinned AOSP `mkbootimg` files; no boot image was generated because the panel is still unknown.
- Also checked the Omarchy AArch64 repository: `omarchy`, `omarchy-settings`, `omarchy-keyring`, and `voxtype-bin` are present; the builder respects the upstream Omarchy 4.0.6 pin.
- Stopped the sequential download of unnecessary Pixel packages. Implemented a selective parallel fetch that checks the signed index, trusted/revoked keys, SHA-256, and the signature of every package.
- **15 dubai packages verified** and imported into the local pacman repository; Arch Linux ARM tarball download in progress.
- Final static checks passed, including the PKGBUILD, the device-package test, and a Python compile that left no cache in the repository.

**State:** rootfs building; no device touched.

## 2026-11-06 — Rootfs resume fix

- The first rootfs build stopped in the post-import filter because Python tarfile does not open the host's zstd packages; replaced it with `bsdtar`.
- The ALARM tarball (791 MiB) was downloaded, checked with the MD5/signature from the upstream code, and imported as a Docker image before the next failure.
- Integrated the verified download of the public Omarchy keyring for hosts that lack the package, pinned in `sources.lock`.
- Resumed the build from the packages and image already present, with no changes to the phone.

**State:** rootfs building after the targeted fix.

- Checked the UCM fork at the pinned commit: it includes the dubai HiFi and VoiceCall profiles; VoiceCall requires `dummystreamhack`, so it is neither declared usable nor integrated automatically.

- Created `packages/omamobile-ucm-dubai` with the three pinned profiles, the BSD-3-Clause license, and no unverified VoiceCall dependency; static tests and the archive SHA-512 checksum passed. Not included in the first rootfs and not tested on hardware.

- `makepkg` produced `omamobile-device-dubai-0.1.0-1-aarch64.pkg.tar.zst`; inspected content: descriptor, mirrorlist, network/udev rules, and license only, with no blobs or activated hardware services.

- The first `pacstrap` stopped because ALARM Hyprland 0.57.1-1 could not find the required SONAMEs. The real dependencies were analyzed instead of being forced.
- Selected from the Omarchy edge binaries `hyprland-0.57.1-2` (libhyprgraphics 5) and `aquamarine-0.16.0-1.1` (libaquamarine 15), compatible with the other current packages; checksums and signatures verified, revisions in `sources.lock`.
- Resumed the rootfs build without rebuilding Hyprland and without changing the Omarchy 4.0.6 pin.

- The first installation of the Omarchy Mobile packages into the rootfs failed because `neard` had been excluded even though it is a mandatory dependency of `omamobile-apps`. Restored the signed generic package; no NFC hardware feature is claimed.
- Restarted the build with the existing package cache; the full log is kept in `out/rootfs/logs/build.log`.

## 2026-11-07 — Arch/Omarchy rootfs completed offline

- Resumed the build from the packages and the ALARM image already present; no download or kernel work was repeated without need.
- Rootfs build **succeeded** in 15 minutes: `work/omarchy-dubai/out/dubai/omamobile-rootfs-dubai-2026.11.07-aarch64.img.zst` (3.4 GiB), with a verified SHA-256 checksum and a 988-line manifest.
- The rootfs contains Arch Linux ARM, systemd 262.1-1, Omarchy 4.0.6-1, Omarchy Mobile shell 0.2.100-1, Hyprland 0.57.1-2, Mesa 26.2.6-1 with Freedreno, the dubai device package, and the `7.2.9-dubai+` modules.
- Upstream smoke test **passed**: ext4 filesystem, keyring and repository, first-boot services, Omarchy patches, modules, absence of host keys/per-device data, and no modem service enabled.
- Kernel, both DTBs, the module archive, and the initramfs were checked again; static tests passed.

**State:** M4 completed for the offline part only; no hardware boot, installation, or claim that dubai works. The next gate remains the read-only capture of model/panel and the authorized runbook for the first boot.

## 2026-11-07 — Device identification and CSOT boot image

- Performed an ADB capture that was **read-only only**, outside the repository: XT2203-1/dubai, LineageOS 23.2 nightly from 2026-05-29, slot `_b`, unlocked bootloader.
- Identified the **CSOT NT37701** panel from the Android cmdline without a reboot; no serial, MAC, or other identifier was copied into the documents.
- Fixed `capture-device-info.sh`: `/proc/device-tree` nodes that are absent on Android are optional and no longer block the `dmesg` capture attempt. That capture remains unavailable because of permissions.
- Generated `out/images/boot-dubai-csot-UNTESTED.img` offline (16 MiB), Android header v2 recognized and SHA-256 verified. No fastboot or boot command was run.
- The LineageOS portal no longer lists the installed nightly and the direct URL returns 404; the exact-restore gate stays open and the boot is not proposed as safe.

**State:** model and panel captured, CSOT artifact ready offline only; waiting for a verifiable recovery and specific authorization for a read-only fastboot session.

## 2026-11-07 — Authorized fastboot capture

- Performed only the authorized reboot from Android to ABL fastboot; no Linux boot, slot change, or write.
- `getvar all` confirms product/SKU, CSOT NT37701, unlocked bootloader, 8 GB RAM, 128 GB UFS, slot `_b`, and non-userspace fastboot.
- Both slots have retry 6 and successful yes, but `_a` is also `slot-unbootable=yes`: the strategy cannot treat it as an available restore.
- Read the sizes of boot, vendor_boot, dtbo, vbmeta, super, and userdata; the capture script now repeats these queries in a reproducible way.
- The phone stays in fastboot. Support for `fastboot boot` and the exact-recovery gate stay open; no image was sent.

## 2026-11-07 — First temporary boot: early failure

- Authorized and ran `fastboot boot` with the CSOT image **once**; the transfer and the command return OKAY.
- The Motorola disconnects and reappears as fastboot after about 3 s; no `1d6b:0104` gadget, shell, or Linux log. Slot, successful/unbootable flags, and retries stay unchanged.
- Identified and ignored the Galaxy Tab S5e connected to the same host: its USB network does not belong to the Motorola; later fastboot commands are bound to the Motorola serial.
- Rebooted only the Motorola into LineageOS `_b`. `pstore` is not readable by the ADB user and `/proc/last_kmsg` does not exist; the cause of the failure was not determined.
- Verified that header v2, offsets, page, DTB, and cmdline match pmaports. Downloaded the Nura package `linux-postmarketos-qcom-sc7280-7.2.9-r3` from the official mirror (SHA-256 `c504a4791b62faaab8ece3f62c5ab3eb8f84bba5a1cf950f338fa5f9b295f543`).
- The Nura CSOT DTB is byte-identical to ours; the kernel differs. Nura builds with LLVM/Clang thin-LTO/BTF, while the first build uses GCC. Started a separate LLVM build to isolate this difference without changing the DTS or the bootloader.

## 2026-11-07 — Cross-checks and verified backup

- LLVM build **succeeded** and was verified: thin-LTO/BTF, 631 module entries, and correct DTBs. Its boot image also returns to fastboot after about 3 s.
- The Nura 7.2.9-r3 binary kernel with our initramfs fails the same way: the toolchain and a single local build are not the demonstrated cause.
- The official LineageOS 23.2 `boot.img` from 2026-10-09, verified with SHA-256, boots correctly through `fastboot boot`: the mechanism is supported, while every mainline header-v2 image fails.
- Entered the existing LineageOS recovery and obtained ADB root after explicit confirmation on the device.
- Performed a read-only backup of boot, vendor_boot, dtbo, and vbmeta of both slots. All eight images have the expected size and a SHA-256 that matches between the host copy and a second read on the phone.
- Prepared the runbook for a persistent test of `boot_b` alone, with rollback from the real backup. No flash was performed; the phone stays in recovery.

## 2026-11-07 — Alpha 0 reached

- Flashing LLVM boot_b alone fails; rollback from the original copy succeeded and the LineageOS `_b` boot completed.
- Reproduced the empty 24 MiB DTBO required by pmaports: LLVM boot_b plus an empty dtbo_b **finally boots mainline**.
- Real shell: `Linux dubai-rescue 7.2.9-dubai+ aarch64`, model `Motorola Edge 30 (CSOT)`, USB NCM/ACM active, and SSH on a public key.
- Every UFS LUN `sda`–`sdf` verified read-only; no Android mount and no use of userdata.
- Fixed `/lib/modules` → `/usr/lib/modules`; loaded the NT37701 panel, GENI SPI, and Goodix Berlin. DRM card0/renderD128, a 1080×2400 framebuffer, and Goodix touch were detected.
- Integrated the linux-firmware Adreno SQE/GMU/zap firmware, with hashes recorded. A manual DRM rebind caused warnings/oops and GMU EBUSY: that method was discarded and only a clean boot will be tested.
- Prepared an NBD variant: qemu-nbd in snapshot mode on the PC and a client in the initramfs, to boot Arch without writing userdata. An LLVM rootfs rebuild was started so the modules match.
- LLVM rootfs completed and the smoke test passed; the manifest records the module tarball SHA-256 `9d49893488989f1d2ac781ae1ea3346700c1d64267daf42b215ad186ee961150`.
- NBD raw copy provisioned with firstboot and the public key, root ownership, and a clean `e2fsck`. qemu-nbd snapshot server active; Arch boot waiting for fastboot access through the keys.
- First NBD flash performed: mainline and USB NCM/ACM active, but the first NBD attempt happens before the host address is configured and leaves `/dev/nbd0` at zero capacity. A later manual mount correctly reads ext4 and finds `/sbin/init`; `switch_root` over SSH is rejected because it must be PID 1.
- `reboot -f` from the BusyBox initramfs puts ABL into fastboot and consumes the slot retries; `set_active b` was required to boot `_b` again. Do not use that reboot for the next tests.
- Alpine 3.24.2 marks root locked (`root:*`), so Dropbear also rejects the key in the new initramfs. Fixed the builder so root has no password in the initramfs only, keeping Dropbear `-s -g` and therefore key-only SSH.
- New NBD boot image built and verified: 90 seconds of retry, an NBD capacity check, and a qemu-nbd `--persistent` server. Flashing the corrected revision requires new physical access to fastboot; Arch/systemd have not been started yet.

## 2026-11-07 — Arch NBD and the Omarchy shell started

- `switch_root` succeeded: `systemd` is PID 1, `/` is ext4 rw on `/dev/nbd0`, firstboot creates the user, and SDDM starts the session. User SSH works after the old Dropbear was removed and the UFW rule on `usb0` was added.
- The initramfs Dropbear survives `switch_root`, loses its keys with the old root, and occupies port 22. The builder now stops it, together with the ACM console, before `switch_root`; the UFS guard stays active.
- UFW fails because four netfilter options are missing. Enabled `xt_limit`, `xt_LOG`, `xt_hl`, and `ip6t_rt` as modules; the LLVM kernel was rebuilt successfully and 636 module entries were verified.
- The initial clock was wrong (26 October) and was corrected; `pacman-key --populate` completed. The local dubai public key was added and signed locally as an owner action; `pacman -Q` and `pacman -Dk` pass, 972 packages, no signature check disabled.
- The generic qcm6490 zap blob causes Freedreno `ENXIO` errors. The dubai-specific blob pinned by pmaports, verified and kept private, allows Hyprland and Quickshell to start.
- EGL reports Freedreno Adreno and OpenGL ES 3.2; DRM offers 1080×2400 at 48/60/90/120/144 Hz. Hyprland recognizes Goodix; `evtest` confirms coordinates, release, and multitouch, with DPMS wake on touch.
- The rootfs rebuild with the updated modules is in progress; a complete firstboot and a boot without manual intervention remain to be validated.
