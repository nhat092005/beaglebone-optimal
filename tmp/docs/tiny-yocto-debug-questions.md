# Tiny Yocto Debug Questions

## Purpose

This document records the full debug state after the latest BBB tiny boot log.

It exists to separate:

- issues already fixed by the deterministic cleanup work
- issues still present in the current log
- warnings that are visible but not yet proven causal
- open technical questions that still require evidence

The goal is to prevent random DT or kernel edits driven only by warning text.

## Current Boot Log Snapshot

The current log proves the following high-level flow:

- U-Boot SPL starts from `MMC1`
- U-Boot proper starts successfully
- environment now loads from nowhere
- U-Boot scans `mmc 0:1`
- `extlinux/extlinux.conf` is found
- kernel is loaded from `/zImage`
- DTB is loaded from `/am335x-boneblack-optimal-tiny.dtb`
- Linux boots as `TI AM335x BeagleBone Black Optimal Tiny`
- `/init` runs successfully
- UART shell prompt appears as `~ #`
- Linux runtime later reports `mmc0` timeout and `error -110`

## Fixed Problems Proven By This Log

### 1. `uboot.env` Probe Noise

This is fixed.

Old behavior:

- `Unable to read "uboot.env" from mmc0:1...`

Current behavior:

- `Loading Environment from nowhere... OK`

Meaning:

- tiny U-Boot no longer depends on FAT `uboot.env`
- tiny path now uses the intended `ENV_IS_NOWHERE` model

### 2. `Invalid partition 2`

This is fixed.

Old behavior:

- `** Invalid partition 2 **`

Current behavior:

- the log no longer shows that line
- boot proceeds directly to:
  - `switch to partitions #0, OK`
  - `mmc0 is current device`
  - `Scanning mmc 0:1...`

Meaning:

- the stale `finduuid -> mmc 0:2` assumption is no longer active in the tiny
  boot flow

### 3. `/init` Hotplug Bug

This is fixed.

Old behavior:

- `/init: line 12: can't create /proc/sys/kernel/hotplug: nonexistent directory`

Current behavior:

- the log contains:
  - `Run /init as init process`
  - `~ #`
- no hotplug write failure is emitted

Meaning:

- `/init` no longer depends on `/proc/sys/kernel/hotplug`
- the old `mdev` hotplug helper path is no longer being executed

### 4. DTB Public Naming Mismatch

This is fixed.

Old behavior:

- U-Boot loaded `/am335x-boneblack.dtb`

Current behavior:

- U-Boot loads:
  - `/am335x-boneblack-optimal-tiny.dtb`
- Linux reports:
  - `Machine model: TI AM335x BeagleBone Black Optimal Tiny`

Meaning:

- public boot media name and tiny DTB identity now match
- deterministic DT naming cleanup is working

### 5. Wrong Tiny Kernel Class

This is fixed.

The current log proves:

- Linux enters kernel execution
- CPU is recognized as `ARMv7`
- board model is correct
- `/init` runs
- UART shell is reachable

Meaning:

- the earlier no-MMU / wrong ARM-class / non-booting tiny kernel problem is no
  longer present

## Problems Still Present In The Current Log

### 1. `mmc0` Runtime Failure

This is still present and is the main unresolved functional issue.

Direct evidence:

- `mmc0: Timeout waiting for hardware interrupt.`
- `mmc0: error -110 whilst initialising SD card`
- later another timeout repeats:
  - `[   21.710554] mmc0: Timeout waiting for hardware interrupt.`

Meaning:

- Linux runtime access to the SD path is still failing
- this is not just bootloader noise
- this is not prevented by the system booting from RAM

Important boundary:

- U-Boot can still boot the kernel because kernel, DTB, and initramfs were
  loaded before Linux took over
- the failure is specifically in Linux runtime SD/MMC initialization

### 2. TPS65217 Child-Node Warnings

These warnings are still present.

Direct evidence:

- `tps65217-pmic: Failed to locate of_node [id: -1]`
- `tps65217-bl: Failed to locate of_node [id: -1]`

What is known:

- they are real warnings
- they are still unresolved

What is not yet proven:

- whether they are only cleanup warnings
- whether they contribute directly or indirectly to the `mmc0 -110` failure

### 3. MMC Regulator Warnings

These warnings are still present.

Direct evidence:

- `sdhci-omap 48060000.mmc: supply pbias not found, using dummy regulator`
- `sdhci-omap 48060000.mmc: supply vqmmc not found, using dummy regulator`

What is known:

- the MMC runtime path is falling back to dummy regulators
- these warnings occur immediately before the later `mmc0` failure

What is not yet proven:

- whether `pbias` is actually required on this tiny BBB path
- whether `vqmmc` is actually required on this tiny BBB path
- whether adding those supplies would fix `error -110`

### 4. Secondary Kernel Warnings Still Visible

These warnings still exist in the current log:

- `ti-sysc 44e31000.target-module: Failed to create device link (0x180) with ocp`
- `ti-sysc 48040000.target-module: Failed to create device link (0x180) with ocp`
- `omap_gpio 44e07000.gpio: Could not set line 6 debounce to 200000 microseconds (-22)`
- `Kernel memory protection not selected by kernel config.`

Current status:

- still present
- not yet classified as causal or harmless
- not currently proven to explain the `mmc0 -110` failure

## Line-By-Line Classification For The Current Runtime Block

This section expands the current runtime-warning cluster line by line so no
visible log item is left implicit.

### 1. `ti-sysc 44e31000.target-module: Failed to create device link (0x180) with ocp`

Classification:

- warning
- unresolved
- not yet proven causal for `mmc0 -110`

Current interpretation:

- this is a real kernel warning
- it may indicate graph-linking rough edges in the AM335x platform path
- it is not yet justified as the direct cause of the SD runtime failure

### 2. `ti-sysc 48040000.target-module: Failed to create device link (0x180) with ocp`

Classification:

- warning
- unresolved
- not yet proven causal for `mmc0 -110`

Current interpretation:

- same status as the previous `ti-sysc` warning
- still visible
- still unclassified beyond "present but unproven"

### 3. `tps65217-pmic: Failed to locate of_node [id: -1]`

Classification:

- warning
- strong suspect area
- not yet proven causal for `mmc0 -110`

Current interpretation:

- this is a real PMIC child-node graph warning
- it may be relevant to power/regulator modeling
- it is not yet proven to be the direct fix target

### 4. `tps65217-bl: Failed to locate of_node [id: -1]`

Classification:

- warning
- strong suspect area
- not yet proven causal for `mmc0 -110`

Current interpretation:

- same status as the PMIC warning above
- still visible
- still unresolved

### 5. `tps65217 0-0024: TPS65217 ID 0xe version 1.2`

Classification:

- informational
- expected device-identification line
- not an error by itself

Current interpretation:

- the TPS65217 PMIC is being detected on I2C
- this line alone does not indicate failure
- it is useful context because it confirms the PMIC probe path is at least
  partially alive

### 6. `omap_i2c 44e0b000.i2c: bus 0 rev0.11 at 400 kHz`

Classification:

- informational
- expected bus-bring-up line
- not an error by itself

Current interpretation:

- I2C bus 0 is up
- this line is supportive context for PMIC communication
- it is not currently a debug target

### 7. `omap_gpio 44e07000.gpio: Could not set line 6 debounce to 200000 microseconds (-22)`

Classification:

- warning
- unresolved
- not yet proven causal for `mmc0 -110`

Current interpretation:

- this is a real GPIO warning
- its relation to the SD runtime failure is still unknown
- it should not be silently treated as harmless yet

### 8. `clk: Disabling unused clocks`

Classification:

- informational
- expected kernel housekeeping line
- not an error by itself

Current interpretation:

- this is normal kernel behavior
- it is not currently suspicious on its own

### 9. `sdhci-omap 48060000.mmc: Got CD GPIO`

Classification:

- informational
- expected MMC-card-detect line
- useful context, not an error by itself

Current interpretation:

- the MMC driver sees a card-detect GPIO path
- this confirms the runtime failure happens after at least some MMC setup has
  succeeded

### 10. `sdhci-omap 48060000.mmc: supply pbias not found, using dummy regulator`

Classification:

- warning
- strong suspect
- not yet proven required

Current interpretation:

- this is one of the strongest visible suspects for the SD runtime failure
- the driver is falling back to a dummy regulator
- but this line alone is still not enough to justify adding a `pbias` binding

### 11. `sdhci-omap 48060000.mmc: supply vqmmc not found, using dummy regulator`

Classification:

- warning
- strong suspect
- not yet proven required

Current interpretation:

- same status as the `pbias` warning
- the fallback is real
- but the correct fix is still unproven

## Warnings Or Behaviors That Are Present But Not Current Primary Targets

### 1. `ethaddr` Not Set

Visible in the log:

- `<ethaddr> not set. Validating first E-fuse MAC`

Current interpretation:

- not the current blocker
- unrelated to the tiny SD/MMC runtime failure

### 2. USB/RNDIS/Ethernet Chatter In U-Boot

Visible in the log:

- `using musb-hdrc`
- `RNDIS ready`
- `eth3: usb_ether`

Current interpretation:

- still extra bootloader chatter
- not the current tiny functional blocker

### 3. `Loading Environment from nowhere... OK`

Visible twice:

- once in SPL stage
- once in full U-Boot stage

Current interpretation:

- this is expected after the deterministic U-Boot cleanup
- not an error

## Locked Facts Already Proven

These points should now be treated as established:

- `extlinux.conf` is the source of truth for Linux payload selection
- `uEnv.txt` is optional low-level U-Boot text input only
- `uboot.env` is not a tiny-path input and is no longer being probed from FAT
- `finduuid` is no longer part of the tiny deterministic boot path
- DTB public media naming is now canonical:
  - `am335x-boneblack-optimal-tiny.dtb`
- the tiny machine/distro/image naming contract is now canonicalized
- `/init` has moved to a `devtmpfs`-only model
- the board reaches Linux shell successfully on the tiny path

## Open Questions That Still Need Answers

### Core Runtime Question

- what is the exact root cause of:
  - `mmc0: error -110 whilst initialising SD card`

### Graph-Level Suspect Questions

- does the failure come from the `mmc0` or `mmc1` DT graph as wired for BBB?
- does it come from a missing regulator binding?
- does it come from incomplete TPS65217 child-node graph modeling?
- does it come from some other runtime interaction in the AM335x BBB path?

### Regulator Questions

- is `pbias` truly required here, or only optional?
- is `vqmmc` truly required here, or only optional?
- if either is required, where is the correct source of truth:
  - board DT
  - included DT fragment
  - PMIC/regulator node
  - another AM335x support path

### TPS65217 Questions

- are the `tps65217-pmic` and `tps65217-bl` warnings functionally relevant to
  SD runtime?
- or are they only graph-cleanliness warnings that should be handled
  independently?

### Classification Questions

Each visible warning still needs to be classified as one of:

- `proven required`
- `proven optional`
- `proven unrelated`

This classification is still missing for:

- `tps65217-pmic: Failed to locate of_node [id: -1]`
- `tps65217-bl: Failed to locate of_node [id: -1]`
- `supply pbias not found, using dummy regulator`
- `supply vqmmc not found, using dummy regulator`
- `Could not set line 6 debounce`
- `Failed to create device link`

## Investigation Rules

Until there is stronger evidence, do not:

- add `pbias` supply bindings just because the warning exists
- add `vqmmc` supply bindings just because the warning exists
- add TPS65217 child nodes just because the warning exists
- enable new kernel config flags only because a warning mentions a subsystem
- treat warning proximity as proof of causality

## Required Evidence Style

The preferred proof method is differential runtime evidence.

Good evidence examples:

- same boot media shape with one tightly controlled DT change
- before/after UART logs for one suspected cause at a time
- comparing baseline and tiny runtime behavior under the same board and SD setup

Useful support evidence:

- DT inspection
- driver inspection
- generated DTB inspection
- kernel config inspection

But static inspection alone is not enough to justify SD/MMC graph changes.

## Recommended Next Investigation Order

1. Treat `mmc0 -110` as the primary unresolved functional bug.
2. Investigate MMC runtime evidence before broad cleanup warnings.
3. Keep TPS65217 warnings visible, but do not assume they are causal yet.
4. Keep `pbias` and `vqmmc` as strong suspects, but not yet proven fixes.
5. Avoid mixing this work with further naming or deterministic boot cleanup.

## Exit Condition For This Document

This document can stop being an open debug note only when:

- the `mmc0 -110` failure has been explained with evidence
- the relevant warnings have been classified as required, optional, or
  unrelated
- and either:
  - the runtime failure is fixed
  - or it is explicitly deferred with a proven reason
