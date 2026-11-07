# PROJECT: OMARCHY MOBILE — MOTOROLA EDGE 30 (DUBAI)
## Full native Linux port — Mainline Kernel, Arch Linux ARM, Hyprland and Mobile Hardware Enablement

### 0. ROLE AND OBJECTIVE

Act as a senior embedded Linux development team made up of:

- Linux ARM64 kernel engineer.
- Qualcomm Snapdragon platform engineer.
- Device Tree engineer.
- Android bootloader / A/B partitions specialist.
- postmarketOS/Nura integration engineer.
- Arch Linux ARM packaging engineer.
- Wayland / Hyprland / Mesa / Freedreno engineer.
- Linux mobile telephony engineer.
- CI/CD and release engineer.
- Hardware QA and power management engineer.

**Mission:** produce a native Omarchy Mobile port for the Motorola Edge 30, codename `dubai`, with Arch Linux ARM, a mainline-based Linux kernel, Hyprland, and the Omarchy Mobile shell.

I do not want an Android launcher, a modified Android ROM, or Linux running through proot, chroot, Termux, or an Android container.

I want Linux started directly from the Motorola bootloader and an Omarchy Mobile environment that actually works on the hardware.

The final goal is to use the device as a Linux smartphone, with a touch interface, connectivity, audio, power management, and possibly telephony.

**Do not rewrite what already exists.** The Motorola Edge 30 already has a Linux port developed in the postmarketOS/Nura ecosystem. Reuse, adapt, and integrate that work with Omarchy Mobile.

The project must be developed by milestones, with real code, runnable builds, tests, and documentation.

---

# 1. TARGET HARDWARE

| Component | Specification |
|---|---|
| Manufacturer | Motorola |
| Model | Edge 30 |
| Codename | `dubai` |
| Reference variant | XT2203-1, to be verified |
| SoC | Qualcomm Snapdragon 778G+ |
| SoC identifier | SM7325-AE |
| Architecture | AArch64 |
| CPU | Kryo 670 |
| GPU | Adreno 642L |
| RAM | 6/8 GB LPDDR5, to be verified |
| Storage | 128/256 GB UFS 3.1 |
| Display | 6.5" P-OLED, 2400×1080 |
| Refresh | Up to 144 Hz |
| Wi-Fi/Bluetooth | Qualcomm WCN6750 |
| USB | USB-C |
| Partitioning | Android A/B with dynamic partitions |
| Current system | LineageOS |

The device belongs to the Qualcomm SM7325 platform.

Do not confuse the repositories, drivers, or device trees of `dubai` with those of the Motorola Edge 30 Pro, Edge 30 Neo, Edge 30 Fusion, or any other model.

Before compiling images intended for the bootloader, verify the exact model and every actual characteristic of the device.

## 1.1 Display variants

This point is particularly important.

The postmarketOS/Nura port provides at least two variants:

- CSOT.
- Tianma.

The available packages include:

- `device-motorola-dubai-kernel-csot`
- `device-motorola-dubai-kernel-tianma`

Do not assume that the device trees and panel parameters are interchangeable.

Determine which panel the user's device has through reliable information from the bootloader, LineageOS, kernel logs, or firmware.

If the identification is uncertain, do not create boot images that are treated as safe to flash.

---

# 2. REQUIRED REPOSITORIES AND SOURCES

## 2.1 Omarchy Mobile — primary upstream

https://github.com/derekross/omarchy-mobile

Analyze Derek Ross's current implementation.

Read at least:

- `README.md`
- `AGENTS.md`
- `CONTRIBUTING.md`
- `docs/DEVICES.md`
- `docs/ROADMAP.md`
- `docs/RELEASES.md`
- `docs/INSTALL.md`
- `bin/omamobile`
- `tools/build-packages`
- `tools/build-rootfs`
- `tools/install-phone`
- `initramfs/init`
- `kernel/configs/`
- `packages/omamobile-shell/`
- `packages/omamobile-device-cheetah/`
- `packages/omamobile-audio/`
- `packages/omamobile-modem/`
- `packages/hyprland/`, if present
- `packages/mesa/`, if present

Check every path in the current revision of the repository.

The purpose is to understand which components are hardware-independent and which are Pixel-specific.

Do not automatically transfer Tensor services, AoC, the Samsung modem, or Google drivers onto the Qualcomm device.

## 2.2 Motorola / Nura Linux port

Primary repository:

https://gitlab.postmarketos.org/postmarketOS/pmaports

Package repository:

https://pkgs.nura.eco/package/main/postmarketos/aarch64/device-motorola-dubai

Find in pmaports:

- The device package for Motorola dubai.
- The kernel package in use.
- Kernel patches and configuration.
- Device tree.
- CSOT and Tianma panel configurations.
- Firmware dependencies.
- ALSA/UCM.
- Modem support.
- USB gadget/networking.
- Boot configuration.
- Partition configuration.
- Any device-specific userspace services.

The Nura package declares dependencies including:

- `alsa-ucm-conf-qcom-sc7280`
- `firmware-motorola-dubai`
- `firmware-qcom-adreno-a660`
- `hexagonrpcd`
- `linux-firmware-ath11k`
- `linux-firmware-qca`
- `soc-qcom`
- `soc-qcom-modem`
- `soc-qcom-qbootctl`
- `make-dynpart-mappings`

Check which of these dependencies are actually required on Arch Linux ARM and which are specific to the postmarketOS infrastructure.

Do not copy Alpine configuration files directly and assume they are compatible with systemd.

## 2.3 LineageOS — Android reference

https://github.com/LineageOS/android_device_motorola_dubai

https://github.com/LineageOS/android_kernel_motorola_sm7325

Documentation:

https://lineageos.github.io/lineage_wiki/devices/dubai/

Use these sources as a reference for:

- Hardware configuration.
- Boot image layout.
- Firmware.
- Audio routing.
- Touchscreen.
- Display panel.
- Modem.
- Cameras.
- Partition layout.
- Thermal management.
- Sensor calibration.

The downstream Motorola kernel is not the project's main kernel.

## 2.4 Hands-on tests of the Linux port

Also analyze:

https://gist.github.com/mbohun/10dab097eb0cbf9b11f175a8fc622b81

This source contains a concrete postmarketOS installation on the Motorola Edge 30, including problems with A/B partitions, fastboot, the rootfs, and `userdata`.

Do not treat those commands as automatically safe or applicable to the current device.

Examine the problems, workarounds, and prerequisites, and compare them with the updated sources.

## 2.5 Working repository

The port must have its own repository, separate from the Samsung `gts4lvwifi-porting` project.

Proposed working name:

`dubai-omarchy-porting`

If a dedicated repository already exists, use it.

Otherwise, prepare the structure locally and ask for authorization before creating a new remote repository.

Do not modify Derek Ross's upstream repository directly without an agreed contribution strategy.

---

# 3. ARCHITECTURAL CONSTRAINTS

## 3.1 Linux kernel

Goal: a mainline-based kernel with only the patches strictly required for Motorola dubai.

Source priority:

1. Upstream Linux kernel.
2. postmarketOS/Nura port patches.
3. Qualcomm patches already accepted upstream.
4. Patches in review.
5. The downstream Motorola kernel as a reference only.

Upstream support for `dubai` already exists.

Verify its exact state in the chosen kernel release, without assuming that every hardware subsystem already works.

Identify the kernel used by the Nura package `linux-postmarketos-qcom-sc7280`.

The package name does not mean the device uses a Snapdragon SC7280 SoC. Check the actual DTS files, config fragments, and included drivers.

Do not automatically choose the newest kernel.

Prefer a revision supported by the dubai port, with reproducible patches and configuration.

## 3.2 Arch Linux ARM

The final operating system will be Arch Linux ARM AArch64.

Use prebuilt binary packages when they are available and compatible.

Do not compile the entire distribution from scratch.

Compile only the components that require it, for example:

- Kernel.
- DTB.
- Modules.
- Firmware integration package.
- Omarchy Mobile packages that are not available.
- Mesa or Hyprland components that need changes.
- Device-specific hardware services.

Analyze the container/QEMU infrastructure already implemented by Omarchy Mobile to build AArch64 packages on an x86_64 host.

The development PC is an HP OMEN 16 running Pop!_OS 24.04 LTS.

Do not assume that the host runs Arch Linux.

## 3.3 User interface

Use the real Omarchy Mobile shell, Hyprland, and the related components.

Do not replace it with Phosh or Plasma Mobile.

Those may be used temporarily only to compare hardware behavior with the Nura port.

The goal is a touch-first mobile experience.

---

# 4. DEVICE SAFETY

This section is mandatory.

The Motorola has an Android A/B configuration.

Do not assume that every part of the system is independent between slots.

In particular:

**`userdata` is shared between the Android slots.**

If it is erased or reformatted to install Arch Linux ARM, LineageOS on the other slot no longer guarantees restoration of the original data and configuration.

The strategy Omarchy Mobile uses on Pixels cannot be transferred automatically to the Motorola.

## 4.1 Operations forbidden without approval

Do not run:

- `fastboot flash`
- `fastboot -w`
- `fastboot erase`
- `fastboot set_active`
- `fastboot flashing lock`
- `dd` on physical partitions
- Persistent changes to `super`
- Formatting of `userdata`
- Changes to `persist`
- Changes to modem/NV partitions
- Changes to calibration partitions

Do not run upstream `tools/install-phone` on the Motorola.

Do not treat commands as safe merely because they exist in the Omarchy Mobile repository or in postmarketOS scripts.

## 4.2 Preferred strategy

Initial phase:

- No flash.
- Offline builds.
- Artifact verification.
- Read-only information collection.
- A possible temporary boot, only after its compatibility has been verified and authorization has been obtained.

Evaluate `fastboot boot` for the first kernel with initramfs, but verify that the device bootloader and image format actually support it.

Do not assume that `fastboot boot` is always available.

If it cannot be used, prepare a runbook for a controlled test that requires explicit authorization.

## 4.3 Partitions and backup

Analyze:

- A/B slots.
- `boot_a` and `boot_b`.
- `vendor_boot_a` and `vendor_boot_b`.
- `dtbo_a` and `dtbo_b`.
- `vbmeta` and the AVB chain.
- `super`.
- `userdata`.
- Modem and calibration partitions.

Verify the actual names on the device.

Determine which partitions are physical and which are logical.

Document precisely the difference between bootloader fastboot and userspace fastbootd.

Prepare backups of the relevant partitions only with verified methods, without assuming root privileges or read capabilities that are not available.

Do not store partition images, serials, IMEI, or sensitive material in a public repository.

For every future installation define:

1. The exact operations.
2. The partitions involved.
3. Possible data loss.
4. Rollback.
5. Brick risk.
6. Rollback limits.
7. The official restore procedure.
8. Stop points.

Do not declare reversible a procedure that destroys `userdata`.

---

# 5. MILESTONE M0 — FULL AUDIT

Before writing code, perform a thorough reconnaissance.

## Activities

1. Clone and analyze Omarchy Mobile.
2. Clone and analyze pmaports.
3. Identify the Motorola dubai package.
4. Find the exact kernel, DTS, and patches.
5. Examine the LineageOS device tree.
6. Verify the model and the hardware variants.
7. Compare the Pixel and Motorola boot architectures.
8. Map the Pixel-specific services to replace.
9. Identify the rootfs build method.
10. Check AArch64 dependency support on Arch Linux ARM.
11. Check firmware and licenses.
12. Define an implementable roadmap.

Produce `docs/AUDIT.md` containing links, versions, commits, and the real state.

Create `sources.lock` to pin the revisions in use.

### Completion criterion

Audit documented, dependencies identified, and no intervention on the device.

---

# 6. MILESTONE M1 — HARDWARE MATRIX

Create `docs/HARDWARE-MATRIX.md`.

Distinguish strictly:

- Driver present in the sources.
- Driver built.
- Hardware detected.
- Hardware tested.
- Hardware working.
- Hardware partially working.
- Hardware not working.
- State not verified.

Evaluate the following subsystems.

| Hardware | Items to verify |
|---|---|
| CPU | Frequencies, scheduler, thermal |
| GPU | Adreno 642L, DRM MSM, Freedreno |
| Display | CSOT/Tianma, DSI, DRM/KMS |
| Touch | Actual controller and driver |
| Storage | UFS, partitions, filesystems |
| USB | DWC3, USB gadget, OTG |
| Wi-Fi | WCN6750, ath11k, firmware |
| Bluetooth | WCN6750, firmware |
| Audio | WCD9375 codec, AW88261 speaker |
| Battery | Qualcomm battmgr |
| Charging | USB-C, power supply |
| Sensors | Accelerometer, gyroscope, brightness |
| Fingerprint | Sensor and driver availability |
| Modem | LTE/5G, QMI/QRTR, IMS |
| Cameras | Sensors, CSI, ISP |
| Suspend | s2idle, resume |
| Thermal | Sensors and thermal limits |
| Vibrator | Haptics |

Do not claim that a peripheral works merely because a patch exists.

If support is only documented by third parties, identify the source and the version.

---

# 7. MILESTONE M2 — MAINLINE KERNEL BUILD

## Objective

Produce a Linux ARM64 kernel that can boot on Motorola dubai.

### Required work

- Identify the best kernel branch.
- Check SM7325 support.
- Identify the dubai-specific DTS.
- Identify any panel overlays.
- Import only the necessary patches.
- Prepare specific config fragments.
- Build the kernel and modules.
- Build the device tree.
- Check any warnings.
- Run static DT tests.
- Record versions and checksums.

Use the GCC or LLVM toolchain appropriate to the chosen kernel.

Do not use a generic device tree if the correct one for the model exists.

Do not build a downstream Android 4.x/5.x kernel as the final system.

### Expected output

- Kernel `Image`, or the required format.
- DTB.
- DTBO, if necessary.
- Modules.
- Final config.
- SHA-256 manifest.
- Build log.

The final boot-image format must come from analysis of the real bootloader.

### Completion criterion

Every artifact built and verified offline.

---

# 8. MILESTONE M3 — DIAGNOSTIC INITRAMFS

Before installing Arch Linux ARM, build a minimal initramfs.

You may reuse the Alpine-based approach adopted by Omarchy Mobile, but verify every dependency.

The initramfs must:

- Start a shell.
- Mount proc, sysfs, and devtmpfs.
- Identify the device.
- Collect dmesg.
- Initialize USB diagnostics.
- Attempt USB networking with compatible drivers.
- Allow SSH through Dropbear, if USB networking works.
- Remain self-contained.
- Not write automatically to Android partitions.
- Not require `userdata` for the first boot.
- Handle errors and timeouts.

Prepare an emergency mode that allows the logs to be recovered.

If the USB gadget does not work, identify alternate diagnostic paths without declaring them available before they have been tried.

### First hardware milestone

Obtain on the device:

```bash
uname -a
cat /proc/cmdline
cat /proc/device-tree/model
dmesg
```

The GPU or the graphical shell does not need to work yet.

### Completion criterion

A real Linux shell accessible on the Motorola, after an authorized test.

---

# 9. MILESTONE M4 — ARCH LINUX ARM ROOTFS

## Objective

Boot Arch Linux ARM as a native Linux system.

Use the existing Omarchy Mobile infrastructure:

- `tools/build-packages`
- `tools/build-rootfs`
- AArch64 packages.
- Initramfs.
- systemd.
- Pacman.
- Device-specific packages.

First verify that the builder architecture supports the Motorola without Pixel-specific assumptions.

## Base packages

Implement the rootfs with:

- systemd.
- pacman.
- NetworkManager.
- OpenSSH.
- udev.
- Kernel modules.
- Required firmware.
- Mesa.
- Wayland.
- PipeWire.
- UPower.
- Diagnostic tools.

Do not build packages that are already available on Arch Linux ARM, unless a demonstrated need exists.

## Storage

Evaluate separately:

A. Temporary rootfs in RAM/initramfs.

B. Rootfs on external USB storage, if compatible with the hardware and the boot strategy.

C. Rootfs on internal storage, with dedicated partitions or images, only after a rigorous analysis.

D. Persistent installation that replaces Android, only as a future authorized phase.

For each option compare:

- Whether LineageOS can be preserved.
- Risk of data loss.
- Performance.
- Complexity.
- Recovery options.
- Bootloader compatibility.
- Persistence of updates.

Do not automatically consider dual boot possible merely because the phone is A/B.

### Completion criterion

Arch Linux ARM booted on the device, with a working shell, systemd, and package management.

---

# 10. MILESTONE M5 — GRAPHICS AND TOUCHSCREEN

This milestone is fundamental for Omarchy Mobile.

## 10.1 Display

The initial upstream port has framebuffer support; check the current DRM/KMS situation.

Analyze the patches for the Novatek NT37701 panel and the CSOT/Tianma variants.

Do not assume that every panel uses equivalent configuration.

Verify:

- DSI initialization.
- Panel driver.
- Correct framebuffer/DRM handover.
- Native resolution.
- Orientation.
- Brightness.
- Display blank/unblank.
- Power off and power on.
- Available refresh rates.

Start from the minimum stable mode.

Do not force 144 Hz before the DRM/KMS path is reliable.

## 10.2 GPU

The GPU is Adreno 642L.

Objective:

- MSM DRM driver.
- Correct GPU firmware.
- Freedreno/Mesa.
- Hardware-accelerated OpenGL ES.
- Vulkan/Turnip, if it is actually available.
- Hardware-accelerated Wayland.

Test:

```bash
ls /dev/dri/
```

Also check `modetest`, `drm_info`, EGL, and the compatible Mesa tools.

The llvmpipe software renderer is not a final solution.

## 10.3 Touchscreen

Verify:

- Kernel input.
- Evdev.
- libinput.
- Multitouch.
- Swipe.
- Scroll.
- Virtual keyboard.
- Gestures.
- Wake from a blanked display.

Do not implement userspace workarounds when a valid kernel driver exists.

### Completion criterion

An accelerated Wayland session with a usable display and touchscreen.

---

# 11. MILESTONE M6 — CONNECTIVITY

## 11.1 Wi-Fi

Qualcomm WCN6750 platform.

Analyze the ath11k driver and the required firmware.

Tests:

- Interface detected.
- Firmware loaded.
- Network scan.
- WPA2/WPA3 connection.
- DHCP.
- DNS.
- Stability.
- Reconnect after suspend.

Do not distribute proprietary firmware without having verified the rights.

## 11.2 Bluetooth

Verify:

- Controller initialization.
- Firmware.
- BlueZ.
- Pairing.
- Bluetooth audio.
- External mice and keyboards.
- Reconnection.

## 11.3 USB-C

Tests:

- USB networking.
- USB gadget.
- USB host.
- Power and charging.
- Connection to the computer.
- Recovery of remote access.

Handle USB roles and transitions correctly.

---

# 12. MILESTONE M7 — AUDIO

Study the audio configuration from Nura, LineageOS, and the most recent Linux patches.

Components to investigate:

- Qualcomm WCD9375.
- Awinic AW88261 amplifiers.
- ALSA SoC.
- ALSA UCM.
- PipeWire.
- Built-in microphones.
- Stereo speakers.
- Bluetooth audio.
- Possible USB-C audio.

The available speaker patches do not automatically guarantee that every audio path works correctly.

Prepare a dubai-specific ALSA UCM configuration when necessary.

For the initial tests:

- Use low volume levels.
- Check amplifier protections and controls.
- Do not force unverified gains or mixers.
- Do not disable hardware protections in order to get audio.

### Completion criterion

Audio playback and microphone recording demonstrated with real tests.

---

# 13. MILESTONE M8 — BATTERY AND POWER MANAGEMENT

The phone must be usable without being constantly connected to the PC.

Analyze:

- Qualcomm battery manager.
- UPower.
- Charger.
- USB-C power delivery.
- Temperature.
- CPU frequency scaling.
- GPU power states.
- Regulators.
- Runtime PM.
- Display idle.
- s2idle suspend.
- Resume.
- Wakeup sources.

Do not enable suspend as the default behavior before resume has been verified.

Run progressive tests:

1. Display off.
2. Display back on.
3. Short suspend.
4. Resume through the power button.
5. Test disconnected from the charger.
6. Extended battery-life test.
7. Check the modem and Wi-Fi after resume.

Record standby consumption, distinguishing measured results from estimates.

Do not consider the device usable day to day until battery charging, power off, and resume are reliable.

---

# 14. MILESTONE M9 — LTE/5G TELEPHONY

This part is not required for the very first boot, but it matters for the final goal.

The Motorola Edge 30 is a smartphone and must keep cellular connectivity as far as is technically possible.

Do not reuse the Samsung/Exynos modem components implemented for Derek Ross's Pixels.

Study instead:

- `soc-qcom-modem`
- Qualcomm QRTR.
- QMI.
- ModemManager.
- The required Qualcomm services.
- Modem firmware.
- SIM management.
- Calls.
- SMS.
- LTE/5G data.
- VoLTE.
- IMS.
- GNSS.

Check which components are already supported by the Nura port.

Do not assume that recognizing the modem is the same as being able to place calls.

## Separate tests

- SIM recognized.
- Network registration.
- Mobile data.
- SMS.
- Incoming calls.
- Outgoing calls.
- Call audio.
- VoLTE.
- VoWiFi, if it can be implemented.
- 5G, if available.

VoLTE/IMS can be a significant blocker: document any proprietary dependencies and the real limits.

Do not modify the IMEI, NV, or calibration data.

---

# 15. MILESTONE M10 — OMARCHY MOBILE

Now integrate the real Omarchy Mobile shell.

## 15.1 Device-specific package

Create a package:

`omamobile-device-dubai`

The name follows the upstream convention.

It must contain only the Motorola-specific configuration:

- Firmware setup.
- Udev rules.
- Systemd services.
- Input configuration.
- Power management.
- Audio.
- Display.
- Modem.
- Sensor setup.
- Device-specific hooks.

Do not duplicate the entire Omarchy project.

## 15.2 Interface

Optimize for the 6.5" 2400×1080 format.

Support:

- Portrait.
- Landscape.
- Automatic rotation.
- Touch gestures.
- Virtual keyboard.
- App launcher.
- Notification center.
- Quick settings.
- Lock screen.
- Call handling, when the modem works.
- Battery management.
- Brightness.
- Volume.
- Wi-Fi and Bluetooth.
- App switching.
- Multitasking.
- Touch-friendly settings.

Reuse the Omarchy Mobile components that are already present and working.

Do not introduce new UI technologies unless they are strictly necessary.

## 15.3 Performance

The target must also work well on the 6 GB RAM variant.

Measure:

- RAM at boot.
- CPU idle.
- GPU use.
- Application open times.
- Frame pacing.
- Scrolling smoothness.
- Power consumption.
- Stability under load.

Evaluate zram without imposing arbitrary configuration.

### Completion criterion

Omarchy Mobile booted natively, with a touchscreen, hardware GPU, and usable applications.

---

# 16. MILESTONE M11 — SECONDARY HARDWARE

Only after the main system works:

- Motion sensors.
- Automatic rotation.
- Brightness sensor.
- Vibration.
- Fingerprint.
- GNSS.
- Cameras.
- Hardware video decoding.
- Multimedia acceleration.
- NFC, if supported and verified.

For the cameras, study the state of:

- OV50A.
- OV32B40.
- S5KJN1.
- Qualcomm camera subsystem.
- libcamera.

Do not turn camera support into a blocker for the first release.

---

# 17. BUILD AND REPOSITORY

Organize the repository, compatibly with the Omarchy Mobile tools, along a structure similar to:

```text
dubai-omarchy-porting/
├── .github/
│   └── workflows/
├── device/
│   └── dubai/
│       ├── device.conf
│       ├── kernel.config
│       ├── panels/
│       ├── firmware/
│       └── NOTES.md
├── kernel/
│   ├── configs/
│   └── patches/
├── initramfs/
├── packages/
│   └── omamobile-device-dubai/
├── rootfs/
├── scripts/
│   ├── fetch-sources.sh
│   ├── build-kernel.sh
│   ├── build-initramfs.sh
│   ├── build-rootfs.sh
│   ├── build-images.sh
│   └── verify-images.sh
├── tests/
├── docs/
│   ├── AUDIT.md
│   ├── HARDWARE-MATRIX.md
│   ├── BOOT-CHAIN.md
│   ├── STORAGE-PLAN.md
│   ├── RECOVERY-RUNBOOK.md
│   ├── BUILD.md
│   └── ROADMAP.md
├── sources.lock
├── PROCESS.md
└── README.md
```

The structure is indicative.

Do not duplicate upstream scripts that can already be used.

Keep large sources and generated artifacts out of version control.

## CI/CD

Prepare GitHub Actions for:

- Lint.
- Dependency checks.
- Kernel build.
- Device tree validation.
- Initramfs build.
- Image validation.
- Arch Linux ARM packages.
- Manifest.
- SHA-256.
- Automatic tests.

No CI workflow may be able to flash the device.

Do not publish proprietary firmware or images that contain personal data.

---

# 18. CODE QUALITY

Every change must be reproducible and documented.

Apply:

- Small thematic commits.
- Automated tests.
- ShellCheck.
- Device tree validation.
- Version control.
- Artifact checksums.
- Removal of temporary hacks that are no longer needed.
- Appropriate licenses.
- Isolated hardware configuration.
- The smallest possible number of out-of-tree patches.

Do not take random code from forums without verifying its origin, license, and compatibility.

Do not paste the downstream Android kernel into the mainline kernel.

Valid, generalizable patches should be prepared for upstream submission.

---

# 19. ACCEPTANCE CRITERIA

Define four main milestones.

## Alpha 0 — First Linux Boot

- Kernel booted.
- Correct device tree.
- Working initramfs.
- Shell available.
- Diagnostics collected.
- Recovery plan verified.

## Alpha 1 — Arch Linux ARM

- Bootable Arch rootfs.
- Working systemd.
- Working pacman.
- Working storage.
- USB networking or another reliable network.
- SSH access.

## Alpha 2 — Omarchy Mobile

- Working Hyprland.
- Accelerated GPU.
- Stable display.
- Touchscreen.
- Wi-Fi.
- Audio.
- Battery reporting.
- Usable mobile interface.

## Beta — Linux smartphone

- Reliable suspend/resume.
- Safe charging.
- Bluetooth.
- Sensors.
- Modem data.
- Telephony, if it can be implemented.
- Stability during extended use.
- Verified update procedure.

Beta status must not be presented as daily-driver ready if calls, reliable power management, or other essential functions are missing.

---

# 20. REPORT AND HANDOFF

Always keep `PROCESS.md` up to date.

It must contain:

- Current state.
- Current commit.
- Kernel version.
- Omarchy Mobile version.
- Arch Linux ARM version.
- Applied patches.
- Builds performed.
- Tests passed.
- Tests failed.
- Hardware verified.
- Blockers.
- Risks.
- Next step.

Do not declare a hardware test complete if it was not actually performed.

If you do not have physical access to the Motorola, prepare scripts and procedures for the user without pretending that you ran them.

Every milestone must produce code, checks, and documentation.

Do not stop at generic suggestions.

---

# 21. FIRST OPERATING CYCLE — START NOW

I want you to start concretely from the work that can be executed without modifying the phone.

## Phase 1 — Technical research

1. Clone Omarchy Mobile.
2. Clone pmaports.
3. Find every file relevant to Motorola dubai.
4. Identify the Nura kernel in use.
5. Find the DTS and the patches.
6. Analyze the CSOT/Tianma differences.
7. Compare the packaging systems.
8. Identify what can be reused without changes.
9. Identify the changes required for Arch Linux ARM.
10. Analyze the Motorola A/B bootloader.

## Phase 2 — Design

Prepare:

- `docs/AUDIT.md`
- `docs/HARDWARE-MATRIX.md`
- `docs/BOOT-CHAIN.md`
- `docs/STORAGE-PLAN.md`
- `docs/RECOVERY-RUNBOOK.md`
- `docs/ROADMAP.md`

## Phase 3 — Offline implementation

If the environment allows it:

1. Prepare the local repository.
2. Implement the scripts that fetch the sources.
3. Prepare the kernel configuration.
4. Build the ARM64 kernel.
5. Build the device tree.
6. Build the modules.
7. Prepare the diagnostic initramfs.
8. Implement artifact verification.
9. Prepare the Arch Linux ARM build system.
10. Implement automatic tests.

Keep every error log and fix the problems that can be verified.

Do not try to fix a failure with simultaneous random changes to the kernel, DTS, and bootloader.

## Phase 4 — First handoff

At the end, provide a report with:

| Field | Information |
|---|---|
| Chosen kernel | Version and commit |
| Mainline state | Upstream/out-of-tree patches |
| Device tree | Path, display variant |
| Kernel build | Pass/Fail/Not run |
| Initramfs build | Pass/Fail/Not run |
| Arch Linux ARM | State |
| Omarchy Mobile | Reusable components |
| Bootloader | Validated strategy |
| Storage | Proposed solution |
| Hardware | Main blockers |
| Tests run | Results and logs |
| Next activity | Concrete action |

## Stop condition

Stop before any destructive or persistent operation on the device.

Ask for authorization and present the runbook.

**Do not sacrifice the current LineageOS installation merely to demonstrate that a kernel compiles.**

---

# 22. FINAL PRIORITIES

The project must not be set up as a complete rewrite of the Motorola Linux port.

The strategy is:

**Mainline kernel + postmarketOS/Nura work + Arch Linux ARM + Omarchy Mobile.**

Do not use Android as the underlying system.

Do not needlessly build AArch64 packages that are already available.

Do not rewrite drivers that already work.

Do not use the Pixel installer.

Do not assume that A/B dual boot protects `userdata`.

Do not flash without authorization.

Do not declare hardware compatibility that was never tested.

**First I want a bootable Linux kernel. Then Arch Linux ARM. Then Hyprland and Omarchy Mobile. Finally telephony, battery life, sensors, and polish.**

Start now from the technical audit and continue with everything you can actually implement and test offline, without waiting for further instructions, except for the points that require confirmation or access to the physical device.
