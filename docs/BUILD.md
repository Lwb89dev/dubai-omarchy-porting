<!-- SPDX-License-Identifier: MIT -->
# Reproducible builds

## Host prerequisites

Pop!_OS/Ubuntu 24.04: working Docker, QEMU AArch64 binfmt with the `F` flag, Git, Python 3, ShellCheck, curl, cpio, gzip, zstd, and GnuPG. The kernel is built in the `docker/Dockerfile.kernel` container, based on the Ubuntu 24.04 digest pinned by Omarchy Mobile and equipped with AArch64 GCC and LLVM/Clang.

Default GCC build:

```sh
scripts/fetch-sources.sh
docker build -f docker/Dockerfile.kernel -t dubai-kernel-builder:24.04 docker
docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp -e JOBS=16 \
  -v "$PWD:$PWD" -w "$PWD" dubai-kernel-builder:24.04 scripts/build-kernel.sh
scripts/build-initramfs.sh
scripts/verify-images.sh
tests/static.sh
```

Comparison LLVM build, aligned with the pmaports/Nura toolchain and with separate output:

```sh
docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp -e JOBS=16 -e LLVM=1 \
  -e KERNEL_OUT="$PWD/out/kernel-llvm" -v "$PWD:$PWD" -w "$PWD" \
  dubai-kernel-builder:24.04 scripts/build-kernel.sh
KERNEL_OUT="$PWD/out/kernel-llvm" scripts/verify-images.sh
KERNEL_OUT="$PWD/out/kernel-llvm" IMAGE_OUT="$PWD/out/images-llvm" \
  PANEL=csot scripts/build-images.sh
```

To enable SSH in the diagnostic image, pass **only a public key**, explicitly:

```sh
SSH_PUBLIC_KEY="$HOME/.ssh/id_ed25519.pub" scripts/build-initramfs.sh
```

Without a key, only the local/serial console is available; the host's keys are not collected automatically.

## Artifacts

- `out/kernel/arch/arm64/boot/Image` and `Image.gz`; the equivalents under `out/kernel-llvm`
- `out/kernel*/arch/arm64/boot/dts/qcom/sm7325-motorola-dubai-{csot,tianma}.dtb`
- `out/kernel*/config.final`, `modules-7.2.9-dubai+.tar.zst`, `SHA256SUMS`
- `out/initramfs/initramfs-dubai.cpio.gz`, logs, and checksums
- build logs in `out/*/logs/`

The GCC fragment disables Clang LTO/BTF; the LLVM fragment keeps the pmaports thin-LTO/BTF. Both build the NCM/ACM gadget in and enable ramoops. The SC7280 tree builds NT37701 as a module through `obj-m`. It does not change the DTS or drivers. `scripts/validate-dtbs.sh` runs `dtbs_check` with dtschema 2026.9.

## Boot image

`scripts/fetch-boot-tools.sh` fetches the pinned AOSP `mkbootimg.py` and checks its SHA-256:

```sh
scripts/fetch-boot-tools.sh
PANEL=csot scripts/build-images.sh
```

The output contains `UNTESTED` and a `NOT-FOR-FLASH` marker. Compiling does not validate the boot and does not authorize a flash. For this unit, variants were also generated under `out/images-llvm` and `out/images-nura`; the hardware results are recorded in `PROCESS.md` and `docs/RECOVERY-RUNBOOK.md`.

## Arch/Omarchy rootfs

`scripts/build-rootfs.sh --prepare-only` creates `work/omarchy-dubai` at the pinned upstream revision and applies only this port's descriptors, device package, and package list. The upstream sources stay unchanged.

`scripts/build-rootfs.sh --build` uses the upstream scripts: it creates an unpublished local key, downloads in parallel only the dubai packages with index/signatures/SHA-256 verified, builds only `omamobile-device-dubai` and `omamobile-ucm-dubai`, uses ALARM Mesa with Freedreno, and invokes `tools/build-rootfs`. For library consistency, Hyprland 0.57.1-2 and aquamarine 0.16.0-1.1 come from the signed Omarchy edge binaries pinned in `sources.lock`; Omarchy stays at pin 4.0.6. It requires the module tarball of the same kernel. Log in `out/rootfs/logs/build.log`. It does not write to the phone.

The image, checksum, and manifest are published in `work/omarchy-dubai/out/dubai/` as `omamobile-rootfs-dubai-<date>-aarch64.img.zst`, `.img.zst.sha256`, and `.MANIFEST`. The builder automatically runs `tests/rootfs-smoke` before publication; a successful rootfs build is not the same as a verified boot on the device.

## Hardware initramfs and NBD rootfs

The initramfs build accepts `KERNEL_OUT` to include the modules, `FIRMWARE_DIR` for SQE/GMU from linux-firmware, `DUBAI_ZAP_FIRMWARE` for the owner's specific zap, and `NBD_SERVER` for the optional remote rootfs. The generic `qcm6490` zap blob is not a compatible substitute. The variant used for dubai is:

```sh
INITRAMFS_OUT="$PWD/out/initramfs-nbd" KERNEL_OUT="$PWD/out/kernel-llvm" \
  FIRMWARE_DIR=/usr/lib/firmware DUBAI_ZAP_FIRMWARE=<private-dubai-a660_zap.mbn> \
  SSH_PUBLIC_KEY="$HOME/.ssh/id_ed25519.pub" \
  NBD_SERVER=172.16.42.2 scripts/build-initramfs.sh
KERNEL_OUT="$PWD/out/kernel-llvm" \
  INITRAMFS="$PWD/out/initramfs-nbd/initramfs-dubai.cpio.gz" \
  IMAGE_OUT="$PWD/out/images-nbd" PANEL=csot scripts/build-images.sh
```

`KERNEL_OUT` is also accepted by `scripts/build-rootfs.sh --build` so the kernel and modules stay consistent. The server uses a raw backing image and a persistent qcow2 overlay:

```sh
zstd -q -d --sparse -f \
  work/omarchy-dubai/out/dubai/omamobile-rootfs-dubai-2026.11.07-aarch64.img.zst \
  -o work/rootfs-dubai-2026.11.07.img
FIRSTBOOT_CONF=<private-firstboot.conf> SSH_PUBLIC_KEY="$HOME/.ssh/id_ed25519.pub" \
  DUBAI_ZAP_FIRMWARE=<private-dubai-a660_zap.mbn> \
  DUBAI_ADSP_DIR=<private-adsp-directory> DUBAI_WPSS_FIRMWARE=<private-wpss.mbn> \
  DUBAI_WIFI_BOARD=<private-WCN6750-board-2.bin> \
  DUBAI_AUDIO_FIRMWARE=<private-aw88261_acf.bin> scripts/provision-nbd-rootfs.sh
qemu-img create -f qcow2 -F raw \
  -b "$PWD/work/rootfs-dubai-2026.11.07.img" work/rootfs-dubai-overlay.qcow2
qemu-nbd --format=qcow2 --persistent --shared=2 --aio=threads --cache=none \
  --bind=172.16.42.2 --port=10809 \
  --export-name=omamobile work/rootfs-dubai-overlay.qcow2
```

After each Motorola enumeration, require the logical USB serial `dubai-rescue`, then bind the existing host profile to that interface. The source-specific route prevents replies from `172.16.42.2` from using another gadget that happens to share the same subnet:

```sh
nmcli connection modify dubai-rescue-usb \
  connection.interface-name <motorola-interface> \
  ipv4.method manual ipv4.addresses 172.16.42.2/24 \
  ipv4.routes '172.16.42.0/24 table=100' \
  ipv4.routing-rules 'priority 100 from 172.16.42.2 table 100'
nmcli connection up dubai-rescue-usb ifname <motorola-interface>
```

Use `ssh -o BindAddress=172.16.42.2 ...` while another device shares that subnet. Provisioning changes only the raw copy and checks the content and ext4. The local repository public key must be added and signed locally on the phone as an owner action (`pacman-key --add`, then `pacman-key --lsign-key` with the build fingerprint); it is not inserted into the upstream keyring.

`--persistent` stops the server from exiting when the client disconnects. The initramfs waits up to 90 seconds for the host to configure `172.16.42.2/24` and checks that `/dev/nbd0` has non-zero capacity before the mount. Root in the initramfs has an empty password because Alpine 3.24 marks it locked and Dropbear would then reject the key as well; Dropbear is still started with `-s -g`, so SSH login stays public-key only.

NBD is not the default: without `/etc/omamobile-nbd-server` the diagnostic shell stays active. The NBD image does not write to `userdata` and does not publish firmware or credentials.

## CI

`.github/workflows/offline-build.yml` runs lint, rootfs preparation, kernel, DTB, initramfs, and checksum verification. It contains no ADB/fastboot commands and does not publish firmware.
