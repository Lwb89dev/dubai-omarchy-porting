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
| Battery | `CONFIG_BATTERY_QCOM_BATTMGR=y`, PMIC GLINK | `0004`+`0005` (`0006` removed) | **T/P (2026-11-25):** Verified on CI kernel `7b48084` (`0006` removed): under PC USB `SDP` (`limit=100000`), `charge_now` net-discharged `114492 -> 114083` uAh while `current_now` read negative (`-281681 -> -264896` uA) and `upower -d` reported `state: discharging`, `0.693 W`, `warning-level: none` (`90-dubai-battery.conf`, `0.1.0-15`). Off-mode/fastboot charging QBG `capacity=2%` desync remains documented |
| Charging | PMIC GLINK/USB-C and thermal in the DTS | Drivers present | **T/P:** USB online and charging reported with plausible V/I; suspend and long-term safety not tested |
| Sensors | FastRPC/CDSP and mount-matrix rule | FastRPC module; `0.1.0-17` `81-libssc` Z=+1 | **T/P (2026-11-26):** writable-registry daemon, `iio-sensor-proxy 3.9-3`, and `omamobile-autorotate-dubai` active across cold boots; `omamobile-device-dubai 0.1.0-17` fixes Z-axis (`-1, 0, 0; 0, -1, 0; 0, 0, 1`) so `monitor-sensor` reports `tilt: face-up` (`330.85 lux`, `303°` compass). Physical rotation re-check, calibration, and lock-screen behavior remain open (`docs/SENSORS.md`) |
| Fingerprint | Pins/SPI reserved in the DTS; no demonstrated userspace support | NV | NV; no RPMB modification allowed |
| Modem | MPSS remoteproc, IPA, QRTR/QMI, Q6Voice | Modules/drivers present | **T (2026-11-22):** With read-only `debugfs` seeding of `persist:/rfs/msm/mpss` (`dhob.bin`/`shob.bin`/`datablock`) into `/var/lib/tqftpserv` (all six UFS LUNs `ro=1`), Slot 1 USIM reaches `ready`, registers on 4G LTE / 5G NR (`FASTWEB`), passes ICMP ping and HTTPS over `qmapmux0.0` (`rmnet_ipa0`), receives SMS via `omatel-agent`, and completes two-way CS voice calls on Earpiece and Speakerphone (`docs/TELEPHONY.md`) |
| Cameras | CAMSS/CCI, only `s5kjn1` (rear main RGB + `ak7375` VCM) and `gc02m1b` (2 MP monochrome depth) in mainline DTS; no `ov50a`/`ov32b40` drivers in `sources/linux-sc7280` | CAMSS + `libcamera 0.7.2-4.26` (contrast AF, EV/manual, EGL cleanup, `s5kjn1.yaml`) + `omacam-lenses.toml` (`0.1.0-19`) | **T/P (2026-11-26):** `s5kjn1` verified by owner in `omacam` with color + `ak7375` autofocus (`1920x1440` `30.0 fps` Adreno eGL preview `42.2 MiB` CMA, `4080x3072` JPEG still `6.9 MiB` / `96.0 MiB` CMA). `gc02m1b` detected (`unused`); `ov50a` ultrawide and `ov32b40` front remain unported |
| Suspend/resume | PDC/SPMI/PSCI/RPMh in kodiak DTS | `PM_SLEEP`/`PM_DEBUG`/`QCOM_PDC` built; `0.1.0-14` udev fix | **T/P (2026-11-24):** `75-dubai-bluetooth.rules` (`99c000.serial/power/wakeup=disabled`, `0.1.0-14`) verified at cold boot with pre/post-wake `bluetoothctl scan on`. Isolated unplugged `VBUS=0uV` freezes (`31 s` and `16 s` with `a600000.usb=auto` + `rmmod ath11k_ahb`) passed on `IRQ 115`, `S2` 100%, `cdsp`/`modem`/`wpss` sleeping, standby `current_now` `34.5 mA` (`4.293 V`). `adsp`/`aosd`/`cxsd` stay `0` (`docs/SUSPEND.md`) |
| Thermal | TSENS/PMIC ADC, several zones; PA2 disabled | Built-in drivers | NV; thresholds and power draw not tested |
| Vibrator | `0008` (`aw86927.c` AW86224) + `0009` (`vibrator@58` `&i2c4` `gpio46`/`47`) | `CONFIG_INPUT_AW86927=m` (`8954580` CI) | **T (2026-11-26):** Clean CI `8954580` DTB flashed to `boot_b` and cold-booted; `aw86927-haptics` probed on `4-0058` (`input4`, `ff=107030000 0`); `FF_RUMBLE` vibration physically confirmed by owner (`GLBRD5=0x07`, clean standby `0x00`) |
| NFC | Pins named; no complete node verified | NV | NV |
| GNSS | Modem/QMI dependency; example service in pmaports | ModemManager + libqmi QRTR | **T/P (2026-11-22):** `mmcli --location-get` returns 3GPP cell info and live GPS NMEA sentences (`$GPGSV`, satellite PRN 28 tracked indoors at 29 dB SNR) (`docs/TELEPHONY.md`) |

## Advancement rules

- "B" requires the log and artifact of the pinned build.
- "R" requires `dmesg`, sysfs, or a tool on the real device.
- "T/P" requires a repeatable functional test and known limits.
- Missing firmware, the wrong panel, or a disabled node prevent promoting the state.
- No result from other phones or variants is transferred to this unit.
