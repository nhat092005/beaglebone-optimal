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

## Sensor Data & Watchdog Rule

The product app reads aggregated kernel surfaces directly from the custom environment manager module (`optimal-env-manager`):

- **Current Metrics:** Reads `/sys/class/optimal-env/optimal_env/` attributes (`temperature` in milli-Celsius, `humidity` in milli-percent, `lux` in Lux, and `night_mode`).
- **Thresholds:** Reads `/sys/class/optimal-env/optimal_env/` configuration limits (`temp_alarm_limit`, `humid_alarm_limit`, `lux_alarm_limit`).
- **History Data & Charts:** Reads the binary 10-point measurement history log array from `/dev/optimal_env` to plot real-time line charts on the dashboard.
- **RTC:** Synchronized directly to the system clock.

No user-space sensor daemon or intermediate middleware is part of this contract.

## Warning LED Indicators Rule

The environment manager driver maps the BeagleBone Black onboard user LEDs to warn of environmental anomalies:

- **USR1:** Alternates high/low at 50ms interval when temperature exceeds `temp_alarm_limit`.
- **USR2:** Alternates high/low at 50ms interval when humidity exceeds `humid_alarm_limit`.
- **USR3:** Completely unused and deleted from the DTS/code layout.

## /dev/optimal_env IOCTL Rule

The character device `/dev/optimal_env` supports exactly two control operations from user-space:

- `OP_ENV_IOCTL_CLEAR_HISTORY`: Resets the 10-point historical log buffer.
- `OP_ENV_IOCTL_TRIGGER_MEASURE`: Immediately prompts a sensor reading update in the kernel.

## Kernel-Userspace Integration Details

### 1. Sysfs Attributes Reference (`/sys/class/optimal-env/optimal_env/`)

| Attribute | Mode | Unit | Description |
| :--- | :---: | :---: | :--- |
| **`temperature`** | RO | milli-°C | Current SHT3x temperature reading (e.g. `27500` for 27.5 °C). |
| **`humidity`** | RO | milli-% | Current SHT3x humidity reading (e.g. `55400` for 55.4%). |
| **`lux`** | RO | Lux | Current BH1750 ambient light intensity. |
| **`night_mode`** | RO | Binary | `1` if `lux < lux_alarm_limit` (triggering dark theme), else `0`. |
| **`temp_alarm_limit`** | RW | °C | Temperature threshold for alerts. Defaults to `45`. |
| **`humid_alarm_limit`** | RW | % | Humidity threshold for alerts. Defaults to `80`. |
| **`lux_alarm_limit`** | RW | Lux | Ambient light threshold for night mode. Defaults to `20`. |
| **`alarm_state`** | RO | Bitmask | Per-sensor alarm flags: bit 0 = temperature alarm, bit 1 = humidity alarm. `0` = no alarm. |
| **`sensor_status`** | RO | Bitmask | Diagnostics flag: `0` = OK, `1` = SHT3x fault, `2` = BH1750 fault, `3` = Both. |

### 2. Character Device Structure (`/dev/optimal_env`)

Each read from `/dev/optimal_env` returns a binary stream of up to 10 historical records formatted as:

```c
struct env_record {
    uint64_t timestamp_ms; // Monotonic boot time or real time in milliseconds
    int32_t temperature;   // in milli-°C
    int32_t humidity;      // in milli-%
    int32_t lux;           // in Lux
} __attribute__((packed));
```

The device supports standard read and control operations via `unlocked_ioctl`:
- `OP_ENV_IOCTL_CLEAR_HISTORY` (`_IO('O', 1)`): Resets the 10-point historical log buffer.
- `OP_ENV_IOCTL_TRIGGER_MEASURE` (`_IO('O', 2)`): Wakes up the monitoring thread for an immediate sensor reading.
