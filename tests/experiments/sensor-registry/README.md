# Read-only registry parent experiment

This is a diagnostic experiment against the GPL-3.0-or-later hexagonrpc
0.4.0 source used by the package, not a package patch or a proposed fix.
`registry-parent.patch` maps the parent directory of the registry instead of
only the registry itself. It expects `sensors/registry-parent/registry` and
`sensors/registry-parent/sns_reg_version` beneath the experimental `-R` root.
It remains read-only; it does not support the DSP's requested writes.

Apply the patch to a disposable 0.4.0 source tree. Compile the path test from
this directory with `hexagonfs.c`, `hexagonfs_mapped.c`,
`hexagonfs_virt_dir.c` and `rpcd_builder.c`, using the source root and
`hexagonrpcd` as include directories. Pass it a fixture root with `9\n` in
`sensors/registry-parent/sns_reg_version` and `ok\n` in
`sensors/registry-parent/registry/example`. The test verifies both DSP paths,
including the `..` path segment, can be read.

On Dubai, a temporary daemon built with this patch and a copied firmware tree
plus an empty version file stopped the missing-version read errors, but the
DSP repeatedly requested writes to `temp.json`; no sensors were detected.
The test does not prove that write support alone will fix initialization. The
upstream [write-support discussion](https://github.com/linux-msm/hexagonrpc/issues/19)
and [draft PR 21](https://github.com/linux-msm/hexagonrpc/pull/21) describe
related work; the draft uses simulated writes and is not included here.

`test-write.c` targets the separate experimental branch
[`FadyAckad/hexagonrpc` at `40e50412812adce9dddc2be9a4510ebce05eef89`](https://github.com/FadyAckad/hexagonrpc/tree/40e50412812adce9dddc2be9a4510ebce05eef89).
It tests actual create/write/rename/read/unlink and a symlink escape attempt;
run it only inside a service sandbox with a writable fixture at
`sensors/persist/registry` and a read-only external canary targeted by
`sensors/persist/escape-test`. The branch alone does not confine writes:
the symlink check depends on the service's mount sandbox. The on-device test
passed under `ProtectSystem=strict`, `ProtectHome=yes`, `NoNewPrivileges=yes`
and `ReadWritePaths` limited to the fixture. It is not a full security audit.
