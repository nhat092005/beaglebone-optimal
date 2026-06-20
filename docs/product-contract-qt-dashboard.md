# Qt Dashboard Product Contract

## Purpose

This document defines the ownership model for the BeagleBone Black Rev D Qt
dashboard product path.

## Ownership Model

The Qt dashboard product path is a tiny-derived product path:

- `meta-beaglebone-optimal`
  - owns the reusable tiny kernel feature catalog
  - keeps the feature catalog default-off
- `meta-beaglebone-optimal-product`
  - owns product selection and boot/runtime policy
  - enables the required tiny kernel features
  - owns the HDMI Rev D patch stack
  - owns the product machine, product image, packagegroup, and WIC layout

## Required Kernel Features

The product path must enable exactly these reusable tiny kernel features:

- `I2C2_BUS`
- `RTC_DS3231`
- `SHT3X`
- `BH1750`

These features remain default-off in the base layer and are enabled only from
the product kernel path.

## HDMI Rule

HDMI Rev D support is product-specific kernel integration.

It must stay in the product kernel path and must not be folded into the
reusable tiny sensor feature catalog.

## Userspace Rule

The product image must remain a single-app appliance path:

- keep serial console debug available
- run the fullscreen Qt dashboard through BusyBox init respawn (no systemd)
- use `linuxfb`
- bundle the required app font in the app
- avoid network, audio, Wayland, X11, or other unrelated desktop surfaces
  unless product scope changes explicitly

## Sensor Data Rule

The product app reads kernel-native surfaces directly:

- RTC -> system clock
- SHT3X -> hwmon sysfs
- BH1750 -> IIO sysfs

No sensor daemon or middleware layer is part of this contract.
