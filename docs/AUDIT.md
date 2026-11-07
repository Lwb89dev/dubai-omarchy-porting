<!-- SPDX-License-Identifier: MIT -->
# M0 — Audit tecnico Motorola Edge 30 (dubai)

Data: 2026-11-06. Metodo: lettura dei sorgenti e build offline; nessun dispositivo collegato, interrogato o modificato.

## 1. Fonti fissate

Le revisioni complete sono in [`sources.lock`](../sources.lock).

| Fonte | Revisione | Uso |
|---|---|---|
| [Omarchy Mobile](https://github.com/derekross/omarchy-mobile) | `cd90d193ac5b4056f877a96f6ec748d0998021c4` | shell, pacchetti, builder Arch/QEMU, riferimento multi-device |
| [pmaports](https://gitlab.postmarketos.org/postmarketOS/pmaports) | `b14105484a206e3b84f26b6f950df436dbb0d414` | package dubai, config kernel, firmware map e boot metadata |
| [sc7280-mainline/linux](https://github.com/sc7280-mainline/linux) | tag `v7.2.9-sc7280`, commit `0ccea71930dbc8e32344a41be96944db4215c3c3` | kernel scelto |
| [LineageOS device dubai](https://github.com/LineageOS/android_device_motorola_dubai) | `03ff95e4b5f0ee44e6408f308fb9f8b17d051620`, `lineage-24.0` | hardware e AVB di riferimento |
| [LineageOS sm7325-common](https://github.com/LineageOS/android_device_motorola_sm7325-common) | `d0dc473dcf587183614483b1ac807e24d76e109f` | layout boot e partizioni |
| [LineageOS kernel sm7325](https://github.com/LineageOS/android_kernel_motorola_sm7325) | `4a129b915ff9feb9f42cfaf141724d814131f068` | solo riferimento downstream 5.4 |
| [ALSA UCM sc7280](https://github.com/sc7280-mainline/alsa-ucm-conf) | `3dbb936f0cc85a5d3f12bab12a4578d85768061c` | profili audio da pacchettizzare/valutare |
| [Firmware dubai usato da pmaports](https://github.com/FairBlobs/dubai-firmware) | `56c15ff4e81e6464983397bc93be3ae5f7cfcec4` | mappa dei nomi; blob non scaricati né distribuiti |

Riferimenti esterni: [scheda LineageOS](https://lineageos.github.io/lineage_wiki/devices/dubai/), [package Nura](https://pkgs.nura.eco/package/main/postmarketos/aarch64/device-motorola-dubai), [esperienza pratica documentata](https://gist.github.com/mbohun/10dab097eb0cbf9b11f175a8fc622b81).

## 2. Identità e varianti

LineageOS 24.0 dichiara il solo modello **XT2203-1**, SoC SM7325-AE, 6/8 GiB LPDDR5, UFS 3.1 e Adreno 642L. Il dispositivo reale non è stato identificato: modello, RAM, build LineageOS, bootloader e stato slot restano da acquisire in sola lettura.

pmaports 2-r0 offre `device-motorola-dubai-kernel-csot` e `...-tianma`. Entrambe le descrizioni indicano di leggere la stringa `Panel` nella schermata fastboot dopo lo sblocco. Il gist riporta un esemplare CSOT, ma non prova la variante dell'utente.

I file sono:

- `arch/arm64/boot/dts/qcom/sm7325-motorola-dubai-csot.dts`
- `arch/arm64/boot/dts/qcom/sm7325-motorola-dubai-tianma.dts`
- `arch/arm64/boot/dts/qcom/sm7325-motorola-dubai-common.dtsi`

I DTS finali selezionano rispettivamente `csot,nt37701-dubai` e `tianma,nt37701-dubai`. `drivers/gpu/drm/panel/panel-novatek-nt37701.c` collega questi compatible a `nt37701_csot_panel_on` e `nt37701_tianma_panel_on`, con sequenze distinte. Entrambi espongono modalità 48/60/90/120/144 Hz; per il primo KMS si sceglierà 60 Hz dopo aver verificato il percorso, senza imporre 144 Hz.

## 3. Kernel e stato mainline

`device/community/linux-postmarketos-qcom-sc7280/APKBUILD` fissa `pkgver=7.2.9`, `pkgrel=3`, `_tag=v7.2.9-sc7280` e source `sc7280-mainline/linux`. Compila con `LLVM=1`; il progetto usa la configurazione completa pubblicata lì, non il defconfig Pixel.

Il tag è un merge di Linux stable v7.2.9 nella linea `sc7280-7.2.y`. Il supporto dubai nel tag comprende DTS, driver pannello, touch Goodix Berlin SPI, MSM DRM/DPU/DSI, Freedreno a livello kernel, UFS, USB, WCN6750, remoteproc, QDSP6 e codec/amplificatori. Questo non equivale a una verifica hardware.

Il progetto non importa patch dal kernel Motorola 5.4. Per i build iniziali si usa il tree sc7280 già integrato; ogni futura modifica sarà mantenuta come commit logico separato.

Il confronto puntuale con Torvalds mostra che i DTS dubai non sono presenti in `v7.2`. Sono invece presenti in `v7.3-rc6`: il board DTS di base è entrato con [12975c0f09c58ccf305b1383131790ea3cf6cedb](https://github.com/torvalds/linux/commit/12975c0f09c58ccf305b1383131790ea3cf6cedb), che dichiara simplefb, touch, tasti, UFS, batteria, USB e WCN6750. Il driver NT37701 non è presente in `v7.3-rc6`; nel DTS upstream il pannello non viene ancora abilitato. Audio e fotocamere del tree SC7280 scelto sono anch'essi delta rispetto a quel DTS upstream. Quindi la build 7.2.9-sc7280 è mainline/stable **più backport e patch out-of-tree**, non mainline puro; il passaggio a una base più recente richiede una valutazione separata.

## 4. Boot e partizioni: evidenze e discrepanze

pmaports `deviceinfo` specifica boot image header **v2**, pagina 4096, DTB aggiunto al boot image, offset kernel `0x8000`, ramdisk `0x01000000`, DTB `0x01f00000` e cmdline `earlycon` per evitare un reboot immediato con ABL. I DTB selezionati sono `qcom/sm7325-motorola-dubai-{csot,tianma}`.

LineageOS corrente dichiara invece header **v3**, `BOARD_INCLUDE_DTB_IN_BOOTIMG`, boot/vendor_boot/dtbo A/B, recovery-as-boot, partizioni boot e vendor_boot da 96 MiB, dtbo da 24 MiB e `super` da 8.925.478.912 byte. Questa differenza impedisce di dichiarare un unico formato “sicuro” senza identificare build e bootloader; per il primo artefatto si conserva il formato v2 del porting Linux esistente, marcato non testato.

`fastboot boot` non è documentato come testato dalle fonti lette. Il suo supporto va verificato con un test autorizzato; non si ripiega automaticamente su un flash.

Il gist descrive modifiche a `vbmeta`, `dtbo`, slot attivo e rootfs su `userdata`, incluso un workaround fastbootd. Sono operazioni storiche di installazione persistente, non una procedura adatta al primo boot e non vengono eseguite.

## 5. Omarchy Mobile: cosa riusare

| Componente | Decisione per dubai |
|---|---|
| `omamobile-shell`, `omamobile-apps`, `omamobile-firstboot`, `omamobile-omarchy`, `omamobile-mirror` | Riutilizzare; non dipendono dai driver Tensor |
| Builder `tools/build-packages`, `tools/build-rootfs`, container ALARM/QEMU | Riutilizzare tramite staging locale; non modificare il checkout upstream |
| Descrittori `device/<codename>` e convenzione `omamobile-device-dubai` | Riutilizzare il modello; il primo descriptor è `ram-only` |
| Initramfs condivisa upstream | Riutilizzare solo lo schema Alpine/gadget; non usare il suo `switch_root`, allowlist `userdata` o panic automatico |
| `omamobile-device-cheetah`, sensori/AoC, `omamobile-audio`, `omamobile-modem`, `omamobile-modem-sit`, `omamobile-mmd` | Non installare: contengono policy, DSP, modem Samsung o calibrazioni Pixel |
| Mesa custom upstream | Non usare: compila Panfrost/PanVK Mali e non Freedreno |
| Hyprland custom upstream | Valutare solo dopo test; Arch ARM fornisce già Hyprland AArch64. La patch DPMS Pixel non si importa senza necessità |
| Installer e comandi flash/push Pixel | Vietati su dubai |

## 6. Dipendenze pmaports → Arch Linux ARM

| Dipendenza Nura | Valutazione |
|---|---|
| `alsa-ucm-conf-qcom-sc7280` | Al commit fissato contiene `Motorola/dubai/{dubai,HiFi,VoiceCall}.conf` e il link `conf.d/sm7325/Motorola-dubai.conf`; BSD-3-Clause. VoiceCall usa `dummystreamhack`, quindi telefonia/audio chiamate restano bloccati finché quel componente non è pacchettizzato e testato |
| `firmware-motorola-dubai` | Necessario per i path nel DTS; licenza proprietaria e diritti di redistribuzione non verificati. Preferire estrazione locale dal firmware del proprietario |
| `firmware-qcom-adreno-a660` | Il nome non cambia la GPU: il DTS richiede `a660_zap.mbn` per SM7325/Adreno 642L; verificare il blob esatto |
| `hexagonrpcd` | Userspace FastRPC per DSP/sensori; non presente come pacchetto ALARM verificato, richiede packaging e servizio systemd |
| `linux-firmware-ath11k`, `linux-firmware-qca` | Nei database ALARM 20261019-1 il firmware WCN6750/ath11k è in `linux-firmware-atheros`, non in split con i nomi Nura. Il rootfs usa `linux-firmware-qcom` + `linux-firmware-atheros` e richiede ancora il `board-2.bin` specifico |
| `soc-qcom` | Metapacchetto: scomporre `tqftpserv`, boot MAC, clock offset, UPower/WirePlumber; non copiare script OpenRC |
| `soc-qcom-modem` | Metapacchetto con `msm-modem`, `q6voiced`, `81voltd`; ogni componente richiede packaging e test separati |
| `soc-qcom-qbootctl` | Non necessario al RAM boot. La marcatura slot può scrivere metadata: non abilitarla nel primo porting |
| `make-dynpart-mappings` | Utility per partizioni logiche Android; non necessaria alla diagnostica RAM e non autorizza modifiche a `super` |
| `systemd-boot`, `unl0kr-fbforcerefresh`, `postmarketos-base` | Integrazione della distribuzione di origine, non dipendenze hardware da traslare letteralmente |

Arch Linux ARM fornisce Mesa 26.2.6 con `vulkan-freedreno`, PipeWire, ModemManager 1.24.2, UPower e `alsa-ucm-conf`. Hyprland 0.57.1-1 ALARM ha mostrato in build una dipendenza non risolvibile sulle librerie correnti; il builder usa quindi i binari firmati Hyprland 0.57.1-2 e aquamarine 0.16.0-1.1 da Omarchy edge, con SHA-256 fissati. `hexagonrpcd`, `tqftpserv`, `qrtr` e `qbootctl` non risultano alle normali URL pacchetto ALARM verificate; ciò non dimostra che siano impossibili da pacchettizzare.

## 7. Rootfs e firmware

Il builder Omarchy importa il tarball AArch64 Arch Linux ARM, verifica MD5 e firma con chiave fissata, costruisce in Docker linux/arm64 tramite QEMU e usa pacman. L'host Pop!_OS ha Docker, binfmt QEMU con flag `F` e cross-toolchain; l'ambiente è quindi adatto.

Il rootfs finale userà pacchetti ALARM per base/systemd, NetworkManager, OpenSSH, Mesa/Freedreno, Wayland, PipeWire e UPower. Il pacchetto device conterrà solo policy e configurazioni. Nessun blob FairBlobs o dato del telefono sarà incluso in Git, CI o release pubbliche finché licenza e provenienza non sono verificate.

## 8. Esito M0

- Repository e revisioni identificati; varianti display e formati boot documentati.
- Componenti riutilizzabili e dipendenze Arch mappati.
- Nessuna operazione sul dispositivo.
- La variante pannello e il supporto `fastboot boot` restano i primi gate hardware.
