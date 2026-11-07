<!-- SPDX-License-Identifier: MIT -->
# M1 — dubai hardware matrix

Legend: **S** = present in the sources; **B** = built; **R** = detected on the phone; **T** = tested; **P** = partially working; **N** = not working; **NV** = not verified. No column implies the next one. The 2026-11-07 hardware evidence uses the LLVM kernel `7.2.9-dubai+`; the full logs stay in the private capture.

| Subsystem | Evidence in the v7.2.9-sc7280 sources | Build | Hardware/test on the device |
|---|---|---|---|
| Kryo 670 CPU | SM7325 SoC DTS, cpufreq/CPU idle | Base config present | **R:** aarch64 kernel booted, scheduler/cpufreq present; frequencies not measured |
| Adreno 642L GPU | `&gpu okay`, MSM DRM, zap `a660_zap.mbn` | DRM_MSM=y | **T:** dubai-specific zap loaded; EGL Freedreno Adreno, OpenGL ES 3.2; Hyprland active. The generic qcm6490 blob does not work |
| CSOT display | CSOT DTS, NT37701, DSI/DPU, 48–144 Hz | DTS and panel module | **T:** Hyprland/Quickshell on DSI 1080×2400@144; DPMS off and wake via touch verified |
| Tianma display | Tianma DTS and a distinct sequence | DTS and panel module | This is not the panel on this unit; NV |
| Touch | Goodix GT9916 on SPI13, Berlin core/SPI | Modules configured | **T:** Goodix detected by Hyprland; coordinates, pressure, release, and multitouch slots verified with `evtest` |
| UFS storage | Host/PHY okay, supplies and reset | Built-in driver | **R/T guard:** six Micron LUNs detected; `blockdev --getro` = 1 on all of them; no Android mount |
| USB-C | Qualcomm DWC3, USB2 HS, PMIC GLINK, FSA4480 | DWC3/NCM/ACM configured | **T gadget:** NCM, ACM, ping, and SSH verified; OTG/charging not tested |
| WCN6750 Wi-Fi | Node okay, ath11k AHB, Motorola_dubai calibration | ath11k=m | NV; firmware and network not tested |
| WCN6750 Bluetooth | UART7, PMU, hci_qca | Modules configured | NV; pairing/A2DP not tested |
| Audio | WCD9375, two AW88261, QDSP6, ADSP, UCM fork | Drivers/modules configured | NV; no sound test or protection check |
| Battery | `CONFIG_BATTERY_QCOM_BATTMGR=y`, PMIC GLINK | Configured | NV; UPower and accuracy not tested |
| Charging | PMIC GLINK/USB-C and thermal in the DTS | Drivers present | NV; limits and safety not tested |
| Sensors | FastRPC/CDSP and mount-matrix rule | FastRPC module | NV; libssc/hexagonrpcd and sensors not tested |
| Fingerprint | Pins/SPI reserved in the DTS; no demonstrated userspace support | NV | NV; no RPMB modification allowed |
| Modem | MPSS remoteproc, IPA, QRTR/QMI, Q6Voice | Modules/drivers present | NV; SIM/data/SMS/calls/IMS not tested |
| Cameras | CAMSS/CCI, S5KJN1 and GC02M1B in the DTS | CAMSS module | NV; other sensors and libcamera not verified |
| Suspend/resume | Partial wakeup nodes and pinctrl | Generic support | NV; s2idle not enabled by default |
| Thermal | TSENS/PMIC ADC, several zones; PA2 disabled | Built-in drivers | NV; thresholds and power draw not tested |
| Vibrator | AW86224 pins named, no complete driver node | NV | NV |
| NFC | Pins named; no complete node verified | NV | NV |
| GNSS | Modem/QMI dependency; example service in pmaports | Userspace not integrated | NV |

## Advancement rules

- "B" requires the log and artifact of the pinned build.
- "R" requires `dmesg`, sysfs, or a tool on the real device.
- "T/P" requires a repeatable functional test and known limits.
- Missing firmware, the wrong panel, or a disabled node prevent promoting the state.
- No result from other phones or variants is transferred to this unit.
