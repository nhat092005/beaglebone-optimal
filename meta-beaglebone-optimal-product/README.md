# meta-beaglebone-optimal-product

Product layer for the BeagleBone Black Qt dashboard path.

## Description

Sits above `meta-beaglebone-optimal` (priority 9 vs 8) and provides the
product-side image, packagegroup, Qt dashboard recipe, and distro overlay
for the fullscreen Qt dashboard build path.

## Dependencies

| Layer | Branch |
|-------|--------|
| `meta` (poky) | scarthgap |
| `meta-poky` | scarthgap |
| `meta-yocto-bsp` | scarthgap |
| `meta-oe` (meta-openembedded) | scarthgap |
| `meta-python` (meta-openembedded) | scarthgap |
| `meta-qt6` | scarthgap |
| `meta-beaglebone-optimal` (this repo) | - |

## Layer priority

`9` - above the BSP layer so product recipes can override BSP defaults.

## BSPDIR

Recipes in this layer reference `${BSPDIR}` to locate the `qt-dashboard-app`
source tree, which lives in the same repository as these meta layers.

`BSPDIR` is set automatically in `layer.conf` to the parent directory of this
layer (i.e. the repo root). For Docker-based builds the repo root is always
`/workspace`. Override in `local.conf` only when building outside the Docker
builder:

```
BSPDIR = "/absolute/path/to/beaglebone-optimal"
```

## Contents

```
conf/
  distro/optimal-qt-dashboard.conf  - optimal-tiny derivative with Qt DISTRO_FEATURES
  layer.conf

recipes-core/
  busybox/busybox-inittab           - custom inittab for Qt auto-login
  images/core-image-optimal-qt-dashboard.bb
  packagegroups/packagegroup-optimal-dashboard.bb
  rtcsync/                          - userspace DS3231 to system clock sync utility

recipes-qt/
  qt6/qtbase_%.bbappend             - platform plugin / eglfs config
  qt-dashboard/qt-dashboard.bb      - CMake Qt app built from qt-dashboard-app/

wic/
  beaglebone-qt-dashboard.wks
  beaglebone-qt-dashboard-extlinux.conf
```

## Maintainer

BeagleBone Optimal project - see repo root `docs/` for build instructions.
