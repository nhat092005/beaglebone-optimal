# beaglebone-optimal

Self-learning Board Support Package (BSP) workspace for BeagleBone Black / TI AM335x.

![BeagleBone Black BSP](assets/hero.png)

This repository provides a reproducible, Docker-isolated workspace for building and developing Yocto-based BSPs for the BeagleBone Black. It keeps all heavy build data, caches, and sources outside the source tree to ensure a clean git repository.

---

## Key Features

- **Containerized Build Host:** A Docker-based development environment mapping host UID/GID to prevent permission issues.
- **Storage-Backed Workspace:** Reusable shared caches (`downloads` and `sstate-cache`) and workspace-isolated build directories stored under a configurable host path (`PROJECT_STORAGE_ROOT`).
- **Dual Boot Paths:**
  - **Baseline Path:** Standard BeagleBone Black SD card boot (`core-image-minimal`) built via Yocto and flashed as a full-disk `.wic` image.
  - **Tiny Path:** Highly optimized, initramfs-only system (`core-image-optimal-tiny-initramfs`) using `linux-yocto-tiny` for extremely fast boot times and a minimal footprint. Boot artifacts are flashed directly onto a single FAT partition.
- **Quality Gates:** Integrated code style formatting (`clang-format`, `shfmt`) and linting (`shellcheck`, `yamllint`, `hadolint`) verified through `make`.

---

## Getting Started

### 1. Prerequisites

Ensure your host machine has:

- **Docker Engine** and **Docker Compose** plugin.
- The current host user added to the `docker` group.

### 2. Initial Setup

Clone the repository and copy the environment configuration:

```bash
cp local.mk.example local.mk
```

Edit `local.mk` and configure `PROJECT_STORAGE_ROOT` pointing to an absolute host path (e.g., `/mnt/data/beaglebone-optimal`). Do not commit `local.mk`.

Verify the configuration and directory structure:

```bash
make doctor
```

### 3. Initialize and Build Yocto

#### Option A: Baseline Path (core-image-minimal)

1. Open the builder shell:
   ```bash
   make docker-shell
   ```
2. Clone `poky` inside `/workspace/yocto/sources`:
   ```bash
   mkdir -p "$YOCTO_SOURCES_DIR" && cd "$YOCTO_SOURCES_DIR"
   git clone -b scarthgap https://git.yoctoproject.org/poky
   ```
3. Initialize the build directory:
   ```bash
   make yocto-init
   ```
4. Apply example config files:
   ```bash
   cp yocto/conf/bblayers.conf.example "$YOCTO_BUILD_DIR/conf/bblayers.conf"
   cat yocto/conf/local.conf.example >> "$YOCTO_BUILD_DIR/conf/local.conf"
   ```
5. Trigger the build:
   ```bash
   make yocto-build
   ```
6. Flash to an SD card:
   ```bash
   make sd-flash SDCARD=/dev/sdX
   ```

#### Option B: Tiny Path (core-image-optimal-tiny-initramfs)

1. Follow the baseline clone steps above to fetch `poky`.
2. Initialize and apply the tiny configuration:
   ```bash
   make yocto-init
   cp yocto/conf/bblayers.conf.tiny.example "$YOCTO_BUILD_DIR/conf/bblayers.conf"
   cat yocto/conf/local.conf.tiny.example >> "$YOCTO_BUILD_DIR/conf/local.conf"
   ```
3. Build the tiny image:
   ```bash
   make yocto-build YOCTO_IMAGE=core-image-optimal-tiny-initramfs
   ```
4. Flash the single FAT boot partition:
   ```bash
   make sd-flash-tiny SDCARD=/dev/sdX
   ```

---

## Quality and Linting

Run checks locally before committing changes:

```bash
make format  # Auto-formats shell and C/C++ files
make check   # Runs style checks and linters
```

---

## Project Contracts and Documentation

Detailed design rules and guides are located in the `docs/` directory:

- [Run Book (EN)](docs/_RUNBOOK_EN.md) / [Run Book (VN)](docs/_RUNBOOK_VN.md) - Operational instructions.
- [Boot Contract](docs/boot-contract.md) - Normative rules for kernel and bootloader boot paths.
- [Coding Style Contract](docs/coding-style.md) - Formatting and linting standards.

---

## Demo

### Docker Build

> Building the Docker image for the isolated development build environment.

![Docker Build](assets/00-build-docker.gif)

### Docker Shell

> Entering the interactive bash shell within the running builder container.

![Docker Shell](assets/01-docker-shell.gif)

### Yocto Init

> Initializing the storage-backed Yocto build directory environment.

![Yocto Init](assets/00-yocto-init.gif)

### Yocto Build

> Running the bitbake build process inside the container to compile the target image.

![Yocto Build](assets/01-yocto-build.gif)
