<!-- SPDX-License-Identifier: MIT -->
# Handoff 2026-11-12 — stato vivo del port e istruzioni per proseguire

Questo documento è il punto di ingresso per chi riprende il lavoro (umano o
agente). Stato rilevato il 2026-11-12 sera; leggere anche `PROCESS.md`
(stato corrente) e `PROGRESS.md` (log completo).

**Aggiornamento 2026-11-22:**
- **M8 sbloccato sul wake PMIC:** 4 cicli `s2idle` reali in RAM rescue (6 s, 11 s con `usb0` giù, 11 s con UDC sganciato, 61 s) si sono svegliati tutti pulitamente su `IRQ 115` (`pm8xxx_rtc_alarm`, `suspend_stats/success=4`). I fallimenti del 12/11 erano dovuti a due bug combinati: offset di 56 anni tra `date +%s` (2026 via NTP) e `/sys/class/rtc/rtc0/since_epoch` (1970 hardware PMK8350), più deadlock NBD quando `usb0` veniva spento su rootfs NBD. Entrambi corretti in `scripts/device-suspend-tests.sh` (dettagli in `docs/SUSPEND.md`). Restano da verificare: pressione Power dentro la finestra `s2idle` e `qcom_stats/{aosd,cxsd}` a cavo USB scollegato.
- **Boot freddo su `work/rootfs-dubai-2026.11.13-recovery.qcow2` riuscito:** batteria/carica ok (`89%`, `Charging`, `4.255 V`, UPower `2.03 W`), 5 sleep target `masked` e `CriticalPowerAction=PowerOff` verificati, Bluetooth acceso al boot, Wi-Fi, Hyprland, ModemManager, sensori (accel + luce + bussola viva `303°–312°`) e `omamobile-autorotate.service` tutti attivi al boot; unica unit fallita `plymouth-start.service`; tutte le 6 LUN UFS `ro=1`. Nota operativa: se `qemu-nbd` era stato avviato prima di uno spegnimento del rescue, eventuali connessioni TCP stantie saturano `--shared=2` e bloccano il nuovo `nbd-client` (riavviare `qemu-nbd` sblocca subito il boot).

**Aggiornamento 2026-11-13:** dopo un'interruzione USB, il filesystem NBD è
stato riparato su una copia e il watcher è predisposto per
`work/rootfs-dubai-2026.11.13-recovery.qcow2`. L'ultimo boot temporaneo è stato
seguito da un secondo boot riuscito sul rootfs di recupero. Linux segnalava
batteria allo 0% e Discharging: è stato disposto uno spegnimento ordinato e,
dopo la scomparsa USB, watcher e server NBD sono stati fermati. I controlli
offline di qcow2 ed ext4 sono passati. Caricare il telefono esternamente prima
di continuare; riavviare il watcher con `DUBAI_NBD_OVERLAY` sull'overlay di
recupero prima del prossimo boot. Le letture batteria non sono state ancora
confrontate con Android o con uno strumento esterno.
Non modificare il backing file né fermare il server se il telefono lo usa.
Il journal dell'avvio precedente registra una sospensione richiesta da UPower
seguita dalla perdita della rete USB. Nell'immagine di recupero, mentre era
offline, i target di sospensione sono stati mascherati e l'azione UPower per
batteria critica è stata impostata su spegnimento; sono precauzioni NBD
temporanee, ancora da verificare in esecuzione, non una correzione del wake.
Nell'avvio precedente, firstboot, Hyprland, Wi-Fi e cattura dalle
due fotocamere funzionano; i sensori sono visibili e l'autorotazione è attiva,
ma rotazione e tocco non sono stati riconfermati visivamente su questo avvio.
Il modem è stato avviato sperimentalmente con copie EFS sul rootfs NBD,
senza scrivere sulle partizioni UFS, che restano in sola lettura. QMI riporta
ancora `no-atr-received` su entrambe le sedi SIM. ModemManager non completa
l'unlock. Dettagli e limiti nell'ultima sezione di `PROGRESS.md` e in
`docs/TELEPHONY.md`. Le istruzioni che seguono descrivono lo stato precedente
se non diversamente indicato.

## 1. Dove siamo

- **Alpha 0/1/2 raggiunti sul dubai CSOT** (kernel mainline 7.2.9-dubai+,
  Arch rootfs via NBD/RNDIS, Hyprland accelerato, touch, Wi-Fi, BT, audio,
  batteria con stato di carica corretto, fotocamere funzionanti).
- **Kernel di riferimento**: build CI (LLVM, 7 patch, Landlock + PM_DEBUG).
  La CI (`offline-build`) è **verde**. `main` su GitHub è in sync.
- **M8 (sospensione)**: root cause della wake prematura individuata
  (traffico link USB gadget), s2idle sostenuto dimostrato con usb0 giù, ma
  **nessuna wake source PMIC funziona** (RTC e power key non svegliano) →
  indagine PDC/irq-wake, vedi `docs/SUSPEND.md`.
- **M9 (modem)**: tutto vivo fino al bordo SIM (serve una SIM fisica).
  Vedi `docs/TELEPHONY.md`.
- **M11 (sensori)**: pacchetti pronti nel repo (`packages/libssc`,
  `packages/hexagonrpcd`, `packages/iio-sensor-proxy`); copiati sul telefono,
  **da compilare e installare** (istruzioni sotto).

## 2. Infrastruttura attiva (host HP OMEN, Pop!_OS)

- `scripts/host-usb-watch.sh` gira in background (nohup): su enumerazione
  `dubai-rescue` attiva il profilo NM e avvia `qemu-nbd` persistente su
  `172.16.42.2:10809` export `omamobile` sull'overlay
  `work/rootfs-dubai-live.qcow2` (backing `work/rootfs-dubai-live-flat3.img`,
  13 GiB). Se il telefono non trova il server entro 90 s dal boot, resta nel
  rescue con dropbear (chiave singola `kimi-dubai`).
- Boot del telefono: `fastboot boot out/images-nbd-2026-11-12/boot-dubai-csot-UNTESTED.img`
  (kernel CI + initramfs NBD a chiave singola, DTB csot). Non consuma retry
  di slot, non flasha nulla. `dtbo_b` vuoto (pmOS) già presente sul device.
- **Recovery manuale dal rescue** (boot che perde la finestra NBD):
  da root nel rescue: `nbd-client 172.16.42.2 -N omamobile /dev/nbd0`,
  `mkdir -p /newroot && mount /dev/nbd0 /newroot`, poi da un processo
  staccato (`setsid nohup sh -c '... &'`): `killall dropbear; sleep 2;
  switch_root /newroot /sbin/init` — la SSH muore a killall, il boot
  completa comunque (~40 s e systemd è su). Usare path assoluti nel
  contesto staccato (`/usr/sbin/nbd-client` nel rescue, ma `/usr/bin/*`
  nel rootfs).

## 3. Accesso al telefono (rootfs attivo)

- SSH: `ssh -i ~/.ssh/kimi-dubai root@172.16.42.1` (root autorizzato,
  chiave del proprietario preservata) oppure `antona89@` (uid 1000).
- `antona89` ha sudo NOPASSWD (`/etc/sudoers.d/kimi`), gruppi wheel.
- Ogni boot del rescue cambia host key (dropbear `-R`): usare
  `-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null` oppure
  ripulire known_hosts. Hostname rootfs: `dubai`.
- Wi-Fi si associa da sola a `Vodafone-A45726846` (NM); orologio di sistema
  corretto una volta partito timesyncd/Wi-Fi; l'RTC del PMIC fa garbage
  dopo i poweroff (usare `date` solo a sistema avviato).

## 4. Da fare subito (ordine consigliato)

**Aggiornamento sessione successiva:** i tre pacchetti sensori sono stati
compilati e installati; `hexagonrpcd` passa 2 test. SSC risponde su QRTR ma
il registro non diventa disponibile e `monitor-sensor` non trova sensori.
Il daemon 0.4.0 rifiuta le scritture richieste dal firmware verso il registro
virtuale. Il proxy è stato fermato dopo il test; vedere `PROCESS.md` per
evidenze e prossima indagine. Non ripetere semplicemente la build/installazione.

**Prova successiva:** un daemon sperimentale con registro scrivibile confinato
ha prodotto misure SSC di luce e accelerazione; una regola udev temporanea ha
reso visibile l'accelerometro al proxy, ma l'orientamento non è ancora
verificato. Il daemon originale è stato ripristinato. Dettagli e limiti in
`PROCESS.md`; il daemon sperimentale non è installato permanentemente.

**Stato più recente:** il daemon sperimentale è ora installato sul rootfs NBD
con copia persistente del registro e sandbox; dopo un avvio temporaneo completo
il proxy segnala tilt e luce. Il client di rotazione è installato e attivo e
il proprietario ha confermato che lo schermo ruota e che il tocco funziona
dopo la richiesta di prova nei due orientamenti; avvii ripetuti restano da verificare.
Vedere `docs/SENSORS.md` per limiti e ripristino; questa nota sostituisce lo
stato di installazione riportato nei due paragrafi precedenti.

### 4.1 Stack sensori M11 (tutto pronto, manca solo build+install)

Sul telefono (rootfs, utente `antona89` per makepkg, sudo per pacman):

```sh
cd /home/antona89/dubai-pkgs/libssc
sudo -u antona89 makepkg -s --noconfirm      # fetch codeberg, meson
sudo pacman -U --noconfirm libssc-*.pkg.tar.*
cd ../hexagonrpcd
sudo pacman -S --noconfirm linux-headers     # makedepends
sudo -u antona89 makepkg -s --noconfirm
sudo pacman -U --noconfirm hexagonrpcd-*.pkg.tar.*
cd ../iio-sensor-proxy
sudo -u antona89 makepkg -s --noconfirm
sudo pacman -U --noconfirm iio-sensor-proxy-*.pkg.tar.*
```

Il registro SensorPD è già installato in
`/usr/share/qcom/sm7325/Motorola/dubai/{sensors,socinfo}` (308 file dal
pin FairBlobs `56c15ff4`; acdb/dsp esclusi come pmOS). La drop-in dubai fa
partire `hexagonrpcd -f /dev/fastrpc-adsp -d adsp -s -R
/usr/share/qcom/sm7325/Motorola/dubai` come utente `fastrpc` (sysusers del
pacchetto). Avviare `systemctl restart hexagonrpcd-adsp-sensorspd` (prima
disattivare/verificare la vecchia unit AUR 0.3.2 se ancora presente:
`systemctl list-unit-files | grep hexagonrpcd`), poi
`iio-sensor-proxy.service`, e testare con `monitor-sensor` / `gdbus` (bus
org.freedesktop.iio-sensor-proxy). Sensori attesi: accel+gyro (icm4x6xx),
magnetometro (mmc5603x), luce (stk3a5x).

### 4.2 M8 — wake source PMIC

`docs/SUSPEND.md` ha fatti e prossimi passi. In sintesi: pwrkey e RTC hanno
`power/wakeup: enabled` e l'IRQ RTC scatta a runtime, ma non svegliano il
s2idle. Correzione: il driver PDC è presente e abilitato; il DTS dubai lo
eredita da kodiak e l'IRQ padre SPMI passa da PDC hwirq 1. Prossimi passi:
(1) confrontare con pmOS su dubai (funziona lì?),
(2) catturare lo stato IRQ in sospensione con pm_debug_messages,
(3) esperimento irq-wake sul genitore spmi. **Non congelare senza una wake
source funzionante**: solo poweroff forzato (Power 10 s) recupera.

### 4.3 M9 — SIM

Con una SIM: sequenza in `docs/TELEPHONY.md` (uim card-status →
registrazione → dati rmnet_ipa0 → SMS → chiamate → LOC GNSS).

## 5. Invarianti e gotcha (appresi sul campo)

- **Moduli ↔ kernel**: con `CONFIG_DEBUG_INFO_BTF_MODULES=y` i moduli
  devono venire dalla stessa build del kernel in esecuzione, altrimenti
  `failed to validate module BTF: -22` e i sottosistemi collassano
  (remoteproc/ath11k/battmgr). I moduli CI sono in
  `/lib/modules/7.2.9-dubai+` (backup `.old`). Se si boota un kernel
  diverso, reinstallare i moduli corrispondenti dall'artifact CI.
- **Verifica kernel dopo il boot**: `dmesg | grep "Linux version"` deve
  dire `#1` (build CI). Un boot anomalo ha mostrato `#2` senza PM_DEBUG:
  rifare il ciclo pulito poweroff → fastboot → boot.
- **Verifica boot completo**: `systemctl is-system-running` (degraded con
  plymouth/uim/rmtfs attesi è OK). Se `pacman`/`systemctl` “not found” si
  è nel rescue, non nel rootfs.
- **Wakealarm RTC**: usare tempo assoluto **da `/sys/class/rtc/rtc0/since_epoch`**
  (`echo $(( $(cat /sys/class/rtc/rtc0/since_epoch) + N )) > /sys/class/rtc/rtc0/wakealarm`);
  `$(date +%s)` su Arch NTP è nel 2026 mentre l'RTC PMK8350 resta nel 1970 (56 anni di scarto) e la sintassi `+N` legge garbage. `rtcwake` segfaulta: usare sysfs.
- **Wi-Fi dopo boot**: se `wld0` manca: `modprobe ath11k_ahb`; se BDF -2:
  `rmmod ath11k_ahb`, bounce WPSS (`echo stop/start >
  /sys/class/remoteproc/remoteproc2/state`), `modprobe ath11k_ahb`.
- **Modem**: `remoteproc0` parte solo con rmtfs `-s` installato; EFS
  scrivibile solo con approvazione del proprietario (backup modemst1/2 in
  `/var/tmp/` del rootfs, 11-11).
- **USB**: una sola istanza di test alla volta — due freeze concorrenti
  danno EBUSY su `/sys/power/state` e stati incoerenti.
- **ufw.service fallisce** nel rootfs (`/etc/ufw/user.rules` sporco da un
  poweroff forzato): riparare o mascherare; il firewall critico è sul host
  (`sudo ufw allow from 172.16.42.0/24`).

## 6. Repo e CI

- Repo: `https://github.com/Lwb89dev/dubai-omarchy-porting`, branch `main`.
  Push come Lwb89dev (gh autenticato, scope `workflow`).
- CI verde su ogni push; artifact (Image/DTB/moduli/initramfs/SHA256) si
  scaricano con `gh run download <run-id> -n dubai-offline-artifacts`.
- Kernel staging locale: `work/kernel-ci-staging/` (layout KERNEL_OUT con
  artifact CI), immagini in `out/images-nbd-2026-11-12/`.
- Identità commit: `Lwb89dev <84742481+Lwb89dev@users.noreply.github.com>`.
- Token: lo scambio a fine sessione ha esaurito la quota Kimi; il lavoro
  passa a Codex — questo file è il contratto di consegna.
