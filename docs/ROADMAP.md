<!-- SPDX-License-Identifier: MIT -->
# Executable roadmap

| Milestone | Deliverable and gate | State on 2026-11-08 |
|---|---|---|
| M0 Audit | Sources pinned, dependencies and boot/storage documented | Completed; sources and recovery documented |
| M1 Hardware matrix | Driver/DT state separated from detection and tests | Active matrix; source, detection, partial and tested states kept separate |
| M2 Kernel | Kernel 7.2.9-sc7280, config, modules, two DTBs, SHA-256, and log | **Completed offline and booted**; GCC/LLVM builds and dtbs_check pass |
| M3 Initramfs | RAM-only, read-only guard, NCM/RNDIS/ACM, Dropbear, logs | **Completed on CSOT hardware**; shell, SSH and UFS read-only guard verified; RNDIS selected for NBD after NCM stalls |
| M4 Arch rootfs | ALARM/QEMU builder, binary packages, kernel/modules | **Completed through RNDIS/NBD**; current packages, clean firstboot, systemd, pacman and SSH verified; `userdata` unused |
| M5 Display/GPU/touch | Stable KMS, Freedreno, libinput | **Substantially verified**; 1080×2400 modes, Freedreno GLES 3.2, Hyprland and Goodix multitouch pass |
| M6 Connectivity | ath11k/WCN6750, BlueZ, USB roles | **Wi-Fi, RNDIS gadget, Bluetooth pairing and A2DP pass**; automatic Bluetooth setup needs a boot test, NCM stalls under NBD load and USB host is open |
| M7 Audio | QDSP6, dubai UCM, PipeWire, safe low-volume tests | **Completed on CSOT hardware**; S32 backend and Q6 mapping verified by an audible 10-second ALSA tone, PipeWire playback and mic capture also pass with libcamera nodes active |
| M8 Power | Battery/charging, runtime PM, progressive s2idle and resume | **Partial**; real battery/charger telemetry works, but unreadable charge-full and implausible firmware power break UPower energy fields; suspend not tested |
| M9 Modem | remoteproc/QRTR/QMI, data, SMS, calls, IMS kept separate | Not qualified; no Pixel stack, no SIM/data/SMS/call test |
| M10 Omarchy | Device package and the real shell, portrait/landscape, 6 GiB performance | Real Hyprland/Quickshell shell starts and touch works; complete UX/performance qualification open |
| M11 Secondary | Sensors, haptics, fingerprint, GNSS, cameras, NFC | Five PipeWire/libcamera RGBA frames captured from each sensor through GStreamer; image quality, metadata and calibration open |

## Release milestones

- **Alpha 0:** first kernel and initramfs actually booted, logs and recovery verified. **Reached.**
- **Alpha 1:** Arch/systemd/pacman, storage, and network/SSH on the device. **Reached through NBD**, without installing on internal storage.
- **Alpha 2:** accelerated Hyprland, touch, Wi-Fi, audio, battery, and the Omarchy shell. **Reached on the owner's CSOT device through RNDIS/NBD**, including audible S32 speaker playback and clean firstboot.
- **Beta:** reliable power/charging, modem data, stability, and updates; telephony evaluated separately. Not reached.

## Next actions, in order

1. Keep RNDIS for NBD qualification; 30 direct-I/O reads of 512 MiB over 39 minutes passed without NBD/I/O errors, while NCM previously stalled under rootfs traffic.
2. Preserve the verified S32/Q6 speaker patches and test normal PipeWire playback at conservative volume after future rebuilds.
3. Test `0003-s5kjn1-selection.patch` at the next authorized boot, then add verified camera metadata/calibration; PipeWire streaming passes but image quality and the square active-area fallback remain open on the running kernel.
4. Verify the packaged Bluetooth address helper at the next authorized boot; pairing and A2DP already pass, while modem, suspend and persistent installation remain later gates.
5. Keep proprietary firmware and private captures outside Git and preserve the verified boot/dtbo rollback.
