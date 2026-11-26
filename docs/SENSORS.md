# Dubai SSC sensor status

2026-11-12: the live NBD rootfs has `omamobile-device-dubai 0.1.0-10`,
`iio-sensor-proxy 3.9-2` and `hexagonrpcd-dubai-experimental
0.5.0.r40e5041-1`. The last package is an unmerged fork pinned to commit
`40e50412812adce9dddc2be9a4510ebce05eef89`; it is experimental.

The setup service seeds `/var/lib/dubai-hexagonrpc` once from the provisioned
firmware tree, preserving subsequent changes. It does not mount Android
`persist`. The daemon's systemd drop-in makes the filesystem read-only except
the copied registry at `sensors/persist`, and retains the `fastrpc` user. A
create/write/rename/unlink test and a symlink-to-outside write test passed with
the same core mount restrictions; this is not a complete security audit. The
existing `/mnt/vendor/persist` bind mount, left from the earlier setup, is
backed by the NBD rootfs and is not used by this daemon.

After restarting the installed services, `monitor-sensor --light` reported
190.744 lux and `monitor-sensor --accel` reported a face-down tilt. The setup
unit was started automatically as a requirement when the daemon was started
after all three units were stopped. This is not a cold-boot test. Rotation,
calibration, suspend interaction, and behavior across a full restart are not
qualified; libssc warns that the firmware mount matrix is zero and uses the
identity fallback. The device rule supplies a separate proxy mount matrix.

Subsequent full temporary fastboot on 2026-11-12: the phone booted the NBD
rootfs and the setup, sensorspd and proxy units all started automatically.
The seeded registry was still present; `monitor-sensor --light` reported
162.048 lux and `--accel` reported a face-down tilt. The service ordering and
one retained registry have therefore been checked across this boot. Startup
logs contain initial missing `sns_reg_version` messages before the file is
created, and missing `sns_geomag_rv*.so` messages; compass behavior remains
unverified. An all-zero firmware mount matrix warning remains. This does not
establish calibration, correct orientation through movement, or repeated-boot
reliability.

Later on the same boot, the owner reported that display rotation did not work.
The proxy provided sensor readings but there was no Hyprland autorotation
client installed. `omamobile-autorotate-dubai 0.2.1-1` packages the unchanged
autorotation client from the pinned Omarchy Mobile source, without its
Pixel-specific sensor backend, and its user service is enabled. During the
test `monitor-sensor` reported `normal`, `left-up` and `right-up`, and the
owner confirmed that rotation works. The sensor, proxy, autorotation service
and user session were active. Autorotation after another full boot, touch
alignment in each orientation, lock-screen behavior and calibration had not
yet been verified. The owner subsequently reported that touch works after
being asked to test both portrait and landscape; precise calibration and lock
behavior remain open. A test launched through root SSH and `sudo -u` was denied by
the active-session polkit policy; the actual user service successfully
claimed the accelerometer.

The previous daemon package is retained at
`/home/antona89/dubai-pkgs/hexagonrpcd/hexagonrpcd-0.4.0-1-aarch64.pkg.tar.xz`.
To revert the daemon on this NBD rootfs, stop the proxy and sensorspd service,
then install that package with `pacman -U` and confirm the conflict removal;
restart `hexagonrpcd-adsp-sensorspd` afterwards. This restores the read-only
daemon and its firmware-tree drop-in, so sensor detection is expected to fail
again. The prior four device configuration files were archived at
`/var/tmp/dubai-sensor-config-before-20261112.tar.gz`; do not restore them
blindly because the old setup reads Android `persist`. The new Linux-only
registry is retained for diagnosis and is not part of the Android partition.

2026-11-23 confinement re-audit on `work/rootfs-dubai-2026.11.13-recovery.qcow2`:
confirmed `/mnt/vendor/persist` is not mounted, `/var/lib/dubai-hexagonrpc`
contains zero symlinks with `root:root` ownership on parent directories and
`fastrpc:fastrpc` limited to `sensors/persist`, and `hexagonrpcd-adsp-sensorspd.service`
runs with `User=fastrpc`, `Group=fastrpc`, `ProtectSystem=strict`,
`ProtectHome=yes`, `NoNewPrivileges=yes`, and
`ReadWritePaths=/var/lib/dubai-hexagonrpc/sensors/persist`. Live
`monitor-sensor` output after cold boot reported `263.33 lux`, `face-down`
tilt, and live compass headings (`268.9°–355.4°`). On 2026-11-24 `/dev/sde27`,
`omamobile-autorotate` remained `active` and `monitor-sensor` reported
`241.38 lux`, `270.8°–271.0°`, and `tilt: face-down` while the phone was lying
screen-up (`-1, 0, 0; 0, -1, 0; 0, 0, -1` in `81-libssc-motorola-dubai.rules`
inverts Z; left unchanged pending owner confirmation of portrait/landscape
axes).

2026-11-26 raw accelerometer check and Z-axis fix on `/dev/sde27` (CI `8954580`
standalone `boot_b`): while lying screen-up (`325.78 lux`), `ssccli --sensor
accelerometer` (identity fallback) reported `X≈0.44, Y≈0.08, Z≈+9.79 m/s²`,
confirming `-1` on Z in `81-libssc-motorola-dubai.rules` caused the false
`tilt: face-down`. Updated `81-libssc-motorola-dubai.rules` to
`-1, 0, 0; 0, -1, 0; 0, 0, 1` (`det = +1`) in `omamobile-device-dubai 0.1.0-17`,
built and installed on `/dev/sde27`: after reloading udev and restarting
`iio-sensor-proxy`, `monitor-sensor` immediately reported **`tilt: face-up`**
(`330.85 lux`, compass `303.1°–303.3°`) with `omamobile-autorotate` `active`.
