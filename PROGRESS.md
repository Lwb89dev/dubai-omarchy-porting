<!-- SPDX-License-Identifier: MIT -->
# Diario dei progressi

## 2026-11-06 — Avvio e ricognizione

- Avviato il primo ciclo M0 senza collegare o modificare il dispositivo.
- Verificati gli strumenti host: Git, GCC/Clang, cross-compilatore AArch64, Docker, QEMU user-mode e ShellCheck presenti; 32 CPU e circa 393 GiB liberi.
- Confermata dalla documentazione LineageOS la variante supportata XT2203-1 e l'hardware di riferimento SM7325-AE / Adreno 642L.
- Analizzato il gist di installazione postmarketOS: il bootloader riporta la variante pannello; il flusso storico modifica `vbmeta`, `dtbo`, `boot` e `userdata`. Tali operazioni non saranno eseguite e non costituiscono il runbook del primo boot.
- Iniziato il recupero dei repository upstream fissandone i commit in `sources.lock`.

**Stato:** ricognizione in corso; nessun test hardware eseguito.

## 2026-11-06 — Audit, progettazione e prime build

- Clonati e fissati Omarchy Mobile, pmaports, il kernel SC7280 e i riferimenti LineageOS; creato `sources.lock`.
- Identificato `linux-postmarketos-qcom-sc7280` 7.2.9-r3 e il tag `v7.2.9-sc7280`.
- Verificate le differenze CSOT/Tianma nei DTS e nelle sequenze del driver NT37701.
- Verificato che il DTS board è upstream da Torvalds v7.3-rc6, mentre il driver NT37701 e altre parti del porting restano fuori dal tree upstream considerato.
- Creati `AUDIT.md`, `HARDWARE-MATRIX.md`, `BOOT-CHAIN.md`, `STORAGE-PLAN.md`, `RECOVERY-RUNBOOK.md`, `ROADMAP.md` e `BUILD.md`.
- Implementati fetch, build kernel, initramfs, immagine panel-specifica non flashabile, verifiche, acquisizione read-only e CI offline.
- Creata una initramfs RAM-only con storage interamente read-only, nessuno switch_root e nessun panic automatico.
- Build initramfs **riuscita**; BusyBox AArch64 eseguito con QEMU e contenuto cpio verificato.
- ShellCheck e test statici **riusciti**; verificato il rifiuto di build-images senza pannello valido.
- Primo tentativo kernel fallito per il target `vmlinuz` non esistente; rimosso il target errato, conservato il log e rilanciata la build.
- Creato `omamobile-device-dubai` senza blob o servizi hardware attivi e preparato con successo lo staging del builder Arch/Omarchy senza modificare il checkout upstream.

**Stato:** build kernel in corso; nessun test hardware, nessuna scrittura sul dispositivo.

## 2026-11-06 — Completamento M2/M3 offline

- Build kernel **riuscita**: `7.2.9-dubai+`, `Image` 33.831.424 byte, `Image.gz`, entrambi i DTB e archivio moduli.
- Corretti in modo mirato il target kernel inesistente, il controllo della release e il percorso `usr/lib/modules`; aggiunto `kmod` per `depmod`.
- `dtbs_check` **passato** per CSOT e Tianma con dtschema 2026.9.
- Verificati i compatible board/pannello via libfdt e tutti gli SHA-256 degli artefatti.
- Due build consecutive della initramfs hanno prodotto SHA-256 `674d8a2ae04e3c7cd4c6ac3f851d8d5b84411c425f82ec921c65e9fff643c1f9`: verifica di riproducibilità passata.
- Verificati i database ALARM: sostituiti `iptables-nft` con `iptables` e `linux-firmware-qca` con `linux-firmware-atheros`, che contiene i path ath11k/WCN6750.
- Preparato CI offline e inizializzato il repository Git locale `main`; nessun repository remoto creato.
- Avviata la build rootfs Arch/Omarchy completa con il builder upstream in staging.

**Stato:** M2 e M3 completati solo offline; nessun boot hardware eseguito o dichiarato.

## 2026-11-06 — Rootfs e verifiche finali in corso

- Verifica finale kernel/initramfs ripetuta con successo: 631 voci nel tarball moduli, inclusi NT37701 e Goodix Berlin; manifest ora con path relativi portabili.
- `fetch-sources.sh` eseguito con successo su tutti i sei repository Git fissati.
- Recuperati e verificati i due file AOSP `mkbootimg` fissati; nessuna boot image generata perché il pannello resta sconosciuto.
- Verificato anche il repository Omarchy AArch64: `omarchy`, `omarchy-settings`, `omarchy-keyring` e `voxtype-bin` sono presenti; il builder rispetta il pin Omarchy 4.0.6 upstream.
- Interrotto il download sequenziale di pacchetti Pixel non necessari. Implementato un fetch selettivo parallelo con verifica dell'indice firmato, chiavi fidate/revocate, SHA-256 e firma di ogni pacchetto.
- **15 pacchetti dubai verificati** e importati nel repository pacman locale; download del tarball Arch Linux ARM in corso.
- Controlli statici finali passati, inclusi PKGBUILD, test del device package e compilazione Python senza lasciare cache nel repository.

**Stato:** rootfs in build; nessun dispositivo toccato.

## 2026-11-06 — Correzione della ripresa rootfs

- La prima build rootfs si è interrotta nel filtro post-import perché Python tarfile non apre i pacchetti zstd dell'host; sostituito con `bsdtar`.
- Il tarball ALARM (791 MiB) è stato scaricato, verificato con MD5/firma dal codice upstream e importato come immagine Docker prima del fallimento successivo.
- Integrato il download verificato del keyring pubblico Omarchy per host privi del pacchetto, fissato in `sources.lock`.
- Ripresa la build dai pacchetti e dall'immagine già presenti, senza modifiche al telefono.

**Stato:** rootfs in build dopo correzione mirata.

- Verificato il fork UCM al commit fissato: include i profili dubai HiFi e VoiceCall; VoiceCall richiede `dummystreamhack`, quindi non viene dichiarato utilizzabile né integrato automaticamente.

- Creato `packages/omamobile-ucm-dubai` con i tre profili fissati, licenza BSD-3-Clause e nessuna dipendenza VoiceCall non verificata; test statici e checksum SHA-512 dell'archivio passati. Non incluso nel primo rootfs né testato sull'hardware.

- `makepkg` ha prodotto `omamobile-device-dubai-0.1.0-1-aarch64.pkg.tar.zst`; contenuto ispezionato: solo descriptor, mirrorlist, regole rete/udev e licenza, senza blob o servizi hardware attivati.

- Il primo `pacstrap` si è fermato perché ALARM Hyprland 0.57.1-1 non trovava le SONAME richieste. Analizzate le dipendenze reali invece di forzarle.
- Selezionati dai binari Omarchy edge `hyprland-0.57.1-2` (libhyprgraphics 5) e `aquamarine-0.16.0-1.1` (libaquamarine 15), compatibili con gli altri pacchetti correnti; checksum e firme verificati, revisioni in `sources.lock`.
- Ripresa la build rootfs senza ricompilare Hyprland e senza cambiare il pin Omarchy 4.0.6.

- La prima installazione dei pacchetti Omarchy Mobile nel rootfs è fallita perché `neard` era stato escluso pur essendo una dipendenza obbligatoria di `omamobile-apps`. Ripristinato il pacchetto firmato generico; nessuna funzionalità NFC hardware viene dichiarata.
- Riavviata la build con cache dei pacchetti esistente; log completo conservato in `out/rootfs/logs/build.log`.

## 2026-11-07 — Rootfs Arch/Omarchy completato offline

- Ripresa la build dai pacchetti e dall'immagine ALARM già presenti; nessun download o lavoro kernel ripetuto inutilmente.
- Build rootfs **riuscita** in 15 minuti: `work/omarchy-dubai/out/dubai/omamobile-rootfs-dubai-2026.11.07-aarch64.img.zst` (3,4 GiB), con checksum SHA-256 verificato e manifest di 988 righe.
- Il rootfs contiene Arch Linux ARM, systemd 262.1-1, Omarchy 4.0.6-1, Omarchy Mobile shell 0.2.100-1, Hyprland 0.57.1-2, Mesa 26.2.6-1 con Freedreno, il device package dubai e i moduli `7.2.9-dubai+`.
- Smoke test upstream **passato**: filesystem ext4, keyring e repository, servizi di primo avvio, patch Omarchy, moduli, assenza di chiavi host/dati per-device e nessun servizio modem abilitato.
- Verificati nuovamente kernel, entrambi i DTB, archivio moduli e initramfs; test statici passati.

**Stato:** M4 completato solo nella parte offline; nessun boot hardware, installazione o dichiarazione di funzionamento su dubai. Il prossimo gate resta l'acquisizione read-only di modello/pannello e il runbook autorizzato per il primo boot.

## 2026-11-07 — Identificazione del dispositivo e boot image CSOT

- Eseguita acquisizione ADB **solo read-only**, fuori dal repository: XT2203-1/dubai, LineageOS 23.2 nightly del 2026-05-29, slot `_b`, bootloader sbloccato.
- Identificato senza reboot il pannello **CSOT NT37701** dalla cmdline Android; nessun seriale, MAC o altro identificativo è stato copiato nei documenti.
- Corretto `capture-device-info.sh`: i nodi `/proc/device-tree` assenti su Android sono opzionali e non impediscono più il tentativo di cattura `dmesg`. Quest'ultimo resta non disponibile per permessi.
- Generata offline `out/images/boot-dubai-csot-UNTESTED.img` (16 MiB), header Android v2 riconosciuto e SHA-256 verificato. Nessun comando fastboot o boot è stato eseguito.
- Il portale LineageOS non elenca più la nightly installata e l'URL diretto restituisce 404; il gate del ripristino esatto resta aperto e il boot non viene proposto come sicuro.

**Stato:** modello e pannello acquisiti, artefatto CSOT pronto solo offline; in attesa di recovery verificabile e autorizzazione specifica per una sessione fastboot read-only.

## 2026-11-07 — Cattura fastboot autorizzata

- Eseguito il solo reboot autorizzato da Android ad ABL fastboot; nessun boot Linux, cambio slot o scrittura.
- `getvar all` conferma prodotto/SKU, CSOT NT37701, bootloader sbloccato, 8 GB RAM, UFS 128 GB, slot `_b` e fastboot non-userspace.
- Entrambi gli slot hanno retry 6 e successful yes, ma `_a` è anche `slot-unbootable=yes`: la strategia non può considerarlo un ripristino disponibile.
- Lette le dimensioni di boot, vendor_boot, dtbo, vbmeta, super e userdata; lo script di cattura ora ripete anche queste query in modo riproducibile.
- Il telefono resta in fastboot. Il supporto a `fastboot boot` e il gate di recovery esatto restano aperti; nessuna immagine è stata inviata.

## 2026-11-07 — Primo boot temporaneo: fallimento precoce

- Autorizzato ed eseguito **una sola volta** `fastboot boot` con l'immagine CSOT; invio e comando ritornano OKAY.
- Il Motorola si scollega e riappare come fastboot dopo circa 3 s; nessun gadget `1d6b:0104`, shell o log Linux. Slot, successful/unbootable flag e retry restano invariati.
- Identificato e ignorato il Galaxy Tab S5e collegato allo stesso host: la sua rete USB non appartiene al Motorola; i comandi fastboot successivi sono vincolati al seriale del Motorola.
- Riavviato il solo Motorola su LineageOS `_b`. `pstore` non è leggibile dall'utente ADB e `/proc/last_kmsg` non esiste; causa del fallimento non determinata.
- Verificato che header v2, offset, pagina, DTB e cmdline corrispondono a pmaports. Scaricato il pacchetto Nura `linux-postmarketos-qcom-sc7280-7.2.9-r3` dal mirror ufficiale (SHA-256 `c504a4791b62faaab8ece3f62c5ab3eb8f84bba5a1cf950f338fa5f9b295f543`).
- Il DTB CSOT Nura è identico byte per byte al nostro; il kernel differisce. Nura compila con LLVM/Clang thin-LTO/BTF, mentre la prima build usa GCC. Avviata una build LLVM separata per isolare questa differenza senza modificare DTS o bootloader.

## 2026-11-07 — Controlli incrociati e backup verificato

- Build LLVM **riuscita** e verificata: thin-LTO/BTF, 631 voci moduli e DTB corretti. Anche la sua boot image ritorna in fastboot dopo circa 3 s.
- Anche il kernel binario Nura 7.2.9-r3 con la nostra initramfs fallisce nello stesso modo: toolchain e singola build locali non sono la causa dimostrata.
- La `boot.img` ufficiale LineageOS 23.2 del 2026-10-09, verificata con SHA-256, si avvia correttamente tramite `fastboot boot`: il meccanismo è supportato, mentre tutte le immagini mainline header v2 falliscono.
- Entrati nella recovery LineageOS esistente e ottenuto ADB root dopo conferma esplicita sul dispositivo.
- Eseguito backup read-only di boot, vendor_boot, dtbo e vbmeta di entrambi gli slot. Tutte le otto immagini hanno dimensione attesa e SHA-256 identico tra copia host e seconda lettura sul telefono.
- Preparato il runbook per un test persistente della sola `boot_b` con rollback dal backup reale. Nessun flash è stato eseguito; il telefono resta in recovery.

## 2026-11-07 — Alpha 0 raggiunta

- Il flash della sola boot_b LLVM fallisce; rollback dalla copia originale riuscito e boot LineageOS `_b` completato.
- Riprodotto il DTBO vuoto da 24 MiB richiesto da pmaports: boot_b LLVM + dtbo_b vuoto **avvia finalmente mainline**.
- Shell reale: `Linux dubai-rescue 7.2.9-dubai+ aarch64`, modello `Motorola Edge 30 (CSOT)`, USB NCM/ACM attivo e SSH su chiave pubblica.
- Tutte le LUN UFS `sda`–`sdf` verificate read-only; nessun mount Android o uso di userdata.
- Corretto `/lib/modules` → `/usr/lib/modules`; caricati pannello NT37701, SPI GENI e Goodix Berlin. DRM card0/renderD128, framebuffer 1080×2400 e touch Goodix rilevati.
- Integrati i firmware linux-firmware Adreno SQE/GMU/zap, con hash registrati. Un rebind DRM manuale ha causato warning/oops ed EBUSY GMU: metodo scartato, sarà testato solo un boot pulito.
- Preparata una variante NBD: qemu-nbd in snapshot sul PC e client nella initramfs per avviare Arch senza scrivere userdata. Rebuild rootfs LLVM avviato per coerenza dei moduli.
- Rootfs LLVM completato e smoke test passato; manifest registra il tarball moduli SHA-256 `9d49893488989f1d2ac781ae1ea3346700c1d64267daf42b215ad186ee961150`.
- Copia raw NBD provisioned con firstboot e chiave pubblica, ownership root e `e2fsck` pulito. Server qemu-nbd snapshot attivo; boot Arch in attesa di accesso fastboot tramite tasti.
- Primo flash NBD eseguito: mainline e USB NCM/ACM attivi, ma il primo tentativo NBD precede la configurazione dell'indirizzo host e lascia `/dev/nbd0` a capacità zero. Un mount manuale successivo legge correttamente ext4 e trova `/sbin/init`; `switch_root` via SSH è rifiutato perché deve essere PID 1.
- `reboot -f` dalla initramfs BusyBox porta ABL in fastboot e consuma i retry dello slot; `set_active b` è stato necessario per riavviare `_b`. Non usare quel reboot per i prossimi test.
- Alpine 3.24.2 marca root bloccato (`root:*`), quindi dropbear rifiuta anche la chiave nella nuova initramfs. Corretto il builder per lasciare root senza password nella sola initramfs, mantenendo dropbear `-s -g` e quindi SSH a sole chiavi.
- Nuova boot image NBD costruita e verificata: 90 secondi di retry, controllo capacità NBD e server qemu-nbd `--persistent`. Il flash della revisione corretta richiede un nuovo accesso fisico a fastboot; Arch/systemd non sono ancora stati avviati.

## 2026-11-07 — Arch NBD e shell Omarchy avviati

- `switch_root` riuscito: `systemd` è PID 1, `/` è ext4 rw su `/dev/nbd0`, firstboot crea l'utente e SDDM avvia la sessione. SSH utente funziona dopo aver eliminato il vecchio dropbear e aggiunto la regola UFW su `usb0`.
- Il dropbear della initramfs sopravvive a `switch_root`, perde le chiavi con il vecchio root e occupa la porta 22. Il builder ora lo termina insieme alla console ACM prima di `switch_root`; il guard UFS resta attivo.
- UFW fallisce per quattro opzioni netfilter assenti. Abilitati `xt_limit`, `xt_LOG`, `xt_hl` e `ip6t_rt` come moduli; kernel LLVM ricompilato con successo e 636 voci moduli verificate.
- Orologio iniziale errato (26 ottobre) corretto; `pacman-key --populate` completato. La chiave pubblica locale dubai è stata aggiunta e firmata localmente come azione del proprietario; `pacman -Q` e `pacman -Dk` passano, 972 pacchetti, nessuna verifica di firma disabilitata.
- Il blob zap qcm6490 generico provoca errori Freedreno `ENXIO`. Il blob dubai-specifico fissato da pmaports, verificato e mantenuto privato, consente l'avvio di Hyprland e Quickshell.
- EGL riporta Freedreno Adreno e OpenGL ES 3.2; DRM offre 1080×2400 a 48/60/90/120/144 Hz. Hyprland riconosce Goodix; `evtest` conferma coordinate, rilascio e multitouch, con riaccensione DPMS tramite tocco.
- È in corso il rebuild rootfs con i moduli aggiornati; firstboot completo e boot senza interventi manuali restano da validare.
