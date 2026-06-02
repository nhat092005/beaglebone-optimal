# Tiny Yocto Foundation Phase 1 Lock

## Purpose

This document locks the exact Phase 1 scope for the `feat/tiny-yocto-foundation`
workstream. It exists to prevent design drift while implementing the first
bootable tiny path for BeagleBone Black.

The canonical directory and layer layout for this workstream is defined in:

- `tmp/docs/tiny-yocto-structure-rules.md`

The strict file-by-file ownership map is also defined there. This document
does not replace that ownership map. It only locks the active Phase 1 outcome,
scope, gates, and acceptance criteria.

Phase 1 is done only when the custom tiny path boots a BeagleBone Black from
SD into an automatic BusyBox shell on UART.

## Outcome

Create a real tiny Yocto path that is:

- size-first
- initramfs-first
- BeagleBone Black only
- UART shell only
- free of fallback to non-tiny kernel/provider paths

The tiny path must coexist with the current baseline path until Phase 1 is
proven on hardware.

## Locked Naming

- Branch: `feat/tiny-yocto-foundation`
- Custom layer: `meta-beaglebone-optimal`
- Custom machine: `beaglebone-optimal-tiny`
- Custom distro: `beaglebone-optimal-tiny`
- Custom image: `core-image-bbb-tiny-initramfs`
- Build list target: `make yocto-list`
- Flash target: `make sd-flash-tiny`
- Contract doc: `docs/boot-contract.md`

## Architecture Lock

### Board and Scope

- Tiny Phase 1 targets BeagleBone Black only.
- Tiny Phase 1 does not support Bone or BoneGreen.
- Tiny Phase 1 does not support multi-board compatibility.

### Kernel and Provider

- Tiny Phase 1 must use `linux-yocto-tiny`.
- No fallback to `linux-yocto` is allowed.
- If the tiny provider fails for BBB, the tiny path must be fixed directly.

### Kernel Metadata Structure

- During Phase 1, the active local kernel metadata tree lives under:
  - `meta-beaglebone-optimal/recipes-kernel/linux/linux-yocto-tiny/phase1/`
- `phase1/` contains exactly:
  - `dts/`
  - `scc/`
  - `cfg/`
- `phase1/scc/beaglebone-tiny.scc` is a thin entrypoint only.
- `phase1/scc/kernel-policy.scc` is the real local Phase 1 kernel policy
  graph.
- `phase1/cfg/core.cfg`, `phase1/cfg/disable.cfg`, and `phase1/cfg/hw.cfg`
  are the config truth for Phase 1 behavior.

### Phase 1 Ownership Boundary

Phase 1 owns:

- the active tiny architecture contract
- the active kernel phase tree under `phase1/`
- the build, flash, and proof gates required for first hardware success

Phase 1 does not redefine:

- the global structure rules in `tiny-yocto-structure-rules.md`
- the deferred optimization backlog reserved for Phase 2

### Root Model

- Tiny Phase 1 is initramfs-first.
- The initramfs must be bundled into the kernel artifact.
- Tiny Phase 1 must not use `.wic`.
- Tiny Phase 1 must not use a separate ext4 rootfs partition.
- Tiny Phase 1 rootfs is ephemeral.

### Boot Media

- Tiny boot media is a single FAT boot partition.
- The SD card is used only as boot media.
- Runtime rootfs does not live on a separate SD partition.
- Boot artifact names on media must be stable, not timestamped.

### Boot Files

The tiny boot media must contain only the minimum boot payload required for
Phase 1:

- `MLO`
- `u-boot.img`
- bundled kernel + initramfs artifact
- `am335x-boneblack.dtb`
- `/extlinux/extlinux.conf`
- optional `uEnv.txt`

## Boot Ownership Lock

### extlinux.conf

`/extlinux/extlinux.conf` is the source of truth for Linux boot payload
selection. It owns:

- kernel file selection
- DTB file selection
- initramfs payload selection
- kernel command line
- the default boot entry

Rules:

- exactly one boot entry in Phase 1
- no multi-entry menu
- tiny command line is minimal
- keep `console=ttyS0,115200`
- do not use `root=PARTUUID=...`
- do not use `rootwait`

### uEnv.txt

Tiny Phase 1 may use `uEnv.txt`, but only as an optional low-level U-Boot
knob file.

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

- `extlinux.conf` owns Linux payload selection.
- `uEnv.txt` must not redefine Linux payload selection.
- Repo-generated artifacts are the only project source of truth.
- Board-side manual tweaks are debug-only and are not project truth.

## Machine and DT Lock

### Machine Direction

The custom machine exists to keep only BBB Black boot essentials.

Must keep:

- SoC/core AM335x boot-critical graph
- UART0 path
- MMC boot path
- required PMIC/regulator path
- pinctrl required by UART and MMC
- clock/reset/core interrupt/memory graph
- `/chosen`
- `DEFAULTTUNE`
- `SPL_BINARY`
- `UBOOT_MACHINE`
- `KERNEL_IMAGETYPE`
- `SERIAL_CONSOLES`

Must cut or stop carrying from the baseline machine where possible:

- board compatibility for non-BBB-Black DTs
- `kernel-modules` recommend
- QEMU-only baggage
- broad image type baggage not required by the tiny path
- runtime `vfat` machine feature semantics

### Device Tree Direction

Tiny Phase 1 must fork a BBB Black-specific DT path.

Rules:

- use only `am335x-boneblack.dtb`
- Phase 1 may disable uncertain nodes first
- Phase 1 may fully remove nodes only when they are clearly not boot-critical

Safe-to-cut direction for Phase 1:

- HDMI path
- Ethernet MAC/PHY path
- USB host path
- USB gadget path
- audio path
- I2C buses
- SPI buses
- board-other baggage

### Kernel Config Direction

Phase 1 kernel config truth is split into:

- `core.cfg`
  - positive must-have options
- `disable.cfg`
  - explicit must-not-have options
- `hw.cfg`
  - BBB hardware essentials only

Phase 1 must not rely on broad inherited standard or base policy to define
final tiny behavior.

## Runtime Lock

Tiny Phase 1 runtime is:

- serial only
- BusyBox-centric
- monolithic-kernel-centric
- read-only mindset

### Shell

- UART must auto-enter a BusyBox `sh`
- no login manager
- no password
- no SSH

Phase 1 shell baseline must support:

- `sh`
- `ls`
- `cd`
- `cat`
- `dmesg`

### init

Tiny Phase 1 must provide a minimal `/init` that:

- mounts `/proc`
- mounts `/sys`
- mounts `/dev`
- then `exec`s `/bin/sh`

### Device Management

- `/dev` uses BusyBox `mdev`
- no `udev` or `eudev`

### Monolithic Kernel

- Tiny Phase 1 is monolithic-kernel oriented
- no runtime package manager
- no runtime module-centric workflow

## Explicitly Removed from Phase 1

Tiny Phase 1 must not keep these active:

- framebuffer or video console
- HDMI
- Ethernet
- USB host
- USB gadget
- audio/ALSA
- I2C
- SPI
- network stack
- package management on target
- persistent logs
- locale/NLS

Watchdog:

- do not intentionally enable it in Phase 1 unless required for boot

## Public Contract Surface

The repo must expose both paths clearly.

### Baseline Path

- existing baseline examples remain available
- `core-image-minimal`
- `make sd-flash`

### Tiny Path

- `yocto/conf/local.conf.tiny.example`
- `yocto/conf/bblayers.conf.tiny.example`
- `make yocto-build YOCTO_IMAGE=core-image-bbb-tiny-initramfs`
- `make sd-flash-tiny SDCARD=/dev/sdX`

Rules:

- the tiny `local.conf` example is a public-input example, not the home for
  long-term kernel policy
- the tiny `bblayers.conf` example is a layer-membership example only
- boot templates under `yocto/boot/` are public-facing boot templates, not
  implementation truth for kernel metadata

### Presentation Rule

- `make help` must show baseline and tiny at a glance
- `make yocto-list` must list supported baseline and tiny surfaces

## Flash Gate

Do not flash new tiny artifacts until all of the following are true:

- `do_patch` is clean
- the final kernel `.config` matches Phase 1 truth
- deploy artifacts match the tiny boot contract
- `make yocto-list` must not carry acceptance logic

## Safety and Mutability Rules

- Final implementation must live in repo-tracked files.
- Build-dir mutation is not acceptable as final state.
- Host-side tiny flashing must preserve baseline-level safety checks.
- `sd-flash-tiny` must handle partitioning, formatting, copying, and unmount
  discipline explicitly.

## Acceptance Criteria

Phase 1 is accepted only when all of the following are true:

- custom layer exists and is wired through example configs
- custom machine exists
- custom distro exists
- custom image exists
- build succeeds with `linux-yocto-tiny`
- `sd-flash-tiny` prepares tiny boot media end-to-end
- BeagleBone Black boots from SD
- system reaches automatic BusyBox shell on UART
- `dmesg` works from that shell
- tiny boot path does not depend on `.wic`
- tiny boot path does not depend on separate ext4 rootfs media
- only BBB Black DT path is used
- removed peripherals are not active in Phase 1

## Required Proof

Phase 1 proof must include:

- UART boot log
- list of files present on the FAT boot partition
- exact build command
- exact flash command
- actual artifact names used to boot

Raw long logs may live outside permanent docs, but final verification must cite
their existence and summarize the proof.

## Documentation Rules

- `docs/boot-contract.md` is the normative long-term boot contract
- `_RUNBOOK_EN.md` must gain a tiny path section
- `_RUNBOOK_VN.md` may reference or summarize later

Any boot-semantic change must update:

- `docs/boot-contract.md`
- tiny example config files
- `make help` or `make yocto-list` if public behavior changed

## Commit Strategy

Work should land as layered commits, not a single big-bang commit.

Preferred order:

1. boot contract and docs surface
2. tiny examples and make targets
3. layer skeleton
4. machine, distro, and image
5. `sd-flash-tiny`
6. boot fixes until UART shell proof
7. runbook polish

Preferred commit style:

- `docs(boot-contract): ...`
- `docs(runbook): ...`
- `docs(readme): ...`
- `build(makefile): ...`
- `build(yocto-conf): ...`
- `feat(meta-beaglebone-optimal): ...`
- `feat(distro): ...`
- `feat(machine): ...`
- `feat(image): ...`
- `feat(sd-flash-tiny): ...`
- `fix(tiny-boot): ...`
- `fix(device-tree): ...`
