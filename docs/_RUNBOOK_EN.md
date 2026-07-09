# Runbook

Vietnamese version: [`_RUNBOOK_VN.md`](./_RUNBOOK_VN.md)

## Scope

This file is the shortest operator path for the current repo contract.

Source of truth:

- runtime: `compose.yaml`
- builder image: `docker/Dockerfile`
- public commands: `Makefile`
- local override: `local.mk`

## Host Setup

Prerequisites:

- Docker Engine
- Docker Compose plugin
- permission to run Docker as the current user

Create local config:

```bash
cp local.mk.example local.mk
```

Set an absolute storage root:

```make
PROJECT_STORAGE_ROOT := /mnt/data/beaglebone-optimal
WORKSPACE_NAME := default
# DOCKER_USER := 1000:1000
```

Validate the setup:

```bash
make doctor
```

Rules:

- do not commit `local.mk`
- large build data lives under `PROJECT_STORAGE_ROOT`
- `sd-flash` and `sd-flash-tiny` are destructive host-side commands

## Important Paths

```text
${PROJECT_STORAGE_ROOT}/
|- shared/
|  |- downloads/
|  `- sstate/
`- workspaces/
   `- ${WORKSPACE_NAME}/yocto/
      |- sources/
      `- build/
```

Derived paths:

- `YOCTO_SOURCES_DIR=${PROJECT_STORAGE_ROOT}/workspaces/${WORKSPACE_NAME}/yocto/sources`
- `YOCTO_POKY_DIR=${YOCTO_SOURCES_DIR}/poky`
- `YOCTO_BUILD_DIR=${PROJECT_STORAGE_ROOT}/workspaces/${WORKSPACE_NAME}/yocto/build`

## Command Surface

| Command | Purpose | Important note |
| --- | --- | --- |
| `make doctor` | Validate Docker and storage setup | Auto-builds the builder image if missing |
| `make docker-build` | Build the builder image | Does not require `PROJECT_STORAGE_ROOT` |
| `make docker-shell` | Open a shell in the builder container | Runs preflight first |
| `make docker-run CMD='...'` | Run one command in the builder container | `CMD` is required |
| `make yocto-init` | Create the Yocto build dir | Does not edit `conf/` |
| `make yocto-parse` | Parse active Yocto metadata | Requires `YOCTO_BUILD_DIR/conf/local.conf` |
| `make yocto-dry-run YOCTO_IMAGE=<image>` | Dry-run image dependencies | Requires a non-empty `YOCTO_IMAGE` |
| `make yocto-qt-profile` | Show effective `qtbase` profile | Use after Qt config is applied |
| `make yocto-build [YOCTO_IMAGE=<image>]` | Build the selected image | Default `YOCTO_IMAGE=core-image-minimal` |
| `make sd-flash SDCARD=/dev/sdX` | Flash a `.wic` image to SD | Requires a whole-disk device |
| `make sd-flash-tiny SDCARD=/dev/sdX` | Create tiny boot media | Partitions and formats the card |
| `make netboot-host-setup NETBOOT_IFACE=<iface>` | Idempotent host TFTP+NFS setup | DEV ONLY, requires `NETBOOT_IFACE` |
| `make netboot-sync-app` | Sync `qt-dashboard` install output to NFS export | DEV ONLY |
| `make netboot-sync-kernel` | Sync `zImage`+dtb to TFTP dir | DEV ONLY |

## Baseline Flow

Clone `poky` first:

```bash
mkdir -p "$YOCTO_SOURCES_DIR"
cd "$YOCTO_SOURCES_DIR"
git clone -b scarthgap https://git.yoctoproject.org/poky
```

Initialize and apply the baseline examples:

```bash
make yocto-init
cp yocto/conf/bblayers.conf.example "$YOCTO_BUILD_DIR/conf/bblayers.conf"
cat yocto/conf/local.conf.example >> "$YOCTO_BUILD_DIR/conf/local.conf"
```

Build and flash:

```bash
make yocto-parse
make yocto-build
make sd-flash SDCARD=/dev/sdX
```

Notes:

- default baseline image: `core-image-minimal`
- default baseline machine: `beaglebone-yocto`
- `sd-flash` uses `IMAGE` if set; otherwise it uses the default `.wic` for the current `YOCTO_IMAGE` and `YOCTO_MACHINE`

## Tiny Flow

Add `meta-swupdate` beside `poky` under `"$YOCTO_SOURCES_DIR"` before building.

Apply the tiny examples:

```bash
make yocto-init
cp yocto/conf/bblayers.conf.tiny.example "$YOCTO_BUILD_DIR/conf/bblayers.conf"
cat yocto/conf/local.conf.tiny.example >> "$YOCTO_BUILD_DIR/conf/local.conf"
```

Build and flash:

```bash
make yocto-parse
make yocto-dry-run YOCTO_IMAGE=core-image-optimal-tiny-initramfs
make yocto-build YOCTO_IMAGE=core-image-optimal-tiny-initramfs
make sd-flash-tiny SDCARD=/dev/sdX
```

Notes:

- tiny image: `core-image-optimal-tiny-initramfs`
- tiny machine: `beaglebone-black-optimal-tiny`
- when `YOCTO_IMAGE=core-image-optimal-tiny-initramfs`, `make yocto-build` also builds `virtual/kernel` and `u-boot`
- `sd-flash-tiny` creates one FAT32 boot partition and copies `MLO`, `u-boot.img`, `zImage`, the tiny DTB, `extlinux.conf`, and `uEnv.txt`

## Qt Dashboard Flow

Add `meta-openembedded`, `meta-qt6`, and `meta-swupdate` beside `poky` under `"$YOCTO_SOURCES_DIR"` before building.

Apply the Qt dashboard examples:

```bash
make yocto-init
cp yocto/conf/bblayers.conf.qt-dashboard.example "$YOCTO_BUILD_DIR/conf/bblayers.conf"
cat yocto/conf/local.conf.qt-dashboard.example >> "$YOCTO_BUILD_DIR/conf/local.conf"
```

Build and flash:

```bash
make yocto-parse
make yocto-qt-profile
make yocto-dry-run YOCTO_IMAGE=core-image-optimal-qt-dashboard
make yocto-build YOCTO_IMAGE=core-image-optimal-qt-dashboard
make sd-flash \
  YOCTO_MACHINE=beaglebone-black-optimal-qt-dashboard \
  YOCTO_IMAGE=core-image-optimal-qt-dashboard \
  SDCARD=/dev/sdX
```

Notes:

- Qt dashboard image: `core-image-optimal-qt-dashboard`
- Qt dashboard machine: `beaglebone-black-optimal-qt-dashboard`

## Qt Dashboard No-A/B Flow

Alternate product path, same image but a single rootfs partition (no OTA/swupdate at runtime). Machine `beaglebone-black-optimal-qt-dashboard-noab`, inherits `beaglebone-black-optimal-tiny.conf` and uses its own WKS, `beaglebone-qt-dashboard-noab.wks`.

Reuses `bblayers.conf.qt-dashboard.example` as-is, so it still requires `meta-openembedded`, `meta-qt6`, and `meta-swupdate` beside `poky` under `"$YOCTO_SOURCES_DIR"` before building (the layer is pulled in even though this machine doesn't use OTA).

Apply the no-A/B examples:

```bash
make yocto-init
cp yocto/conf/bblayers.conf.qt-dashboard.example "$YOCTO_BUILD_DIR/conf/bblayers.conf"
cat yocto/conf/local.conf.qt-dashboard-noab.example >> "$YOCTO_BUILD_DIR/conf/local.conf"
```

Build and flash:

```bash
make yocto-build YOCTO_IMAGE=core-image-optimal-qt-dashboard
make sd-flash \
  YOCTO_MACHINE=beaglebone-black-optimal-qt-dashboard-noab \
  YOCTO_IMAGE=core-image-optimal-qt-dashboard \
  SDCARD=/dev/sdX
```

Notes:

- the machine is selected via `MACHINE` in `local.conf.qt-dashboard-noab.example`; there is no separate `YOCTO_MACHINE` variable for `yocto-build` (only `sd-flash` needs `YOCTO_MACHINE` to pick the right `.wic`)
- shares the same image as the A/B path: `core-image-optimal-qt-dashboard`
- this path is a new working-tree change, not yet committed — check `git status`/`git log` before treating it as stable contract

## Qt Dashboard Dev Netboot Flow (DEV ONLY)

Dev-only, not a production contract. Machine `beaglebone-black-optimal-qt-dashboard-dev`.
Transport is **USB gadget** (RJ45 CPSW confirmed hardware-dead on this board,
see bd `beaglebone-optimal-24b`), not an Ethernet cable. Static point-to-point:
host `192.168.7.1`, board `192.168.7.2`.

**Required order: power the board via USB cable FIRST, then run
`netboot-host-setup`** - unlike a physical NIC (always present), the USB
gadget interface only appears once U-Boot has brought up `usb_ether`.

Plug the USB cable into the board, power it on, then see which new interface
appeared:

```bash
ip link show   # look for the new enx... interface after powering the board
```

Host setup (each host reboot, after the board is already powered):

```bash
make netboot-host-setup NETBOOT_IFACE=<enx...>
```

Build and flash once:

```bash
make yocto-init
cp yocto/conf/bblayers.conf.qt-dashboard.example "$YOCTO_BUILD_DIR/conf/bblayers.conf"
cat yocto/conf/local.conf.qt-dashboard-dev.example >> "$YOCTO_BUILD_DIR/conf/local.conf"
make yocto-build YOCTO_MACHINE=beaglebone-black-optimal-qt-dashboard-dev YOCTO_IMAGE=core-image-optimal-qt-dashboard
make sd-flash YOCTO_MACHINE=beaglebone-black-optimal-qt-dashboard-dev SDCARD=/dev/sdX
```

This dev flow uses the same `bblayers.conf.qt-dashboard.example`, so it also requires `meta-openembedded`, `meta-qt6`, and `meta-swupdate` beside `poky`.

Dev loop:

```bash
make yocto-bitbake BITBAKE_RECIPE=qt-dashboard && make netboot-sync-app
make yocto-bitbake BITBAKE_RECIPE=virtual/kernel && make netboot-sync-kernel
```

Power-cycle the board after each sync. No reflash.

Notes:

- `netboot-host-setup` requires `tftpd-hpa` and `nfs-kernel-server` installed (not auto-installed)
- Ctrl-C during the 2s U-Boot bootdelay for a manual shell if netboot isn't ready
- changing the host IP needs a u-boot rebuild + boot partition reflash (`CONFIG_ENV_IS_NOWHERE=y`)
- don't use this machine to measure production boot time

## Boot Timing Capture (`make boot-capture`)

Host-side UART capture defaults:

- `BOOT_SERIAL_DEVICE=/dev/ttyUSB0`
- `BOOT_SERIAL_BAUD=115200`
- `BOOT_CAPTURE_LOG=tmp/boot-captures/latest.log`

Run:

```bash
make boot-capture
```

Behavior:

- captures the serial stream with host timestamps
- appends output to `tmp/boot-captures/latest.log`
- stop with `Ctrl-C`

## References

- `make help`
- `make yocto-list`
- `docs/boot-contract.md`
