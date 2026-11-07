<!-- SPDX-License-Identifier: MIT -->
# Executable roadmap

| Milestone | Deliverable and gate | State on 2026-11-07 |
|---|---|---|
| M0 Audit | Sources pinned, dependencies and boot/storage documented | Completed; sources and recovery documented |
| M1 Hardware matrix | Driver/DT state separated from detection and tests | Active matrix; source, detection, partial and tested states kept separate |
| M2 Kernel | Kernel 7.2.9-sc7280, config, modules, two DTBs, SHA-256, and log | **Completed offline and booted**; GCC/LLVM builds and dtbs_check pass |
| M3 Initramfs | RAM-only, read-only guard, NCM/ACM, Dropbear, logs | **Completed on CSOT hardware**; shell, SSH and UFS read-only guard verified |
| M4 Arch rootfs | ALARM/QEMU builder, binary packages, kernel/modules | **Completed through NBD**; clean firstboot, systemd, pacman and SSH verified; `userdata` unused |
| M5 Display/GPU/touch | Stable KMS, Freedreno, libinput | **Substantially verified**; 1080×2400 modes, Freedreno GLES 3.2, Hyprland and Goodix multitouch pass |
| M6 Connectivity | ath11k/WCN6750, BlueZ, USB roles | **Wi-Fi and USB gadget pass**; Bluetooth detected, pairing/A2DP and USB host still open |
| M7 Audio | QDSP6, dubai UCM, PipeWire, safe low-volume tests | **Software path passes**; UCM HiFi, PipeWire playback and mic capture verified with video enumeration disabled; audibility/clean rebuild pending |
| M8 Power | Battery/charging, runtime PM, progressive s2idle and resume | **Partial**; real battery/charger telemetry works with incorrect UPower energy fields; suspend not tested |
| M9 Modem | remoteproc/QRTR/QMI, data, SMS, calls, IMS kept separate | Not qualified; no Pixel stack, no SIM/data/SMS/call test |
| M10 Omarchy | Device package and the real shell, portrait/landscape, 6 GiB performance | Real Hyprland/Quickshell shell starts and touch works; complete UX/performance qualification open |
| M11 Secondary | Sensors, haptics, fingerprint, GNSS, cameras, NFC | Cameras partially detected but disabled in WirePlumber because enumeration blocks audio; capture/calibration open |

## Release milestones

- **Alpha 0:** first kernel and initramfs actually booted, logs and recovery verified. **Reached.**
- **Alpha 1:** Arch/systemd/pacman, storage, and network/SSH on the device. **Reached through NBD**, without installing on internal storage.
- **Alpha 2:** accelerated Hyprland, touch, Wi-Fi, audio, battery, and the Omarchy shell. **Nearly reached:** all software paths have been exercised; speaker audibility and a clean boot with the final packages remain open.
- **Beta:** reliable power/charging, modem data, stability, and updates; telephony evaluated separately. Not reached.

## Next actions, in order

1. Rebuild the rootfs with `omamobile-device-dubai` 0.1.0-3 and `omamobile-ucm-dubai` 0.1.0-2, then verify a clean NBD boot without manual package installation.
2. Confirm audible speaker playback and keep microphone gain conservative; current PipeWire tests use 10% playback and 20% capture.
3. Diagnose the queued WirePlumber video-node event before re-enabling camera enumeration; do not trade camera detection for a blocked audio graph.
4. Test Bluetooth pairing and audio separately; leave modem, suspend, and persistent installation as later gates.
5. Keep proprietary firmware and private captures outside Git and preserve the verified boot/dtbo rollback.
