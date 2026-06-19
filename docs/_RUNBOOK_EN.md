# Runbook

Vietnamese version: [`_RUNBOOK_VN.md`](./_RUNBOOK_VN.md)

## Purpose

This runbook explains how to operate the Docker phase 1 builder workflow for
the `beaglebone-optimal` repository.

Current contract:

- runtime truth lives in `compose.yaml`
- image build lives in `docker/Dockerfile`
- public interface lives in `Makefile`
- local machine override lives in `local.mk`

This builder is an ad-hoc build environment. It is not a long-running service
container.

## Relevant structure

```text
.
├── Makefile
├── compose.yaml
├── docker/
│   └── Dockerfile
├── local.mk.example
└── scripts/docker/
    ├── doctor.sh
    └── lib.sh
```

## Prerequisites

The local machine must have:

- Docker Engine
- Docker Compose plugin, used through `docker compose`
- permission to run Docker from the current user

This runbook assumes the machine's Docker daemon is already healthy.

## Local setup

1. Create the local config file:

```bash
cp local.mk.example local.mk
```

2. Edit `local.mk` and set `PROJECT_STORAGE_ROOT` to an absolute path.

Example:

```make
PROJECT_STORAGE_ROOT := /mnt/data/beaglebone-optimal
WORKSPACE_NAME := default

# Optional override. By default Make auto-detects the current host uid:gid.
# DOCKER_USER := 1000:1000
```

Important rules:

- `PROJECT_STORAGE_ROOT` must be an absolute path
- `DOCKER_USER` is an optional override and must match `uid:gid` if set
- do not commit `local.mk`
- large build data must live under `PROJECT_STORAGE_ROOT`, not in the source
  tree

## Storage model

Container mounts:

- repo root -> `/workspace`
- host storage root -> `/storage`

Inside the host storage root, the repo creates this standard layout:

```text
${PROJECT_STORAGE_ROOT}/
├── shared/
│   ├── downloads/
│   └── sstate/
└── workspaces/
    └── ${WORKSPACE_NAME}/
        ├── logs/
        ├── out/
        ├── tmp/
        └── yocto/
            ├── sources/
            └── build/
```

Meaning:

- `shared/` stores reusable caches
- `workspaces/<name>/` stores outputs and state for the current workspace
- `yocto/sources/` stores pinned Yocto checkouts and layers for the workspace
- `yocto/build/` stores the active Yocto Build Directory

Derived host paths exported by `Makefile`:

- `YOCTO_SOURCES_DIR=${PROJECT_STORAGE_ROOT}/workspaces/${WORKSPACE_NAME}/yocto/sources`
- `YOCTO_BUILD_DIR=${PROJECT_STORAGE_ROOT}/workspaces/${WORKSPACE_NAME}/yocto/build`
- `YOCTO_DOWNLOADS_DIR=${PROJECT_STORAGE_ROOT}/shared/downloads`
- `YOCTO_SSTATE_DIR=${PROJECT_STORAGE_ROOT}/shared/sstate`

## Standard public commands

Show help:

```bash
make help
```

Build the image:

```bash
make docker-build
```

Validate the environment:

```bash
make doctor
```

Open a shell inside the builder container:

```bash
make docker-shell
```

Run any command inside the builder container:

```bash
make docker-run CMD='uname -a'
```

Initialize the Yocto build directory:

```bash
make yocto-init
```

Build the default Yocto image:

```bash
make yocto-build
```

Parse the active Yocto metadata:

```bash
make yocto-parse
```

Dry-run the current image dependency graph:

```bash
make yocto-dry-run
```

Flash the default Yocto image to an SD card on the host:

```bash
make sd-flash SDCARD=/dev/sdX
```

## Behavior of each command

### `make docker-build`

Behavior:

- runs `docker compose build builder`
- does not require `PROJECT_STORAGE_ROOT`
- uses Docker build cache when available

Use it when:

- building the image for the first time
- rebuilding after editing `docker/Dockerfile`

### `make doctor`

Behavior:

- checks `docker compose version`
- checks `PROJECT_STORAGE_ROOT`
- creates the required directory tree under the storage root
- renders `docker compose config`
- auto-builds the image if it does not exist
- runs a container and performs a real write test to `/storage`

Successful output:

```text
doctor: ok
```

Use it when:

- cloning the repo on a new machine
- changing `local.mk`
- debugging mount or permission problems

### `make docker-shell`

Behavior:

- runs a light preflight
- requires a valid `PROJECT_STORAGE_ROOT`
- creates storage directories if missing
- auto-builds the image if it does not exist
- opens a shell in `/workspace`

### `make docker-run CMD='...'`

Behavior:

- runs the same light preflight as `docker-shell`
- fails immediately if `CMD` is empty
- runs the command with this pattern:

```bash
docker compose run --rm builder bash -lc "$CMD"
```

Examples:

```bash
make docker-run CMD='pwd'
make docker-run CMD='ls -la /storage'
make docker-run CMD='env | sort'
```

### `make yocto-init`

Behavior:

- runs the same preflight as `docker-shell`
- requires a valid `poky` checkout at `YOCTO_POKY_DIR`
- creates the Yocto Build Directory by sourcing `oe-init-build-env`
- does not edit files under `conf/`
- prints the project `local.conf` and `bblayers.conf` example paths and the next manual step

Use it when:

- `poky` is already cloned under `YOCTO_SOURCES_DIR`
- you want `conf/` generated under the storage-backed build dir

### `make yocto-build`

Behavior:

- runs the same preflight as `docker-shell`
- requires the `poky` checkout and `YOCTO_BUILD_DIR/conf/local.conf`
- sources `oe-init-build-env` for the storage-backed build dir
- runs `bitbake ${YOCTO_IMAGE}`

Use it when:

- `make yocto-init` already created the build dir
- `conf/local.conf` already includes the project settings you want

### `make yocto-parse`

Behavior:

- runs the same preflight as `docker-shell`
- requires the `poky` checkout and `YOCTO_BUILD_DIR/conf/local.conf`
- sources `oe-init-build-env` for the storage-backed build dir
- runs `bitbake -p`

Use it when:

- you want to confirm the active metadata parses before a real build
- you changed `bblayers.conf`, recipes, or layer composition

### `make yocto-dry-run`

Behavior:

- runs the same preflight as `docker-shell`
- requires the `poky` checkout and `YOCTO_BUILD_DIR/conf/local.conf`
- requires a non-empty `YOCTO_IMAGE`
- sources `oe-init-build-env` for the storage-backed build dir
- runs `bitbake ${YOCTO_IMAGE} -n`

Use it when:

- you want to confirm the current image dependency graph before a real build
- you changed image, packagegroup, or recipe contracts

### `make sd-flash SDCARD='/dev/sdX'`

Behavior:

- runs on the host, not in the builder container
- requires an explicit whole-disk block device through `SDCARD`
- uses `IMAGE` if provided, otherwise flashes the default `.wic` under `YOCTO_BUILD_DIR`
- unmounts mounted child partitions of the selected device before writing
- prefers `bmaptool` with `${IMAGE}.bmap` when both exist
- falls back to `dd` when `bmaptool` or the `.bmap` file is missing

Use it when:

- `make yocto-build` already produced the `.wic` artifact
- you have identified the correct SD card device on the host
- you want a repeatable host-side flash command for Phase 2 bring-up

## Yocto storage convention

The repo keeps Yocto's heavy data under the same host storage root as Docker:

- `/storage/workspaces/${WORKSPACE_NAME}/yocto/sources`
- `/storage/workspaces/${WORKSPACE_NAME}/yocto/build`
- `/storage/shared/downloads`
- `/storage/shared/sstate`

Recommended workflow inside the builder container:

```bash
mkdir -p "$YOCTO_SOURCES_DIR"
cd "$YOCTO_SOURCES_DIR"
git clone -b scarthgap https://git.yoctoproject.org/poky
cd poky

source oe-init-build-env "$YOCTO_BUILD_DIR"

cat /workspace/yocto/conf/local.conf.example
cat /workspace/yocto/conf/bblayers.conf.example
```

This keeps source checkouts, build output, downloads, and sstate off the source
tree and under the same host-managed storage root.

Manual update flow for `conf/local.conf`:

```bash
make yocto-init

cd "$YOCTO_POKY_DIR"
source oe-init-build-env "$YOCTO_BUILD_DIR"

cp /workspace/yocto/conf/bblayers.conf.example conf/bblayers.conf
cat /workspace/yocto/conf/local.conf.example >> conf/local.conf
```

## Tiny path workflow

The tiny path is Phase 1 initramfs-only bring-up for BeagleBone Black.

Public contract files:

- `docs/boot-contract.md`
- `yocto/conf/local.conf.tiny.example`
- `yocto/conf/bblayers.conf.tiny.example`
- `yocto/boot/extlinux.tiny.conf`
- `yocto/boot/uEnv.tiny.txt`

Manual tiny config apply flow:

```bash
make yocto-init

cd "$YOCTO_POKY_DIR"
source oe-init-build-env "$YOCTO_BUILD_DIR"

cp /workspace/yocto/conf/bblayers.conf.tiny.example conf/bblayers.conf
cat /workspace/yocto/conf/local.conf.tiny.example >> conf/local.conf
```

Build the tiny image:

```bash
make yocto-parse
make yocto-dry-run YOCTO_IMAGE=core-image-optimal-tiny-initramfs
make yocto-build YOCTO_IMAGE=core-image-optimal-tiny-initramfs
```

Create tiny SD boot media on the host:

```bash
make sd-flash-tiny SDCARD=/dev/sdX
```

Tiny path operator notes:

- `sd-flash-tiny` creates a single FAT boot partition
- tiny boot media carries stable names:
  - `MLO`
  - `u-boot.img`
  - `zImage`
  - `am335x-boneblack-optimal-tiny.dtb`
  - `extlinux/extlinux.conf`
  - optional `uEnv.txt`
- tiny path does not use `.wic` or a separate ext4 rootfs partition
- tiny path still expects proof on hardware through UART boot logs

## Qt dashboard product path

The Qt dashboard path is a separate product-side product contract. It does not
redefine the tiny path contract.

Public contract files:

- `yocto/conf/bblayers.conf.qt-dashboard.example`
- `yocto/conf/local.conf.qt-dashboard.example`
- `meta-beaglebone-optimal-product/conf/layer.conf`
- `meta-beaglebone-optimal-product/recipes-core/images/core-image-optimal-qt-dashboard.bb`
- `meta-beaglebone-optimal-product/recipes-core/packagegroups/packagegroup-optimal-dashboard.bb`
- `meta-beaglebone-optimal-product/recipes-qt/qt6/qtbase_%.bbappend`
- `meta-beaglebone-optimal-product/recipes-qt/qt-dashboard/qt-dashboard.bb`
- `meta-beaglebone-optimal-product/recipes-qt/qt-dashboard/files/qt-dashboard.service`
- `meta-beaglebone-optimal-product/recipes-qt/qt-dashboard/files/qt-dashboard.sh`
- `qt-dashboard-app/`

Expected upstream layer path:

- `${YOCTO_SOURCES_DIR}/meta-qt6`

Manual product config apply flow:

```bash
make yocto-init

cd "$YOCTO_POKY_DIR"
source oe-init-build-env "$YOCTO_BUILD_DIR"

cp /workspace/yocto/conf/bblayers.conf.qt-dashboard.example conf/bblayers.conf
cat /workspace/yocto/conf/local.conf.qt-dashboard.example >> conf/local.conf
```

Build the product image:

```bash
make yocto-parse
make yocto-qt-profile
make yocto-dry-run YOCTO_IMAGE=core-image-optimal-qt-dashboard
make yocto-build YOCTO_IMAGE=core-image-optimal-qt-dashboard
```

Flash the BeagleBone Black product image:

```bash
make sd-flash \
  YOCTO_MACHINE=beaglebone-black-optimal-qt-dashboard \
  YOCTO_IMAGE=core-image-optimal-qt-dashboard \
  SDCARD=/dev/sdX
```

Operator notes:

- the product path keeps the current BSP layer at `/workspace/meta-beaglebone-optimal`
- the product path adds `/workspace/meta-beaglebone-optimal-product` as a separate layer
- the product path expects `meta-qt6` to exist beside `poky`
- tiny stays headless; it must not become the owner of HDMI/display behavior
- the product path owns HDMI/display behavior and verification
- the product path now targets BeagleBone Black explicitly instead of the
  generic `beaglebone-yocto` machine
- runtime display defaults live in `qt-dashboard.sh`
- build-time feature trimming lives in `local.conf.qt-dashboard.example` and `qtbase_%.bbappend`
- product policy drops desktop, audio, wifi, and zeroconf stacks that are not
  part of the local-only fullscreen appliance path
- the launcher contract is a single fullscreen Qt Quick app on LinuxFB with software rendering

Build-side proof checklist:

```bash
make yocto-parse
make yocto-qt-profile
make yocto-dry-run YOCTO_IMAGE=core-image-optimal-qt-dashboard
make docker-run WORKSPACE_NAME=qt-dashboard CMD='cd "$$YOCTO_POKY_DIR" && source oe-init-build-env "$$YOCTO_BUILD_DIR" && bitbake gcc-source-13.4.0'
make docker-run WORKSPACE_NAME=qt-dashboard CMD='cd "$$YOCTO_POKY_DIR" && source oe-init-build-env "$$YOCTO_BUILD_DIR" && bitbake gcc'
make yocto-build WORKSPACE_NAME=qt-dashboard YOCTO_IMAGE=core-image-optimal-qt-dashboard
```

Board-side HDMI proof checklist:

```bash
ls -l /dev/fb0
systemctl status qt-dashboard
journalctl -u qt-dashboard -b --no-pager
```

Required operator observation:

- the HDMI-attached screen shows the fullscreen dashboard

If `/dev/fb0` is missing on the product image, treat that as a product-path
display gap and pause before expanding into kernel or device tree work.

### Known boot messages

**"Kernel memory protection not selected by kernel config."**

Source: `init/main.c::mark_readonly()`

Meaning:
- ARM architecture supports kernel memory protection (`CONFIG_ARCH_HAS_STRICT_KERNEL_RWX=y`)
- Tiny kernel intentionally disables it (`CONFIG_STRICT_KERNEL_RWX=n`)
- Trade-off: ~200-300 KB size savings vs. W^X kernel hardening

Safety:
- Acceptable for isolated learning board (no network, no USB in Phase 1)
- Protection prevents code injection attacks and detects memory corruption bugs early
- If adding network stack in future phases, consider enabling via `hardening.cfg` fragment

This is an intentional configuration choice for the tiny profile, not a defect.

## Runtime contract

The current Compose service name is `builder`.

Important runtime contract:

- image: `${DOCKER_IMAGE}:${DOCKER_TAG}`
- source bind mount: `.:/workspace`
- storage bind mount: `${PROJECT_STORAGE_ROOT}:/storage`
- user mapped from host: `${DOCKER_USER}`
- env inside the container:
  - `PROJECT_STORAGE_ROOT=/storage`
  - `WORKSPACE_NAME=${WORKSPACE_NAME}`
  - `YOCTO_ROOT=/storage/workspaces/${WORKSPACE_NAME}/yocto`
  - `YOCTO_SOURCES_DIR=/storage/workspaces/${WORKSPACE_NAME}/yocto/sources`
  - `YOCTO_POKY_DIR=/storage/workspaces/${WORKSPACE_NAME}/yocto/sources/poky`
  - `YOCTO_BUILD_DIR=/storage/workspaces/${WORKSPACE_NAME}/yocto/build`
  - `YOCTO_DOWNLOADS_DIR=/storage/shared/downloads`
  - `YOCTO_SSTATE_DIR=/storage/shared/sstate`
  - `YOCTO_IMAGE=${YOCTO_IMAGE}`

## Image contract

The current `docker/Dockerfile`:

- uses `ubuntu@sha256:...` pinned by digest
- installs the toolchain and build dependencies for the builder
- uses `--no-install-recommends`
- cleans apt lists
- pins `dtschema==2026.4`
- uses `WORKDIR /workspace`
- uses `bash` as the default command

It does not include:

- `ENTRYPOINT`
- `HEALTHCHECK`
- `EXPOSE`
- hardcoded local APT mirror settings
- hardcoded fixed runtime user

## Recommended operating flow

### First time on a new machine

```bash
cp local.mk.example local.mk
$EDITOR local.mk
make doctor
make docker-shell
```

### After editing the Dockerfile

```bash
make docker-build
make doctor
```

### Quick command checks

```bash
make docker-run CMD='uname -a'
make docker-run CMD='python3 --version'
```

## Common failures

### `PROJECT_STORAGE_ROOT is required`

Cause:

- `local.mk` has not been created yet
- the variable has not been exported

Fix:

```bash
cp local.mk.example local.mk
```

Then set:

```make
PROJECT_STORAGE_ROOT := /absolute/path
```

### `PROJECT_STORAGE_ROOT must be an absolute path`

Cause:

- a relative path was used

Wrong:

```make
PROJECT_STORAGE_ROOT := tmp/build
```

Correct:

```make
PROJECT_STORAGE_ROOT := /mnt/data/beaglebone-optimal
```

### `CMD is required`

Cause:

- `make docker-run` was called without `CMD`

Correct:

```bash
make docker-run CMD='uname -a'
```

### `make doctor` fails on the `/storage` write step

Common causes:

- the host path is not writable
- the current user lacks permission on that path
- the Docker daemon is running but the bind mount target is not suitable

Fix flow:

1. check `PROJECT_STORAGE_ROOT` in `local.mk`
2. check host write permission on that path
3. rerun:

```bash
make doctor
```

### Shell shows `I have no name!`

Meaning:

- the container is still working correctly
- the host-mapped UID/GID does not have a matching name entry inside the image

Impact:

- mostly cosmetic in the shell prompt
- it does not block `docker-shell`, `docker-run`, or `doctor`

Current status:

- this is a known follow-up, not a phase 1 blocker

## What not to do

- do not write build artifacts into the source tree
- do not hardcode local paths such as `/mnt/data/...` into tracked files
- do not change runtime behavior in README only and forget to sync `Makefile`,
  `compose.yaml`, and `scripts/docker/*.sh`
- do not use `rtk` inside repo docs or repo scripts

## When changing the contract

If Docker phase 1 behavior changes, run at least:

```bash
docker compose config
make help
make docker-build
make doctor
make docker-run CMD='uname -a'
```

## Source of truth

If this document conflicts with code, read in this order:

1. `Makefile`
2. `scripts/docker/lib.sh`
3. `scripts/docker/doctor.sh`
4. `compose.yaml`
5. `docker/Dockerfile`
