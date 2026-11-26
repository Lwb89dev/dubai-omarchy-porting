<!-- SPDX-License-Identifier: MIT -->
# Handoff 2026-11-12 — stato vivo del port e istruzioni per proseguire

Questo documento è il punto di ingresso per chi riprende il lavoro (umano o
agente). Stato rilevato il 2026-11-12 sera; leggere anche `PROCESS.md`
(stato corrente) e `PROGRESS.md` (log completo).

**Aggiornamento 2026-11-26:**
- **Implementazione parallela OV50A/OV32B40 + diagnosi LPASS/BT + verifica autorotate (`192.168.1.164`, 2026-11-26 sera):**
  - Estratti in sola lettura da `/dev/sde26` (`super` -> `vendor`) i blob Chromatix `com.qti.sensormodule.mot_dubai_{ov50a_sunny,ov32b40_ofilm,s5kjn1_qtech,gc02m1b_hlt}.bin` + `.so` in `private-capture/2026-11-26/camera-blobs/` (fuori dal repo Git). Verificato dai registri (`0x4888=0x80`, `laneAssign=0x0210`, `op_px_clk` C-PHY 16/7×3) che **sia OV50A sia OV32B40 usano MIPI CSI-2 C-PHY a 3 trio** (`bus-type = <1>`, `data-lanes = <0 1 2>`, supportato nativamente da `qcom_camss` SC7280).
  - Create e validate le patch kernel **`0010`** (`drivers/media/i2c/ov50a.c`, `5041`, 5 modi `4096x3072@30`, `8192x6144@22`, `2048x1536@60`, `1920x1080@120`, `1280x720@240`, link-freq `962`/`980` MHz), **`0011`** (`drivers/media/i2c/ov32b40.c`, `3242`, 2 modi `3264x2448@30`, `6528x4896@15`, link-freq `450` MHz) e **`0012`** (schemi `ovti,ov50a.yaml`, `ovti,ov32b40.yaml`, cablaggio DT `ov50a` con VCM `ak7375` su `&cci1_i2c0`/`port@1` e `ov32b40` su `&cci0_i2c0`/`port@0` in `sm7325-motorola-dubai-common.dtsi`), abilitati `CONFIG_VIDEO_OV50A=m` e `CONFIG_VIDEO_OV32B40=m` in `device/dubai/kernel{,-llvm}.config`.
  - Aggiornati `packages/libcamera/` (`dubai-sensor-helpers.patch` con `CameraSensorHelperOv50a` e `CameraSensorHelperOv32b40` `1/256`, `pkgrel=4.27`), `packages/omamobile-device-dubai/` (`omacam-lenses.toml` a 3 lenti: `ov50a` `main`, `s5kjn1` `ultrawide`, `ov32b40` `front`, `pkgrel=20`), e `tests/camera-pipewire.sh` (`4` sorgenti).
  - Isolati su `192.168.1.164` due ulteriori blocker di ADSP/`cx` sleep: `lpass-{rx,tx,va}-macro.c` abilitano `macro`/`dcodec` (`LPASS_HW_MACRO`/`LPASS_HW_DCODEC`) in `_probe()` ma non li disabilitano in `runtime_suspend()` (refcount `1` residuo visibile su `3370000.codec` anche in stato `suspended`) né hanno `SYSTEM_SLEEP_PM_OPS`; e `rfkill block bluetooth` manda subito `99c000.serial` in `suspended` (`gcc_qupv3_wrap0_s7_clk` `0`). Aggiunta **`0013-ASoC-codecs-lpass-macro-drop-clock-votes-on-suspend.patch`**.
  - Compilati offline con LLVM zero errori/warning `ov50a.o`, `ov32b40.o`, `lpass-{rx,tx,va}-macro.o`, entrambi i DTB CSOT/Tianma, superati `git apply` sequenziale su `0001..0013`, `dt-doc-validate`, e `dtschema 2026.9` (`14` errori noti allowlisted per pannello, `0` inattesi, `0` stale). Confermato live nel journal di `192.168.1.164` che `omamobile-autorotate` è attivo e applica `DSI-1: transform 0/1/3`. Prossimo passo: push + rebuild CI (kernel + pacchetti), installazione ed esecuzione test live delle 4 camere, `s2idle` con `fw_devlink.sync_state=timeout` + `0013`, e verifica visiva R/B Bayer su OV50A/OV32B40.
- **Flash standalone `boot_b`, avvio a freddo, `qbootctl` e fix sensori (`0.1.0-17`):**
  - Verificati gli SHA-256 di `work/kernel-ci-8954580/` e `out/images-userdata-8954580/boot-dubai-csot-UNTESTED.img` (`vibrator@58` nel DTB CSOT), avviata prima in `fastboot boot` temporaneo (`19.852s`) e poi, con consenso esplicito del proprietario (`product=dubai`, `current-slot=b`, `slot-retry-count:b: 5`, `battery-voltage=3883 mV`), flashata su `boot_b` (`1.189s`, `dtbo_b` invariato).
  - Avviato a freddo direttamente da `boot_b` su `/dev/sde27` (`19.370s` totali, `graphical.target` `3.262s`, unica unit fallita `plymouth-start.service`), eseguito `/usr/lib/omamobile/dubai-qbootctl-mark-successful` (`SLOT _b: Marked boot successful`, `is marked bootable` / `is marked successful`; tutte le altre LUN/partizioni `ro=1`), con `aw86927-haptics` su `4-0058` (`input4`, `ff=107030000 0`), `qcom-battmgr-bat` + `upower` (`warning-level: none` al `4%`), tutti e 4 i remoteproc, `wld0`, `hci0`, `ModemManager` e `s5kjn1`/`gc02m1b`.
  - Misurato `ssccli --sensor accelerometer` a schermo in su (`325.78 lux`): `X≈0.44, Y≈0.08, Z≈+9.79 m/s²`. Aggiornato [81-libssc-motorola-dubai.rules](packages/omamobile-device-dubai/81-libssc-motorola-dubai.rules) a `-1, 0, 0; 0, -1, 0; 0, 0, 1` (`omamobile-device-dubai 0.1.0-17`), installato su `/dev/sde27`: `monitor-sensor` ora riporta **`tilt: face-up`** (`330.85 lux`, bussola `303.1°–303.3°`, `omamobile-autorotate` `active`).
  - Risolto il B/W in `omacam` e abilitato autofocus `ak7375`: con `omacam-lenses.toml` (`s5kjn1` `main`, `preview = [1920, 1440]` `42.2 MiB` CMA `30.0 fps` su Adreno eGL + `s5kjn1.yaml`, `still = [4080, 3072]` `96.0 MiB` CMA -> `6.9 MiB` JPEG) il proprietario ha confermato i colori reali su `s5kjn1`; portate poi da `omarchy-mobile` le patch `0.7.2` di autofocus a contrasto (`ak7375 17-000c`), tap-to-focus, EV/manuale e cleanup EGL in `libcamera 0.7.2-4.26` insieme a `autofocus = true` in `omamobile-device-dubai 0.1.0-19` (`IPASoftAf` `0–4095`, `511/127`, `Autofocus completed at 2608`) e confermata anche la messa a fuoco in `omacam`. Frontale `ov32b40` e main `ov50a` restano senza driver mainline Linux.
  - Follow-up offline `sync_state` + mapping camere: tracciato dai log che `chosen:framebuffer` + `3d6a000.gmu` bloccano `sync_state()` su `gcc-sc7280`/`gpu_cc-sc7280`/`disp_cc-sc7280` lasciando 6 GDSC bloccati `on` (`disp_cc_mdss_core_gdsc`, `mmnoc` TBU, `ufs_phy`, `usb30_prim`); abilitato `CONFIG_FW_DEVLINK_SYNC_STATE_TIMEOUT=y` in `device/dubai/kernel{,-llvm}.config` e generata l'immagine test `out/images-userdata-8954580-syncstate/boot-dubai-csot-UNTESTED.img` (`fw_devlink.sync_state=timeout`). Verificato inoltre in `yupik-camera-sensor-mot-dubai-overlay.dtsi` + `camss.c` che `s5kjn1` è `sensor_wide` (`cci0_i2c1@56`, `csiphy2`, `MCLK3`), `gc02m1b` è `sensor_depth` (`cci1_i2c1@37`, `csiphy3`, `MCLK1`), mentre `ov50a` (`sensor_main` OIS, `cci1_i2c0`, `csiphy1`, `MCLK0`) e `ov32b40` (`sensor_front`, `cci0_i2c0`, `csiphy0`, `MCLK2`) attendono l'estrazione in sola lettura da `/dev/sde26` (`super` -> `vendor`).
  - Prossimi passi (telefono collegato e carico): testare `out/images-userdata-8954580-syncstate/boot-dubai-csot-UNTESTED.img` via `fastboot boot` + isolamento `pmic_glink`/`q6*` per `adsp`/`aosd`/`cxsd`, estrarre da `/dev/sde26` (`super`) i moduli Android `ov50a` e `ov32b40` per scrivere i driver V4L2 + nodi DTS, e confermare la rotazione fisica dello schermo.

**Aggiornamento 2026-11-25:**
- **Verifica su hardware della build CI `7b48084` su `/dev/sde27` (batteria senza `0006` + aptica `AW86224` a `0x58`):**
  - Riattivato slot `_b` (`fastboot set_active b`, retry `7`), avviata rescue `7b48084` e sincronizzati i `636` moduli `7.2.9-dubai+` su `/dev/sde27` (vecchi in `.old`).
  - `modprobe aw86927` a `4-005a` dava `-ENXIO`: `i2cdetect`/`i2cget` su `i2c-4` hanno confermato che l'`AW86224` su `dubai` risponde a **`0x58`** (`CHIPID=0x00`, `EFRD9=0xb4`, come `aw862xx_i2c_addr = <0x58>` nel DTS downstream). Corretta la patch `0009` a `vibrator@58` (`reg = <0x58>`) e avviato Arch su `/dev/sde27` (`19.908s`, `graphical.target` `3.687s`, solo `plymouth-start.service` failed): `aw86927-haptics` (`4-0058`, `input4`, `SYSER=0x00`) ha eseguito `FF_RUMBLE` con vibrazione fisica confermata dal proprietario.
  - Su `qcom-battmgr-bat` senza `0006` sotto USB `SDP` (`limit=100000`) `charge_now` è calato `114492 -> 114083` uAh con `current_now = -281681 -> -264896` µA (segno negativo reale in scarica) e `upower -d` (`discharging`, `0.693 W`, `warning-level: none`).
  - Verificato `dubai-qbootctl-mark-successful --check` (`SLOT _b: ready to mark successful via /dev/sdd and /dev/sdf (dry-run)`). Prossimo passo: commit/push di `0009` (`vibrator@58`) per avere la build CI pulita, poi flash standalone `boot_b` e test `dubai-qbootctl-mark-successful`.

**Aggiornamento 2026-11-24:**
- **M8 pacchettizzato e isolamento `adsp`/`wpss` su `/dev/sde27`:**
  - `omamobile-device-dubai 0.1.0-14` (`75-dubai-bluetooth.rules`) imposta `99c000.serial/power/wakeup=disabled` al boot freddo; verificato scan BT `bluetoothctl --timeout 4 scan on` sia prima sia dopo wake `s2idle`.
  - Test unplugged `VBUS=0uV` isolati: `31s` (`iio-sensor-proxy`/`hexagonrpcd`/PipeWire fermi, `sde27-step2-isolated.log`) e `16s` (`a600000.usb/power/control=auto`, `rmmod ath11k_ahb`, `sde27-step2b-ath-usb.log`) tutti svegliati su `IRQ 115`, cluster `S2` 100%, `cdsp`/`modem`/`wpss` in sleep, consumo in standby sceso a `34.5 mA` (`4.293 V`). `adsp`, `aosd` e `cxsd` restano `0` (ADSP/audio/`pmic_glink` e voto `cx` `128` di `99c000.serial`). Nota: lasciare `a600000.usb=auto` impedisce il re-enum USB al ricollegamento cavo (tenere `on`); con Hyprland 0.57 usare `hyprctl eval 'hl.dsp.dpms("on")'` per riaccendere il pannello dopo blanking.
- **Batteria `qcom-battmgr` (`0006` rimossa) e sicurezza UPower (`0.1.0-15`):** dimostrato che `BATT_CURR_NOW` usa già il segno Linux (con `0006` anche la scarica reale appariva positiva: su USB `SDP` `input_current_limit=100000` la carica calava `110403 -> 107131` con segno `+`). Rimossa `kernel/patches/0006-qcom-battmgr-sm7325-current-sign.patch` (serve rebuild kernel CI) e aggiunto `90-dubai-battery.conf` (`UsePercentageForPolicy=false`) in `omamobile-device-dubai 0.1.0-15`: `upower -d` ora segna `warning-level: none` finché `time_to_empty > 0` evitando spegnimenti mentre `capacity=2%` (QBG desincronizzato da ricariche a telefono spento/fastboot).
- **Camere (`libcamera 0.7.2-4.25`), `qbootctl` (`0.1.0-16`) e `AW86224` (`0008`+`0009`):**
  - `libcamera` `0.7.2-4.25` installato su `/dev/sde27` con `s5kjn1.yaml` e `0005-ipa-simple` (`wireplumber` carica `s5kjn1.yaml` e `IPASoft: gain 1-64 (1)`, `max_chroma_diff` `33 -> 130`; da verificare `omacam` inquadrando un soggetto illuminato a colori); `ov50a` e `ov32b40` non hanno driver in `sources/linux-sc7280`.
  - Installato `qbootctl 0.2.2-1` e pacchettizzato `/usr/lib/omamobile/dubai-qbootctl-mark-successful` + unit disabilitata in `omamobile-device-dubai 0.1.0-16` (`--check` verificato su `/dev/sde27`, nessun flash/scrittura eseguito).
  - Preparate e validate offline (`clang`, `checkpatch.pl`, `dtschema 2026.9`) le patch kernel `0008` (AW86224 in `aw86927.c`) e `0009` (`vibrator@5a` su `&i2c4`), pronte per il prossimo build CI del kernel.

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
