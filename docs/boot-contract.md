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

The baseline path remains valid while the tiny path is being proven.

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

## Change Policy

Any change that alters boot semantics must update all affected public contract
surfaces together:

- this file
- relevant tiny or baseline example configs
- `make help`
- `make yocto-list`
- `_RUNBOOK_EN.md` when the operator workflow changes

Boot changes must not merge with stale contract docs.
