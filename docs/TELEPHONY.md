<!-- SPDX-License-Identifier: MIT -->
# Dubai telephony, GNSS and VoLTE state (M9/M11 research)

2026-11-22: **Full M9 physical SIM verification passed on hardware** (SIM
recognition, 4G LTE / 5G NR registration, 4G LTE data over `qmapmux0.0` /
`rmnet_ipa0` with ICMP ping and HTTPS, incoming SMS storage via
`omatel-agent`, incoming/outgoing CS voice calls with two-way audio on both
Earpiece and Speakerphone via `dummystreamhack` + `dubai-callaudiod` +
`omamobile-ucm-dubai 0.1.0-3`, and live 3GPP + GPS NMEA location via
ModemManager).

### 2026-11-22 live SIM & call-audio findings

1. **Motorola DHOB / RFS requirement in `tqftpserv`:** Motorola's MPSS
   firmware (`M7325_HI433_*`) requests `dhob.bin`, `shob.bin`,
   `datablock/{id_00,id_01,slid_00}`, `cal_rfs/*`, and `mot_rfs/imei_sv`
   over TFTP (`tqftpserv`). Without them, the modem writes
   `FATAL: blank dhob in trusted mode` to `/var/lib/tqftpserv/dhob_report.txt`,
   enters `Mode: 'shutting-down'`, and leaves the USIM application stuck at
   `Application state: 'detected'` (`UimUninitialized`). Extracting
   `persist:/rfs/msm/mpss` **strictly read-only** via `debugfs` into
   `/var/lib/tqftpserv` on the private NBD rootfs (without mounting or
   writing to `persist`; all six UFS LUNs remained `ro=1`) allowed DHOB
   authentication to pass (`DHOB created at the factory`) and transitioned
   Slot 1 USIM immediately to `Application state: 'ready'` and
   `Personalization state: 'ready'`.
2. **DMS online transition:** `dubai-uim-selection` now sets
   `--dms-set-operating-mode=online` after selecting the primary-gw USIM
   provisioning session on `qrtr://0`.
3. **4G LTE / 5G NR registration & mobile data:** Registered on the home
   network (`FASTWEB`, `MCC 222`, CS+PS attached, LTE `eutran-20` 10 MHz,
   RSSI `-79 dBm`, 5G NR SNR `8.5 dB`, ModemManager `state: registered`,
   `signal quality: 55–59%`). Connected bearer `/Bearer/1` on `qmapmux0.0`
   (`rmnet_ipa0` QMAP mux, MTU 1430); ICMP ping and `curl -I https://1.1.1.1`
   (`HTTP/2 301`) both succeeded over cellular data.
4. **SMS & Voice calls (Earpiece + Speakerphone):**
   - `omatel-agent` automatically received and stored incoming SMS messages.
   - Packaged `dummystreamhack` (`0.r20261020.6faaa6b-1`, MIT) to hold the
     hostless `VoiceMMode1` (`hw:0,5`) Q6Voice playback/capture streams open
     during calls.
   - Extended `omamobile-ucm-dubai` (`0.1.0-3`) `VoiceCall.conf` with
     `SectionDevice."Speaker"` (`ConflictingDevice` with `Earpiece`).
   - Added `dubai-callaudiod` in `omamobile-device-dubai` (`0.1.0-11`),
     implementing `org.mobian_project.CallAudio` across PipeWire 1.2+ UCM
     split profiles (`Voice Call (Earpiece, Mic3)` ↔ `Voice Call (Mic3, Speaker)`
     ↔ `HiFi`). Owner verified clear two-way call audio on both Earpiece
     and Speakerphone (Vivavoce).
5. **GNSS (`mmcli --location-get`):** Returned both 3GPP cell location and
   live GPS NMEA sentences (`$GPGSV`, satellite PRN 28 tracked indoors at
   29 dB SNR).

Consolidates the 2026-11-11 modem bring-up state with the offline GNSS and
VoLTE/IMS feasibility research. The limited status recheck below was made on
the subsequent NBD boot; it did not exercise registration, data or calls.

On 2026-11-12 after the NBD boot, ModemManager, rmtfs and tqftpserv were
active, remoteproc0 was running, and ModemManager listed one Qualcomm modem.
`rmnet_ipa0` was present but down; QMI UIM reported `no-atr-received` for both
slots and ModemManager reported a failed state. This does not prove whether a
SIM is physically inserted or why it did not answer.

## Verified modem state (2026-11-11)

- MPSS boots `modem.mbn` from the FairBlobs pin; `qcom_smd_qrtr` binds the
  IPCRTR glink channel; AF_QIPCRTR works; the telephony service table is on
  **qrtr://0** (`qrtr://1` is a decoy endpoint).
- DMS returns the real IMEI/ESN from NV; rmtfs serves modemst1/2 writable
  (`-P -s`), tqftpserv serves `modem_pr`; the watchdog reset loop was the
  read-only EFS and is gone with the packaged drop-in.
- `yupik_ipa_fws.mbn` must exist before `1e40000.ipa` probes at boot;
  `provision-nbd-rootfs.sh` (DUBAI_MODEM_DIR) now guarantees it. The IPA
  rebind workaround is documented in PROGRESS for older images.
- ModemManager creates the `qcom-soc` modem with qrtr0 + rmnet_ipa0 and
  stops at the unlock check with `GW primary session index unknown` —
  the expected no-SIM state. UIM reports `no-atr-received` on both slots.
- Open, in order: insert a physical SIM, then registration, data over
  `rmnet_ipa0`, SMS, calls. The packaged uim-selection oneshot already
  targets qrtr://0.

## GNSS

The location stack on SM7325 is the modem's **QMI LOC service**; libqmi
(already installed, 1.38.0, with QRTR support) speaks it directly:

```sh
qmicli -d qrtr://0 --loc-start
qmicli -d qrtr://0 --loc-get-position
```

Notes and caveats:

- LOC is a modem service, so it shares the M9 gate: the SIM hypothesis is
  untested, and the PROCESS observation "LOC resets its QRTR endpoint like
  DPM did" suggests the service refuses sessions while the modem sits in
  the no-provisioning-session state. Re-test immediately after the SIM
  session exists, before assuming a deeper problem.
- The dubai firmware package does not ship a separate GNSS firmware blob;
  the XTRA/data assistance files Android keeps in `/data/vendor/location`
  are optional for a first fix and can be sourced later.
- UI plumbing is future work once raw fixes work: geoclue needs an NMEA
  source; either a small QMI-LOC→NMEA bridge or gpsd's socket driver. No
  pmOS component does this today, so there is nothing to port — design it
  only after `qmicli --loc-get-position` returns real coordinates.

## VoLTE / IMS feasibility

Realistic assessment: **hard, and not required for Beta.**

- VoLTE call signaling runs on the modem, but activation needs the **IMSS
  QMI service** (service id 0xEA), which libqmi/ModemManager do not
  implement; Android's proprietary ims daemons drive it. The related IMSA
  service (0xF3) is partially covered by libqmi, but IMSA alone cannot
  provision IMS.
- A successful IMS registration also requires the carrier profile in the
  modem EFS (MBN/OMH selection for the actual operator) and the IMS APN
  context; both are carrier- and SIM-dependent and were never exercised
  on this hardware.
- CS fallback (plain voice calls over NAS) needs a network that still
  offers 2G/3G circuit-switched service — decreasingly true, and untested.
- postmarketOS does not ship working VoLTE for this class of device; there
  is no Nura/pmOS component to port. Documented here so the milestone
  stays honest: data + SMS + CS calls where available is the Beta
  telephony bar; VoLTE/VoWiFi are a later investigation that would start
  from a qmicli IMSS exploration session with a SIM inserted.

## What to do when the SIM arrives

1. `qmicli -d qrtr://0 --uim-get-card-status` — expect ATR and app list.
2. MM unlock check → registration; `mmcli -m 0 --3gpp-register-in-operator`
   if auto-register stalls.
3. Data: `--wds-start-network` / MM bearer on rmnet_ipa0; ping.
4. SMS: `--wms-list-messages`; send/receive round trip.
5. Calls: NAS voice; check audio path vs the M7 UCM profile (voice-call
   UCM verb is intentionally untested in omamobile-ucm-dubai).
6. LOC: the two commands above; record TTFF.
