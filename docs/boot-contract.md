# Boot Contract

## Purpose

This document is the normative boot contract for `beaglebone-optimal`.

It defines the public boot ownership rules for the baseline and tiny paths, and
it is the source of truth for Phase 1 tiny boot semantics.

## Path Overview

The repo currently exposes two boot paths:

- `Baseline path`
  - standard BeagleBone Black SD-rootfs workflow
  - `core-image-minimal`
  - full-disk `.wic` flashing through `make sd-flash`
- `Tiny path`
  - BeagleBone Black only
  - initramfs-first
  - single FAT boot partition
  - `core-image-optimal-tiny-initramfs`
  - boot media creation through `make sd-flash-tiny`

- `Qt dashboard product path`
  - BeagleBone Black Rev D only
  - full rootfs product image
  - `core-image-optimal-qt-dashboard`
  - product-owned `.wic` flashing through `make sd-flash`
  - reuses the tiny kernel feature catalog without redefining the tiny path
  - A/B rootfs + bootcount failsafe + OTA (swupdate)

- `Qt dashboard no-A/B path`
  - same hardware, same image recipe, same kernel/DTS as the product path
  - single rootfs partition, no bootcount, no OTA/swupdate
  - `beaglebone-black-optimal-qt-dashboard-noab` machine

The baseline path remains valid while the tiny path is being proven.
The Qt dashboard product path is a separate product surface. It must not
silently redefine the Phase 1 tiny path contract below.

## Tiny Path Scope

Phase 1 tiny path is:

- BeagleBone Black only
- `linux-yocto-tiny` only
- initramfs bundled into the kernel artifact
- U-Boot MMC-only boot through `extlinux.conf`
- UART BusyBox shell only
- single FAT boot partition
- repo-generated and reproducible

Phase 1 tiny path must not depend on:

- `.wic`
- a separate ext4 rootfs partition
- board-side mutable boot state as project truth

## Qt Dashboard Product Path Boundary

The Qt dashboard product path may reuse the tiny kernel feature catalog and the
`linux-yocto-tiny` provider as a base, but it is not the Phase 1 tiny path.

The Qt dashboard product path may therefore keep product-owned surfaces that
the tiny path explicitly removes, including:

- a product-owned `.wic`
- an ext4 rootfs partition
- HDMI / DRM / framebuffer output
- systemd service ownership for the single fullscreen Qt app

Ownership for the Qt dashboard product path belongs in the product layer, not
in the Phase 1 tiny contract surface.

## Qt Dashboard No-A/B Path

`beaglebone-black-optimal-qt-dashboard-noab` is the same physical target and
the same image recipe (`core-image-optimal-qt-dashboard.bb`) as the product
path, differing only in `DISTRO_FEATURES`: it does not declare
`optimal-ab-update`.

Consequences, all driven by that one token (see "Feature Toggle Contract"):

- `beaglebone-qt-dashboard-noab.wks`: one `/boot` (vfat, 32MB) + one `/`
  rootfs (ext4, 256MB) + `/data` (ext4, 64MB). No `rootfs_b`.
- No `bootcount.cfg`/`bootcount.env` merged into the U-Boot config, no
  `active_slot`/`altbootcmd` - `beaglebone-qt-dashboard-noab-extlinux.conf`
  boots a single entry from `root=/dev/mmcblk0p2`.
- No `swupdate`, `swupdate-local-tools`, `emmc-flash-tools`,
  `u-boot-fw-utils`, or `u-boot-env` in `IMAGE_INSTALL`. Re-provisioning is
  full-image only, through `sd-flash` from the host; there is no on-device
  update path and no rollback.
- Kernel sensor catalog (gpio-leds, i2c2-bus, rtc-ds3231, sht3x, bh1750) and
  HDMI/DRM support are unchanged from the product path - both machines
  inherit them the same way through `MACHINEOVERRIDES`.

Creating a different feature combination for this hardware means creating a
new machine.conf, not adding a `local.conf` override - see "Feature Toggle
Contract".

## Feature Toggle Contract

Every optional feature across the tiny/qt-dashboard machine family (A/B
update, dev netboot, USB gadget, and the kernel sensor catalog - gpio-leds,
i2c2-bus, rtc-ds3231, sht3x, bh1750) is toggled through one mechanism:
`DISTRO_FEATURES` tokens prefixed `optimal-` (e.g. `optimal-ab-update`,
`optimal-gpio-leds`), read via `bb.utils.contains('DISTRO_FEATURES', token,
...)` in the recipe/bbclass that needs it.

Rules:

- Each machine.conf declares its own token set with
  `DISTRO_FEATURES:append = " optimal-..."` and mirrors that exact list into
  `OPTIMAL_REQUIRED_FEATURES`. This is the single declaration point per
  machine - no other file may add or remove `optimal-` tokens.
- `core-image-optimal-qt-dashboard.bb` validates the two match at parse time
  and calls `bb.fatal()` if `OPTIMAL_REQUIRED_FEATURES` is not a subset of
  the resolved `DISTRO_FEATURES` (e.g. because of a `DISTRO_FEATURES:remove`
  added elsewhere). BitBake parses `local.conf` before `machine.conf`
  (`bitbake.conf` include order), so a machine-declared `:append` already
  wins over anything set earlier in `local.conf` for the same variable: this
  validator exists specifically to catch the one operator that direction
  doesn't protect against, `DISTRO_FEATURES:remove`, which strips a token
  from the fully-resolved value regardless of which file added it. A
  mismatch fails the build loudly instead of silently shipping a machine
  missing a required feature.
- `optimal-rtc-ds3231`, `optimal-sht3x`, and `optimal-bh1750` each require
  `optimal-i2c2-bus`; `linux-yocto-tiny-feature-dts.bbclass` enforces this
  with the same `bb.fatal()` pattern.
- Tokens are never set from `local.conf`, `distro.conf`, or any file other
  than the owning machine.conf. `local.conf` only selects `MACHINE`.

## Boot Media Contract

Tiny boot media is one FAT boot partition containing stable file names.

The public tiny boot payload is:

- `MLO`
- `u-boot.img`
- `zImage`
- `am335x-boneblack-optimal-tiny.dtb`
- `extlinux/extlinux.conf`
- optional `uEnv.txt`

The FAT partition is a boot-media requirement. It is not a declaration that the
runtime system supports VFAT as a general machine feature.

## Ownership Rules

### extlinux.conf

`/extlinux/extlinux.conf` is the Linux payload source of truth.

It owns:

- kernel file selection
- DTB file selection
- initramfs payload selection
- kernel command line
- the default boot entry

Phase 1 rules:

- exactly one boot entry
- no multi-entry menu
- minimal command line
- keep `console=ttyS0,115200`
- no `root=PARTUUID=...`
- no `rootwait`

### uEnv.txt

`uEnv.txt` is optional and is reserved for low-level U-Boot behavior only.

Allowed:

- simple variable assignments such as `bootdelay=1`

Forbidden:

- `uenvcmd`
- boot script logic
- overriding `bootcmd`
- overriding `bootargs`
- overriding kernel path
- overriding DTB path
- overriding initramfs path

### Forbidden Overlap

- `extlinux.conf` must own Linux payload selection.
- `uEnv.txt` must not own Linux payload selection.
- The project must not introduce a second source of truth for kernel, DTB,
  initramfs, or kernel command line.
- The tiny path must not depend on `uboot.env` as a project input.

## Source of Truth Policy

Repo-generated artifacts are the only project source of truth.

Board-side mutations are not project truth:

- editing boot files manually on the SD card
- changing U-Boot behavior interactively on the board
- saving board-local state without reflecting it back into the repo

These may be used for temporary debugging, but they do not redefine the
contract.

## Runtime Contract for Tiny Phase 1

Tiny Phase 1 runtime is:

- serial only
- BusyBox-centric
- monolithic-kernel-centric
- read-only mindset

The system must auto-enter a BusyBox `sh` on UART.

Phase 1 shell baseline must provide:

- `sh`
- `ls`
- `cd`
- `cat`
- `dmesg`

The Phase 1 `/init` path must:

- mount `/proc`
- mount `/sys`
- mount `/dev`
- mount `/dev/pts`
- then exec the BusyBox shell

The tiny Phase 1 path uses kernel `devtmpfs` only.

## Phase 1 Removed Surface

Phase 1 tiny path must not keep these active:

- framebuffer or video console
- HDMI
- Ethernet
- network stack
- USB host
- USB gadget
- audio
- non-boot-essential I2C buses
- SPI
- package manager on target
- persistent logs
- locale/NLS

Boot-essential board wiring may remain when required to reach the tiny shell.
For BeagleBone Black this includes the UART path, SD boot path, and the PMIC
path on `i2c0`.

The tiny U-Boot path follows the same removed-surface rule: it boots from
`mmc 0:1` through `/extlinux/extlinux.conf` and must not initialize Ethernet,
USB gadget, RNDIS, DFU, fastboot, PXE, DHCP, EFI boot paths, or U-Boot
watchdog servicing.

## Build and Flash Surface

### Baseline

- examples:
  - `yocto/conf/local.conf.example`
  - `yocto/conf/bblayers.conf.example`
- build:
  - `make yocto-build`
- flash:
  - `make sd-flash SDCARD=/dev/sdX`

### Tiny

- examples:
  - `yocto/conf/local.conf.tiny.example`
  - `yocto/conf/bblayers.conf.tiny.example`
- build:
  - `make yocto-build YOCTO_IMAGE=core-image-optimal-tiny-initramfs`
- flash:
  - `make sd-flash-tiny SDCARD=/dev/sdX`

### Qt dashboard no-A/B

- examples:
  - `yocto/conf/local.conf.qt-dashboard-noab.example`
  - `yocto/conf/bblayers.conf.qt-dashboard.example` (reused as-is)
- build:
  - `make yocto-build YOCTO_IMAGE=core-image-optimal-qt-dashboard` (with `MACHINE=beaglebone-black-optimal-qt-dashboard-noab` in `local.conf`)
- flash:
  - `make sd-flash YOCTO_MACHINE=beaglebone-black-optimal-qt-dashboard-noab YOCTO_IMAGE=core-image-optimal-qt-dashboard SDCARD=/dev/sdX`

## Acceptance for Tiny Phase 1

The tiny Phase 1 path is accepted only when:

- the tiny public contract surface exists in repo-tracked files
- the custom layer, machine, distro, image, and kernel delta exist
- the tiny build succeeds with `linux-yocto-tiny`
- `sd-flash-tiny` prepares the tiny boot media end-to-end
- BeagleBone Black boots from SD to an automatic BusyBox shell on UART
- `dmesg` works from that shell

Required proof:

- UART boot log
- FAT boot partition file list
- exact build command
- exact flash command
- actual boot artifact names

## eMMC Flashing from SD Card

While the workspace scripts (`sd-flash.sh` and `sd-flash-tiny.sh`) target host-side flashing of SD cards, provisioning the onboard eMMC is done from a running SD-booted system using `flash-emmc.sh` (package `emmc-flash-tools`, installed on every `core-image-optimal-qt-dashboard` build).

### Prerequisites

1. The onboard eMMC controller (`&mmc2`) must be enabled in the Device Tree (standard `am335x-boneblack.dts` included by the product DTS).
2. The board must be booted from the SD card (press and hold the `S2` Boot button during power-on).
3. The built product image (`core-image-optimal-qt-dashboard.wic` and its `.bmap` file) must be copied to the SD card rootfs or made accessible (e.g., via a USB flash drive or NFS mount).

### Flashing Procedure

On the booted BeagleBone Black running from the SD card:

```bash
flash-emmc.sh /path/to/core-image-optimal-qt-dashboard.wic
```

The tool determines the running root device from `/proc/cmdline`, targets the
one other real `mmcblkN` device present (refusing to run if that can't be
determined unambiguously, or if it ever resolves to the running root device),
and requires typing back the exact target device path before writing anything.
It writes via `bmaptool` (block-verified against the `.bmap` file) when
available, falling back to `dd` otherwise. The A/B `extlinux.conf` baked into
the image already hardcodes `root=/dev/mmcblk0pN`, which is correct once the
SD card is removed and the eMMC is renumbered to `/dev/mmcblk0`; no manual
edit is needed.

On success the tool `sync`s and powers the board off automatically. On
failure it stops without powering off, leaving the board running from the SD
card so the failure can be investigated.

**Boot from eMMC**: remove the SD card and power the board back on. It boots
from the onboard eMMC.

## Change Policy

Any change that alters boot semantics must update all affected public contract
surfaces together:

- this file
- relevant tiny or baseline example configs
- `make help`
- `make yocto-list`
- `_RUNBOOK_EN.md` when the operator workflow changes

Boot changes must not merge with stale contract docs.
