# Tiny Yocto Structure Rules

## Purpose

This document locks the intended directory structure, layer boundaries, and
naming rules for the tiny Yocto path. It exists to stop implementation drift
while the `feat/tiny-yocto-foundation` workstream is still converging on a
clean `linux-yocto-tiny` build for BeagleBone Black.

This is a structure and ownership document. It does not replace the Phase 1 or
Phase 2 lock documents.

The scope and lifecycle rules for those phases are defined in:

- `tmp/docs/tiny-yocto-phase-1-lock.md`
- `tmp/docs/tiny-yocto-phase-2-lock.md`

## Canonical Naming Map

The tiny path uses one locked naming map across all layers:

- layer:
  - `meta-beaglebone-optimal`
- machine:
  - `beaglebone-black-optimal-tiny`
- distro:
  - `optimal-tiny`
- image:
  - `core-image-optimal-tiny-initramfs`
- DTS root:
  - `am335x-boneblack-optimal-tiny`
- DTS:
  - `am335x-boneblack-optimal-tiny.dts`
- DTB:
  - `am335x-boneblack-optimal-tiny.dtb`

Old tiny names must be removed completely. No compatibility alias is allowed.

## Core Rule

The tiny path must separate:

- public repo-facing inputs
- host-side operational scripts
- normative docs
- Yocto layer implementation truth
- kernel metadata orchestration
- kernel config truth
- device-tree truth

No directory may mix more than one of these responsibilities.

## Layer Stack

This is the strict layering model for the tiny path.

Read it top-down:

1. public command surface
2. normative docs
3. host-side execution helpers
4. public example inputs and boot templates
5. Yocto layer registration
6. distro truth
7. machine truth
8. image truth
9. kernel recipe wiring
10. active kernel phase tree
11. active DT truth
12. active kernel metadata graph
13. active kernel config truth

If a file belongs to one layer, it must not silently absorb responsibility from
another layer.

## Canonical Structure

```text
beaglebone-optimal/
├── Makefile
├── docs/
│   ├── boot-contract.md
│   └── _RUNBOOK_EN.md
├── scripts/
│   ├── docker/
│   ├── sd-flash
│   └── sd-flash-tiny
├── yocto/
│   ├── conf/
│   │   ├── local.conf.example
│   │   ├── bblayers.conf.example
│   │   ├── local.conf.tiny.example
│   │   └── bblayers.conf.tiny.example
│   └── boot/
│       ├── extlinux.tiny.conf
│       └── uEnv.tiny.txt
└── meta-beaglebone-optimal/
    ├── conf/
    │   ├── layer.conf
    │   ├── distro/
    │   │   └── optimal-tiny.conf
    │   └── machine/
    │       └── beaglebone-black-optimal-tiny.conf
    ├── recipes-core/
    │   └── images/
    │       ├── core-image-optimal-tiny-initramfs.bb
    │       └── files/
    │           └── init
    └── recipes-kernel/
        └── linux/
            ├── linux-yocto-tiny_6.6.bbappend
            └── linux-yocto-tiny/
                └── phase1/
                    ├── dts/
                    │   └── am335x-boneblack-optimal-tiny.dts
                    ├── scc/
                    │   ├── beaglebone-tiny.scc
                    │   └── kernel-policy.scc
                    └── cfg/
                        ├── core.cfg
                        ├── disable.cfg
                        └── hw.cfg
```

## Layer Responsibilities

### Repo Root

- `Makefile` is the public command surface only.
- It may expose build, flash, list, and check targets.
- It must not contain tiny kernel policy or DT semantics.

### docs/

- `boot-contract.md` is the normative boot ownership document.
- `_RUNBOOK_EN.md` is the operator workflow document.
- Docs describe truth but are not the implementation truth themselves.

### scripts/

- `sd-flash` and `sd-flash-tiny` are host-side execution helpers.
- They may partition, format, and copy artifacts.
- They must not become the place where kernel policy is encoded.

### scripts/docker/

- `scripts/docker/` holds host-side helper scripts related to the builder
  workflow only.
- It must not hold tiny kernel policy, DT truth, or boot payload truth.

### yocto/

- `yocto/conf/` holds public example inputs for the external build dir.
- `yocto/boot/` holds public boot templates.
- `yocto/` is the public contract layer for examples and templates.
- `yocto/` must not hold `.scc`, `.cfg`, `.dts`, image recipes, machine
  configs, or distro configs.
- `yocto/` does not own kernel policy, DT policy, or image composition truth.

### meta-beaglebone-optimal/conf/

- `layer.conf` registers the layer.
- `distro/` holds distro policy truth.
- `machine/` holds machine policy truth.

### recipes-core/images/

- Image recipes define runtime image content.
- They own userspace composition, such as BusyBox and `/init`.
- They do not own kernel metadata graphs.
- `files/init` is the tracked source for the tiny runtime `/init` script if
  `/init` is not generated elsewhere.

### recipes-kernel/linux/linux-yocto-tiny_6.6.bbappend

- The bbappend is the single wiring point for tiny kernel customization.
- It injects local files into the recipe.
- It points the recipe at the currently active phase path.
- It must not become a large policy document.

## Configuration Flow

This section answers a stricter question than directory layout:

- which file declares public examples
- which file declares distro behavior
- which file declares machine behavior
- which file declares image composition
- which file declares DT truth
- which file declares kernel metadata orchestration
- which file declares final kernel config truth

### Public Entry Surface

`Makefile`

- exposes the supported public commands
- may reference:
  - `make yocto-build`
  - `make yocto-list`
  - `make sd-flash`
  - `make sd-flash-tiny`
- must not define tiny boot semantics or kernel feature policy

`docs/boot-contract.md`

- defines the normative boot contract
- answers:
  - who owns kernel path selection
  - who owns DTB path selection
  - who owns command-line selection
  - who owns low-level U-Boot knobs

`docs/_RUNBOOK_EN.md`

- defines the operator procedure
- answers:
  - how to prepare config examples
  - how to run build
  - how to flash
  - how to capture proof

### Public Example Input Layer

`yocto/conf/local.conf.tiny.example`

- configures only example build-dir inputs
- should answer:
  - which `MACHINE` to build
  - which `DISTRO` to build
  - where `DL_DIR` lives
  - where `SSTATE_DIR` lives
- must not become the permanent home for machine truth

`yocto/conf/bblayers.conf.tiny.example`

- configures only example layer membership for the external build dir

`yocto/boot/extlinux.tiny.conf`

- configures Linux payload selection on the boot media
- should answer:
  - which kernel artifact to boot
  - which DTB to boot
  - which kernel cmdline to use
  - which boot label is default

`yocto/boot/uEnv.tiny.txt`

- configures optional low-level U-Boot knobs only
- should answer:
  - boot delay
  - other simple U-Boot environment assignments if separately approved
- must never become a second Linux payload selector

### Yocto Layer Truth

`meta-beaglebone-optimal/conf/distro/optimal-tiny.conf`

- configures distro-wide behavior
- should answer:
  - tiny distro direction
  - libc direction
  - locale/NLS policy
  - package-management policy
  - broad userspace defaults

`meta-beaglebone-optimal/conf/machine/beaglebone-black-optimal-tiny.conf`

- configures board and machine truth
- should answer:
  - BBB Black-only scope
  - `KERNEL_IMAGETYPE`
  - `UBOOT_MACHINE`
  - `SPL_BINARY`
  - DTB deploy naming
  - `SERIAL_CONSOLES`
  - minimal machine features
- preferred home for:
  - initramfs bundle direction
  - machine-owned serial defaults

`meta-beaglebone-optimal/recipes-core/images/core-image-optimal-tiny-initramfs.bb`

- configures image composition
- should answer:
  - which packages are present in the tiny runtime
  - whether BusyBox is present
  - whether `/init` is installed
  - what the rootfs contents are

`meta-beaglebone-optimal/recipes-core/images/files/init`

- configures the tracked runtime `/init` implementation
- should answer:
  - what gets mounted before shell
  - which shell is executed

### Kernel Truth

`meta-beaglebone-optimal/recipes-kernel/linux/linux-yocto-tiny_6.6.bbappend`

- configures only kernel recipe wiring
- should answer:
  - which local files are added to the recipe
  - which phase path is active
  - which DT/SCC/CFG files are handed to the kernel build

`phase1/dts/am335x-boneblack-optimal-tiny.dts`

- configures DT truth for the active tiny BBB path
- should answer:
  - which peripherals exist in the active board graph
  - which peripherals are disabled or removed
  - which aliases, chosen nodes, and pinctrl paths remain

`phase1/scc/beaglebone-tiny.scc`

- configures only the thin machine entrypoint into the local kernel graph
- should answer:
  - which local kernel policy graph to enter

`phase1/scc/kernel-policy.scc`

- configures the active kernel metadata graph
- should answer:
  - which feature buckets are allowed
  - which include order is active
  - which branch anchoring is required

`phase1/cfg/core.cfg`

- configures positive required kernel options
- should answer:
  - what must be built in for ARM/MMU/initramfs/devtmpfs/proc/sysfs/tmpfs

`phase1/cfg/disable.cfg`

- configures explicit negative policy
- should answer:
  - what must be turned off for Phase 1

`phase1/cfg/hw.cfg`

- configures BBB hardware essentials only
- should answer:
  - which AM33XX / OMAP2PLUS platform path is required
  - which UART console stack is required
  - which MMC/SD stack is required
  - which minimal pinctrl and PMIC/regulator support is required

## File-to-Behavior Ownership

This is the strictest ownership map. A behavior should have one primary owner.

### Boot Payload Selection

- kernel artifact path
  - owner: `yocto/boot/extlinux.tiny.conf`
- DTB path
  - owner: `yocto/boot/extlinux.tiny.conf`
- kernel command line
  - owner: `yocto/boot/extlinux.tiny.conf`
- low-level U-Boot timing knob
  - owner: `yocto/boot/uEnv.tiny.txt`

### Build Selection

- active machine selection example
  - owner: `yocto/conf/local.conf.tiny.example`
- active distro selection example
  - owner: `yocto/conf/local.conf.tiny.example`
- active layer membership example
  - owner: `yocto/conf/bblayers.conf.tiny.example`

### Distro Behavior

- libc direction
  - owner: `meta-beaglebone-optimal/conf/distro/optimal-tiny.conf`
- locale/NLS policy
  - owner: `meta-beaglebone-optimal/conf/distro/optimal-tiny.conf`
- package-management policy
  - owner: `meta-beaglebone-optimal/conf/distro/optimal-tiny.conf`

### Machine Behavior

- `KERNEL_IMAGETYPE`
  - owner: `meta-beaglebone-optimal/conf/machine/beaglebone-black-optimal-tiny.conf`
- `UBOOT_MACHINE`
  - owner: `meta-beaglebone-optimal/conf/machine/beaglebone-black-optimal-tiny.conf`
- `SPL_BINARY`
  - owner: `meta-beaglebone-optimal/conf/machine/beaglebone-black-optimal-tiny.conf`
- `SERIAL_CONSOLES`
  - owner: `meta-beaglebone-optimal/conf/machine/beaglebone-black-optimal-tiny.conf`
- DTB deploy name
  - owner: `meta-beaglebone-optimal/conf/machine/beaglebone-black-optimal-tiny.conf`
- initramfs bundle direction
  - preferred owner: `meta-beaglebone-optimal/conf/machine/beaglebone-black-optimal-tiny.conf`

### Image Composition

- BusyBox presence
  - owner: `meta-beaglebone-optimal/recipes-core/images/core-image-optimal-tiny-initramfs.bb`
- tiny package list
  - owner: `meta-beaglebone-optimal/recipes-core/images/core-image-optimal-tiny-initramfs.bb`
- tracked `/init` content
  - owner: `meta-beaglebone-optimal/recipes-core/images/files/init`

### DT and Kernel Truth

- active BBB tiny DT graph
  - owner: `phase1/dts/am335x-boneblack-optimal-tiny.dts`
- active kernel metadata graph
  - owner: `phase1/scc/kernel-policy.scc`
- positive kernel requirements
  - owner: `phase1/cfg/core.cfg`
- forbidden kernel options
  - owner: `phase1/cfg/disable.cfg`
- boot-critical BBB hardware kernel options
  - owner: `phase1/cfg/hw.cfg`

## Ownership Map

This section is the strict answer to "which file configures what?".

If a behavior belongs to one file below, another file must not silently own it.

### `Makefile`

Owns:

- public command surface
- public target names
- operator-facing command examples

Must not own:

- kernel policy
- DT truth
- runtime package composition
- boot ownership semantics

### `docs/boot-contract.md`

Owns:

- boot ownership rules
- `extlinux.conf` vs `uEnv.txt` source-of-truth split
- flash gate policy
- repo-generated artifact truth rules

Must not own:

- kernel config option lists
- DT node lists
- build-recipe implementation details

### `docs/_RUNBOOK_EN.md`

Owns:

- operator workflow
- manual sequencing for build, flash, and proof

Must not own:

- kernel metadata truth
- machine or distro truth

### `scripts/sd-flash-tiny`

Owns:

- host-side partition/format/copy flow
- safety checks before writing SD media

Must not own:

- kernel selection policy
- DT selection policy
- command-line boot semantics

### `yocto/conf/local.conf.tiny.example`

Owns only public example values needed in the external build dir, such as:

- `MACHINE`
- `DISTRO`
- `DL_DIR`
- `SSTATE_DIR`

Must not own long-term implementation truth for:

- serial console policy
- initramfs bundling semantics
- kernel artifact ownership
- image composition

If a value is boot-architecture truth rather than an example-input convenience,
it belongs in machine or image metadata, not here.

### `yocto/conf/bblayers.conf.tiny.example`

Owns:

- layer membership example only

Must not own:

- build policy
- kernel policy
- image content

### `yocto/boot/extlinux.tiny.conf`

Owns:

- boot label
- kernel path
- DTB path
- Linux command line

Must not own:

- U-Boot script logic
- dynamic boot fallback logic

### `yocto/boot/uEnv.tiny.txt`

Owns only optional low-level U-Boot knobs, such as:

- `bootdelay`

Must not own:

- `bootargs`
- kernel path
- DTB path
- initramfs path
- script logic
- Linux payload selection

### `meta-beaglebone-optimal/conf/distro/optimal-tiny.conf`

Owns distro-wide system policy, such as:

- tiny vs non-tiny distro semantics
- libc direction
- locale/NLS policy
- package-management policy
- userspace-wide default policy

Must not own:

- BBB-specific hardware truth
- DTB file naming
- board-specific serial path declarations

### `meta-beaglebone-optimal/conf/machine/beaglebone-black-optimal-tiny.conf`

Owns board/machine truth, such as:

- BBB Black-only scope
- boot artifact naming tied to the machine
- `KERNEL_IMAGETYPE`
- `UBOOT_MACHINE`
- `SPL_BINARY`
- DTB deploy naming
- `SERIAL_CONSOLES`
- minimal machine feature semantics

This is also the preferred home for boot-architecture truth such as:

- initramfs bundle direction
- machine-owned serial console defaults

Must not own:

- userspace package composition
- public example-layer values

### `meta-beaglebone-optimal/recipes-core/images/core-image-optimal-tiny-initramfs.bb`

Owns image content, such as:

- BusyBox presence
- tiny userspace package list
- installation of `/init`
- rootfs composition

Must not own:

- kernel feature graph
- DT node policy

### `meta-beaglebone-optimal/recipes-core/images/files/init`

Owns:

- tracked runtime `/init` script content

Must not own:

- machine selection
- kernel config policy

### `meta-beaglebone-optimal/recipes-kernel/linux/linux-yocto-tiny_6.6.bbappend`

Owns:

- file injection into the kernel recipe
- wiring to the active phase tree
- DTS/SCC/CFG handoff into the recipe

Must not own:

- large policy logic
- long config lists
- broad feature-selection semantics

### `phase1/dts/am335x-boneblack-optimal-tiny.dts`

Owns:

- DT truth for the active tiny BBB Black path

Must not own:

- kernel config options
- SCC include orchestration

### `phase1/scc/beaglebone-tiny.scc`

Owns:

- thin machine entrypoint into the local Phase 1 kernel policy

Must not own:

- broad upstream-standard semantics
- a large feature graph
- long config lists

### `phase1/scc/kernel-policy.scc`

Owns:

- the active local Phase 1 kernel metadata graph
- include ordering
- feature selection
- branch anchoring if needed

Rules:

- every include must justify itself against Phase 1 acceptance
- if a feature is not required for boot, UART shell, initramfs, or BBB boot
  essentials, it must be absent

### `phase1/cfg/core.cfg`

Owns:

- positive required kernel options only

Examples:

- ARM/MMU class correctness
- initramfs support
- `/proc`, `/sys`, `/dev`-supporting basics
- shell-supporting runtime kernel requirements

Must not own:

- forbidden option shutoffs
- board-specific peripheral baggage

### `phase1/cfg/disable.cfg`

Owns:

- explicit forbidden kernel options only

Examples:

- modules
- network stack
- USB
- audio
- framebuffer/DRM
- I2C/SPI
- FAT-family filesystems not needed in runtime

Must not own:

- positive boot essentials
- board-specific hardware keep-list

### `phase1/cfg/hw.cfg`

Owns:

- BBB hardware essentials only

Examples:

- AM33XX / OMAP2PLUS platform path
- UART console stack
- MMC/SD boot path
- minimal pinctrl
- minimal PMIC/regulator support

Must not own:

- non-essential peripherals
- generic userspace or distro semantics

## Kernel Phase Tree

### phase1/

`phase1/` is the only active kernel metadata tree during Phase 1.

It contains exactly three sub-layers:

- `dts/`
- `scc/`
- `cfg/`

No other sub-layer is required for the minimal structure.

### phase1/dts/

- Holds DT source truth for the active tiny BBB path.
- Contains only local DT sources needed by the active phase.
- Must not contain `.cfg` or `.scc` files.

### phase1/scc/

- Holds kernel metadata orchestration only.
- Owns include graphs, feature assembly, and branch anchoring if needed.
- Must not contain broad semantic names inherited from upstream policy if they
  no longer describe the file truthfully.

File roles:

- `beaglebone-tiny.scc`
  - thin machine entrypoint only
  - may point to `kernel-policy.scc`
  - must stay small
- `kernel-policy.scc`
  - the real local Phase 1 kernel policy graph
  - must contain only includes justified by Phase 1 acceptance

### phase1/cfg/

- Holds kernel config truth.
- Config files are the source of truth for final kernel behavior in Phase 1.
- Split responsibilities are mandatory:

- `core.cfg`
  - positive required options only
  - examples: ARM/MMU/initramfs/devtmpfs/proc/sysfs/tmpfs
- `disable.cfg`
  - explicit forbidden options only
  - examples: modules, network, USB, audio, framebuffer, DRM, I2C, SPI,
    FAT family
- `hw.cfg`
  - BBB hardware essentials only
  - examples: AM33XX/OMAP2PLUS path, UART console, MMC boot path, minimal
    pinctrl and PMIC/regulator support

## Naming Rules

### Phase Naming

- Phase belongs in the directory path, not in the filename.
- During Phase 1, active kernel metadata lives under `linux-yocto-tiny/phase1/`.
- `phase2/` must not exist until Phase 1 is proven on hardware.
- If Phase 2 starts, it must mirror the same sub-layer split as `phase1/`.

### File Naming

- Filenames describe responsibility, not lifecycle.
- Prefer names like:
  - `kernel-policy.scc`
  - `core.cfg`
  - `disable.cfg`
  - `hw.cfg`
- Do not keep patch-up names long term, such as:
  - `standard-arm-nopatch.scc`
  - `tiny-arm-nopatch.scc`
  - `tiny.cfg` as the primary policy file

### Naming by Responsibility

- DT and DTB names carry hardware lineage.
- machine names carry board target identity.
- distro names carry policy and flavor only.
- image names carry image family, product flavor, and boot model only.

Board identity must not appear in distro names.
Board shorthand must not appear in image names.

### DT and DTB Continuity

- DTS basename is the canonical root.
- DTB is the compiled form of the same basename.
- source name = deploy artifact name = boot media name = extlinux reference
- no alias
- no rename during SD population
- no stable public name different from internal deploy name

For the tiny path this means:

- DTS:
  - `am335x-boneblack-optimal-tiny.dts`
- DTB deploy artifact:
  - `am335x-boneblack-optimal-tiny.dtb`
- DTB on FAT boot media:
  - `am335x-boneblack-optimal-tiny.dtb`
- `extlinux.conf` FDT path:
  - `/am335x-boneblack-optimal-tiny.dtb`

### Machine, Distro, and Image Continuity

- machine:
  - `beaglebone-black-optimal-tiny`
- distro:
  - `optimal-tiny`
- image:
  - `core-image-optimal-tiny-initramfs`

### Variable Contract

Makefile variables may keep the `YOCTO_TINY_*` prefix, but their values must
use the canonical naming map.

Examples:

- `YOCTO_TINY_MACHINE=beaglebone-black-optimal-tiny`
- `YOCTO_TINY_DISTRO=optimal-tiny`
- `YOCTO_TINY_IMAGE=core-image-optimal-tiny-initramfs`
- `YOCTO_TINY_DTB=am335x-boneblack-optimal-tiny.dtb`

## Policy Rules

### Public vs Implementation Truth

- `yocto/` is public-input truth.
- `meta-beaglebone-optimal/` is implementation truth.
- Public examples must not absorb implementation internals.
- Implementation truth must not depend on hidden logic in `yocto/`.
- Naming cleanup is all-or-nothing across code, scripts, examples, public
  output, deploy artifacts, and docs.
- The tiny path must not keep old names as compatibility aliases.

### Kernel Policy Scope

- Every feature include in `kernel-policy.scc` must justify itself against
  Phase 1 acceptance.
- If a feature is not required for boot, UART shell, initramfs, or the tiny
  BBB boot path, it must be removed.
- The active policy must be ARM-only and BBB-oriented for Phase 1.
- Broad inherited standard or base policy must not control final Phase 1
  behavior.
- The active policy must not chase stale patch buckets indefinitely; if a
  bucket is not required by Phase 1 acceptance, it should be removed from the
  active graph rather than debugged as a first-class requirement.

### Hardware Scope

- DT trimming and `hw.cfg` trimming must follow the same hardware truth list.
- Hardware not required for boot, UART, MMC, or minimal board bring-up must
  be absent from the active Phase 1 truth.
- Upstream broad BBB hardware configs must not remain the final source of
  truth once the local tiny hardware truth exists.

## Active-Phase Rule

- At any moment, the bbappend must wire exactly one active phase path.
- During Phase 1, that path is `linux-yocto-tiny/phase1/`.
- Do not mix `phase1` config files with `phase2` SCC files.
- Do not let implementers guess which phase is active.

## Flash Gate Rule

Do not flash new artifacts to hardware until all of the following are true:

- `do_patch` is clean
- the final kernel `.config` matches the Phase 1 truth
- deploy artifacts match the tiny boot contract

Until then, all work remains in the kernel metadata and build-validation loop.
