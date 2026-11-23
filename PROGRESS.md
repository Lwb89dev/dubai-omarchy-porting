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


## 2026-11-11 (fourth part) — M9 modem: MPSS boots, QMI transport works, NV layer is the open blocker

- Inventory on the running system: MPSS remoteproc0 was offline with firmware `qcom/sm7325/motorola/dubai/modem.mbn`; ADSP and WPSS run; ModemManager was not installed; the dubai firmware directory lacked modem files. The postmarketOS device package depends on `soc-qcom-modem` and enables `tqftpserv-populate-readwrite`; its `msm-modem` dependency comes from Alpine aports and bundles qrtr-ns/rmtfs/tqftpserv-style bring-up that has no direct Arch equivalent.
- Installed `modemmanager 1.24.2-2`, `libqmi 1.38.0-2`, and `libqrtr-glib 1.4.0-2` from the Arch Linux ARM repos over the phone Wi-Fi. pacman 7 needs Landlock for its sandbox and this kernel does not enable it, so installs required `--disable-sandbox`; `CONFIG_SECURITY_LANDLOCK=y` is recorded as a kernel-fragment candidate, not bundled.
- Downloaded the FairBlobs dubai-firmware tarball pinned by pmaports (commit `56c15ff4`, sha512 verified) and copied `modem.mbn`, `modem*.jsn`, `modem_pr/`, `yupik_ipa_fws.mbn`, and the cdsp files into `/lib/firmware/qcom/sm7325/motorola/dubai/`; the firmware stays local and is never committed.
- Started remoteproc0: `Booting fw image qcom/sm7325/motorola/dubai/modem.mbn, size 88608932` then `remote processor modem is now up`. The glink `IPCRTR` channel of the modem edge bound to `qcom_smd_qrtr` (alongside the ADSP and WPSS instances).
- Verified the QRTR stack end to end: AF_QIPCRTR sockets open (family 42; 43 and 44 return E97), and `qmicli -d qrtr://1 --get-service-version-info` reached the modem and got a real QMI protocol answer.
- Every QMI service client allocation (dms, uim, and the service-version query itself answered `NotSupported`) fails with QMI error 3 `Internal`: the modem firmware is alive but has no configuration/NV layer. This matches the postmarketOS bring-up order, where `rmtfs` serves the persist-derived rfs files and `tqftpserv` serves the readwrite items before the modem is expected to be useful.
- `rmtfs`, `qrtr`, `tqftpserv`, and `pd-mapper` all exist in AUR; no `msm-modem` equivalent exists on Arch. ModemManager was unmasked, enabled, and started with libqrtr-glib linked in, and still finds no modem while the services are closed.
- Consequence for M9: firmware boot, glink/QRTR transport, and QMI reachability are verified; SIM detection, registration, data, and telephony stay gated on the rfs/NV layer. Next session: build the AUR pieces natively on the phone or as dubai packages, populate an rmtfs working copy from a read-only persist extraction (never write persist), restart MPSS, and re-run the QMI/UIM checks.
- MPSS was left running; the change is runtime-only and does not survive a reboot.


## 2026-11-11 (fifth part) — M9 modem: rmtfs layer built, crash root-caused, write gate reached

- Built the AUR stack natively on the phone: `qrtr 1.2` (linux-msm lib and tools, installed first so `rmtfs` resolves its dependency), `rmtfs 1.2`, and `tqftpserv 1.2` with `makepkg`; packages install with `pacman -U` because `makepkg -s` cannot prompt for sudo. The Arch package artifacts use the `.pkg.tar.xz` suffix.
- Installed base tooling for the builds (`base-devel`, `git`, `meson`, `ninja`) over the phone Wi-Fi with pacman's `--disable-sandbox` (Landlock is not enabled in the kernel; recorded as a fragment candidate).
- Took read-only backups of the modem NV storage before touching anything: `dd` of `modemst1` and `modemst2` (3 MiB each) into `/var/tmp/modemst{1,2}-backup.img` on the NBD rootfs. The persist partition (32 MiB ext4) was also copied read-only and its `rfs/mdm` tree inspected, then left unused for now.
- Started `rmtfs.service` (`rmtfs -r -P -s`, read-only raw EFS with remoteproc sync) and `tqftpserv.service` with the state directory populated from the `modem_pr` files shipped by the pinned firmware package.
- The modem now boot-loops: `qcom_q6v5_pas 4080000.remoteproc: fatal error received: dog_hal_common.c:177:DOG detects stalled initialization`. The hardware watchdog resets the modem because initialization stalls; rmtfs logs no served requests, so the stall happens before any EFS access completes and the read-only EFS cannot satisfy the modem's first-boot journal writes.
- Conclusion: the transport, firmware loading, and QRTR/QMI stack are all verified; the remaining blocker is the deliberately read-only EFS. The standard operating mode (rmtfs serving modemst1/2 read-write) is what LineageOS runs daily, but PROMPT.md requires owner approval for changes to NV partitions, so the session stops at this gate with backups in hand.
- Next approved step: drop `-r` from the rmtfs unit, let MPSS boot cleanly, replicate the uim-selection step from Nura's `msm-modem` (gitlab.nura.eco/nura/msm-modem, inspected via the Alpine aports packaging; it ships a uim-selection helper plus an rmtfs.service drop-in), then probe the SIM with qmicli and hand the modem to ModemManager.


## 2026-11-11 (sixth part) — M9 modem services live: IMEI on QMI, SIM ATR and data port open

- With owner approval the rmtfs unit was switched from `-r -P -s` to writable `-P -s`; the previous crash loop did not return, but the first modem instance had booted under the read-only era, so the remoteproc was bounced with a small script (the ad-hoc nested `echo stop > state` attempts through ssh quoting silently did nothing; the script logged `rc=0` and clean offline/running transitions).
- The correct QRTR node is `qrtr://0`: Nura's msm-modem uim-selection script targets it, while the earlier `qrtr://1` probes hit a decoy endpoint whose control service answered `NotSupported`. `qrtr-lookup` from the AUR qrtr package prints the modem service table.
- On `qrtr://0`, DMS answers with the real device identity (IMEI, ESN, IMEI SV), proving the NV content is intact and services are healthy. UIM answers too, but both slots report `error: no-atr-received (3)` — no provisioning session exists and the physical card does not answer reset. Owner confirmation about whether a SIM is inserted is the next question; if one is present, the SIM electrical path needs separate investigation.
- ModemManager probes `qrtr0` through its QMI steps but refuses to create the modem: `Failed to find a net port in the QMI modem`. The pmOS answer is the msm-modem-wwan-port step, a `qmicli --dpm-open-port=hw-data-ep-type=bam-dmux,...`; on dubai it fails with `Connection reset by peer / endpoint hangup`, no `rmnet_ipa0` appears, and the DPM service is not visible in the modem service table. `CONFIG_QCOM_IPA=m` and `CONFIG_RMNET=m` are built and the ipa module loads; `CONFIG_WWAN` is off and the interconnect logs `sync_state() pending due to 1e40000.ipa` from boot.
- Session result: the 2026-11-11 work took the modem from offline to healthy QMI telephony services with real NV identity. Open items, in order: SIM ATR, data port (DPM parameters or missing service), ModemManager integration, registration and call tests, VoLTE/IMS feasibility.


## 2026-11-11 (seventh part) — M9 data port fixed via IPA rebind; MM creates the modem

- After the writable-EFS boot the full modem service table appeared in `qrtr-lookup`, including DPM (47), WDS (1), WDA (26), and the other telephony services; the DPM `bam-dmux` open-port still ends with an endpoint hangup but the service itself exists.
- The missing net port was root-caused to a boot-time race: the IPA driver probed at 6.1 s and failed with `Direct firmware load for qcom/sm7325/motorola/dubai/yupik_ipa_fws.mbn failed with error -2` because the firmware had been copied into the rootfs after this boot started. Unbinding and rebinding `1e40000.ipa` with the firmware present made `IPA driver setup completed successfully` and created `rmnet_ipa0` (the `unexpected init_completed response` line is non-fatal). The pmOS uim-selection and wwan-port scripts were also fetched from Nura's msm-modem for reference; the wwan-port step targets `qrtr://0` with bam-dmux ep 1.
- ModemManager then created the modem: `[device qcom-soc] creating modem with plugin 'qcom-soc' and '2' ports` and `modem for device 'qcom-soc' successfully created`. A warning about `/dev/qrtr0` not existing during the QMI port reset is non-fatal; the state machine reached `locked` and failed only at `Couldn't check unlock status: QMI operation failed: GW primary session index unknown`.
- That failure is the expected no-SIM path: the UIM provisioning session (`Primary GW: session doesn't exist`) needs a physical USIM to select, and the owner confirmed no SIM is available for now. With a SIM, the next steps are the msm-modem uim-selection equivalent, MM unlock check, network registration, data over `rmnet_ipa0`, then call tests.
- Session result: the modem stack is fully live up to the SIM boundary — firmware, EFS, QRTR/QMI services, IMEI identity, IPA data port, and ModemManager modem creation are all verified. M9 resumes with a SIM card.
- Operational note for the rootfs builder: `yupik_ipa_fws.mbn` must be present in the image before the IPA driver probes at boot, otherwise the rebind workaround is required every boot; consider adding it to the private provisioning set and to the modem firmware copy list used on 2026-11-11.


## 2026-11-11 (eighth part) — M11 inventory: inputs and PMIC ADCs live; sensors need the SLPI stack

- Input inventory on the running system: `pmic_pwrkey`, `pmic_resin`, `gpio-keys` (volume), the Goodix Berlin touchscreen, the headset jack, and the USB offload jack; all six enumerate cleanly.
- IIO inventory: only the two PMIC SPMI ADCs (`pmic@8:adc`, `pmic@0:adc`) that back the battery telemetry; no accelerometer/gyroscope/ALS is exposed in mainline because dubai's motion and light sensors live behind the sensor DSP (SLPI) and need the FastRPC sensor stack.
- `sscrpcd` is not packaged in AUR (pmOS-only); `hexagonrpcd` is in AUR but not installed on the phone, and ADSP FastRPC audio already works without it. LED class exposes only the two flash channels (`white:flash`, `white:flash_1`); no vibrator class driver is present. GNSS has no userspace yet and depends on the modem location service, so it stays gated with M9.
- M11 sequencing therefore depends on packaging `hexagonrpcd` (AUR) and porting `sscrpcd` from pmOS, or revisiting after the SIM-based modem work. Pushed all 2026-11-11 commits to GitHub (`807741d..2e78ead` plus the follow-ups).


## 2026-11-11 (ninth part) — Actions fix, modem firmware provisioning, sensor-PD prerequisite

- GitHub Actions had never run a single job: `permissions: contents:read` on one line parses as a scalar string and GitHub rejects the workflow at queue time, so every push since the workflow was added failed in 0 seconds with zero jobs. Fixed the mapping; both jobs (static, kernel-initramfs) now queue and run, which also gives the reference kernel a CI build with patch 0006.
- `scripts/provision-nbd-rootfs.sh` now accepts `DUBAI_MODEM_DIR` and installs `modem.mbn`, `modem*.jsn`, `cdsp.mbn`, `cdsp*.jsn`, and `yupik_ipa_fws.mbn` into the image, so fresh rootfs builds carry the modem files before the IPA driver probes at boot; `docs/BUILD.md` documents the variable.
- M11 sensor prerequisite: `hexagonrpcd` 0.3.2 was built from AUR on the phone. The packaged units require `dev-fastrpc-adsp.device`, which the kernel fastrpc device does not advertise with the systemd udev tag, so the service cannot self-start; running the daemon manually works. The ADSP sensor PD wants the sensor registry from the Android path `/mnt/vendor/persist/sensors`, so a writable copy of the persist sensors tree was placed at `/var/lib/dubai-sensors` and bind-mounted at `/mnt/vendor/persist` (persist itself stays read-only and untouched). With `sns_reg_version` pre-created, hexagonrpcd serves the registry including the gyro calibration table. Actual sensor enumeration still needs `sscrpcd`, which is pmOS-only and must be ported before iio devices appear.


## 2026-11-11 (tenth part) — CI brought to life: three real bugs found and fixed

- The `offline-build` workflow had never executed a job: `permissions: contents:read` on one line parses as a scalar string, GitHub rejects the workflow at queue time, and every push failed in 0 seconds. Fixed the mapping; jobs now queue.
- With jobs finally running, three latent CI bugs surfaced in order. First, the staging clone in `build-rootfs.sh` used `--shared`, which disables promisor lazy fetching and aborted fresh checkouts with `could not fetch ... from promisor remote`; a regular clone keeps the promisor remote. Second, bulk lazy blob fetches intermittently kill GitHub's pack-objects under runner load (`git-pack-objects died`), even though the same blob is servable individually; `fetch-sources.sh` now retries three times and falls back to a full `--depth 1` clone, and the staging checkout retries up to five times, re-fetching only the still-missing blobs each pass. Third, the CI kernel container ran as root against runner-owned checkouts and git aborted with `detected dubious ownership`; the workflow now passes `-u "$(id -u):$(id -g)"` like `build-all.sh` does.
- All CI fixes are pushed; the workflow now performs real static checks, source fetching, the patched kernel build, initramfs creation, DTB validation, and artifact upload on every push. The six-patch kernel gets its first reference CI build on this push.


## 2026-11-11 (eleventh part) — Modem and sensor bring-up captured in the device package

- `omamobile-device-dubai` 0.1.0-7 now carries the whole 2026-11-11 runtime bring-up: an `rmtfs.service.d` drop-in switching to writable `-P -s` (the read-only EFS stall was the watchdog-reset root cause), the uim-selection oneshot adapted from Nura's msm-modem (GPL-3.0, attributed) targeting `qrtr://0`, the sensors-setup oneshot that copies `persist:/sensors` once from a read-only mount into `/var/lib/dubai-sensors` and binds it over `/mnt/vendor/persist`, a `75-dubai-fastrpc-systemd.rules` udev rule that tags `/dev/fastrpc-adsp` for systemd (verified: the device unit now plugs in and the packaged hexagonrpcd dependency resolves), and `omamobile-dubai-modem.target` as a soft integration point (Wants is tolerant of the AUR services being absent). ModemManager enablement ships as a symlink; rmtfs/tqftpserv/hexagonrpcd stay optdepends.
- Package tests updated only in content, not in policy: the RAM-only device.conf and storage allowlist checks still pass. Built with makepkg on the phone and installed; the install initially conflicted with the manually created ModemManager symlink, which was removed in favor of the packaged one.
- Remaining runtime-only state that a reboot still loses (by design, until a SIM session): the remoteproc start (rmtfs `-s` handles it when installed), the IPA rebind (no longer needed once the firmware is provisioned into the image before boot), and the bind-mounted sensor registry (the packaged oneshot now recreates it).


## 2026-11-11 (twelfth part) — CI static job green; kernel build in flight

- The `static` job of the `offline-build` workflow completed successfully for the first time after the fetch/worktree fixes: shellcheck, package tests, syntax checks, source fetching with pinned blob materialization, and the staging-tree preparation all pass on a fresh runner.
- The `kernel-initramfs` job (patched LLVM reference build, initramfs, DTB validation, artifact upload) runs for 30-45 minutes per attempt and was still in progress when the session ended; its result is visible on the repository's Actions page.
- Device package 0.1.0-7 with the packaged modem/sensor bring-up is installed on the phone and pushed; PROCESS.md next-steps now reflect the SIM-gated M9 path, the sscrpcd port for M11, and the GNSS/LOC endpoint-reset investigation.


## 2026-11-12 — Offline session: CI truth fixes, sensor stack packaging, suspend and telephony research

- No device access, no push rights (the available GitHub token belongs to `roadstrapp` and cannot push to `Lwb89dev/dubai-omarchy-porting`); all work is committed locally on `main` and pushes once the owner provides credentials.
- Docker daemon down and no passwordless sudo, so the canonical container build path was unavailable; the CI workflow remains the reference build for the kernel.
- CI audit found two real bugs: `validate-dtbs.sh` ran `make` on toolchain-less hosts (CI failure was the missing cross gcc, not schema errors — dt-validate output never fails the build because the kernel Makefile appends `|| true`), and the kernel job compiled the pristine pinned tree, silently publishing an unpatched reference kernel (the `7.2.9-dubai+` release string came from CONFIG_LOCALVERSION, not from patches).
- `validate-dtbs.sh` rewritten: re-execs inside the kernel builder container when the cross toolchain is missing, prints the log on make failure, and gates on parsed dt-validate errors against `tests/dtschema-allowlist.txt` (unexpected or stale entries fail). Host-side reproduction with a fresh dtschema 2026.9 venv and a rebuilt processed schema validated the gating against real logs (28 known errors across both panels).
- Kernel patch 0007 adds SM7325 to the lpass-tx-macro binding with an SM8450/SM8550 fallback enum (dubai + FP5 both use the pair; referenced lore.kernel.org series); the patch applies cleanly and removes two of the 16 findings. Remaining findings are genuine upstream gaps (wl2864c, apr-service naming, q6mvm/q6cvs/q6cvp, gc02m1b, nt37701 panel variants, dubai-sndcard, wcd9375 pairing) and are allowlisted with reasons.
- Workflow now routes the kernel job through `build-all.sh` (worktree + patch application); `build-all.sh` resets and re-applies the disposable worktree when the patch set or pinned revision changes instead of aborting; Dockerfile.kernel gains python3-pip/venv for in-container validation.
- Kernel fragments: CONFIG_SECURITY_LANDLOCK=y (CONFIG_LSM already lists landlock; pacman 7 sandbox stops needing --disable-sandbox) and CONFIG_PM_DEBUG/PM_SLEEP_DEBUG for the suspend test matrix.
- M8: `docs/SUSPEND.md` documents that "HS-PHY not in L2" is informational (link active at entry, not proof of wake cause), ranks USB gadget traffic / running MPSS / ath11k RX as the likely ~0.7 s periodic wake sources, and defines a six-test matrix (pm_debug_messages, Wi-Fi down, MPSS stopped, stalled host link, pm_test bisect, IRQ masking) for the next device session.
- M11: research showed a standalone sscrpcd port is obsolete — the modern stack attaches hexagonrpcd to the SensorPD and exposes sensors via libssc over QMI/QRTR, and upstream iio-sensor-proxy 3.9 already supports ssc. Packaged `libssc` 0.4.4 (aarch64 port of the official Arch PKGBUILD) and `hexagonrpcd` 0.4.0 (Alpine systemd-services patch, fastrpc sysusers, udev rule, dubai `-R /usr/share/qcom/sm7325/Motorola/dubai` drop-in); device package 0.1.0-9 soft-wants the sensor units; `provision-nbd-rootfs.sh` accepts optional DUBAI_HEXAGONFS_DIR for the FairBlobs registry (checksum-verified against the pmOS pin).
- M9: `docs/TELEPHONY.md` consolidates the verified modem state, the ordered SIM bring-up list, the GNSS path (`qmicli --loc-start`/`--loc-get-position` on qrtr://0, gated with the SIM like the rest of LOC), and a realistic VoLTE/IMS assessment (IMSS QMI 0xEA not implemented by libqmi/MM; no pmOS component to port; data+SMS+CS calls is the honest Beta bar).
- Device package 0.1.0-8/9 also enables serial-getty@ttyGS0 so the running rootfs offers a login on the ACM gadget console.


## 2026-11-12 (second part) — Push unlocked, first fully green CI run

- Owner switched gh to the Lwb89dev account (device flow) and added the `workflow` scope; the eight local commits plus the follow-up fixes were pushed to GitHub.
- Fixed `shellcheck SC2015` in `scripts/device-suspend-tests.sh` after the first static run flagged it; added `packages/iio-sensor-proxy` (aarch64 rebuild of Arch 3.9 with `-Dssc-support=enabled` and libssc — neither Arch nor Alpine ships the SSC backend) and the automated `docs/SUSPEND.md` matrix script; confirmed ALARM ships neither libssc nor iio-sensor-proxy, so the dubai packages fill a real gap; refreshed the sensor/GNSS rows in the hardware matrix.
- CI run on the first push failed in the dtschema venv inside the builder container: `pylibfdt` builds from source there and `Python.h` was missing (`python3-venv` without `python3-dev`); fixed in `docker/Dockerfile.kernel`. The patched LLVM kernel itself had built fine.
- The next run proved the dtschema gate works: it failed on exactly the two lpass-tx-macro blocks because `validate-dtbs.sh` generated its processed schema from the pristine tree while the kernel builds from the patched worktree. `build-all.sh` now exports `KERNEL_SRC=$worktree` for the validation step.
- Run 43244056166 (`345bf06`) is the first fully green `offline-build`: static 5m59s (shellcheck + fetch + staging), then `build-all.sh` built the seven-patch LLVM kernel `7.2.9-dubai+` and both DTBs, the dtschema 2026.9 gate passed with 28 known allowlisted errors, the initramfs and offline artifact verification passed, and the artifact bundle (Image/Image.gz, both DTBs, config.final, SHA256SUMS, modules tar.zst, initramfs) was uploaded.


## 2026-11-12 (third part) — Live M8 session on the CI kernel: USB link is the early wake, PMIC wake is missing

- Booted the CI reference kernel (7.2.9-dubai+ #1, Landlock active in LSM, /sys/power/pm_test present) via fastboot boot with a fresh NBD-rescue initramfs carrying a single rescue key (the two-key dropbear authorized_keys of 2026-11-11 is confirmed broken; single key works).
- Hit and fixed a regression: the rootfs still carried the 2026-11-11 module set, and the CI kernel rejects them at load (CONFIG_DEBUG_INFO_BTF_MODULES: "failed to validate module BTF: -22"), which had collapsed remoteproc (no ADSP/WPSS/CDSP/modem), ath11k and battmgr. Installed the CI artifact modules into /lib/modules/7.2.9-dubai+ (old set kept as .old), depmod, loaded the qcom remoteproc chain; WPSS needed a start plus an ath11k_ahb reload (documented recovery) for wld0 to associate again.
- Injected /root/.ssh/authorized_keys (owner key preserved, kimi-dubai appended) and /etc/sudoers.d/kimi (NOPASSWD) through the offline flatten-and-debugfs recipe (flat3 + fresh overlay; old overlay kept as .bak-20261111) so the session runs as root over SSH.
- rtcwake from util-linux segfaults on this rootfs; scripts/device-suspend-tests.sh now programs the RTC alarm via sysfs (absolute epoch — the +N relative syntax reads back garbage) and enters freeze via /sys/power/state. Fixed shellcheck SC2015; T3 falls back to taking usb0 down when the netem qdisc is unavailable.
- Suspend results (single clean freezes, PM_DEBUG on): baseline/Wi-Fi-down/MPSS-down all wake after ~0.6 s; with usb0 administratively down the system enters a sustained freeze and does NOT self-wake — the ~0.6 s wake source is the USB gadget link traffic (HS-PHY not in L2 confirmed as symptom). Sustained freeze also showed that NO wake source works: the RTC alarm (absolute wakealarm armed and verified) and the PMIC power key (power/wakeup enabled, RTC IRQ fires at runtime) both fail to wake s2idle; only forced reboot recovered.
- Historical hypothesis (corrected in `docs/SUSPEND.md`): PMIC interrupts are SPMI edge IRQs. The earlier claim that the PDC driver and dubai PDC node were absent was incorrect: `qcom-pdc.c` is built, and Dubai inherits the PDC and SPMI routing from kodiak. Suspend-time wake behavior remains under investigation.
- Kernel `#2` anomaly: one boot today ran a stale 7.2.9-dubai+ #2 kernel with an Android-style cmdline (no PM_DEBUG) despite fastboot boot reporting OK; the next clean poweroff-fastboot-boot cycle delivered the expected #1 CI kernel. Not understood; power-cycle fully if pm_test is missing after a boot.


## 2026-11-12 (fourth part) — NBD manual recovery, sensor stack staged on device

- The phone was found in the rescue initramfs (boot had missed the NBD window); completed the boot manually from the rescue shell: nbd-client to the host server, mount /dev/nbd0 on /newroot, kill dropbear, switch_root — documented as the standard manual recovery in docs/HANDOFF.md (detached process, absolute paths, SSH dies at killall and the boot completes anyway).
- Copied packages/{libssc,hexagonrpcd,iio-sensor-proxy} to /home/antona89/dubai-pkgs on the device and the pinned FairBlobs hexagonfs tree (308 files, acdb/dsp excluded) to /usr/share/qcom/sm7325/Motorola/dubai; removed a stray nested copy. Builds are the immediate next task; docs/HANDOFF.md carries the exact commands and all the field gotchas (BTF module rule, #1 kernel check, wakealarm absolute syntax, ath11k recovery, single-instance freezes, ufw cleanup).

- Final debug sweep: fixed two bugs in scripts/device-suspend-tests.sh found by re-reading after the live session — the wakealarm still used the +N relative syntax (reads garbage on this PMIC and never fires, so a freeze without USB wake would hang the phone; now absolute epoch) and the restore trap flags were inverted (Wi-Fi/MPSS were reconnected only when the script had NOT taken them down; now -n). Also normalized a trailing slash in DUBAI_HEXAGONFS_DIR in provision-nbd-rootfs.sh. Static checks pass; fixed script synced to the device.

## 2026-11-13 — rootfs image build completed

- Resumed the interrupted rootfs build using the CI kernel modules. All seven local packages built, including the experimental sensor daemon and autorotation client. The image builder completed with exit code 0, its rootfs smoke checks passed, and an independent SHA-256 check passed.
- The image, checksum and manifest are in `work/omarchy-dubai-resumed-build/out/dubai/` as `omamobile-rootfs-dubai-2026.11.13-aarch64.*`. The compressed image is approximately 3.3 GiB; the ext4 filesystem is 12 GiB. This is an unbooted generic rootfs: private firmware and per-device data are not included and provisioning remains separate.
- The first resume exposed a staging bug: `build-rootfs.sh` treated a Git worktree's `.git` file as missing, removed `work/omarchy-dubai-sensors-build`, then failed because Git still registered that worktree. Its staging files and local signing key were lost; the live NBD overlay and phone were not touched. The script now recognizes a `.git` file and refuses to delete an existing non-worktree staging directory. A fresh staging directory and signing key were used for the successful build.

- Prepared a separate private raw rootfs at `work/rootfs-dubai-2026.11.13-provisioned.img` with the existing firstboot configuration, rescue public key, pinned Dubai firmware and SensorPD registry. The first provisioning attempt exposed missing parent directories in the registry copy; `provision-nbd-rootfs.sh` now creates parent directories in order and deduplicates them. Re-running provisioning verified all copied files and `e2fsck -fn` passed. The firstboot config also passed the new image's validation in a scratch root. Both the raw image and its new `work/rootfs-dubai-2026.11.13-test.qcow2` overlay are private (mode 0600); `qemu-img check` passed. The previous live overlay remains untouched. The phone was observed in fastboot, but no boot or device writes were performed.

## 2026-11-13 — temporary boot of the new image

- With owner authorization, booted the previously verified CSOT image temporarily, serving `work/rootfs-dubai-2026.11.13-test.qcow2` via the USB watcher and NBD. The new rootfs completed firstboot, reached Hyprland and runs over NBD. The watcher's `DUBAI_NBD_OVERLAY` option selects this overlay without changing the old default. The owner Wi-Fi profile was recovered privately from a read-only conversion of the old overlay; Wi-Fi connected. The new local repository signing key had not been trusted after firstboot reset the pacman keyring, so its verified staging public key was locally signed on the phone; this remains a future image-builder integration issue.
- The experimental sensors daemon and proxy start; ambient light reported 187 lux and the accelerometer was present. Enabled the autorotation user service; visual rotation and touch were not rechecked on this boot. Both cameras captured five 640x480 RGBA frames through PipeWire. Battery status was Charging. Plymouth and console-less systemd-firstboot remain the two failed units.
- The fresh image lacked ModemManager, qrtr, rmtfs and tqftpserv. Installed ModemManager from ALARM and built qrtr/rmtfs/tqftpserv 1.2 from SHA-256-verified AUR recipes on the phone. As all physical UFS LUNs remain read-only, made verified private backups of modemst1, modemst2 and fsc, then configured rmtfs to use separate writable copies under `/var/lib/dubai-rmtfs` (`-P -o ... -s`) instead of the block devices; seeded tqftpserv from modem firmware and enabled both services. This is an experiment, not validated persistent telephony or a reason to copy Linux EFS data back to Android. The modem booted, QMI services and rmnet_ipa0 appeared, and ModemManager created a qcom-soc modem but failed its unlock check. UIM reports `no-atr-received` for both slots. The original three partitions still match the backups and all six UFS LUNs remain read-only. Restarting the UIM selection service after the modem came up yielded a clean no-SIM result.
- The test rootfs and watcher were left running; do not modify the active backing file or stop the NBD server while the phone uses it. SIM presence, registration, data and calls, repeated boots, display/touch confirmation and suspend wake remain unqualified.

## 2026-11-13 — NBD recovery and local repository key

- The USB connection disappeared and the owner returned the phone to fastboot. After confirming the phone was in fastboot, stopped the watcher and NBD server, checked the old qcow2, and converted it to a separate raw recovery image. Read-only e2fsck found a dirty journal and allocation metadata; `e2fsck -p` replayed the journal and cleaned orphans. A subsequent read-only e2fsck and a new recovery qcow2 check both passed; the prior overlay was preserved. A temporary fastboot boot was accepted, but the phone did not enumerate USB afterwards, so rootfs startup remains unverified; the watcher is configured to serve `work/rootfs-dubai-2026.11.13-recovery.qcow2` if it appears.
- For future image builds, stage a helper that places the local repo signing public key and its fingerprint trust record in `/usr/share/pacman/keyrings`; firstboot's existing `pacman-key --populate` should then import it into the newly created keyring. An isolated GnuPG keyring using the produced files successfully validated the signature of the built libssc package with full trust. A new image build and firstboot test of this integration are still required.
- Examined the previous boot's recovered journal: `upowerd` requested suspend via logind; the USB link lost carrier as the kernel attempted deep sleep, then the system entered s2idle without a recorded subsequent exit. The trigger for UPower's request is not yet established. While the recovery image was offline, masked the systemd sleep targets and set UPower `CriticalPowerAction=PowerOff` on that recovery image only, so a genuinely critical battery can cause a clean shutdown rather than the known-broken suspend. These are temporary NBD protections, not a suspend fix; runtime behavior and battery state remain to be checked. `e2fsck -fn` and `qemu-img check` pass after the offline changes.
- The owner returned the phone to fastboot and a second temporary boot reached the recovery rootfs over NBD. The bootloader reported 3510 mV; running Linux reported battery capacity 0%, status Discharging and voltage 3347830 µV. Issued `systemctl poweroff` successfully to protect the filesystem; after USB disappeared, stopped the NBD watcher/server. The qcow2 check and offline `e2fsck -fn` on a flattened copy both passed. These battery readings are consistent with the earlier UPower suspend request, but do not prove its precise trigger; charge the phone externally before further boot tests. The Linux capacity and status readings have not been cross-checked against Android or an external meter.

## 2026-11-22 — M8 PMIC RTC wakeup proven in RAM rescue; recovery rootfs cold-boot verified

- Bootloader preflight confirmed `dubai`, `current-slot: b`, `slot-retry-count:b: 1`, `slot-unbootable:b: no`, and `battery-voltage: 4364 mV` (fully charged). Verified `SHA256SUMS-csot` on `out/images-nbd-2026-11-12/boot-dubai-csot-UNTESTED.img` and ran an authorized temporary `fastboot boot` into the RAM-only rescue initramfs (`7.2.9-dubai+ #1`, `PM_DEBUG` active, all six UFS LUNs `ro=1`).
- **M8 breakthrough:** four consecutive real `s2idle` (`freeze`) tests in RAM rescue slept for their full programmed intervals and woke cleanly via the PMIC RTC alarm (`PM: Triggering wakeup from IRQ 115`, `pm8xxx_rtc_alarm`, `suspend_stats/success=4, fail=0`): 6 s with `usb0` up, 11 s with `ip link set usb0 down`, 11 s with UDC `a600000.usb` unbound, and a 61 s control freeze. This disproves the earlier hypothesis that PMIC/SPMI/PDC wakeup was broken on `dubai`.
- Root-caused the 2026-11-12 failure to two combined bugs: (1) PMK8350 `rtc-pm8xxx` keeps a raw 1970 hardware epoch (`rtc0/since_epoch` ≈ `248189`) while NTP advances Arch wall-clock `date +%s` to 2026 (`1795367259`), so `$(date +%s) + N` armed the alarm 56 years ahead; (2) `T3` in `scripts/device-suspend-tests.sh` brought `usb0` down and then wrote to `/dev/nbd0` (`note`/`sync`/`snapshot`) before bringing `usb0` back up, deadlocking userspace. Fixed both in `scripts/device-suspend-tests.sh` (`rtc0/since_epoch` arithmetic + skipping link-down on NBD rootfs). `qcom_stats/{aosd,cxsd}` stayed 0 while the USB cable remained physically connected; in-window `pmic_pwrkey` wake (press arrived just after the 60 s RTC timeout expired; IRQ 116 incremented 0 → 6 → 12 while awake) and unplugged CXSD/AOSD sleep remain open.
- Cleanly powered off from RAM rescue (`poweroff -f`, keeping `slot-retry-count:b: 1` intact) and ran a second authorized `fastboot boot` with `host-usb-watch.sh` and `qemu-nbd` serving `work/rootfs-dubai-2026.11.13-recovery.qcow2` (`qemu-img check`: 0 errors). Cleared two stale `--shared=2` TCP sessions on `qemu-nbd` so PID 1's `nbd-client` connected cleanly and completed `switch_root` into systemd.
- Cold-boot verification on the recovery rootfs: `7.2.9-dubai+ #1` on `/dev/nbd0`, all six UFS LUNs `ro=1`, only `plymouth-start.service` failed; all five systemd sleep targets `masked` and UPower `CriticalPowerAction=PowerOff` confirmed live; battery/charging live (`89%`, `Charging`, `4.255 V`, `+331 mA`; UPower `charging`, `2.03 W`, `51.9 min to full`); Bluetooth powered on at boot; Wi-Fi connected, Hyprland running, ModemManager detected `Modem/0`; `omamobile-dubai-sensors-setup`, `hexagonrpcd-adsp-sensorspd`, `iio-sensor-proxy 3.9-3`, and user `omamobile-autorotate.service` all active at cold boot with `monitor-sensor` reporting accelerometer (`face-down`), ambient light (`275.14 lux`), and live compass headings (`303°–312°`). Private logs saved in `private-capture/2026-11-22/`.

## 2026-11-22 (second part) — M9 full telephony, 4G LTE data, SMS, GNSS, and two-way voice calls (Earpiece + Speakerphone) verified

- With a physical SIM inserted in Slot 1, QMI UIM initially detected the card (`Card state: 'present'`, `usim (2)`), but the application stayed in `Application state: 'detected'` (`UimUninitialized`) and DMS reported `Mode: 'shutting-down'`.
- Root-caused the USIM initialization block via `/var/lib/tqftpserv/dhob_report.txt` and `hob_report.txt`: Motorola's MPSS firmware logged `FATAL: blank dhob in trusted mode` / `FATAL: dhob functionality blocked` because `dhob.bin`, `shob.bin`, `datablock/{id_00,id_01,slid_00}`, `cal_rfs/*`, and `mot_rfs/imei_sv` were missing from `/var/lib/tqftpserv/`. Extracted `persist:/rfs/msm/mpss` strictly read-only via `debugfs` into `/var/lib/tqftpserv/` on the private NBD rootfs (without mounting or writing to `persist`; all six UFS LUNs stayed `ro=1`). After restarting `remoteproc0` and setting `--dms-set-operating-mode=online`, `dhob_report.txt` reported `DHOB created at the factory` and the USIM transitioned immediately to `Application state: 'ready'` and `Personalization state: 'ready'`.
- **Network registration, 4G LTE data, SMS, and GNSS:** Registered on `FASTWEB` (`MCC 222`, home network, CS+PS attached, LTE `eutran-20` 10 MHz, RSSI `-79 dBm`, 5G NR SNR `8.5 dB`, ModemManager `state: registered`, `signal quality: 55–59%`). Connected bearer `/Bearer/1` on `qmapmux0.0` (QMAP mux over `rmnet_ipa0`, MTU 1430) and passed both ICMP `ping -I qmapmux0.0 1.1.1.1` and `curl --interface qmapmux0.0 -I https://1.1.1.1` (`HTTP/2 301`). `omatel-agent` automatically received and stored incoming SMS messages. `mmcli --location-get` returned both 3GPP cell location and live GPS NMEA sentences (`$GPGSV`, PRN 28 at 29 dB SNR indoors).
- **Voice calls (Earpiece + Speakerphone):** The first incoming CS call rang and connected (`ringing-in → active → terminated`), with no audio because `dummystreamhack` and a PipeWire 1.2+ `org.mobian_project.CallAudio` handler were not yet installed. Packaged, built, and installed `dummystreamhack 0.r20261020.6faaa6b-1` (MIT, opening the hostless `VoiceMMode1` playback/capture streams on `hw:0,5`), added `SectionDevice."Speaker"` (`ConflictingDevice` with `Earpiece`) to `VoiceCall.conf` (`omamobile-ucm-dubai 0.1.0-3`), and implemented `dubai-callaudiod` (`omamobile-device-dubai 0.1.0-11`) handling `SelectMode`, `EnableSpeaker`, and `MuteMic` across PipeWire 1.2+ split profiles (`Voice Call (Earpiece, Mic3)` ↔ `Voice Call (Mic3, Speaker)` ↔ `HiFi`). Owner verified clear two-way call audio on both Earpiece and Speakerphone (Vivavoce).

## 2026-11-23 — M8 PMIC power-key (IRQ 116) s2idle wakeup and PSCI OSI cluster S2 (`cluster_sleep_llcc_off`) verified

- Bootloader preflight confirmed `dubai`, `current-slot: b`, `slot-retry-count:b: 1`, `slot-unbootable:b: no`, and `battery-voltage: 3429 mV`. Verified `SHA256SUMS-csot` on `out/images-nbd-2026-11-12/boot-dubai-csot-UNTESTED.img` and `qemu-img check` on `work/rootfs-dubai-2026.11.13-recovery.qcow2` (0 errors), then booted into the RAM-only rescue initramfs (`7.2.9-dubai+ #1`, all six UFS LUNs `ro=1`) with the panel blanked so the PMIC charged the battery from `3.429 V` to `3.796 V` (`3796386 µV` on `pmic@8:adc` `vbat_sns`).
- **M8 PMIC power-key (`pmic_pwrkey`, `IRQ 116`) wakeup proven:** Armed a 300-second `rtc0/since_epoch` safety fallback (`t1=959`, `alarm=1259`), brought `usb0` down, and entered `s2idle` (`echo freeze > /sys/power/state`). Pressing the physical Power button woke the device cleanly after **22 s** (`t2=981`, 278 s before the RTC fallback) with `pm_wakeup_irq=116`, `PM: Triggering wakeup from IRQ 116`, and `IRQ 116` incrementing `4 → 5, 1`. A subsequent 30 s window also woke cleanly after **3 s** on `pm_wakeup_irq=116` (`IRQ 116: 9,1 → 10,2`). Across all five `s2idle` cycles on this boot (three RTC `IRQ 115` wakes and two power-key `IRQ 116` wakes), `/sys/power/suspend_stats/success` reached `5` with `fail=0`.
- **PSCI OSI cluster deep idle (`S2` / `cluster_sleep_llcc_off`) & `pm_genpd_summary` findings:**
  - Mounted `debugfs` in RAM rescue and inspected `/sys/kernel/debug/pm_genpd/power-domain-cluster/idle_states` (`18200000.rsc`) and `cpuidle`: at runtime idle, all 8 Kryo 670 cores enter `little-rail-power-down` (`0x40000004`) / `big-rail-power-down` (`0x40000004`) and the APSS cluster enters `S0` (`cluster_sleep_apss_off`, `0x41000044`, 3,543 entries) and `S1` (`cluster_sleep_cx_ret`, `0x41001344`, 34,056 entries, 749.0 s total residency).
  - On **5 out of 5 `s2idle` freezes (`Usage: 5, Rejected: 0, S2idle: 5`)**, `power-domain-cluster` entered its deepest PSCI domain idle state **`S2` (`cluster_sleep_llcc_off`, `0x4100b344`)**, confirming that `rpmh_rsc_pd_callback(GENPD_NOTIFY_PRE_OFF)` and `rpmh_flush()` succeed without rejection on every `s2idle` entry.
  - Blanking `fb0` (`echo 4 > /sys/class/graphics/fb0/blank`) transitions `ae00000.display-subsystem`, `ae01000.display-controller`, and `ae94000.dsi` from `active` (vote `256` on `cx`) to `suspended` (vote `0`). While USB VBUS (`~4.98 V`) is present, `a600000.usb` (`dwc3-qcom`) remains `runtime_status=active` (vote `256` on `gcc_usb30_prim_gdsc` → `cx`), and in RAM rescue the four remoteproc DSPs (`adsp`, `cdsp`, `wpss`, `mpss`) are unbooted so their SMEM sleep-stat items (`605..631`) are unallocated and chip-wide `qcom_stats/{aosd,cxsd,ddr}` stays `0`.
- Verified NBD connectivity from the phone to the host `qemu-nbd` server on Omarchy 4.5.0 (`Negotiation: ..size = 12288MB`, `NBD_CONNECT=OK size=12884901888`) and saved the M8 captures in `private-capture/2026-11-23/`.

## 2026-11-23 (second part) — M8 unplugged VBUS=0 s2idle, full-rootfs DSP qcom_stats, packaged M9 update, M10 perf & M11 audit

- **True unplugged `VBUS = 0 uV` `s2idle` test (RAM rescue):** Armed an unplug-triggered `rtc0/since_epoch + 25` freeze on `7.2.9-dubai+ #1` (panel blanked) and waited for `usb_in_v_div_16 < 1.5 V`. Once physically unplugged (`VBUS_BEFORE=0uV`, `VBUS_AFTER=0uV`), the device slept **26 s** (`t1=20598`, `t2=20624`, `alarm=20623`), woke cleanly on `pm8xxx_rtc_alarm` (`pm_wakeup_irq=115`, `suspend_stats/fail=0`), and entered PSCI OSI cluster `S2` (`cluster_sleep_llcc_off`, `Usage: 1 -> 2`, `S2idle: 0 -> 1`, `Rejected: 0`). Captured why `qcom_stats/{aosd,cxsd}` stay `0` in RAM rescue even at `VBUS=0`: `qcom-rpmhpd` (`18200000.rsc:power-controller`) still has `sync_state()` pending due to unprobed `aa00000.video-codec` and the four remoteprocs, and `a600000.usb` (`dwc3-qcom`) stays `runtime_status=active` (`role=device`, `port-1 HS-PHY not in L2`, `256` vote on `gcc_usb30_prim_gdsc`/`cx`). Saved capture in `private-capture/2026-11-23/m8-unplugged-vbus0-s2idle.log`.
- **Cold boot on `work/rootfs-dubai-2026.11.13-recovery.qcow2` (full-rootfs `qcom_stats` & M10 baseline):** Booted via `fastboot boot` (`battery-voltage: 3818 mV`, `slot-retry-count:b: 0`, all six UFS LUNs `ro=1`). `systemd-analyze`: `2.629s (kernel) + 21.455s (userspace) = 24.085s`, `graphical.target` in `8.403s`; only `plymouth-start.service` failed; `serial-getty@ttyGS0.service` active. With all four remoteprocs running (`modem`, `adsp`, `wpss`, `cdsp`), `qcom-rpmhpd` `sync_state()` is **no longer pending** and DSP sleep stats increment live: `cdsp` (`Count: 120`, `Accumulated Duration: 5900910336`), `modem` (`Count: 66`, `Accumulated Duration: 3443492277`), and `wpss` (`Count: 3`, `Accumulated Duration: 17228`), while `adsp` stayed `0` (PipeWire/sensors active). In `pm_genpd_summary`, only `a600000.usb` (`256`, NBD) and `99c000.serial` (`128`, BT) held `cx` active.
- **Packaged M9 stack on recovery rootfs:** The recovery overlay still held `omamobile-device-dubai 0.1.0-10` and `omamobile-ucm-dubai 0.1.0-2` (missing `dubai-callaudiod` and `--dms-set-operating-mode=online`). Built and installed `omamobile-device-dubai 0.1.0-11` and `omamobile-ucm-dubai 0.1.0-3` via `makepkg`/`pacman -U` on the phone alongside `dummystreamhack 0.r20261020.6faaa6b-1`; verified `org.mobian_project.CallAudio` D-Bus auto-activation and PipeWire 1.6.11 profile switching (`SelectMode(1)` ↔ `EnableSpeaker(true/false)` ↔ `SelectMode(0)`, all `true`). No physical SIM was present during this cold boot (`no-atr-received`).
- **M10 performance & ZRAM evaluation:**
  - `free -m`: `7367 MiB` total, `3437 MiB` used (`AnonPages: 1805 MiB`, `Shmem: 815 MiB`, `Unevictable: 787 MiB`), `3930 MiB` available; top RSS consumers: `quickshell` (`725 MiB`), `voxtype` + `voxtype-osd-gtk` (`320 MiB`), `Hyprland` (`189 MiB`), `superwhisper*` (`143 MiB`), `wireplumber` (`89 MiB`), `Xwayland` (`78 MiB`). `SwapTotal: 0` (`CONFIG_ZRAM=y` with `zstd` default is in the kernel and `/dev/zram0` exists, but no userspace generator is configured; `zram-generator 1.2.1-1` is in ALARM `extra`). Recommended for 6 GB RAM variant stability.
  - CPU `schedutil` (~81–82% idle in `vmstat`), thermals 24–37.5 °C; `DSI-1` `1080x2400@144Hz` scale `3`, Freedreno `Adreno 7c+ Gen 3` OpenGL 4.6 / GLES 3.2 (`Mesa 26.2.6`), `3d00000.gpu` at `315 MHz`.
  - Hyprland app launch-to-map times over NBD: `omacalc` **535 ms**, `omamessages` **817 ms**, `omacam` **1028 ms**, `omaphone` **1189 ms**.
- **M11 sensor confinement & haptics audit:** Confirmed `/var/lib/dubai-hexagonrpc` contains zero symlinks, `root:root` parent dirs, `fastrpc:fastrpc` limited to `sensors/persist`, `ProtectSystem=strict`, `ProtectHome=yes`, `NoNewPrivileges=yes`, and no `/mnt/vendor/persist` mount; live `monitor-sensor` reported `263.33 lux`, `face-down` tilt, and compass `268.9°–355.4°`. Confirmed `sm7325-motorola-dubai-common.dtsi` only defines `aw86224_reset_default` (`gpio46`) and `aw86224_int_default` (`gpio47`) pinctrl states with no I2C/input haptic node (`CONFIG_INPUT_AW86927=m` is for AW86927/AW86938, not AW86224). Static/prepare checks (`build-rootfs.sh --prepare-only`, `tests/static.sh` package/syntax checks) pass; full `build-rootfs.sh --build` cannot run on this host without Docker socket access or passwordless sudo.

## 2026-11-23 (third part) — ZRAM (`zram-generator`) packaged and verified on device

- **Root cause of `SwapTotal: 0`:** Booted `work/rootfs-dubai-2026.11.13-recovery.qcow2` via `fastboot boot` (`7.2.9-dubai+ #1`, `/dev/nbd0`, all six UFS LUNs `ro=1`) and confirmed `/usr/lib/systemd/zram-generator.conf.d/90-omarchy.conf` (`omarchy-settings 4.5.0-3`), `/usr/lib/systemd/zram-generator.conf.d/91-omamobile.conf` (`omamobile-omarchy 0.1.44-1`, overriding `zram-size = ram / 2`, `zstd`, `swap-priority = 100`), and `/etc/sysctl.d/99-omarchy-sysctl.conf` (`vm.swappiness=150`, `vm.vfs_cache_pressure=50`, `vm.page-cluster=0`, `vm.watermark_boost_factor=0`, `vm.watermark_scale_factor=125`) were already present, while `zram-generator` itself was absent (`not in omarchy-base.packages`).
- **Live verification:** Installed `zram-generator 1.2.1-1` from Arch Linux ARM `[extra]` and started `dev-zram0.swap`; `systemd-zram-setup@zram0.service` succeeded (`status=0/SUCCESS`), `zramctl` reported `/dev/zram0 zstd 3.6G`, `swapon --show` reported `3.6G` at priority `100`, `free -m` showed `Swap: 3683 MiB`, and `/run/systemd/generator/swap.target.wants/dev-zram0.swap` was generated for automatic activation on boot.
- **Packaging & staging:** Added `zram-generator` to `rootfs/packages.base` and `packages/omamobile-device-dubai/PKGBUILD` `depends` (`pkgrel=12`), added the dependency check in `packages/omamobile-device-dubai/test/all`, built and installed `omamobile-device-dubai 0.1.0-12` on the live phone, and verified `scripts/build-rootfs.sh --prepare-only` and all package tests/syntax checks (`shellcheck` not installed on host).

## 2026-11-23 (fourth part) — Internal `userdata` (`sde27`) persistent Arch/Omarchy rootfs live

- **Read-only UFS audit & authorization:** Inspected UFS partitions read-only (`sde26` `super` 8.3 GiB, `sde27` `userdata` 108.4 GiB, both `data` / encrypted Android; live rootfs already 9.5 GiB used). With explicit owner authorization (LineageOS expendable), implemented opt-in fail-closed `UFS_RW=userdata` and `ROOT_DEVICE=userdata` in `initramfs/init` and `scripts/build-initramfs.sh` (including Alpine `e2fsprogs`/`e2fsprogs-extra` when `UFS_RW` is set, removing `/dev/sde` whole-disk node, locking `sda`–`sdd`, `sde1`–`sde26`, and `sdf` at `ro=1`, and checking `ufs_unguarded` before `switch_root`). Added `10-dubai-storage.rules` in `omamobile-device-dubai 0.1.0-13` (`MODE="0000"`, `UDISKS_IGNORE="1"` on `/dev/sde` and non-`userdata` partitions), installed it on the recovery rootfs, powered off cleanly, flattened the recovery qcow2 to `work/rootfs-dubai-2026.11.23-internal.img` (`e2fsck -fn` clean), and documented the layout/rollback in `docs/STORAGE-PLAN.md`.
- **Provisioning & resize onto `/dev/sde27`:** Booted `out/images-userdata-rescue/boot-dubai-csot-UNTESTED.img` via `fastboot boot` (`UFS_RW=userdata`, `ROOT_DEVICE=""`), verified `/dev/sde` absent and ONLY `sde27 (userdata)` writable, cloned `work/rootfs-dubai-2026.11.23-internal.img` over read-only NBD via `e2image -rap` (`2596430/2596430` blocks at `31.02 MB/s`), ran `e2fsck -fy`, `resize2fs` to `28403451` 4K blocks (~108.35 GiB), and `e2fsck -fn` (clean).
- **First internal `userdata` boot verified:** Booted `out/images-userdata/boot-dubai-csot-UNTESTED.img` via `fastboot boot`. System switched to `/dev/sde27` at `1.926s` (`22.088s` total systemd boot, `graphical.target` `6.815s`, only `plymouth-start.service` failed), `df -h /` shows `107G` (`9.7G` used, `96G` free), `/dev/sde` remains absent, ONLY `sde27 (userdata)` is writable (all `sda`–`sdd`, `sde1`–`sde26`, `sdf` verified `ro=1`), `/dev/zram0` (`3.6G zstd`, priority `100`) activated automatically at cold boot, and all 4 remoteprocs, Wi-Fi, Bluetooth, sensors, ModemManager, and battery charging (`25%`, `3.55 V`, `+1.10 A`) came up cleanly.
