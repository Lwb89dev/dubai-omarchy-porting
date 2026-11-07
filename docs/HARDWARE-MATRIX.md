<!-- SPDX-License-Identifier: MIT -->
# M1 — Matrice hardware dubai

Legenda: **S** = presente nei sorgenti; **B** = compilato; **R** = rilevato sul telefono; **T** = testato; **P** = parzialmente funzionante; **N** = non funzionante; **NV** = non verificato. Nessuna colonna implica quella successiva. Le evidenze hardware 2026-11-07 usano il kernel LLVM `7.2.9-dubai+`; i log completi restano nella cattura privata.

| Sottosistema | Evidenza nei sorgenti v7.2.9-sc7280 | Compilazione | Hardware/test sul dispositivo |
|---|---|---|---|
| CPU Kryo 670 | SM7325 SoC DTS, cpufreq/CPU idle | Config base presente | **R:** kernel aarch64 avviato, scheduler/cpufreq presenti; frequenze non misurate |
| GPU Adreno 642L | `&gpu okay`, MSM DRM, zap `a660_zap.mbn` | DRM_MSM=y | **T:** zap dubai-specifico caricato; EGL Freedreno Adreno, OpenGL ES 3.2; Hyprland attivo. Il blob qcm6490 generico non funziona |
| Display CSOT | DTS CSOT, NT37701, DSI/DPU, 48–144 Hz | DTS e modulo pannello | **T:** Hyprland/Quickshell su DSI 1080×2400@144; DPMS off e riaccensione tramite touch verificati |
| Display Tianma | DTS Tianma e sequenza distinta | DTS e modulo pannello | Non è il pannello di questo esemplare; NV |
| Touch | Goodix GT9916 su SPI13, Berlin core/SPI | Moduli configurati | **T:** Goodix rilevato da Hyprland; coordinate, pressione, rilascio e slot multitouch verificati con `evtest` |
| Storage UFS | Host/PHY okay, alimentazioni e reset | Driver built-in | **R/T guard:** sei LUN Micron rilevate; `blockdev --getro` = 1 su tutte; nessun mount Android |
| USB-C | DWC3 Qualcomm, USB2 HS, PMIC GLINK, FSA4480 | DWC3/NCM/ACM configurati | **T gadget:** NCM, ACM, ping e SSH verificati; OTG/charging non testati |
| Wi-Fi WCN6750 | Nodo okay, ath11k AHB, calibrazione Motorola_dubai | ath11k=m | NV; firmware e rete non testati |
| Bluetooth WCN6750 | UART7, PMU, hci_qca | Moduli configurati | NV; pairing/A2DP non testati |
| Audio | WCD9375, due AW88261, QDSP6, ADSP, UCM fork | Driver/moduli configurati | NV; nessun test sonoro o protezione verificata |
| Batteria | `CONFIG_BATTERY_QCOM_BATTMGR=y`, PMIC GLINK | Configurato | NV; UPower e accuratezza non testati |
| Charging | PMIC GLINK/USB-C e thermal nel DTS | Driver presenti | NV; limiti e sicurezza non testati |
| Sensori | FastRPC/CDSP e regola mount matrix | FastRPC modulo | NV; libssc/hexagonrpcd e sensori non testati |
| Fingerprint | Pin/SPI riservati nel DTS; nessun supporto userspace dimostrato | NV | NV; nessuna modifica RPMB consentita |
| Modem | MPSS remoteproc, IPA, QRTR/QMI, Q6Voice | Moduli/driver presenti | NV; SIM/dati/SMS/chiamate/IMS non testati |
| Fotocamere | CAMSS/CCI, S5KJN1 e GC02M1B nel DTS | CAMSS modulo | NV; altri sensori e libcamera non verificati |
| Suspend/resume | Nodi wakeup e pinctrl parziali | Supporto generico | NV; s2idle non abilitato di default |
| Thermal | TSENS/PMIC ADC, varie zone; PA2 disabilitata | Driver built-in | NV; soglie e consumi non testati |
| Vibrator | Pin AW86224 nominati, nessun nodo driver completo | NV | NV |
| NFC | Pin nominati; nessun nodo completo verificato | NV | NV |
| GNSS | Dipendenza modem/QMI; servizio di esempio in pmaports | Userspace non integrato | NV |

## Regole di avanzamento

- “B” richiede log e artefatto della build fissata.
- “R” richiede `dmesg`, sysfs o tool sul dispositivo reale.
- “T/P” richiede test funzionale ripetibile e limiti noti.
- Un firmware mancante, un pannello errato o un nodo disabilitato impediscono di promuovere lo stato.
- Nessun risultato di altri telefoni o varianti viene trasferito a questo esemplare.
