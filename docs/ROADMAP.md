<!-- SPDX-License-Identifier: MIT -->
# Executable roadmap

| Milestone | Deliverable and gate | State on 2026-11-06 |
|---|---|---|
| M0 Audit | Sources pinned, dependencies and boot/storage documented | Completed offline; no device test |
| M1 Hardware matrix | Driver/DT state separated from detection and tests | Source matrix; hardware not verified |
| M2 Kernel | Kernel 7.2.9-sc7280, config, modules, two DTBs, SHA-256, and log | **Completed offline**; dtbs_check pass, not booted |
| M3 Initramfs | RAM-only, read-only guard, NCM/ACM, Dropbear, logs | **Build and QEMU pass**, reproducible; Alpha 0 requires an authorized boot |
| M4 Arch rootfs | ALARM/QEMU builder, binary packages, kernel/modules | Preparation; no `userdata` |
| M5 Display/GPU/touch | Stable 60 Hz KMS, Freedreno, libinput | Source evidence only |
| M6 Connectivity | ath11k/WCN6750, BlueZ, USB roles | Firmware and tests still to do |
| M7 Audio | QDSP6, dubai UCM, PipeWire, safe low-volume tests | UCM packaging and services still to do |
| M8 Power | Battery/charging, runtime PM, progressive s2idle and resume | Not tested; suspend is not the default |
| M9 Modem | remoteproc/QRTR/QMI, data, SMS, calls, IMS kept separate | No Pixel stack; Qualcomm services still to package |
| M10 Omarchy | Device package and the real shell, portrait/landscape, 6 GiB performance | After M5/M6 |
| M11 Secondary | Sensors, haptics, fingerprint, GNSS, cameras, NFC | Does not block the first release |

## Release milestones

- **Alpha 0:** first kernel and initramfs actually booted, logs and recovery verified. Not reached.
- **Alpha 1:** Arch/systemd/pacman, storage, and network/SSH on the device. Not reached.
- **Alpha 2:** accelerated Hyprland, touch, Wi-Fi, audio, battery, and the Omarchy shell. Not reached.
- **Beta:** reliable power/charging, modem data, stability, and updates; telephony evaluated separately. Not reached.

## Next actions, in order

1. Phone identity and panel, with a read-only capture.
2. Finish the kernel/initramfs build and static validation.
3. Request approval for a single temporary boot if every gate passes.
4. Only after the logs: fix one subsystem at a time and prepare an Arch rootfs that matches the same kernel.
5. Integrate Freedreno and Omarchy without importing Pixel policy.
