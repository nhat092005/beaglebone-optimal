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

## Additional Informational Lines Still Worth Recording

The current document already captures the main failures, warnings, and suspects.
The following items are not primary debug targets right now, but they are still
meaningful log lines and should be preserved as part of a complete inventory.

### U-Boot Stage Informational Lines

- `U-Boot SPL 2024.01 (Jan 08 2024 - 15:37:48 +0000)`
- `Trying to boot from MMC1`
- `U-Boot 2024.01 (Jan 08 2024 - 15:37:48 +0000)`
- `CPU  : AM335X-GP rev 2.1`
- `Model: TI AM335x BeagleBone Black`
- `DRAM:  512 MiB`
- `Core:  160 devices, 18 uclasses, devicetree: separate`
- `WDT:   Started wdt@44e35000 with servicing every 1000ms (60s timeout)`
- `NAND:  0 MiB`
- `MMC:   OMAP SD/MMC: 0, OMAP SD/MMC: 1`
- `switch to partitions #0, OK`
- `mmc0 is current device`
- `Found /extlinux/extlinux.conf`
- `Retrieving file: /extlinux/extlinux.conf`
- `1:      tiny`
- `Retrieving file: /zImage`
- `append: console=ttyS0,115200`
- `Retrieving file: /am335x-boneblack-optimal-tiny.dtb`
- `Hit any key to stop autoboot:  0`
- `Kernel image @ 0x82000000 [ 0x000000 - 0x27cda0 ]`
- `## Flattened Device Tree blob at 88000000`
- `Booting using the fdt blob at 0x88000000`
- `Working FDT set to 88000000`
- `Loading Device Tree to 8ffec000, end 8ffff551 ... OK`
- `Working FDT set to 8ffec000`

### Exact USB Network Chatter Lines

- `<ethaddr> not set. Validating first E-fuse MAC`
- `Net:   eth2: ethernet@4a100000using musb-hdrc, OUT ep1out IN ep1in STATUS ep2in`
- `MAC de:ad:be:ef:00:01`
- `HOST MAC de:ad:be:ef:00:00`
- `RNDIS ready`
- `, eth3: usb_ether`

Current interpretation:

- these lines should be treated as bootloader USB/network chatter unless a
  later goal explicitly targets U-Boot network cleanup
- the exact MAC values are now preserved in the debug inventory

Current interpretation:

- these lines confirm the tiny boot contract is being exercised as intended
- they are not error lines by themselves
- together they prove the boot path reaches the expected kernel, DTB, and
  command line inputs

### Early Kernel Informational Lines

- `Booting Linux on physical CPU 0x0`
- `Linux version 6.6.127-yocto-tiny ...`
- `CPU: ARMv7 Processor [413fc082] revision 2 (ARMv7), cr=10c5387d`
- `OF: fdt: Machine model: TI AM335x BeagleBone Black Optimal Tiny`
- `Kernel command line: console=ttyS0,115200`
- `devtmpfs: initialized`
- `printk: console [ttyS0] disabled`
- `44e09000.serial: ttyS0 at MMIO 0x44e09000 (irq = 18, base_baud = 3000000) is a 8250`
- `printk: console [ttyS0] enabled`
- `pinctrl-single 44e10800.pinmux: 142 pins, size 568`
- `OMAP GPIO hardware version 0.1`
- `mmc0 bounce up to 128 segments into one, max segment size 65536 bytes`
- `mmc0: SDHCI controller on 48060000.mmc [48060000.mmc] using DMA`
- `Freeing unused kernel image (initmem) memory: 1540K`

Current interpretation:

- these lines show the kernel bring-up path is substantially healthy
- they are useful context for proving that the failure happens late enough to
  be a runtime MMC issue, not an early boot crash

### Informational Lines Near The Warning Cluster

- `omap_voltage_late_init: Voltage driver support not added`
- `/ocp/interconnect@44c00000/segment@200000/target-module@10000/scm@0/pinmux@800: Fixed dependency cycle(s) ...`
- `tps65217 0-0024: TPS65217 ID 0xe version 1.2`
- `omap_i2c 44e0b000.i2c: bus 0 rev0.11 at 400 kHz`
- `clk: Disabling unused clocks`
- `sdhci-omap 48060000.mmc: Got CD GPIO`

Current interpretation:

- some of these are clearly informational
- some are context lines adjacent to the warnings
- none of them, by themselves, are yet the proven fix target

### SDHCI Register Dump Evidence

The runtime failure includes a full SDHCI register dump:

- `Sys addr`
- `Version`
- `Blk size`
- `Blk cnt`
- `Argument`
- `Trn mode`
- `Present`
- `Host ctl`
- `Power`
- `Blk gap`
- `Wake-up`
- `Clock`
- `Timeout`
- `Int stat`
- `Int enab`
- `Sig enab`
- `ACmd stat`
- `Slot int`
- `Caps`
- `Caps_1`
- `Cmd`
- `Max curr`
- `Resp[0]`
- `Resp[1]`
- `Resp[2]`
- `Resp[3]`
- `Host ctl2`

Current interpretation:

- the dump is important evidence that the MMC driver reached a hard runtime
  failure state
- the current document does not yet interpret these registers individually
- if the MMC investigation deepens, this dump should be decoded separately

### Exact SDHCI Register Dump Values From The Current Log

- `Sys addr:  0x00000000`
- `Version:  0x00003101`
- `Blk size:  0x00000008`
- `Blk cnt:  0x00000001`
- `Argument:  0x00000000`
- `Trn mode: 0x00000013`
- `Present:   0x01f70a06`
- `Host ctl: 0x00000000`
- `Power:     0x0000000f`
- `Blk gap:  0x00000000`
- `Wake-up:   0x00000000`
- `Clock:    0x00003c07`
- `Timeout:   0x00000003`
- `Int stat: 0x00000000`
- `Int enab:  0x027f000b`
- `Sig enab: 0x027f000b`
- `ACmd stat: 0x00000000`
- `Slot int: 0x00000000`
- `Caps:      0x07e10080`
- `Caps_1:   0x00000000`
- `Cmd:       0x0000333a`
- `Max curr: 0x00000000`
- `Resp[0]:   0x00000920`
- `Resp[1]:  0xe8f37f80`
- `Resp[2]:   0x5b590000`
- `Resp[3]:  0x400e0032`
- `Host ctl2: 0x00000000`

Current interpretation:

- these values are now preserved exactly for later low-level MMC analysis
- they are not yet decoded in this document

### Truncated Or Imperfectly Rendered Lines

Some log lines appear truncated or shortened in the capture:

- `Linux version ... #1 P6`
- `/ocp/... Fixed dependency cycle(s) with /ocp/interconnect@44c00000s`

Current interpretation:

- these lines should be treated carefully if later analysis depends on exact
  wording
- if needed, a cleaner UART capture should be taken before drawing precise
  conclusions from them

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
