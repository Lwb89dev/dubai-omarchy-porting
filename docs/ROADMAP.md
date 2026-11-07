<!-- SPDX-License-Identifier: MIT -->
# Roadmap eseguibile

| Milestone | Deliverable e gate | Stato al 2026-11-06 |
|---|---|---|
| M0 Audit | Fonti fissate, dipendenze e boot/storage documentati | Completato offline; nessun device test |
| M1 Matrice hardware | Stato driver/DT separato da rilevamento e test | Matrice sorgenti; hardware non verificato |
| M2 Kernel | Kernel 7.2.9-sc7280, config, moduli, due DTB, SHA-256 e log | **Completato offline**; dtbs_check pass, non avviato |
| M3 Initramfs | RAM-only, guard read-only, NCM/ACM, Dropbear, log | **Build e QEMU pass**, riproducibile; Alpha 0 richiede boot autorizzato |
| M4 Arch rootfs | Builder ALARM/QEMU, pacchetti binari, kernel/modules | Preparazione; nessun `userdata` |
| M5 Display/GPU/touch | 60 Hz KMS stabile, Freedreno, libinput | Solo evidenza nei sorgenti |
| M6 Connettività | ath11k/WCN6750, BlueZ, ruoli USB | Firmware e test da fare |
| M7 Audio | QDSP6, UCM dubai, PipeWire, test sicuri a basso volume | Packaging UCM e servizi da fare |
| M8 Power | Batteria/charging, runtime PM, s2idle e resume progressivi | Non testato; suspend non predefinito |
| M9 Modem | remoteproc/QRTR/QMI, dati, SMS, chiamate, IMS separati | Nessuno stack Pixel; servizi Qualcomm da pacchettizzare |
| M10 Omarchy | Device package e shell reale, portrait/landscape, prestazioni 6 GiB | Dopo M5/M6 |
| M11 Secondario | Sensori, haptics, fingerprint, GNSS, camere, NFC | Non blocca la prima release |

## Traguardi di release

- **Alpha 0:** primo kernel e initramfs realmente avviati, log e recovery verificati. Non raggiunto.
- **Alpha 1:** Arch/systemd/pacman, storage e rete/SSH sul dispositivo. Non raggiunto.
- **Alpha 2:** Hyprland accelerato, touch, Wi-Fi, audio, batteria e shell Omarchy. Non raggiunto.
- **Beta:** power/charging affidabili, modem dati, stabilità e update; telefonia valutata separatamente. Non raggiunto.

## Prossime azioni in ordine

1. Identità e pannello del telefono con acquisizione read-only.
2. Completare build kernel/initramfs e validazione statica.
3. Richiedere approvazione per un solo boot temporaneo se tutti i gate passano.
4. Solo dopo i log: correggere un sottosistema alla volta e preparare Arch rootfs coerente con lo stesso kernel.
5. Integrare Freedreno e Omarchy senza importare policy Pixel.
