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
| USB-C | Qualcomm DWC3, USB2 HS, PMIC GLINK, FSA4480 | DWC3/NCM/RNDIS/ACM configured | **T/P gadget:** ACM and SSH work; NCM stalls under NBD traffic while ACM survives; RNDIS passed firstboot/audio and 30×512 MiB direct reads over 39 minutes without errors; OTG not tested |
| WCN6750 Wi-Fi | Node okay, ath11k AHB, Motorola_dubai calibration | ath11k=m | **T:** WPSS/ath11k active; real scan, WPA2 DHCP/DNS, Internet and HTTPS verified; board-data warning remains |
| WCN6750 Bluetooth | UART7, PMU, hci_qca | Modules configured; retrying helper 0.1.0-6 | **T/P (2026-11-22):** pairing/A2DP pass; `omamobile-dubai-bluetooth-address@hci0` powers `hci0` automatically at cold boot with stable local address |
| Audio | WCD9375, two AW88261, QDSP6, ADSP, UCM fork | UCM 0.1.0-3, `dummystreamhack`, `dubai-callaudiod`, plus two S32 patches | **T (2026-11-22):** HiFi PipeWire playback/capture verified; two-way voice call audio verified on both Earpiece (`Receiver`) and Speakerphone (`Music` stereo) via Q6Voice `VoiceMMode1` |
| Battery | `CONFIG_BATTERY_QCOM_BATTMGR=y`, PMIC GLINK | Charge/POWER_NOW/sign fixes booted | **T/P (2026-11-24):** charging current positive (`+232..+587 mA`); however on 2026-11-24 `qcom-battmgr-bat` reported `capacity=2%` (`voltage_ocv=3.460–3.688 V`) despite `vbat_sns=4.10–4.23 V` (triggering UPower `PowerOff` on unplug), and `current_now` stayed positive (`+224 -> +41.8 mA`) while `status=Discharging` |
| Charging | PMIC GLINK/USB-C and thermal in the DTS | Drivers present | **T/P:** USB online and charging reported with plausible V/I; suspend and long-term safety not tested |
| Sensors | FastRPC/CDSP and mount-matrix rule | FastRPC module | **T/P (2026-11-22):** experimental writable-registry daemon, `iio-sensor-proxy 3.9-3`, and `omamobile-autorotate-dubai` start automatically across cold NBD boots; `monitor-sensor` reports accelerometer, light (`275 lux`), and live compass (`303°–312°`); owner confirmed display rotation and touch. Lock-screen behavior, calibration, and security review remain open (`docs/SENSORS.md`). |
| Fingerprint | Pins/SPI reserved in the DTS; no demonstrated userspace support | NV | NV; no RPMB modification allowed |
| Modem | MPSS remoteproc, IPA, QRTR/QMI, Q6Voice | Modules/drivers present | **T (2026-11-22):** With read-only `debugfs` seeding of `persist:/rfs/msm/mpss` (`dhob.bin`/`shob.bin`/`datablock`) into `/var/lib/tqftpserv` (all six UFS LUNs `ro=1`), Slot 1 USIM reaches `ready`, registers on 4G LTE / 5G NR (`FASTWEB`), passes ICMP ping and HTTPS over `qmapmux0.0` (`rmnet_ipa0`), receives SMS via `omatel-agent`, and completes two-way CS voice calls on Earpiece and Speakerphone (`docs/TELEPHONY.md`) |
| Cameras | CAMSS/CCI, only `s5kjn1` (rear main) and `gc02m1b` (2 MP monochrome depth) in mainline DTS; ultrawide and front cameras absent | CAMSS module; selection fix and libcamera 0.7.2-4.24 helpers booted | **T/P (2026-11-24):** `s5kjn1` (8160×6144) and `gc02m1b` stream via PipeWire/libcamera, but owner reports image output is still B/W and two of three cameras do not work; color/ISP tuning and missing camera DT/driver nodes remain open |
| Suspend/resume | PDC/SPMI/PSCI/RPMh in kodiak DTS | `PM_SLEEP`/`PM_DEBUG`/`QCOM_PDC` built | **T/P (2026-11-24):** 10/10 RAM-only freezes (`IRQ 115` + `IRQ 116`) plus full-rootfs `/dev/sde27` freezes: `99c000.serial/power/wakeup` (`IRQ 151`, BT UART7) caused `0s` wake until set to `disabled`; with it disabled, plugged (`11s`) and unplugged (`VBUS=0uV`, `46s`, `S2` `Usage: 5 -> 8, Rejected: 0`, `cdsp` +46.26 s, `modem` +46.26 s, `current_now` `224 -> 41.8 mA`) woke cleanly on `IRQ 115`. `adsp`/`wpss`/`aosd`/`cxsd` stayed `0` with sensors/Wi-Fi active (`docs/SUSPEND.md`) |
| Thermal | TSENS/PMIC ADC, several zones; PA2 disabled | Built-in drivers | NV; thresholds and power draw not tested |
| Vibrator | AW86224 pins named (`gpio46`/`gpio47`), no complete I2C/driver node | `CONFIG_INPUT_AW86927=m` (different IC family) | **N/NV:** no I2C device or input FF device present on `dubai` |
| NFC | Pins named; no complete node verified | NV | NV |
| GNSS | Modem/QMI dependency; example service in pmaports | ModemManager + libqmi QRTR | **T/P (2026-11-22):** `mmcli --location-get` returns 3GPP cell info and live GPS NMEA sentences (`$GPGSV`, satellite PRN 28 tracked indoors at 29 dB SNR) (`docs/TELEPHONY.md`) |

## Advancement rules

- "B" requires the log and artifact of the pinned build.
- "R" requires `dmesg`, sysfs, or a tool on the real device.
- "T/P" requires a repeatable functional test and known limits.
- Missing firmware, the wrong panel, or a disabled node prevent promoting the state.
- No result from other phones or variants is transferred to this unit.
