<!-- SPDX-License-Identifier: MIT -->
# Motorola Edge 30 (dubai): note di bring-up

## Identità acquisita il 2026-11-07

- Acquisizioni ADB e fastboot esclusivamente read-only: `dubai`, Motorola Edge 30, SKU `XT2203-1`, 8 GB RAM e UFS da 128 GB.
- Cmdline Android e `primary-display` fastboot concordano su **CSOT NT37701** `1080x2400_655_dsc_cmd_v1`. Non usare il DTB Tianma.
- Slot corrente `_b`; bootloader sbloccato (`flashing_unlocked`), ABL fastboot (`is-userspace: no`). Sono stati eseguiti reboot autorizzati Android↔fastboot, senza cambio slot o flash.
- Entrambi gli slot hanno retry 6 e `slot-successful=yes`, ma `_a` ha anche `slot-unbootable=yes`: non considerarlo un fallback funzionante.
- Sistema installato: LineageOS 23.2 nightly, build del 2026-05-29. Il pacchetto corrispondente non è più elencato dal portale ufficiale e il suo URL diretto restituisce 404: recovery corrispondente non ancora disponibile.
- La cattura privata è fuori dal repository. Android non consente `dmesg` o `pstore` all'utente ADB; `/proc/last_kmsg` non esiste.
- Dimensioni lette via fastboot: `boot_a/b` e `vendor_boot_a/b` 96 MiB, `dtbo_a/b` 24 MiB, `vbmeta_a/b` 64 KiB, `super` 0x214000000, `userdata` 0x1b166fb000.
- **Primo boot GCC:** `fastboot boot` accettato, ma ritorno in fastboot dopo circa 3 s senza shell/gadget; flag e retry invariati. Nessun secondo tentativo con la stessa immagine.

## Scelte correnti

- Kernel: `sc7280-mainline/linux`, tag `v7.2.9-sc7280`, commit `0ccea71930dbc8e32344a41be96944db4215c3c3`.
- Configurazione base: quella pubblicata con `linux-postmarketos-qcom-sc7280` 7.2.9-r3.
- Prima initramfs: interamente in RAM, storage forzato in sola lettura, nessun mount o `switch_root`.
- Firmware proprietario: non incluso negli artefatti e non versionato.

## Evidenze dai sorgenti, non test hardware

Il DTS comune abilita diversi sottosistemi. La presenza di un nodo `okay` dimostra solo l'intento del porting, non il funzionamento sul telefono. Le varianti CSOT/Tianma condividono il DTS comune ma impostano compatible e sequenze di inizializzazione differenti nel driver NT37701.

Il pacchetto pmaports crea un `dtbo.img` di 24 MiB interamente nullo. Questo è un dato sul porting esistente, non un'autorizzazione a scrivere `dtbo`: nessuna immagine DTBO vuota viene prodotta o proposta per il primo test RAM-only.
