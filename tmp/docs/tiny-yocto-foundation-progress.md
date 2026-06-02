# Tiny Yocto Foundation Progress

## 2026-06-02

- Claimed beads issue `beaglebone-optimal-09q` for Phase 1 tiny foundation implementation.
- Re-read the locked Phase 1 and Phase 2 documents in `tmp/docs/`.
- Inspected current repo public surface:
  - `Makefile`
  - `scripts/sd-flash`
  - `docs/_RUNBOOK_EN.md`
  - `yocto/conf/*.example`
- Inspected Poky kernel/image/U-Boot plumbing for:
  - `poky-tiny`
  - `core-image-tiny-initramfs`
  - `linux-yocto-tiny`
  - `uboot-extlinux-config`
  - bundled initramfs artifact naming
- Confirmed `linux-yocto-tiny` needs BBB-specific compatibility and mapping in the custom layer.
- Added a BBB tiny kernel metadata path in `meta-beaglebone-optimal`:
  - custom external BSP file `beaglebone-tiny.scc`
  - custom BBB tiny DT `am335x-boneblack-optimal-tiny.dts`
  - custom kernel delta `tiny.cfg`
- Fixed the first tiny-kernel blockers in sequence:
  - missing BBB tiny BSP definition for `do_kernel_metadata`
  - bad relative `beaglebone.cfg` lookup from the custom `.scc`
  - incompatible upstream ARM patch stack by switching the custom BSP to a config-only external BSP
  - DT compile failure from the unlabeled `leds` node on kernel `6.6.127`
- Proved the custom `linux-yocto-tiny` path now builds successfully through:
  - `do_kernel_metadata`
  - `do_patch`
  - `do_compile`
- Proved the full tiny Yocto build now succeeds with:
  - `make yocto-build YOCTO_IMAGE=core-image-bbb-tiny-initramfs`
- Confirmed deploy artifacts now exist under the tiny deploy directory, including:
  - `MLO`
  - `u-boot.img`
  - `am335x-boneblack-optimal-tiny.dtb`
  - `core-image-bbb-tiny-initramfs-*.cpio.gz`
  - `zImage-initramfs-beaglebone-optimal-tiny.bin`
- Tightened tiny target package drift after the first successful build:
  - removed `busybox-udhcpc`
  - removed `update-alternatives-opkg`
- Current tiny manifest now contains only:
  - `base-files`
  - `base-passwd`
  - `beaglebone-optimal-tiny-init`
  - `busybox`
  - `busybox-inittab`
  - `busybox-mdev`
  - `musl`
  - `ttyrun`
- Remaining Phase 1 blocker is now physical proof, not Yocto build plumbing:
  - run `make sd-flash-tiny SDCARD=/dev/sdX`
  - boot BBB from SD
  - capture UART log showing automatic BusyBox shell and working `dmesg`

## 2026-06-02 Continuation Verification

- Re-ran the public tiny contract listing:
  - `make yocto-list`
- Confirmed the tiny deploy directory still contains the expected boot artifacts:
  - `MLO`
  - `u-boot.img`
  - `am335x-boneblack-optimal-tiny.dtb`
  - `core-image-bbb-tiny-initramfs-beaglebone-optimal-tiny.cpio.gz`
  - `zImage-initramfs-beaglebone-optimal-tiny.bin`
- Re-ran the full tiny build successfully:
  - `make yocto-build YOCTO_IMAGE=core-image-bbb-tiny-initramfs`
- Build configuration confirmed:
  - `MACHINE = "beaglebone-optimal-tiny"`
  - `DISTRO = "beaglebone-optimal-tiny"`
  - `meta-beaglebone-optimal = "feat/tiny-yocto-foundation:98a8ab6b0038a3e83dc5e94de7e7e7d0e4b4bb93"`
- Current tiny manifest still contains only:
  - `base-files`
  - `base-passwd`
  - `beaglebone-optimal-tiny-init`
  - `busybox`
  - `busybox-inittab`
  - `busybox-mdev`
  - `musl`
  - `ttyrun`
- Ran repo quality gate:
  - `make check`
  - result: passed; host emitted only the existing non-fatal `hadolint` warning.
- Remaining Phase 1 blocker is unchanged and requires physical hardware access:
  - flash SD using `make sd-flash-tiny SDCARD=/dev/sdX`
  - boot BeagleBone Black from SD
  - capture UART proof showing automatic BusyBox shell and working `dmesg`

## 2026-06-02 Hardware Availability Check

- Checked current host block devices with:
  - `lsblk -o NAME,PATH,TYPE,SIZE,MODEL,RM,MOUNTPOINTS`
- Result:
  - no removable SD-card-sized disk is currently visible
  - only internal NVMe disks and loop devices are present
- Checked UART candidates with:
  - `find /dev -maxdepth 1 -type c \( -name 'ttyUSB*' -o -name 'ttyACM*' -o -name 'ttyS*' \)`
- Result:
  - no `/dev/ttyUSB*` or `/dev/ttyACM*` device is currently visible
- Checked USB devices with:
  - `lsusb`
- Result:
  - no obvious BeagleBone Black or USB UART adapter is currently attached
- No destructive flash command was run because there is no confirmed target
  `SDCARD` device.
- Remaining Phase 1 blocker is physical access:
  - attach the SD card to the host
  - identify the whole-disk device, for example `/dev/sdX`
  - run `make sd-flash-tiny SDCARD=/dev/sdX`
  - connect UART
  - boot BBB from SD
  - capture the UART log showing automatic BusyBox shell and working `dmesg`

## 2026-06-02 Kernel Phase-Tree Refactor

- Replaced the ad-hoc root-level tiny kernel metadata files with the locked
  active tree:
  - `phase1/dts/`
  - `phase1/scc/`
  - `phase1/cfg/`
- Updated `linux-yocto-tiny_6.6.bbappend` to wire only:
  - `am335x-boneblack-optimal-tiny.dts`
  - `beaglebone-tiny.scc`
  - `kernel-policy.scc`
  - `core.cfg`
  - `disable.cfg`
  - `hw.cfg`
- Removed the incorrect legacy active-path files:
  - root-level `am335x-boneblack-optimal-tiny.dts`
  - root-level `beaglebone-tiny.scc`
  - root-level `tiny.cfg`
  - the transitional `standard-arm-nopatch.scc`
  - the transitional `tiny-arm-nopatch.scc`
- Rebuilt from clean kernel state:
  - `make docker-run CMD='cd "$$YOCTO_POKY_DIR" && source oe-init-build-env "$$YOCTO_BUILD_DIR" >/dev/null && bitbake -c cleansstate linux-yocto-tiny'`
  - `make yocto-build YOCTO_IMAGE=core-image-bbb-tiny-initramfs`
- New evidence:
  - `do_kernel_metadata` succeeded using only `phase1/` files
  - `do_patch` succeeded after dropping the broad inherited standard feature
    buckets from the active path
  - full tiny build completed successfully again
- Final tiny kernel config evidence:
  - `CONFIG_MMU=y`
  - `CONFIG_ARCH_MULTI_V7=y`
  - `CONFIG_SOC_AM33XX=y`
  - `CONFIG_ARCH_OMAP2PLUS=y`
  - `# CONFIG_MODULES is not set`
  - `# CONFIG_NET is not set`
  - `# CONFIG_THUMB2_KERNEL is not set`
- Deploy artifact evidence now includes stable symlink names consumed by
  `sd-flash-tiny`:
  - `MLO`
  - `u-boot.img`
  - `am335x-boneblack-optimal-tiny.dtb`
  - `zImage`
  - `zImage-initramfs-beaglebone-optimal-tiny.bin`
  - `core-image-bbb-tiny-initramfs-beaglebone-optimal-tiny.cpio.gz`

## 2026-06-03 Runtime Ownership Canonicalization

- Moved tracked tiny `/init` ownership into the image layer:
  - removed the standalone `recipes-core/beaglebone-optimal-tiny-init/`
    package recipe
  - added `meta-beaglebone-optimal/recipes-core/images/files/init`
  - made `core-image-bbb-tiny-initramfs.bb` install `/init` directly during
    image rootfs assembly
- Moved boot-architecture truth out of
  `yocto/conf/local.conf.tiny.example`:
  - removed `SERIAL_CONSOLES`
  - removed `INITRAMFS_IMAGE`
  - removed `INITRAMFS_IMAGE_BUNDLE`
- Made machine metadata the owner of those values in
  `conf/machine/beaglebone-optimal-tiny.conf`:
  - `SERIAL_CONSOLES`
  - `INITRAMFS_IMAGE`
  - `INITRAMFS_IMAGE_BUNDLE`
- Rebuilt the tiny image successfully:
  - `make yocto-build YOCTO_IMAGE=core-image-bbb-tiny-initramfs`
- Verified contract and artifact truth:
  - `make yocto-list` still reports the expected tiny public surface
  - the built initramfs contains executable `/init`
  - the built initramfs contains `/dev/console`
