<!-- SPDX-License-Identifier: MIT -->
# Stato tecnico del porting

Aggiornato: 2026-11-07.

## Stato attuale

- **Fase:** M0/M1 documentati; M2/M3 completati; **M4 raggiunto** con Arch/systemd/SSH/pacman su NBD; grafica accelerata, Hyprland e touch M5 verificati nella snapshot. Boot pulito e firstboot completo restano da verificare.
- **Commit del porting:** repository Git locale `main`, non pubblicato; nessun commit creato in questo ciclo.
- **Omarchy Mobile:** `cd90d193ac5b4056f877a96f6ec748d0998021c4`.
- **Kernel:** 7.2.9, tag `v7.2.9-sc7280`, commit `0ccea71930dbc8e32344a41be96944db4215c3c3`.
- **Arch Linux ARM:** rootfs `2026.11.07` con moduli LLVM; SHA-256 e smoke test passati.
- **Configurazioni:** fragment GCC e LLVM separati sopra pmaports 7.2.9-r3; nessuna patch ai sorgenti kernel.

## Build e test

| Attività | Esito | Evidenza |
|---|---|---|
| Recupero sorgenti | Pass | Checkout e archivi in `sources.lock` |
| ShellCheck/sintassi | Pass | `tests/static.sh` |
| Build kernel GCC e LLVM | **Pass offline** | Image/Image.gz, entrambi i DTB, 636 voci moduli LLVM e SHA-256 |
| Build initramfs | **Pass** | RAM-only, riproducibile; varianti con moduli, SSH, firmware dubai e NBD |
| Rootfs Arch/Omarchy GCC | **Pass offline** | Checksum e smoke test passati |
| Rootfs Arch/Omarchy LLVM | **Pass offline** | Checksum, smoke test ed e2fsck della copia NBD passati |
| Backup boot chain | **Pass** | Otto immagini originali, due letture SHA-256 coincidenti |
| Boot mainline senza DTBO vuoto | **Fail** | GCC/LLVM/Nura ritornano in fastboot; nessuna shell |
| Boot mainline con DTBO vuoto | **Pass M3** | Kernel 7.2.9-dubai+, modello CSOT, ACM/NCM/SSH attivi |
| Arch NBD | **Pass M4** | systemd PID 1, ext4 su NBD, SSH e pacman funzionanti |
| Display/touch | **Pass nella snapshot** | Hyprland 1080×2400@144, DPMS wake e multitouch Goodix verificati |
| Storage guard | **Pass** | Tutte le LUN `sda`–`sdf` read-only; nessun mount Android |
| GPU accelerata | **Pass nella snapshot** | EGL Freedreno Adreno, OpenGL ES 3.2; richiesto zap dubai-specifico |
| Rollback LineageOS | **Pass** | boot_b originale ripristinata e boot completato prima del test DTBO |

## Hardware e blocchi

- Il DTBO Android deve essere sostituito dal DTBO vuoto pmaports per avviare mainline; vbmeta non è stata modificata.
- Slot `_a` è marcato unbootable; `_b` contiene attualmente la initramfs di test e il backup è verificato.
- Il boot pulito deve ancora verificare cleanup dropbear/ACM, moduli UFW e firstboot senza interventi manuali.
- Wi-Fi, audio, modem, batteria/charging, suspend e sensori non qualificati.
- Firmware proprietario non pubblicato; gli artefatti NBD sono solo locali.

## Rischi

`userdata` condivisa, AVB, slot A non avviabile e molti driver non ancora testati. La strategia NBD evita qualunque scrittura allo storage interno oltre boot_b/dtbo_b già coperte da backup.

## Prossimo passo

Completare il rootfs con i nuovi moduli, provisionare il solo zap dubai privato e ripetere un boot NBD pulito. Verificare firstboot, UFW, SSH, Hyprland, GPU e touch senza interventi manuali e senza usare `userdata`.
