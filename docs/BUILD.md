<!-- SPDX-License-Identifier: MIT -->
# Build riproducibili

## Prerequisiti host

Pop!_OS/Ubuntu 24.04: Docker funzionante, QEMU AArch64 binfmt con flag `F`, Git, Python 3, ShellCheck, curl, cpio, gzip, zstd e GnuPG. Il kernel viene compilato nel container `docker/Dockerfile.kernel`, basato sul digest Ubuntu 24.04 fissato da Omarchy Mobile e dotato di GCC AArch64 e LLVM/Clang.

Build GCC predefinita:

```sh
scripts/fetch-sources.sh
docker build -f docker/Dockerfile.kernel -t dubai-kernel-builder:24.04 docker
docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp -e JOBS=16 \
  -v "$PWD:$PWD" -w "$PWD" dubai-kernel-builder:24.04 scripts/build-kernel.sh
scripts/build-initramfs.sh
scripts/verify-images.sh
tests/static.sh
```

Build LLVM di confronto, allineata alla toolchain pmaports/Nura e con output separato:

```sh
docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp -e JOBS=16 -e LLVM=1 \
  -e KERNEL_OUT="$PWD/out/kernel-llvm" -v "$PWD:$PWD" -w "$PWD" \
  dubai-kernel-builder:24.04 scripts/build-kernel.sh
KERNEL_OUT="$PWD/out/kernel-llvm" scripts/verify-images.sh
KERNEL_OUT="$PWD/out/kernel-llvm" IMAGE_OUT="$PWD/out/images-llvm" \
  PANEL=csot scripts/build-images.sh
```

Per abilitare SSH nella diagnostica, passare esplicitamente **solo una chiave pubblica**:

```sh
SSH_PUBLIC_KEY="$HOME/.ssh/id_ed25519.pub" scripts/build-initramfs.sh
```

Senza chiave sono disponibili solo console locale/seriale; non vengono raccolte automaticamente tutte le chiavi dell'host.

## Artefatti

- `out/kernel/arch/arm64/boot/Image` e `Image.gz`; analoghi sotto `out/kernel-llvm`
- `out/kernel*/arch/arm64/boot/dts/qcom/sm7325-motorola-dubai-{csot,tianma}.dtb`
- `out/kernel*/config.final`, `modules-7.2.9-dubai+.tar.zst`, `SHA256SUMS`
- `out/initramfs/initramfs-dubai.cpio.gz`, log e checksum
- log di build in `out/*/logs/`

Il fragment GCC disabilita Clang LTO/BTF; quello LLVM conserva thin-LTO/BTF di pmaports. Entrambi rendono built-in il gadget NCM/ACM e abilitano ramoops. Il tree SC7280 compila NT37701 come modulo tramite `obj-m`. Non cambia DTS o driver. `scripts/validate-dtbs.sh` esegue `dtbs_check` con dtschema 2026.9.

## Boot image

`scripts/fetch-boot-tools.sh` recupera il `mkbootimg.py` AOSP fissato e ne verifica gli SHA-256:

```sh
scripts/fetch-boot-tools.sh
PANEL=csot scripts/build-images.sh
```

L'output contiene `UNTESTED` e un marker `NOT-FOR-FLASH`. Compilare non valida il boot né autorizza il flash. Per questo esemplare sono state generate anche varianti sotto `out/images-llvm` e `out/images-nura`; i risultati hardware sono registrati in `PROCESS.md` e `docs/RECOVERY-RUNBOOK.md`.

## Rootfs Arch/Omarchy

`scripts/build-rootfs.sh --prepare-only` crea `work/omarchy-dubai` alla revisione upstream fissata e applica solo descriptor, device package e package list di questo port. I sorgenti upstream restano invariati.

`scripts/build-rootfs.sh --build` usa gli script upstream: crea una chiave locale non pubblicata, scarica in parallelo solo i pacchetti dubai con indice/firme/SHA-256 verificati, compila solo `omamobile-device-dubai`, usa Mesa ALARM con Freedreno e invoca `tools/build-rootfs`. Per la coerenza delle librerie, Hyprland 0.57.1-2 e aquamarine 0.16.0-1.1 provengono dai binari firmati Omarchy edge fissati in `sources.lock`; Omarchy resta al pin 4.0.6. Richiede il tarball dei moduli dello stesso kernel. Log in `out/rootfs/logs/build.log`. Non scrive sul telefono.

L'immagine, il checksum e il manifest vengono pubblicati in `work/omarchy-dubai/out/dubai/` come `omamobile-rootfs-dubai-<data>-aarch64.img.zst`, `.img.zst.sha256` e `.MANIFEST`. Il builder esegue automaticamente `tests/rootfs-smoke` prima della pubblicazione; una build rootfs riuscita non equivale a un boot verificato sul dispositivo.

## Initramfs hardware e rootfs NBD

La build initramfs accetta `KERNEL_OUT` per includere i moduli, `FIRMWARE_DIR` per SQE/GMU da linux-firmware, `DUBAI_ZAP_FIRMWARE` per lo zap specifico del proprietario e `NBD_SERVER` per il rootfs remoto opzionale. Il blob zap `qcm6490` generico non è compatibile come sostituto. La variante usata per dubai è:

```sh
INITRAMFS_OUT="$PWD/out/initramfs-nbd" KERNEL_OUT="$PWD/out/kernel-llvm" \
  FIRMWARE_DIR=/usr/lib/firmware DUBAI_ZAP_FIRMWARE=<private-dubai-a660_zap.mbn> \
  SSH_PUBLIC_KEY="$HOME/.ssh/id_ed25519.pub" \
  NBD_SERVER=172.16.42.2 scripts/build-initramfs.sh
KERNEL_OUT="$PWD/out/kernel-llvm" \
  INITRAMFS="$PWD/out/initramfs-nbd/initramfs-dubai.cpio.gz" \
  IMAGE_OUT="$PWD/out/images-nbd" PANEL=csot scripts/build-images.sh
```

`KERNEL_OUT` è accettato anche da `scripts/build-rootfs.sh --build` per mantenere kernel e moduli coerenti. Il server usa una copia raw e snapshot temporanei:

```sh
zstd -q -d --sparse -f \
  work/omarchy-dubai/out/dubai/omamobile-rootfs-dubai-2026.11.07-aarch64.img.zst \
  -o work/rootfs-dubai-2026.11.07.img
FIRSTBOOT_CONF=<private-firstboot.conf> SSH_PUBLIC_KEY="$HOME/.ssh/id_ed25519.pub" \
  DUBAI_ZAP_FIRMWARE=<private-dubai-a660_zap.mbn> scripts/provision-nbd-rootfs.sh
qemu-nbd --format=raw --snapshot --persistent --bind=172.16.42.2 --port=10809 \
  --export-name=omamobile work/rootfs-dubai-2026.11.07.img
```

Il provisioning modifica soltanto la copia raw e verifica contenuto ed ext4. La chiave pubblica del repository locale va aggiunta e firmata localmente sul telefono come azione del proprietario (`pacman-key --add`, poi `pacman-key --lsign-key` con il fingerprint della build); non viene inserita nel keyring upstream.

`--persistent` impedisce al server di terminare quando il client si disconnette. La initramfs attende fino a 90 secondi che l'host abbia configurato `172.16.42.2/24` e verifica che `/dev/nbd0` abbia una capacità non nulla prima del mount. Root nella initramfs ha la password vuota perché Alpine 3.24 lo marca bloccato e dropbear ne rifiuterebbe anche la chiave; dropbear resta avviato con `-s -g`, quindi il login SSH resta esclusivamente su chiave pubblica.

NBD non è il default: senza `/etc/omamobile-nbd-server` resta attiva la shell diagnostica. L'immagine NBD non scrive su `userdata` e non pubblica firmware o credenziali.

## CI

`.github/workflows/offline-build.yml` esegue lint, preparazione rootfs, kernel, DTB, initramfs e verifica checksum. Non contiene comandi ADB/fastboot e non pubblica firmware.
