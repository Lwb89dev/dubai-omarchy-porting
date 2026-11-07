<!-- SPDX-License-Identifier: MIT -->
# Piano storage e rootfs

## Regola fondamentale

`userdata` è condivisa fra A e B. Scriverla o riformattarla elimina dati e configurazione usati da LineageOS su qualunque slot. La presenza di un secondo sistema Android non preserva quel contenuto.

La prima initramfs imposta tutti i dischi e le partizioni `/dev/sd*` in sola lettura, ripetutamente, senza allowlist. Non monta filesystem Android, non crea device-mapper, non apre `super`, non ridimensiona filesystem e non esegue `switch_root`.

## Opzioni

| Opzione | Preserva LineageOS | Rischio dati | Prestazioni/complessità | Recovery e aggiornamenti | Stato |
|---|---|---|---|---|---|
| A. Rootfs in RAM/initramfs | Sì | Nessuna scrittura prevista | RAM limitata, sistema non persistente | Basta riavviare; aggiornamento = nuova immagine | **Scelta per M3**; boot non testato |
| B. Rootfs su USB esterno | Potenzialmente sì | Basso per UFS, ma errori di selezione restano possibili | USB 2.0 nel DTS attuale, alimentazione e ruolo OTG da verificare | Dispositivo esterno sostituibile; update persistenti sul media | Futuro; host mode e boot da USB non dimostrati |
| C. Rootfs in partizione/immagine interna dedicata | Solo se si trova spazio senza alterare dati | Alto: GPT, `super` o `userdata` possono essere coinvolti | Migliori prestazioni, layout complesso | Richiede backup, rollback e update specifici | Non autorizzato; nessun layout proposto come sicuro |
| D. Rootfs su `userdata`, sostituendo Android | No | **Distruzione dei dati** | Semplice ereditando il builder Pixel | Slot A non ripristina i dati; recovery richiede reinstallazione/reset | Escluso dalle fasi iniziali; solo decisione futura esplicita |

## Sequenza raccomandata

1. Diagnostica RAM, senza firmware modem e senza mount storage.
2. Inventario read-only delle LUN UFS e dei nomi GPT, dopo verifica del guard.
3. Rootfs Arch in RAM o eventualmente su USB esterna solo dopo test del ruolo host.
4. Valutare storage interno solo con mappa completa delle partizioni fisiche/logiche, backup leggibili e piano di recovery.
5. Non usare lo slot inattivo come prova che un'installazione sia reversibile.

## Backup

Un backup utile richiede accesso read-only ai block device, normalmente non disponibile da Android senza root. Non si assume che `adb`, fastboot o fastbootd possano leggere partizioni arbitrarie. Se il privilegio non è verificato, il backup è “non disponibile”, non simulato.

Le immagini di boot e le partizioni NV/calibrazione contengono dati sensibili o specifici del telefono. Si conservano fuori dal repository, con accesso ristretto e SHA-256; non in issue, CI o release. Un backup non verificato con seconda lettura/checksum non viene dichiarato valido.
