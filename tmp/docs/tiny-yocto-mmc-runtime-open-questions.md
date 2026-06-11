# Tiny Yocto MMC Runtime Open Questions

## Purpose

This document isolates the unresolved Linux runtime `mmc0` failure from the
deterministic tiny-path cleanup work.

It exists so the repo can:

- keep moving on the parts that are already locked
- avoid mixing contract cleanup with hardware-runtime speculation
- force future SD/MMC fixes to be evidence-driven

## Recommended Next Goal Split

The next implementation goal should fix the deterministic parts first.

That deterministic goal includes:

- canonical naming cleanup across machine, distro, image, DTB, scripts, docs,
  and examples
- tiny U-Boot cleanup so the tiny path:
  - keeps `extlinux.conf` as Linux payload truth
  - keeps `uEnv.txt` only as optional low-level text env
  - does not use `uboot.env` as a project input
  - removes `finduuid` from the tiny boot flow
  - eventually stops probing `uboot.env`
- tiny `/init` cleanup to match the locked `devtmpfs`-only model:
  - remove `echo /sbin/mdev > /proc/sys/kernel/hotplug`
  - remove `mdev -s`

The unresolved runtime SD/MMC work should stay separate until the deterministic
cleanup is done and verified.

## Locked Facts Already Proven

These points are no longer open questions:

- `extlinux.conf` is the source of truth for Linux payload selection.
- `uEnv.txt` is only an optional low-level U-Boot text env input.
- `uboot.env` is not the tiny-path source of truth and should not be added just
  to suppress log noise.
- `Invalid partition 2` comes from `finduuid` trying `mmc 0:2`, not from the
  initramfs root model.
- `/init` currently has a real contract bug because it writes to
  `/proc/sys/kernel/hotplug` while the tiny kernel does not enable
  `UEVENT_HELPER`.
- The chosen device-management direction is `devtmpfs` only:
  - no `mdev`
  - no `udev`
- The board now boots far enough to:
  - load kernel and DTB through `extlinux.conf`
  - reach Linux
  - run `/init`
  - present a shell

## Still Unresolved

The following points remain open:

- the precise root cause of:
  - `mmc0: error -110 whilst initialising SD card`
- whether that failure comes from:
  - the `mmc1` DT graph
  - the regulator graph
  - the TPS65217 child-node graph
  - some other runtime interaction
- whether:
  - `supply pbias not found, using dummy regulator`
  - `supply vqmmc not found, using dummy regulator`
  are harmless optional warnings or required missing bindings on this tiny BBB
  path
- whether:
  - `tps65217-pmic: Failed to locate of_node [id: -1]`
  - `tps65217-bl: Failed to locate of_node [id: -1]`
  are only cleanup warnings or functionally related to SD runtime failure

## Rules For The Runtime Investigation

Until there is differential evidence, do not:

- add `pbias` DT supply bindings
- add `vqmmc` DT supply bindings
- add new TPS65217 child nodes
- enable new kernel config flags just because warning text mentions a feature
- treat PMIC or regulator warnings as proven root cause

Every future runtime fix must classify each suspect as one of:

- `proven required`
- `proven optional`
- `proven unrelated`

## Current Evidence Snapshot

### Direct Runtime Log Clues

The current boot log contains:

- `tps65217-pmic: Failed to locate of_node [id: -1]`
- `tps65217-bl: Failed to locate of_node [id: -1]`
- `sdhci-omap 48060000.mmc: supply pbias not found, using dummy regulator`
- `sdhci-omap 48060000.mmc: supply vqmmc not found, using dummy regulator`
- `mmc0: Timeout waiting for hardware interrupt.`
- `mmc0: error -110 whilst initialising SD card`

### Static Repo And Build Evidence

The current tiny path has already established:

- the tiny kernel boots on BBB with the correct ARM/MMU class
- the tiny DTB content is accepted by the kernel as the BBB tiny board model
- the tiny runtime `/init` script still contains the old hotplug and `mdev`
  assumptions and must be cleaned up
- AM335x BBB DT includes provide `vmmc-supply` for `mmc1`, but no proven local
  evidence yet that `pbias` or `vqmmc` are mandatory on this path
- the current warning text alone is not enough to prove which DT or regulator
  change would be correct

## Required Evidence Style

The preferred proof method is differential runtime evidence, not static
inspection alone.

Future investigation should prefer comparisons such as:

- baseline kernel behavior on the same SD media shape
- tiny kernel behavior after one tightly controlled DT or U-Boot change
- before/after UART logs for one suspected variable at a time

Static DT and driver inspection is useful only as support material. It is not
enough, by itself, to justify a runtime hardware-graph change.

## Exit Condition For This Open-Questions Doc

This document stops being needed only when the runtime suspects above have been
reclassified from open questions into proven outcomes and the `mmc0 -110`
failure has either:

- been fixed with evidence
- or been shown to come from an out-of-scope dependency that is explicitly
  deferred
