# Tiny Yocto Foundation Phase 2 Lock

## Purpose

This document locks the work that is intentionally deferred until after Phase 1
has already proven a bootable tiny path on BeagleBone Black.

The canonical directory and layer layout for both phases is defined in:

- `tmp/docs/tiny-yocto-structure-rules.md`

The strict file-by-file ownership map also lives there. This document only
locks what is deferred until after Phase 1 proof and how the project may
legally diverge into a future `phase2/` tree.

Phase 2 starts only after Phase 1 can:

- build successfully
- create tiny boot media
- boot BBB from SD
- reach automatic BusyBox shell on UART

## Phase 2 Objective

Push the already-booting tiny path deeper toward final minimalism and stronger
project hardening without reopening Phase 1 architecture decisions.

Phase 2 is about trimming and tightening, not redefining the tiny foundation.

## Phase 2 Ownership Boundary

Phase 2 owns only:

- work intentionally deferred until after Phase 1 hardware proof
- deeper pruning, hardening, and measurement that do not belong in first-boot
  bring-up

Phase 2 does not own:

- the initial Phase 1 hardware proof contract
- the current active phase path while Phase 1 is still unproven
- the structure rules already locked in `tiny-yocto-structure-rules.md`

## Inputs Required Before Phase 2

Phase 2 assumes the following already exist and are trusted:

- `docs/boot-contract.md`
- stable tiny examples
- stable `make yocto-list`
- stable `make sd-flash-tiny`
- stable `meta-beaglebone-optimal`
- stable `beaglebone-optimal-tiny` machine
- stable `beaglebone-optimal-tiny` distro
- stable `core-image-bbb-tiny-initramfs`
- a UART boot log proving Phase 1 acceptance

## Phase Tree Rule

- `phase2/` must not exist before Phase 1 is proven.
- If Phase 2 starts, its local kernel metadata must live under:
  - `meta-beaglebone-optimal/recipes-kernel/linux/linux-yocto-tiny/phase2/`
- `phase2/` must follow the same layer split as `phase1/`:
  - `dts/`
  - `scc/`
  - `cfg/`
- The bbappend must point at exactly one active phase path at a time.
- Do not mix `phase1` files with `phase2` files in the active kernel path.

## In Scope for Phase 2

### Device Tree Deep Pruning

After Phase 1 boot proves the tiny DT path is correct, Phase 2 may replace
large chunks of `disable`-based pruning with true removal.

Goal:

- remove more dead DT nodes and include baggage
- shrink the final DTB further
- reduce future maintenance surface

Examples:

- remove leftover disabled HDMI graph
- remove leftover disabled Ethernet graph
- remove leftover disabled USB graph
- remove unused aliases or board baggage where safe

### Kernel Config Deep Pruning

Phase 2 may push kernel minimization beyond the Phase 1 safe-cut set.

Goal:

- remove more built-in support that is no longer needed
- shrink kernel image and runtime surface

Examples:

- additional debug and compatibility options not needed for the tiny path
- filesystem support beyond what the tiny path truly uses
- driver families irrelevant to the locked BBB tiny architecture

### DT and Kernel Alignment Cleanup

Phase 2 may tighten the coupling between DT and kernel so that:

- disabled DT features no longer leave unnecessary built-in drivers
- built-in drivers no longer remain for removed DT graphs

This is a cleanup and optimization pass, not a boot-foundation pass.

### Runtime and Shell Tightening

Phase 2 may decide whether the Phase 1 BusyBox shell remains the correct final
contract or whether the project wants to move toward a more appliance-like mode.

Possible Phase 2 directions:

- keep shell but trim applets further
- restrict write capability even harder
- reduce shell convenience further
- eventually consider removing interactive shell in a later phase

Removing the shell is explicitly not part of Phase 1.

### Additional Boot-Path Hardening

Phase 2 may harden low-level boot policy once Phase 1 behavior is proven.

Examples:

- tighten `uEnv.txt` generation and validation
- formalize failure behavior when `uEnv.txt` is absent
- verify that `extlinux.conf` remains the sole Linux payload selector
- add stronger repo checks preventing drift in boot semantics

### Measurement and Regression Tracking

Phase 2 may add size and performance tracking once the tiny path is real.

Examples:

- kernel artifact size comparison
- DTB size comparison
- boot media file inventory comparison
- boot time comparison baseline vs tiny
- persistent measurement notes in docs or reports

Phase 1 only requires proof of function, not full benchmarking.

## Explicitly Out of Scope for Phase 2 Lock

This document does not approve future work automatically. It only records the
next bucket of work that belongs after Phase 1.

Still out of scope until separately approved:

- re-adding peripherals for real feature development
- production reliability hardening beyond the tiny foundation
- network reintroduction
- USB reintroduction
- I2C/SPI reintroduction
- LED-specific production behavior in kernel or userspace
- general productization beyond the locked tiny architecture

## Suggested Phase 2 Order

Recommended order once Phase 1 is proven:

1. measure actual Phase 1 artifacts and boot behavior
2. create the `phase2/` tree only when a real Phase 2 truth needs to diverge
3. convert safe disabled DT leftovers into real removals
4. tighten kernel config further against the final DT graph
5. review BusyBox applet surface again
6. decide whether appliance mode should remove or restrict shell behavior more
7. add stronger regression checks to stop future drift

## Phase 2 Validation Direction

Every deep-cut change in Phase 2 should preserve the core proof:

- BBB still boots from SD
- still reaches the expected UART state
- boot media contract is unchanged unless docs are updated together

Extra validation that becomes valuable in Phase 2:

- compare old vs new DTB size
- compare old vs new kernel artifact size
- compare boot media file count and byte size
- compare boot time and UART log changes

## Phase Boundary Rule

Do not pull Phase 2 optimization work into Phase 1 unless it is strictly
required to make the Phase 1 tiny path boot.

Use this rule:

- if the system cannot boot to UART shell without it, it may belong in Phase 1
- if the system already boots and the change only shrinks or cleans further, it
  belongs in Phase 2

## Documentation Rule

If any Phase 2 work changes boot semantics, the same documentation discipline
from Phase 1 still applies:

- update `docs/boot-contract.md`
- update relevant example config files
- update `make help` or `make yocto-list` if public surface changes

Phase 2 must not silently redefine Phase 1 contract behavior.
