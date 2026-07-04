FILESEXTRAPATHS:prepend:beaglebone-black-optimal-tiny := "${THISDIR}/files-tiny:"
FILESEXTRAPATHS:prepend:beaglebone-black-optimal-qt-dashboard := "${THISDIR}/files-qt-dashboard:"

DEPENDS += "lz4-native"

inherit linux-yocto-tiny-feature-dts

LINUX_YOCTO_TINY_FEATURE_ROOT := "${THISDIR}/${PN}/features"
LINUX_YOCTO_TINY_FEATURE_KEYS = "GPIO_LEDS I2C2_BUS RTC_DS3231 SHT3X BH1750"

# Feature catalog, shared across machines; ENABLED is opt-in per machine below.

# GPIO_LEDS: BBB USR0 heartbeat LED.
LINUX_YOCTO_TINY_FEATURE_GPIO_LEDS_ENABLED = "0"
LINUX_YOCTO_TINY_FEATURE_GPIO_LEDS_DIR = "gpio-leds"
LINUX_YOCTO_TINY_FEATURE_GPIO_LEDS_DTS = "gpio-leds.dtsi"
LINUX_YOCTO_TINY_FEATURE_GPIO_LEDS_CFG = "leds.cfg"
LINUX_YOCTO_TINY_FEATURE_GPIO_LEDS_SCC = "gpio-leds.scc"

# I2C2_BUS: bus bring-up + pinmux for i2c2 devices below.
LINUX_YOCTO_TINY_FEATURE_I2C2_BUS_ENABLED = "0"
LINUX_YOCTO_TINY_FEATURE_I2C2_BUS_DIR = "i2c2-bus"
LINUX_YOCTO_TINY_FEATURE_I2C2_BUS_DTS = "i2c2-bus.dtsi"
LINUX_YOCTO_TINY_FEATURE_I2C2_BUS_CFG = ""
LINUX_YOCTO_TINY_FEATURE_I2C2_BUS_SCC = ""

# RTC_DS3231: DS3231 RTC over i2c2 (needs I2C2_BUS).
LINUX_YOCTO_TINY_FEATURE_RTC_DS3231_ENABLED = "0"
LINUX_YOCTO_TINY_FEATURE_RTC_DS3231_DIR = "rtc-ds3231"
LINUX_YOCTO_TINY_FEATURE_RTC_DS3231_DTS = "rtc-ds3231.dtsi"
LINUX_YOCTO_TINY_FEATURE_RTC_DS3231_CFG = "rtc.cfg"
LINUX_YOCTO_TINY_FEATURE_RTC_DS3231_SCC = "rtc-ds3231.scc"

# SHT3X: hwmon over i2c2 at 0x44 (needs I2C2_BUS).
LINUX_YOCTO_TINY_FEATURE_SHT3X_ENABLED = "0"
LINUX_YOCTO_TINY_FEATURE_SHT3X_DIR = "sht3x"
LINUX_YOCTO_TINY_FEATURE_SHT3X_DTS = "sht3x.dtsi"
LINUX_YOCTO_TINY_FEATURE_SHT3X_CFG = "sht3x.cfg"
LINUX_YOCTO_TINY_FEATURE_SHT3X_SCC = "sht3x.scc"

# BH1750: IIO light sensor over i2c2 at 0x23 (needs I2C2_BUS).
LINUX_YOCTO_TINY_FEATURE_BH1750_ENABLED = "0"
LINUX_YOCTO_TINY_FEATURE_BH1750_DIR = "bh1750"
LINUX_YOCTO_TINY_FEATURE_BH1750_DTS = "bh1750.dtsi"
LINUX_YOCTO_TINY_FEATURE_BH1750_CFG = "bh1750.cfg"
LINUX_YOCTO_TINY_FEATURE_BH1750_SCC = "bh1750.scc"

# Tiny machine defaults
COMPATIBLE_MACHINE:beaglebone-black-optimal-tiny = "beaglebone-black-optimal-tiny"
KMACHINE:beaglebone-black-optimal-tiny ?= "beaglebone"
LINUX_YOCTO_TINY_FEATURE_BASE_DTS:beaglebone-black-optimal-tiny = "am335x-boneblack-optimal-tiny.dts"

SRC_URI:append:beaglebone-black-optimal-tiny = " \
	file://am335x-boneblack-optimal-tiny.dts \
	file://0001-mmc-sdhci-omap-use-optional-regulators-for-capabilit.patch \
	file://0002-arm-omap2-skip-voltage-init-on-am33xx.patch \
	file://0003-driver-core-demote-fw-devlink-sync-state-link-failur.patch \
	file://0004-mfd-tps65217-do-not-require-pmic-of-node.patch \
	file://beaglebone-tiny.scc \
	file://kernel-policy.scc \
	file://core.cfg \
	file://disable.cfg \
	file://hw.cfg \
	file://hardening.cfg \
	${LINUX_YOCTO_TINY_FEATURE_SRC_URI} \
"

# Qt dashboard machine defaults
COMPATIBLE_MACHINE:beaglebone-black-optimal-qt-dashboard = "beaglebone-black-optimal-qt-dashboard"
KMACHINE:beaglebone-black-optimal-qt-dashboard ?= "beaglebone"
LINUX_YOCTO_TINY_FEATURE_BASE_DTS:beaglebone-black-optimal-qt-dashboard = "am335x-boneblack-optimal-qt-dashboard.dts"

LINUX_YOCTO_TINY_FEATURE_GPIO_LEDS_ENABLED:beaglebone-black-optimal-qt-dashboard = "1"
LINUX_YOCTO_TINY_FEATURE_I2C2_BUS_ENABLED:beaglebone-black-optimal-qt-dashboard = "1"
LINUX_YOCTO_TINY_FEATURE_RTC_DS3231_ENABLED:beaglebone-black-optimal-qt-dashboard = "1"
LINUX_YOCTO_TINY_FEATURE_SHT3X_ENABLED:beaglebone-black-optimal-qt-dashboard = "1"
LINUX_YOCTO_TINY_FEATURE_BH1750_ENABLED:beaglebone-black-optimal-qt-dashboard = "1"

KERNEL_FEATURES:append:beaglebone-black-optimal-qt-dashboard = " beaglebone-qt-dashboard-hdmi.scc"

SRC_URI:append:beaglebone-black-optimal-qt-dashboard = " \
	file://0001-drm-bridge-it66121-add-it66122-support-for-bbb-rev-.patch \
	file://0002-drm-bridge-it66121-retry-edid-read-on-ddc-busy.patch \
	file://0003-drm-tilcdc-pass-no-connector-flag-for-hdmi-bridge.patch \
	file://0004-drm-tilcdc-create-bridge-connector-for-external-hdmi.patch \
	file://0005-drm-bridge-it66121-debounce-hpd-disconnect-glitch.patch \
	file://0006-mm-memfd-silence-memfd_create-warning.patch \
	file://0007-drm-bridge-it66121-use-dev_err_probe-on-supply-defer.patch \
	file://am335x-boneblack-optimal-qt-dashboard.dts \
	file://beaglebone-qt-dashboard-hdmi.cfg \
	file://beaglebone-qt-dashboard-hdmi.scc \
	${LINUX_YOCTO_TINY_FEATURE_SRC_URI} \
"
