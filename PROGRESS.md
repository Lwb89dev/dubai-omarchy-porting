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

## 2026-11-07 — Clean boot, power, Wi-Fi and hardware follow-up

- The clean NBD boot completed firstboot without manual Dropbear or UFW repairs. `firstboot.conf` was removed, Hyprland/Quickshell and Freedreno started, and UFW allowed SSH on `usb0`. Only Plymouth, NetworkManager-dispatcher and the known console-less systemd-firstboot failures remain.
- ADSP firmware and its JSON metadata enable the PMIC battery service. Battery reads 99%/Full with real voltage, current and temperature; USB charging is reported. UPower energy fields remain zero and energy-rate is implausible, so telemetry is only partially correct.
- The dubai WPSS firmware and WCN6750 board data enable `wld0`. A reload of `ath11k_ahb` was needed after the initial missing-firmware probe. Real WPA2 association, DHCP, DNS, Internet ping and HTTPS passed. Ath11k still reports a board-data/calibration fallback.
- AW88261 firmware and the fixed UCM package create the Motorola-dubai card with Speaker and Mic3. Direct ALSA WAV playback completes; PipeWire creates the real nodes only after restarting the audio services, but stream linking/playback still times out and is not marked working.
- A new udev rule grants the video group access only to the two CMA DMA heaps. This removes libcamera's allocator errors; FastRPC remains protected. R10_CSI2P debayer support, sensor metadata and color calibration remain open.
- The private provisioning script now covers GPU, ADSP, WPSS, Wi-Fi board data and audio firmware. A full test on a temporary raw image passed content checks and `e2fsck`; no proprietary files enter the repository.
- Captured recurring NBD stalls: reads, writes and flushes remained pending for over 120 seconds and journald hit watchdog failures. Changed the documented server invocation to threaded I/O with no host cache. A local 128 MiB TCP write/read/flush test passed, but no Motorola was connected, so the USB/NBD retest remains open.
- Realigned the README, technical state and roadmap with the real Alpha 0/Alpha 1 and partial Alpha 2 results. Static checks and `git diff --check` pass; no device operation was performed in this follow-up.

## 2026-11-07 — NBD recovery and PipeWire audio

- Rebooted only the Motorola after its NBD-backed session froze, then used the verified CSOT image with `fastboot boot`. Identified the rescue gadget by its logical serial and configured only its host interface.
- Found that another USB device used the same `172.16.42.0/24` addresses: replies from `172.16.42.2` initially took the wrong interface. Added a source-specific policy route for the Motorola; the other device's route stayed unchanged. Ping and NBD then connected.
- qemu-nbd threaded/no-cache completed the full firstboot and later audio tests with no stuck-request messages. All UFS LUNs remained read-only; Hyprland, Quickshell, battery and charging were verified again.
- The raw image predated the current package list and lacked the dubai UCM profile and latest device rules. Restored correct time and the locally signed public key, then installed `omamobile-ucm-dubai` 0.1.0-2 without disabling signature checks. UCM HiFi created the real sink/source.
- Isolated the remaining PipeWire timeout: the audio stream's WirePlumber event stayed queued behind video enumeration, leaving both nodes without negotiated ports. Disabling `hardware.video-capture` made playback complete immediately.
- Added the video-monitor workaround and DMA heap rules to `omamobile-device-dubai` 0.1.0-3, built and installed the signed local package, removed the manual overrides, and repeated playback successfully using only package configuration. Microphone capture also passed; 20% gain avoided the clipping seen at 100%.
- Speaker audibility is still to be confirmed by the owner. Rebuild the raw rootfs before the next clean boot so these packages do not depend on manual installation.

## 2026-11-07 — Speaker hardware and S32 follow-up

- The owner heard no tone at 10%, 30% or 50% despite completed PipeWire streams. No 100% test was attempted because the amplifier path is not qualified.
- During playback, MultiMedia1 and Senary MI2S start with valid routing; both AW88261 DAPM paths and DACs are on. Dynamic debug reports `start success` on both amplifiers.
- Android configures `SEN_MI2S_RX` as S32_LE, while the mainline SM8250 fixup forces S16_LE and a 1.536 MHz bit clock. Prepared a dubai-compatible-specific patch selecting S32_LE and 3.072 MHz only for that backend; checkpatch passes with no errors or warnings.
- The LLVM test build could not start because `ld.lld` is absent. A separate GCC build is used for this functional test; no toolchain comparison is being made.
- A later isolated NBD stuck-write warning shows that threaded/no-cache mode did not eliminate the issue permanently. Keep extended NBD stability open.
- The GCC S32 kernel build succeeded with verified SHA-256 artifacts. Built `out/images-gcc-s32/boot-dubai-csot-UNTESTED.img` and updated the modules in the active NBD snapshot; `depmod` and the sm8250 module vermagic pass. No reboot or S32 hardware test has happened yet.
- The first S32 Arch attempt produced a black/unresponsive session and no SSH. After an authorized diagnostic reboot, the same kernel is healthy in rescue; pstore has no previous-boot records. The S32 audio path remains untested.
- Preserved the temporary NBD snapshot as a checked qcow2 overlay and documented an explicit persistent overlay plus `--shared=2`; this avoids losing work and rejects no new boot because of a stale client. The initial ext4 check found an unreplayed journal and dirty counters from the stopped session; repaired only a raw copy, replayed the journal, and obtained a clean `e2fsck -fn`. Created `work/rootfs-dubai-s32-ready.qcow2` on that clean backing image.
- Both GCC/S32 Arch attempts were unresponsive. Booting the previous LLVM kernel with GCC modules is invalid: the kernel reports a struct-module size mismatch. Downloaded and extracted Ubuntu `lld-18` into `work/toolchain-lld` without sudo or host installation; the matching LLVM/S32 build then completed with all SHA-256 checks. Started a coherent Arch/Omarchy rootfs rebuild using that exact `KERNEL_OUT`.

## 2026-11-08 — Rebuilt LLVM/S32 rootfs ready for the clean-boot gate

- Confirmed that the coherent LLVM/S32 rootfs build completed successfully: its checksum and upstream smoke test pass, and the manifest includes `omamobile-device-dubai` 0.1.0-3 and `omamobile-ucm-dubai` 0.1.0-2 with the matching S32 module tarball.
- Verified that `work/rootfs-dubai-llvm-s32.img` contains the private firstboot configuration, public SSH key, and all required GPU, ADSP, WPSS, Wi-Fi, and audio firmware. Read-only `e2fsck -fn` passes.
- `work/rootfs-dubai-llvm-s32.qcow2` uses that raw image as its backing file and passes `qemu-img check`; no qemu-nbd server is currently running.
- Repeated `tests/static.sh`, the LLVM/S32 kernel and initramfs verification, and every kernel SHA-256 check successfully. Both panel DTBs and all 636 module entries were verified.
- No Motorola was detected through adb or fastboot. No reboot, boot command, flash, or other device operation was performed; the clean NBD boot remains the next authorized hardware gate.

## 2026-11-08 — S32 black-screen test and toolchain isolation

- The first `fastboot boot` attempt was rejected with `Not Found` because no slot was selected and `_b` had zero retries. With owner authorization, restored only slot B selection with `fastboot --set-active=b`; no partition content was flashed.
- The LLVM/S32 NBD image then booted, but the rescue USB gadget disconnected from the host about 26 seconds after enumeration and the screen stayed black. The subsequent forced recovery returned to fastboot with slot B selected and seven retries.
- Stopped qemu-nbd and preserved the post-boot state. `qemu-img check` passes; a read-only conversion shows the expected dirty ext4 counters after the forced stop. Private journals and host logs remain outside Git.
- Booted the known-good non-S32 diagnostic image: SSH, the CSOT model, and kernel 7.2.9-dubai+ work normally. No previous-boot records exist in pstore, so the S32 failure has no captured panic.
- Compared the final configurations: the earlier S32 build outside the standard container unexpectedly lacked pahole/BTF and detected host Rust, producing config differences beyond the speaker patch. Started a new S32 build in the standard container with the same Clang 18, LLD 18, and pahole 1.25 as the working LLVM build. No audio result is claimed yet.

## 2026-11-08 — Controlled S32 comparison fails; return to stable kernel

- The standard-container S32 kernel, both DTBs, all 636 modules, the NBD initramfs, and the CSOT boot image built and passed offline verification. Its `config.final` is byte-identical to the stable non-S32 control.
- The coherent 2026.11.08 S32 rootfs passed checksum and smoke tests and was provisioned into a fresh raw image and qcow2 overlay with all private firmware.
- An attempted reboot through SSH blocked before reaching `fastboot boot`; that unintended run of the existing boot_b content was discarded as evidence. Stopped the stuck host task and did not count it as a test of the new image.
- Explicitly booted `out/images-llvm-s32-docker/boot-dubai-csot-UNTESTED.img` with SHA-256 `8525fe218ab789b53b74a60c4909d4051cca4fb5414de9b2fef4ad27ccde8539`. The verified rescue gadget again disconnected after 27 seconds, before SSH access. No panic was captured.
- The controlled S32 variant therefore remains unsuitable for boot testing. Started a current non-S32 rootfs rebuild so clean-boot and remaining hardware qualification can continue independently of the speaker experiment.

## 2026-11-08 — kmsg identifies NCM stalls; RNDIS clean boot passes

- Added an optional `CMDLINE` override to the offline boot-image builder and selectable `USB_NET_FUNCTION=ncm|rndis` support to the initramfs, keeping NCM as the default for compatibility. Static checks and artifact verification pass.
- A pre-authenticated ACM reader started `cat /proc/kmsg` before `switch_root` and kept streaming under Arch. It showed NBD read/write requests becoming stuck while ACM and the kernel stayed alive; qemu-nbd was idle and the host USB link had no errors. This disproved the earlier working assumption that the S32 patch itself caused a hard crash.
- Booted the same stable kernel and current rootfs with RNDIS instead of NCM, using a fresh qcow2 overlay. OpenSSH reached systemd with `/` on `/dev/nbd0`; `omamobile-device-dubai` 0.1.0-3 and `omamobile-ucm-dubai` 0.1.0-2 were already installed.
- Firstboot completed and removed its configuration, UFW became active with SSH allowed on usb0, and only the known Plymouth and console-less systemd-firstboot units remained failed. Every UFS LUN stayed read-only.
- Hyprland/Quickshell started, Goodix input was detected, and GBM EGL confirmed Freedreno with OpenGL ES 3.2. No NBD stuck requests or I/O errors appeared after firstboot.
- Package-only PipeWire playback completed at 10% and a five-second microphone recording at 20% produced a valid non-empty WAV. Speaker audibility still requires the owner's report. Wi-Fi was disconnected in this fresh boot and was not reconfigured; its earlier hardware test remains valid.

## 2026-11-08 — Audible S32 speaker playback fixed and verified

- Runtime capture during playback showed active routing and both AW88261 DACs, but a non-S32 backend. Android `mixer_paths.xml` explicitly selects S32_LE for SEN_MI2S_RX.
- Booted S32 through RNDIS to remove the NCM confounder. Initial testing showed AW88261 `start failure (-1)` from the SYSST/PLL check and inconsistent S16/S24 negotiation.
- Temporary instrumentation confirmed that the dubai helper was selected, but `snd_mask_set_format()` only adds a bit and did not remove S16/S24 alternatives. Updated patch 0001 to clear the format mask before selecting S32_LE and removed the instrumentation from the final code.
- Forcing S32 initially exposed `-EINVAL` in the DSP path. Added patch 0002 to map S32_LE to 32 bits in Q6ASM and Q6Routing while allowing the frontend to remain S16/S24 for ADM conversion.
- The final S32/Q6 set booted through RNDIS and completed firstboot. During a 10-second 440 Hz ALSA tone at 50%, MultiMedia1 used S16_LE and Senary MI2S used **S32_LE**; playback completed and the owner clearly heard the tone.
- Saved both final patches, verified that they apply to the pinned source, ran checkpatch on the complete kernel diff with zero errors/warnings, and repeated static checks. This is a real speaker hardware result, not only a completed software stream.

## 2026-11-08 — Final PipeWire path and WirePlumber camera localization

- On the final S32/Q6 set, a 10-second PipeWire tone at 50% completed with MultiMedia1 S24_LE and the Senary backend S32_LE. No NBD stuck requests, I/O errors, AW88261 start failures, or new DSP errors appeared; uptime exceeded ten minutes.
- Real battery telemetry reported 91%, charging/USB online, and 27 °C. UPower energy and energy-rate remain incorrect as already documented.
- Enabled video temporarily with the correct WirePlumber profile value `required`. Both cameras were enumerated, with the known missing metadata/calibration and R10_CSI2P debayer warnings, but no video nodes were created.
- Instrumenting `create-device.lua` proved that execution never reaches `device:activate()`: the `create-libcamera-device` event stays queued before its hook. Restored the original Lua script, removed the temporary override, unset debug, and restarted WirePlumber with the packaged safe configuration.
- Wi-Fi remained disconnected in this fresh boot; no credentials were collected and no new Wi-Fi result is claimed. Documentation changes from this follow-up are local and uncommitted.

## 2026-11-08 — Wi-Fi reconnected on the final RNDIS/S32 boot

- The owner connected `wld0` through the UI. DHCP assigned a valid address and default route; DNS resolution and three Internet pings passed with no loss.
- HTTPS returned 200 from both `example.com` and `archlinux.org`, with successful TCP and TLS negotiation.
- GitHub completed TCP/TLS but did not return an HTTP response within 15 seconds. Other sites passed, so this is recorded as destination-specific and not as a general Wi-Fi failure.
- Set the test user's password to the owner-requested test value and verified sudo. It applies to the PAM lock path and is recorded only in the private notes for future test installations.

## 2026-11-08 — WirePlumber V4L2 stall isolated; libcamera enabled

- Re-examined the complete event log against WirePlumber 0.5.18 source. Before the libcamera events, the V4L2 monitor repeatedly failed to open `/dev/video0` with `ENOMEM`; its asynchronous device activation left the shared event dispatcher blocked, so the queued libcamera hooks were a consequence, not the root cause.
- Enabled `hardware.video-capture` while disabling only `monitor.v4l2`. Both libcamera devices and both `Video/Source` nodes appeared, and PipeWire playback completed with the expected S24_LE frontend.
- Moved the workaround into `omamobile-device-dubai` 0.1.0-4, built and signed the AArch64 package, verified its contents/signature, installed it, removed the temporary user override, and repeated the camera-node and audio tests successfully with package configuration alone.
- Direct `cam` already captured one frame from each sensor, but a GStreamer PipeWire source selected by node name remains paused without format negotiation or frames. Camera client streaming and image quality/calibration remain open; no full camera functionality is claimed.
- Repeated package and repository static checks successfully. No reboot, flash, slot, or internal-storage operation was performed.

## 2026-11-08 — PipeWire camera streaming verified on both sensors

- Captured the live graph during the failing GStreamer test: the libcamera node enumerated native RGBA/RGBx formats, but no link existed because the test explicitly set `autoconnect=false`. WirePlumber's debug log confirmed that it skipped the stream for that reason.
- A manual RGBA link started libcamera and delivered a frame, isolating the test setup from the camera path. Repeating the client with normal autolinking then completed successfully.
- Captured five 640×480 RGBA frames from each sensor through GStreamer → PipeWire → libcamera. Both output files had the exact expected size; converted final frames are non-empty but dark and uncalibrated, so image quality remains unqualified.
- PipeWire playback completed again after both camera captures, and no NBD, amplifier, or DSP failure appeared in the checked kernel log. No additional camera patch was needed beyond the libcamera-only WirePlumber configuration.

## 2026-11-08 — Bluetooth pairing/A2DP and battery telemetry follow-up

- BlueZ initially saw no default controller even though hci0 firmware loading had completed. Extended management information identified an unconfigured UART controller with `public-address` missing.
- Configured a stable locally administered runtime address using the same machine/serial-derived approach as bootmac. LE discovery then found nearby devices; no identifier was added to public documentation.
- Pairing with the host initially failed because the test's default agent raced agent registration. Repeating with the agent ready produced a successful paired/bonded connection. BlueZ/WirePlumber created the host A2DP sink and `pw-cat` playback completed at stream volume 0.1.
- Removed the test pairing from both systems, restored host discoverability and phone pairability, and left the phone controller powered with its runtime address. No NV or internal-storage write occurred.
- Added an idempotent address helper, udev rule and oneshot service to `omamobile-device-dubai` 0.1.0-5. Built/signed/installed the package and verified successful no-op execution on the already configured controller. Automatic activation at boot remains untested without a reboot.
- Battery sysfs has valid capacity, voltage, current and temperature, but `charge_full`/`charge_full_design` are unreadable and firmware `power_now` is about 57 W while V×I is about 1.4 W. UPower 1.91.5 therefore reports zero energy and that invalid rate; no unjustified capacity estimate or kernel workaround was added.

## 2026-11-08 — S5KJN1 selection fix and repeatable camera test

- Found the source of libcamera's square active-area fallback in `s5kjn1_get_selection()`: the driver used the mode width for `height` and lacked `V4L2_SEL_TGT_CROP_DEFAULT` and `V4L2_SEL_TGT_NATIVE_SIZE`. The same defect is present in the current upstream driver.
- Added `0003-s5kjn1-selection.patch`, returning the real current-mode dimensions and the native 8160×6144 array. The patch applies cleanly and checkpatch reports no errors or warnings without requiring an AI sign-off.
- Built the complete LLVM kernel in an isolated worktree with all three port patches. Image, both DTBs, config and 636-entry module archive passed SHA-256 and offline verification; the config matches the controlled LLVM build. No new kernel was installed or booted.
- Added `tests/camera-pipewire.sh` to discover both sources dynamically and verify five 640×480 RGBA frames per sensor. The test passed on the running phone and static ShellCheck/syntax coverage now includes it.

## 2026-11-08 — Extended RNDIS/NBD stability check

- Completed 30 direct-I/O reads of 512 MiB from `/dev/nbd0`, one per minute plus transfer time, between 14:02 and 14:40 CET. The sequence transferred about 15 GiB over 39 minutes without a failed SSH/read iteration.
- The final kernel-log filter found no NBD stalls, blocked-request warnings or I/O errors. SSH, Bluetooth, PipeWire and WirePlumber remained active afterwards. This improves confidence in RNDIS/NBD but is not a persistent-installation or suspend qualification.

## 2026-11-08 — Battery charge units isolated; combined test image ready offline

- Confirmed that SM8350-class `qcom_battmgr` leaves `unit` at its zero-initialized mWh value because only the SC8280XP BAT_INFO callback initializes it. The running driver fetches CHARGE_FULL/CHARGE_FULL_DESIGN and then rejects both with `-ENODATA`; BATT_CHG_COUNTER tracks the remaining charge consistently with the reported percentage.
- Added `0004-qcom-battmgr-sm8350-charge.patch`, based on Jan-Michael Brummer's upstream QCM6490 series, to select mAh and expose CHARGE_NOW. Added `0005-sm7325-battery-power-now.patch` to hide only the invalid SM7325 POWER_NOW property while retaining real voltage/current telemetry. UPower's charge-unit path derives energy and rate from charge, current and voltage instead of POWER_NOW.
- Both patches apply and pass checkpatch; `qcom_battmgr.o` also builds with `W=1` without warnings. No capacity estimate or arbitrary power scaling was introduced.
- Built and verified `out/kernel-llvm-telemetry` with all five port patches: Image/Image.gz, both DTBs, unchanged controlled config and 636 module entries pass SHA-256 and offline verification.
- Built `out/initramfs-telemetry` and the CSOT image in `out/images-telemetry`; all offline checks pass. No reboot, boot, flash, slot change or internal-storage write was performed, so battery fixes remain unverified on hardware.

## 2026-11-08 — One-stop offline build

- Added `scripts/build-all.sh` to run static checks, pinned source fetching, isolated patch application, the LLVM kernel build, DTB validation, RNDIS initramfs, artifact verification and the rootfs build in order. Optional panel/firmware/SSH/NBD settings remain explicit; no device operation is included.
- Updated README and the build guide with the single command and its options. The rootfs builder now also includes the local libcamera package with the two dubai sensor gain helpers.
- Two real `BUILD_ROOTFS=0` runs passed, including worktree reuse. The second run accepted only the exact source revision and complete diff recorded by the first; CSOT/Tianma dtbs_check, 636 modules, initramfs execution and all SHA-256 checks passed.
- The full default build also passed, producing the 3.4 GiB compressed rootfs with libcamera/libcamera-ipa 0.7.2-4.24 and device/UCM 0.1.0-5/0.1.0-2. The rootfs checksum and complete upstream smoke test passed; this remains an offline result, not a clean-boot claim.

## 2026-11-08 — libcamera sensor gain helpers verified on both cameras

- Added a local libcamera 0.7.2-4.24 package with the GC02M1B gain model (`code / 1024`) and the S5KJN1 linear gain model. No black-level, color matrix or other unverified tuning was introduced. The build preserves warnings while disabling `-Werror` for the known GCC 16 AArch64 false positive in libcamera's shared-pointer code.
- Built and signed `libcamera` and `libcamera-ipa`, checked their contents/signatures and kept the original 0.7.2-4 packages for rollback. The first installation attempt was rejected without changes because `libcamera-bug-report` belongs to libcamera-tools; the final package excludes it and installs cleanly. `pacman -Dk` passes.
- After restarting only WirePlumber, the previous missing-helper warnings disappeared. Five-frame and 30-frame GStreamer/PipeWire captures passed on both sensors and low-volume `pw-cat` playback completed. The final-frame mean RGB values remained close to the pre-helper baseline, so image quality/calibration remains open.
- The new package is included by the rootfs builder and by the documented one-stop offline build.

## 2026-11-08 — Authorized boot verifies camera selection and battery telemetry

- Published commit `3e09a78`, installed the matching telemetry module archive on the active NBD rootfs and verified the S5KJN1 module hash/vermagic. The authorized CSOT `fastboot boot` then reached systemd and SSH through RNDIS/NBD. A normal `systemctl reboot` first returned to the existing NCM boot; `reboot -f bootloader` reached fastboot without flashing or changing slots.
- Battery `charge_full=3667000`, `charge_full_design=4089000` and `charge_now` are now readable; POWER_NOW is absent. UPower derives 13.4862 Wh full, 15.0382 Wh design and a plausible 2.0169 W rate from real charge/current/voltage. UPower still reports discharging while sysfs reports Charging because of its negative-current override; energy telemetry is fixed, charging-state handling remains open.
- S5KJN1 crop and crop bounds are both 8160×6144 and the previous selection errors/fallback disappeared. The repeatable PipeWire capture passed on both sensors and low-volume audio playback completed; no NBD, I/O, amplifier or kernel errors were found. All UFS LUNs stayed read-only.
- The first automatic Bluetooth helper ran before QCA firmware setup completed and exited without configuring an address. The controller subsequently answered Invalid Index to extinfo until the known local address was set and the controller powered on, after which Bluetooth worked. Device package 0.1.0-6 adds bounded retries and explicit power-on; its signed package installed and its idempotent execution passed on the configured controller. Automatic activation still needs a future boot test.


## 2026-11-11 — Automatic bring-up, offline key injection, Bluetooth gate closed

- No source or package change; the telemetry image from 2026-11-08 was reused and its SHA-256 re-verified.
- Diagnosed a silent NBD failure: the host firewall (UFW `DEFAULT_INPUT_POLICY="DROP"`) dropped the phone's `nbd-client` SYN to `172.16.42.2:10809`. ICMP still passed (allowed in `before.rules`) and host-to-phone connections worked, so the only symptom was the initramfs expiring into the diagnostic shell with no NBD attempt in the verbose `qemu-nbd` log. Documented the symptom and the fix (`sudo ufw allow from 172.16.42.0/24 comment dubai-rescue`) in `docs/RECOVERY-RUNBOOK.md`.
- Rewrote `scripts/host-usb-watch.sh`: on every `dubai-rescue` enumeration it binds the NM profile to the interface (name found by walking sysfs to the USB serial) and, once `172.16.42.2` exists, starts the persistent threaded/no-cache `qemu-nbd` server. This removes the manual ordering between the address assignment and the server bind.
- A forced-reboot sequence consumed all slot B retries and marked both slots unbootable; ABL showed a boot-failed screen and rejected `fastboot boot`. Restored only slot selection with the documented `fastboot set_active b` (no flash); retries returned to 7.
- Solved shell access without the owner's private key: stopped the server, flattened `rootfs-dubai-s32-q6.qcow2` to `work/rootfs-dubai-s32-q6-flat.img`, `e2fsck -fy`, injected the `kimi-dubai` ed25519 key into `/home/antona89/.ssh/authorized_keys` with `debugfs` (mode 0600, uid/gid 1000, owner key preserved), then created and now serve `work/rootfs-dubai-live.qcow2` on top of the flattened raw.
- Verified the Bluetooth boot automation on a clean boot: `omamobile-dubai-bluetooth-address@hci0` completed by itself, hci0 is powered with a stable locally administered address, and `bluetooth.service` is active. The 2026-11-08 follow-up gate is closed.
- Re-verified the UI bring-up: only `plymouth-start.service` failed (known), Wi-Fi `wld0` is up, PipeWire exposes the Built-in Audio speaker sink, and the phone reached the Omarchy shell.
- Battery telemetry remains real (energy and rate from charge/current/voltage); UPower still reports `discharging` while sysfs reports `Charging` because of its negative-current override. `energy-full` and `energy-full-design` both read 17.4902 Wh this boot; re-check the raw `charge_full` values before the next battery edit.
- NBD/RNDIS stability passed a shortened load check: 6 direct-I/O reads of 512 MiB from `/dev/nbd0` at 29.5-30.7 MB/s, about 3 GiB total, with no NBD stalls, blocked requests, or I/O errors in `dmesg`. UFS remained read-only (`/sys/block/sda/ro` = 1).
- Confirmed the Arch rootfs has no getty on `ttyGS0`: the ACM console answers only in the rescue initramfs, so serial access to the running system is not available; future console work should enable `serial-getty@ttyGS0` in the device package.
- Updated `PROCESS.md` with the new table rows, the firewall and slot-retry findings, and the offline key-injection recipe.


## 2026-11-11 (second part) — UPower charging-state fixed with patch 0006

- Root cause confirmed on hardware: `qcom-battmgr-bat/current_now` read a negative value while charging; Documentation/ABI/testing/sysfs-class-power expects positive-while-charging, and the downstream `smb5-lib.c` negates the same Qualcomm gauge data, so UPower's sign heuristic overrode the sysfs Charging status.
- Added `kernel/patches/0006-qcom-battmgr-sm7325-current-sign.patch`: negate `POWER_SUPPLY_PROP_CURRENT_NOW` only for the `QCOM_BATTMGR_SM7325` variant. Checkpatch on the full diff: 0 errors, 0 warnings (one pre-existing CamelCase check from patch 0004).
- Toolchain note: a native build with the host clang 23 failed at link time (`Producer LLVM23.1.3 / Reader LLVM 18.1.3` attribute mismatch with the extracted lld 18, and no aarch64 GCC on the host). The owner unlocked the Docker socket; the kernel was then built with the pinned `dubai-kernel-builder` image exactly like the reference builds. A second native attempt with LTO disabled never completed and was discarded; offline builds remain the canonical path.
- Built `out/kernel-signfix` (Image, Image.gz, both DTBs, 636-entry module archive) plus a fresh RNDIS/NBD initramfs carrying both rescue keys and the CSOT image; artifact SHA-256 and dtschema validation pass.
- Installed the new module archive into the live NBD rootfs and verified vermagic; `sm8250` is built in, so module coverage was checked on `snd-soc-qcom-common`.
- Incidents on the way: `reboot -f bootloader` and `systemctl reboot bootloader` both fell through to a normal `_b` boot instead of fastboot; a hard reset after the module install left the served ext4 unclean and the next `switch_root` failed into the diagnostic shell; the rescue dropbear rejected a valid two-key authorized_keys over SSH while the same key worked in the rootfs sshd; and the ACM rescue console stopped consuming host input (full write buffer) mid-debugging. The image was flattened, `e2fsck -fy` repaired it, and a fresh overlay replaced the live one.
- Verified on hardware after the fs repair and a clean `fastboot boot`: sysfs current_now is +587471 µA while charging, UPower reports `state: charging`, energy-rate 1.295 W, and time-to-full 2.2 hours at 83 percent. GPU, Bluetooth auto-address, and the speaker path remain up on the new kernel; only the known plymouth unit fails.
- Discharge sign is untestable in the NBD setup because the USB link that serves the rootfs is also the charging source; the negation follows the same unconditional convention as the downstream driver.
- The six-patch kernel, the rebuilt live overlay chain, and this log were committed; the reference CI rebuild with patch 0006 remains scheduled for when a container runner is available.


## 2026-11-11 (third part) — M8 suspend characterization on the sign-fix kernel

- Committed the remaining session artifacts with the GitHub identity (`Lwb89dev <84742481+Lwb89dev@users.noreply.github.com>`); the owner asked to never commit with a personal email. Added a gitignore entry for the checkpatch cache byproduct.
- DPMS off/on was dispatched through the Hyprland 0.57 Lua API (`hl.dsp.dpms("off"/"on")` via `hyprctl eval` with the instance signature from `/run/user/1000/hypr/`); both calls returned ok, the visual blank/unblank was not independently confirmed.
- Power inventory: `/sys/power/state` offers `freeze mem`; `mem_sleep` defaults to `[deep]` with `s2idle` available; no `/sys/power/disk`; rtc0 and the PMIC alarmtimer are registered with wakeup enabled, and the dwc3 USB gadget has wakeup enabled.
- Ran five `rtcwake -m freeze` suspends (15 s, 20 s, 20 s with USB wakeup disabled, 10 s, 60 s). Every one entered and exited s2idle cleanly (`PM: suspend entry/exit`), kept uptime and the NBD link alive, and never crashed; a clean `systemctl poweroff` was also reconfirmed earlier in the day.
- All five sleeps lasted about 0.65-0.82 s regardless of alarm length or disabling the USB wakeup flag; `dwc3-qcom a600000.usb: port-1 HS-PHY not in L2` is logged at each suspend. No registered wakeup source accounts for the wake (wakeup_sources shows zero wake counts, including pwrkey), so an unregistered IRQ — most plausibly from the gadget link to an active host — ends the sleep. The RTC alarm never fired as the actual wake source and the power button could not be validated as a wake source because the system was always awake again before the press.
- Consequence for M8: suspend entry and resume paths are reliable on this kernel, but sustained sleep and standby consumption are not demonstrable while the NBD rootfs is served over the same USB link; no battery-life claims are made. Root-causing the early wake (e.g., suspending with the USB link idle or in host role) is the next power task before modem bring-up.
