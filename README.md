<!-- SPDX-License-Identifier: MIT -->
# Omarchy Mobile su Motorola Edge 30 (dubai)

Porting nativo AArch64 basato su Linux mainline, il lavoro del porting Motorola esistente, Arch Linux ARM e la shell Omarchy Mobile. Non usa Android come runtime, né proot/chroot/Termux.

**Stato attuale: audit e build offline. Nessun boot o test hardware è stato eseguito.** Nessuna immagine presente è approvata per il flash. Il pannello CSOT/Tianma e il supporto del bootloader a `fastboot boot` devono essere verificati sul dispositivo.

## Obiettivi e limiti

- Kernel `7.2.9-sc7280` fissato in `sources.lock`; DTS specifici per CSOT e Tianma.
- Prima initramfs interamente in RAM: shell, log, USB NCM/ACM e Dropbear; tutti i dischi SCSI/UFS in sola lettura.
- Rootfs Arch Linux ARM costruito con l'infrastruttura container/QEMU di Omarchy Mobile.
- La shell e i pacchetti hardware-indipendenti vengono riutilizzati; niente driver o stack modem Pixel/Tensor.

## Build offline

```sh
scripts/fetch-sources.sh
scripts/build-kernel.sh
scripts/build-initramfs.sh
scripts/verify-images.sh
tests/static.sh
```

Gli artefatti e i log sono in `out/`; sorgenti e download in `sources/` e `work/` sono ignorati da Git. `scripts/build-images.sh` richiede una variante pannello esplicita, ma un'immagine compilata resta non testata e non autorizza alcun flash.

Documentazione: [audit](docs/AUDIT.md), [matrice hardware](docs/HARDWARE-MATRIX.md), [boot chain](docs/BOOT-CHAIN.md), [storage](docs/STORAGE-PLAN.md), [recovery](docs/RECOVERY-RUNBOOK.md), [build](docs/BUILD.md) e [roadmap](docs/ROADMAP.md).

`PROCESS.md` riporta lo stato tecnico corrente; `PROGRESS.md` è il diario cronologico delle attività.

## Sicurezza

Non eseguire `tools/install-phone` upstream su questo dispositivo. Non formattare `userdata`: è condivisa e la sua perdita non viene annullata dal dual slot A/B. Non modificare `super`, `persist`, modem/NV, calibrazioni o `vbmeta`. Ogni boot temporaneo o scrittura richiede un runbook specifico e approvazione esplicita.
