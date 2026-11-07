<!-- SPDX-License-Identifier: MIT -->
# Recovery runbook — Motorola dubai

Questo documento registra operazioni già eseguite con autorizzazione e il rollback associato. L'installazione Arch su `userdata` resta fuori scope; la strategia corrente usa NBD senza scrivere lo storage interno.

## Stato e backup

- XT2203-1/dubai, 8 GB RAM, UFS 128 GB, CSOT NT37701, LineageOS 23.2 del 2026-05-29, slot `_b`.
- Slot `_a` marcato unbootable; non usarlo come fallback.
- Backup privato verificato con due letture SHA-256: boot, vendor_boot, dtbo e vbmeta di entrambi gli slot.
- Dimensioni: boot/vendor_boot 96 MiB, dtbo 24 MiB, vbmeta 64 KiB.

## Risultati dei test

| Test | Esito |
|---|---|
| `fastboot boot` GCC/LLVM/Nura, header v2 | Ritorno in fastboot dopo circa 3 s |
| `fastboot boot` immagine ufficiale LineageOS | Android avviato; comando validato |
| Flash sola boot_b mainline | Boot failed; rollback boot_b riuscito e LineageOS avviato |
| Flash boot_b LLVM + dtbo_b vuoto | **Mainline avviato**, shell ACM/NCM/SSH, UFS read-only |

Il DTBO vuoto pmaports è quindi necessario. Non modificare vbmeta: non è servito nei test riusciti.

## Rollback completo alle immagini originali

Assegnare localmente il seriale senza pubblicarlo e verificare i checksum prima del ripristino:

```sh
export FASTBOOT_SERIAL=<motorola-serial>
export PRIVATE_BACKUP=<private-backup-directory>
fastboot -s "$FASTBOOT_SERIAL" getvar product
fastboot -s "$FASTBOOT_SERIAL" flash boot_b "$PRIVATE_BACKUP/boot_b.img"
fastboot -s "$FASTBOOT_SERIAL" flash dtbo_b "$PRIVATE_BACKUP/dtbo_b.img"
fastboot -s "$FASTBOOT_SERIAL" reboot
```

Atteso: LineageOS `_b` completamente avviato. Questo rollback è già stato verificato per boot_b dopo il primo flash. Non cambiare slot, non scrivere vendor_boot/vbmeta e non usare immagini di una nightly differente.

## Accesso fastboot

Da Android: `adb -s "$FASTBOOT_SERIAL" reboot bootloader`. Dalla initramfs le ragioni `bootloader` e `fastboot` sono state ignorate; usare Power+Volume Giù fino a fastboot. Verificare sempre `product=dubai` e il seriale prima di qualunque scrittura.

## Rootfs senza installazione interna

Il rootfs Arch/Omarchy viene decompresso sul PC e servito con qemu-nbd in modalità snapshot. Le scritture restano in overlay temporanei sul PC; il Motorola non monta `userdata`, `super` o altre partizioni Android.

```sh
qemu-nbd --format=raw --snapshot --persistent --bind=172.16.42.2 --port=10809 \
  --export-name=omamobile work/rootfs-dubai-2026.11.07.img
```

La initramfs NBD carica il client solo se `/etc/omamobile-nbd-server` è presente. Attende fino a 90 secondi la rete host, rifiuta un device NBD con capacità zero e in caso di errore resta nella shell diagnostica senza tentare mount alternativi. Il server deve restare persistente perché il reboot del client altrimenti lo termina.

Dopo ogni enumerazione, configurare l'indirizzo host prima che scada il retry. Il nome dell'interfaccia cambia a ogni boot; risalire dal suo path udev al device USB padre e richiedere `serial=dubai-rescue`. `PRODUCT=1d6b/104/*` è un ID gadget generico e non basta quando è collegato anche un altro dispositivo Linux. Non usare il nome precedente né il solo elenco delle interfacce USB.

Se ABL ha esaurito i retry e marca `_b` unbootable, verificare `product=dubai`, `running-bl-slot=_b/_b` e le immagini, quindi `fastboot -s "$FASTBOOT_SERIAL" set_active b` ripristina il solo slot di test. Non usare mai `_a` come fallback.

## Stop e sintomi

- Identità/slot non coerenti o checksum mancante: stop prima di scrivere.
- Ritorno in fastboot dopo un nuovo test: rollback delle sole partizioni modificate.
- Kernel attivo senza display: raccogliere SSH/ACM e dmesg; non cambiare DTS, kernel e bootloader insieme.
- Qualunque LUN UFS non read-only: stop e nessun mount.
- Niente erase, wipe, lock, scritture su super/userdata, modem/NV o calibrazioni. `set_active b` solo nel caso documentato sopra, mai su altri slot o dispositivi.
