<!-- SPDX-License-Identifier: MIT -->
# Handoff 2026-11-12 — stato vivo del port e istruzioni per proseguire

Questo documento è il punto di ingresso per chi riprende il lavoro (umano o
agente). Stato rilevato il 2026-11-12 sera; leggere anche `PROCESS.md`
(stato corrente) e `PROGRESS.md` (log completo).

**Aggiornamento 2026-11-23 (notte):**
- **Storage persistente interno su `userdata` (`/dev/sde27`) attivo e verificato:** con autorizzazione del proprietario (LineageOS sacrificabile) e dopo l'aggiunta di `zram-generator 1.2.1-1` (`3.6 GiB` `zstd` swap, `rootfs/packages.base` + `omamobile-device-dubai 0.1.0-12`) e `10-dubai-storage.rules` (`omamobile-device-dubai 0.1.0-13`), il rootfs verificato è stato clonato su `/dev/sde27` (`107 GiB` ext4 `omamobile-root`, `9.7 GiB` usati, `96 GiB` liberi) e avviato via `fastboot boot` con `out/images-userdata/boot-dubai-csot-UNTESTED.img` (`UFS_RW=userdata`, `ROOT_DEVICE=userdata`). Boot completo in `22.088s` (`graphical.target` `6.815s`), `/dev/sde` assente, **solo `sde27` scrivibile** e tutte le altre partizioni/LUN (`sda`–`sdd`, `sde1`–`sde26`, `sdf`) a `ro=1`, ZRAM `3.6G` attivo al cold boot, tutti e 4 i remoteproc, Wi-Fi, BT, sensori, ModemManager e ricarica attivi. `boot_b` su flash non è ancora stato aggiornato (resta il rescue 2026-11-07; `slot-retry-count:b: 0`).

**Aggiornamento 2026-11-23 (sera):**
- **M8 unplugged (`VBUS = 0 uV`) verificato in RAM rescue:** con cavo USB-C scollegato fisicamente (`VBUS_BEFORE=0uV`, `VBUS_AFTER=0uV`), il freeze `s2idle` è durato **26 s** svegliandosi su `IRQ 115` (`pm8xxx_rtc_alarm`, `fail=0`, `S2` `cluster_sleep_llcc_off`). Documentata la causa per cui `aosd`/`cxsd` restano `0` nella RAM rescue (il `sync_state()` di `qcom-rpmhpd` resta pendente senza i 4 remoteproc/`video-codec`, e `a600000.usb` resta `active` con `role=device` e `port-1 HS-PHY not in L2`).
- **Cold-boot su `work/rootfs-dubai-2026.11.13-recovery.qcow2`:** con tutti e 4 i remoteproc avviati, `qcom-rpmhpd` completa `sync_state()` e `qcom_stats` registra sleep reali su `cdsp` (`Count: 120`), `modem` (`Count: 66`) e `wpss` (`Count: 3`), mentre `adsp` resta a `0` (PipeWire/sensori attivi). Compilati e installati sul rootfs di recupero i pacchetti **`omamobile-device-dubai 0.1.0-11`** e **`omamobile-ucm-dubai 0.1.0-3`** insieme a `dummystreamhack`; verificato D-Bus `org.mobian_project.CallAudio` (`dubai-callaudiod`) su PipeWire 1.6.11 (`SelectMode`/`EnableSpeaker` = `true`).
- **M10/M11 misure e audit:** `systemd-analyze` `24.085s` (`graphical.target` `8.403s`), RAM idle `3437/7367 MiB` (`SwapTotal: 0`, `CONFIG_ZRAM=y` senza `zram-generator` configurato — rilevante per variante 6 GB), Hyprland `1080x2400@144Hz` Freedreno OpenGL 4.6 / GLES 3.2, tempi lancio app (`omacalc` 535 ms, `omamessages` 817 ms, `omacam` 1028 ms, `omaphone` 1189 ms), `monitor-sensor` live (`263.33 lux`, bussola `268.9°–355.4°`), confinamento `/var/lib/dubai-hexagonrpc` verificato (`0` symlink, nessun mount `/mnt/vendor/persist`), `AW86224` presente solo come pinctrl nel DTS (`gpio46`/`gpio47`).

**Aggiornamento 2026-11-23:**
- **M8 wake da tasto Power (`pmic_pwrkey`, `IRQ 116`) e PSCI OSI cluster `S2` (`cluster_sleep_llcc_off`) verificati su hardware:** in RAM rescue (`7.2.9-dubai+ #1`, tutte le 6 LUN UFS `ro=1`, batteria ricaricata da `3.429 V` a `3.796 V` con display in blanking), una pressione fisica del tasto Power dentro una finestra `s2idle` di 300 s ha svegliato il telefono al **22° secondo** (`pm_wakeup_irq=116`, `PM: Triggering wakeup from IRQ 116`, `IRQ 116: 4 → 5, 1`), seguita da una seconda conferma a **3 s** su una finestra di 30 s (`suspend_stats/success=5, fail=0`). In `debugfs`, `/sys/kernel/debug/pm_genpd/power-domain-cluster/idle_states` (`18200000.rsc`) conferma che il cluster APSS entra nello stato più profondo **`S2` (`cluster_sleep_llcc_off`, `0x4100b344`)** nel **100% dei cicli `s2idle` (`Usage: 5, Rejected: 0, S2idle: 5`)** ed esegue `S0`/`S1` (`cluster_sleep_cx_ret`) per > 749 s in idle runtime. Il blanking di `fb0` (`echo 4 > /sys/class/graphics/fb0/blank`) azzera il voto `256` del display su `cx`, mentre con VBUS presente `a600000.usb` mantiene attivo `gcc_usb30_prim_gdsc` (`256`) e nella RAM rescue i 4 DSP (`adsp`, `cdsp`, `wpss`, `mpss`) non sono avviati (`qcom_stats` SMEM vuoti). Connessione `nbd-client` verificata anche sul nuovo host Omarchy 4.5.0 (`NBD_CONNECT=OK size=12884901888`). Vedi `docs/SUSPEND.md`.

**Aggiornamento 2026-11-22:**
- **M8 sbloccato sul wake PMIC:** 4 cicli `s2idle` reali in RAM rescue (6 s, 11 s con `usb0` giù, 11 s con UDC sganciato, 61 s) si sono svegliati tutti pulitamente su `IRQ 115` (`pm8xxx_rtc_alarm`, `suspend_stats/success=4`). I fallimenti del 12/11 erano dovuti a due bug combinati: offset di 56 anni tra `date +%s` (2026 via NTP) e `/sys/class/rtc/rtc0/since_epoch` (1970 hardware PMK8350), più deadlock NBD quando `usb0` veniva spento su rootfs NBD. Entrambi corretti in `scripts/device-suspend-tests.sh` (dettagli in `docs/SUSPEND.md`). Restano da verificare: pressione Power dentro la finestra `s2idle` e `qcom_stats/{aosd,cxsd}` a cavo USB scollegato.
- **M9 completato su hardware con SIM fisica (registrazione, 4G LTE data, SMS, chiamate voce capsula + vivavoce, GNSS):** estratti in sola lettura via `debugfs` i file RFS Motorola da `persist:/rfs/msm/mpss` (`dhob.bin`, `shob.bin`, `datablock/*`, `cal_rfs/*`, `mot_rfs/imei_sv`) in `/var/lib/tqftpserv` (tutte le 6 LUN UFS `ro=1`) e impostato `--dms-set-operating-mode=online` in `dubai-uim-selection`, la USIM passa a `ready`, il modem si registra in 4G LTE / 5G NR (`FASTWEB`), naviga su `qmapmux0.0` (`rmnet_ipa0`, ping + HTTPS verificati), riceve SMS in `omatel-agent`, espone GPS NMEA live (`$GPGSV`) e gestisce chiamate voce bidirezionali sia su **capsula auricolare** sia su **vivavoce (Speakerphone)** tramite `dummystreamhack`, `omamobile-ucm-dubai 0.1.0-3` e `dubai-callaudiod` (`omamobile-device-dubai 0.1.0-11`). Vedi `docs/TELEPHONY.md`.
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
