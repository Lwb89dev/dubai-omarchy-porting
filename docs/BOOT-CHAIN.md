<!-- SPDX-License-Identifier: MIT -->
# Boot chain Motorola dubai

## Stato verificato

- Fastboot ABL (`is-userspace: no`), prodotto `dubai`, XT2203-1, bootloader sbloccato, slot attivo `_b`.
- Slot `_a` marcato `slot-unbootable=yes`; non è un fallback. Il backup delle immagini originali è verificato con due letture SHA-256.
- Pannello CSOT NT37701 confermato da cmdline Android e `primary-display` fastboot.
- `fastboot boot` funziona con la boot image ufficiale LineageOS, ma le immagini mainline v2 temporanee ritornano in fastboot.
- Il flash della sola `boot_b` mainline senza modificare DTBO fallisce; il rollback a LineageOS è stato verificato.
- **Flash di `boot_b` mainline + `dtbo_b` vuoto: boot riuscito.** Kernel 7.2.9-dubai+, initramfs, ACM/NCM/SSH e storage read-only verificati.

## Layout verificato via fastboot

- `boot_a`/`boot_b` e `vendor_boot_a`/`vendor_boot_b`: 96 MiB ciascuna.
- `dtbo_a`/`dtbo_b`: 24 MiB ciascuna; `vbmeta_a`/`vbmeta_b`: 64 KiB ciascuna.
- `super`: 0x214000000, con partizioni logiche dinamiche; non è una rootfs Linux da sovrascrivere.
- `userdata`: 0x1b166fb000, fisica e condivisa fra gli slot; non usata dalla strategia NBD.

## Requisiti dell'immagine mainline

- Boot header v2, pagina 4096, offset e DTB appeso derivati da pmaports.
- Cmdline `earlycon console=ttyMSM0,115200n8 console=tty0 panic=10`; ABL sovrascrive/aggiunge i propri argomenti.
- DTBO vuoto da 24 MiB, esattamente come generato dal device package pmaports. Il DTBO Android non è compatibile con il percorso mainline.
- Nessuna modifica vbmeta necessaria nei test riusciti; non disabilitare ulteriori verifiche.
- `reboot-to bootloader` e `reboot-to fastboot` dalla initramfs vengono ignorati e ritornano al normale boot di `_b`: per flash successivi usare i tasti Power+Volume Giù.

## Artefatti correnti

- Kernel/moduli LLVM: `out/kernel-llvm`.
- Initramfs diagnostica con moduli/SSH: `out/initramfs-llvm-ssh`.
- Initramfs con firmware GPU e client NBD: `out/initramfs-nbd`.
- Boot image Arch/NBD: `out/images-nbd/boot-dubai-csot-UNTESTED.img`.
- DTBO vuoto: `out/images-llvm/dtbo-empty.img`.

La boot image resta etichettata UNTESTED nel nome anche dopo M3 perché ogni nuova variante userspace richiede una verifica separata. Il rootfs NBD viene esportato dal PC in snapshot qemu-nbd; nessuna installazione su `userdata` è necessaria per M4.

## Recovery

Il rollback di boot_b/dtbo_b usa esclusivamente le copie originali verificate nella directory privata. Non cambiare slot e non ripristinare partizioni non modificate. Il runbook completo è in `docs/RECOVERY-RUNBOOK.md`.
