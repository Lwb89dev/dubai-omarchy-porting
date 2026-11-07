<!-- SPDX-License-Identifier: MIT -->
# M0 — Technical audit of the Motorola Edge 30 (dubai)

Date: 2026-11-06. Method: source reading and offline builds; no device was connected, queried, or modified.

## 1. Pinned sources

The full revisions are in [`sources.lock`](../sources.lock).

| Source | Revision | Use |
|---|---|---|
| [Omarchy Mobile](https://github.com/derekross/omarchy-mobile) | `cd90d193ac5b4056f877a96f6ec748d0998021c4` | shell, packages, Arch/QEMU builder, multi-device reference |
| [pmaports](https://gitlab.postmarketos.org/postmarketOS/pmaports) | `b14105484a206e3b84f26b6f950df436dbb0d414` | dubai package, kernel config, firmware map, and boot metadata |
| [sc7280-mainline/linux](https://github.com/sc7280-mainline/linux) | tag `v7.2.9-sc7280`, commit `0ccea71930dbc8e32344a41be96944db4215c3c3` | chosen kernel |
| [LineageOS device dubai](https://github.com/LineageOS/android_device_motorola_dubai) | `03ff95e4b5f0ee44e6408f308fb9f8b17d051620`, `lineage-24.0` | reference hardware and AVB |
| [LineageOS sm7325-common](https://github.com/LineageOS/android_device_motorola_sm7325-common) | `d0dc473dcf587183614483b1ac807e24d76e109f` | boot and partition layout |
| [LineageOS kernel sm7325](https://github.com/LineageOS/android_kernel_motorola_sm7325) | `4a129b915ff9feb9f42cfaf141724d814131f068` | downstream 5.4 reference only |
| [ALSA UCM sc7280](https://github.com/sc7280-mainline/alsa-ucm-conf) | `3dbb936f0cc85a5d3f12bab12a4578d85768061c` | audio profiles to package and evaluate |
| [dubai firmware used by pmaports](https://github.com/FairBlobs/dubai-firmware) | `56c15ff4e81e6464983397bc93be3ae5f7cfcec4` | name map; blobs neither downloaded nor distributed |

External references: [LineageOS page](https://lineageos.github.io/lineage_wiki/devices/dubai/), [Nura package](https://pkgs.nura.eco/package/main/postmarketos/aarch64/device-motorola-dubai), [documented hands-on experience](https://gist.github.com/mbohun/10dab097eb0cbf9b11f175a8fc622b81).

## 2. Identity and variants

LineageOS 24.0 declares only the **XT2203-1** model, SoC SM7325-AE, 6/8 GiB LPDDR5, UFS 3.1, and Adreno 642L. The real device has not been identified: model, RAM, LineageOS build, bootloader, and slot state remain to be captured read-only.

pmaports 2-r0 offers `device-motorola-dubai-kernel-csot` and `...-tianma`. Both descriptions say to read the `Panel` string on the fastboot screen after unlock. The gist reports a CSOT unit, but that does not prove the user's variant.

The files are:

- `arch/arm64/boot/dts/qcom/sm7325-motorola-dubai-csot.dts`
- `arch/arm64/boot/dts/qcom/sm7325-motorola-dubai-tianma.dts`
- `arch/arm64/boot/dts/qcom/sm7325-motorola-dubai-common.dtsi`

The final DTS files select `csot,nt37701-dubai` and `tianma,nt37701-dubai` respectively. `drivers/gpu/drm/panel/panel-novatek-nt37701.c` binds these compatibles to `nt37701_csot_panel_on` and `nt37701_tianma_panel_on`, with distinct sequences. Both expose 48/60/90/120/144 Hz modes; the first KMS path will use 60 Hz after the path is verified, without forcing 144 Hz.

## 3. Kernel and mainline state

`device/community/linux-postmarketos-qcom-sc7280/APKBUILD` pins `pkgver=7.2.9`, `pkgrel=3`, `_tag=v7.2.9-sc7280`, and source `sc7280-mainline/linux`. It builds with `LLVM=1`; the project uses the full configuration published there, not the Pixel defconfig.

The tag is a merge of Linux stable v7.2.9 into the `sc7280-7.2.y` line. Dubai support in the tag includes the DTS, panel driver, Goodix Berlin SPI touch, MSM DRM/DPU/DSI, kernel-level Freedreno, UFS, USB, WCN6750, remoteproc, QDSP6, and codecs/amplifiers. That is not a hardware verification.

The project does not import patches from the Motorola 5.4 kernel. Early builds use the already integrated sc7280 tree; every future change will be kept as a separate logical commit.

A point comparison with Torvalds shows that the dubai DTS files are not present in `v7.2`. They are present in `v7.3-rc6`: the base board DTS landed in [12975c0f09c58ccf305b1383131790ea3cf6cedb](https://github.com/torvalds/linux/commit/12975c0f09c58ccf305b1383131790ea3cf6cedb), which declares simplefb, touch, keys, UFS, battery, USB, and WCN6750. The NT37701 driver is not present in `v7.3-rc6`; in the upstream DTS the panel is not enabled yet. Audio and cameras in the chosen SC7280 tree are also a delta against that upstream DTS. The 7.2.9-sc7280 build is therefore mainline/stable **plus backports and out-of-tree patches**, not pure mainline; moving to a newer base needs a separate evaluation.

## 4. Boot and partitions: evidence and discrepancies

pmaports `deviceinfo` specifies boot image header **v2**, page 4096, DTB appended to the boot image, kernel offset `0x8000`, ramdisk `0x01000000`, DTB `0x01f00000`, and an `earlycon` cmdline to avoid an immediate reboot with ABL. The selected DTBs are `qcom/sm7325-motorola-dubai-{csot,tianma}`.

Current LineageOS instead declares header **v3**, `BOARD_INCLUDE_DTB_IN_BOOTIMG`, A/B boot/vendor_boot/dtbo, recovery-as-boot, 96 MiB boot and vendor_boot partitions, 24 MiB dtbo, and `super` of 8,925,478,912 bytes. This difference prevents declaring a single "safe" format without identifying the build and bootloader; the first artifact keeps the v2 format of the existing Linux port and is marked untested.

`fastboot boot` is not documented as tested by the sources that were read. Its support must be checked with an authorized test; do not fall back to a flash automatically.

The gist describes changes to `vbmeta`, `dtbo`, the active slot, and a rootfs on `userdata`, including a fastbootd workaround. Those are historical persistent-install operations, not a procedure suitable for the first boot, and they are not performed.

## 5. Omarchy Mobile: what to reuse

| Component | Decision for dubai |
|---|---|
| `omamobile-shell`, `omamobile-apps`, `omamobile-firstboot`, `omamobile-omarchy`, `omamobile-mirror` | Reuse; they do not depend on Tensor drivers |
| Builder `tools/build-packages`, `tools/build-rootfs`, ALARM/QEMU container | Reuse through local staging; do not modify the upstream checkout |
| `device/<codename>` descriptors and the `omamobile-device-dubai` convention | Reuse the model; the first descriptor is `ram-only` |
| Shared upstream initramfs | Reuse only the Alpine/gadget scheme; do not use its `switch_root`, `userdata` allowlist, or automatic panic |
| `omamobile-device-cheetah`, sensors/AoC, `omamobile-audio`, `omamobile-modem`, `omamobile-modem-sit`, `omamobile-mmd` | Do not install: they contain Pixel policy, DSP, the Samsung modem, or Pixel calibrations |
| Upstream custom Mesa | Do not use: it builds Panfrost/PanVK Mali, not Freedreno |
| Upstream custom Hyprland | Evaluate only after tests; Arch ARM already provides AArch64 Hyprland. Do not import the Pixel DPMS patch without a need |
| Pixel installer and flash/push commands | Forbidden on dubai |

## 6. pmaports dependencies → Arch Linux ARM

| Nura dependency | Assessment |
|---|---|
| `alsa-ucm-conf-qcom-sc7280` | At the pinned commit it contains `Motorola/dubai/{dubai,HiFi,VoiceCall}.conf` and the link `conf.d/sm7325/Motorola-dubai.conf`; BSD-3-Clause. VoiceCall uses `dummystreamhack`, so telephony/call audio stays blocked until that component is packaged and tested |
| `firmware-motorola-dubai` | Required for the paths in the DTS; proprietary license and redistribution rights not verified. Prefer local extraction from the owner's firmware |
| `firmware-qcom-adreno-a660` | The name does not change the GPU: the DTS requires `a660_zap.mbn` for SM7325/Adreno 642L; verify the exact blob |
| `hexagonrpcd` | FastRPC userspace for DSP/sensors; not present as a verified ALARM package, needs packaging and a systemd service |
| `linux-firmware-ath11k`, `linux-firmware-qca` | In the ALARM 20261019-1 databases the WCN6750/ath11k firmware is in `linux-firmware-atheros`, not in splits named as Nura does. The rootfs uses `linux-firmware-qcom` + `linux-firmware-atheros` and still needs the specific `board-2.bin` |
| `soc-qcom` | Metapackage: split out `tqftpserv`, boot MAC, clock offset, UPower/WirePlumber; do not copy OpenRC scripts |
| `soc-qcom-modem` | Metapackage with `msm-modem`, `q6voiced`, `81voltd`; each component needs separate packaging and tests |
| `soc-qcom-qbootctl` | Not required for the RAM boot. Slot marking can write metadata: do not enable it in the first port |
| `make-dynpart-mappings` | Utility for Android logical partitions; not required for RAM diagnostics and does not authorize changes to `super` |
| `systemd-boot`, `unl0kr-fbforcerefresh`, `postmarketos-base` | Integration of the source distribution, not hardware dependencies to translate literally |

Arch Linux ARM provides Mesa 26.2.6 with `vulkan-freedreno`, PipeWire, ModemManager 1.24.2, UPower, and `alsa-ucm-conf`. ALARM Hyprland 0.57.1-1 showed an unresolvable library dependency during the build; the builder therefore uses the signed Hyprland 0.57.1-2 and aquamarine 0.16.0-1.1 binaries from Omarchy edge, with pinned SHA-256. `hexagonrpcd`, `tqftpserv`, `qrtr`, and `qbootctl` do not appear at the normal ALARM package URLs that were checked; that does not prove they cannot be packaged.

## 7. Rootfs and firmware

The Omarchy builder imports the Arch Linux ARM AArch64 tarball, checks the MD5 and signature with a pinned key, builds in Docker linux/arm64 through QEMU, and uses pacman. The Pop!_OS host has Docker, QEMU binfmt with the `F` flag, and a cross toolchain; the environment is therefore suitable.

The final rootfs will use ALARM packages for the base/systemd, NetworkManager, OpenSSH, Mesa/Freedreno, Wayland, PipeWire, and UPower. The device package will contain only policy and configuration. No FairBlobs blob or phone data will be included in Git, CI, or public releases until the license and provenance are verified.

## 8. M0 outcome

- Repository and revisions identified; display variants and boot formats documented.
- Reusable components and Arch dependencies mapped.
- No operation on the device.
- The panel variant and `fastboot boot` support remain the first hardware gates.
