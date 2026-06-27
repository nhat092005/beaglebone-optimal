# meta-beaglebone-optimal

BSP layer for the BeagleBone Black optimal build paths.

## Description

Provides the machine configurations, distro policy, kernel recipes, and
U-Boot recipes for the two build paths shipped by this project:

| Path | Machine | Distro |
|------|---------|--------|
| Tiny initramfs | `beaglebone-black-optimal-tiny` | `optimal-tiny` |
| Qt dashboard (BSP half) | `beaglebone-black-optimal-qt-dashboard` | see `meta-beaglebone-optimal-product` |

## Dependencies

| Layer | Branch |
|-------|--------|
| `meta` (poky) | scarthgap |
| `meta-poky` | scarthgap |
| `meta-yocto-bsp` | scarthgap |

## Layer priority

`8` — below the product layer (`meta-beaglebone-optimal-product`, priority 9).

## Contents

```
conf/
  distro/optimal-tiny.conf          — poky-tiny derivative, init_manager=none
  machine/beaglebone-black-optimal-tiny.conf
  machine/beaglebone-black-optimal-qt-dashboard.conf

classes/
  linux-yocto-tiny-feature-dts.bbclass — feature-flag DTS composition system

recipes-bsp/u-boot/                 — u-boot_2024.01 bbappend + patches
recipes-core/images/                — core-image-optimal-tiny-initramfs
recipes-kernel/linux/               — linux-yocto-tiny_6.6 bbappend + feature catalog
recipes-kernel/optimal-env-manager/ — out-of-tree kernel module (SHT3x/BH1750/chardev)
```

## Maintainer

BeagleBone Optimal project — see repo root `docs/` for build instructions.
