# Phase 1
#FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}/phase1/dts:${THISDIR}/${PN}/phase1/patches:${THISDIR}/${PN}/phase1/scc:${THISDIR}/${PN}/phase1/cfg:"

# Phase2
#FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}/phase2/dts:${THISDIR}/${PN}/phase2/patches:${THISDIR}/${PN}/phase2/scc:${THISDIR}/${PN}/phase2/cfg:"

# Phase3
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}/phase3/dts:${THISDIR}/${PN}/phase3/patches:${THISDIR}/${PN}/phase3/scc:${THISDIR}/${PN}/phase3/cfg:"

inherit linux-yocto-tiny-feature-dts

LINUX_YOCTO_TINY_FEATURE_ROOT := "${THISDIR}/${PN}/features"
LINUX_YOCTO_TINY_FEATURE_BASE_DTS = "am335x-boneblack-optimal-tiny.dts"
LINUX_YOCTO_TINY_FEATURE_KEYS = "GPIO_LEDS I2C2_BUS RTC_DS3231 SHT3X"

# GPIO LEDS feature, default-off. Set ENABLED to "1" temporarily to verify BBB USR0 heartbeat support.
LINUX_YOCTO_TINY_FEATURE_GPIO_LEDS_ENABLED = "0"
LINUX_YOCTO_TINY_FEATURE_GPIO_LEDS_DIR = "gpio-leds"
LINUX_YOCTO_TINY_FEATURE_GPIO_LEDS_DTS = "gpio-leds.dtsi"
LINUX_YOCTO_TINY_FEATURE_GPIO_LEDS_CFG = "leds.cfg"

# I2C2 shared bus feature, default-off. Enable this alongside i2c2 devices that need bus bring-up and pinmux.
LINUX_YOCTO_TINY_FEATURE_I2C2_BUS_ENABLED = "0"
LINUX_YOCTO_TINY_FEATURE_I2C2_BUS_DIR = "i2c2-bus"
LINUX_YOCTO_TINY_FEATURE_I2C2_BUS_DTS = "i2c2-bus.dtsi"
LINUX_YOCTO_TINY_FEATURE_I2C2_BUS_CFG = ""

# RTC DS3231 feature, default-off. Set ENABLED to "1" temporarily with I2C2_BUS to verify DS3231 RTC support over i2c2.
LINUX_YOCTO_TINY_FEATURE_RTC_DS3231_ENABLED = "0"
LINUX_YOCTO_TINY_FEATURE_RTC_DS3231_DIR = "rtc-ds3231"
LINUX_YOCTO_TINY_FEATURE_RTC_DS3231_DTS = "rtc-ds3231.dtsi"
LINUX_YOCTO_TINY_FEATURE_RTC_DS3231_CFG = "rtc.cfg"

# SHT3X feature, default-off. Set ENABLED to "1" temporarily with I2C2_BUS to verify SHT3X hwmon support over i2c2 at 0x44.
LINUX_YOCTO_TINY_FEATURE_SHT3X_ENABLED = "0"
LINUX_YOCTO_TINY_FEATURE_SHT3X_DIR = "sht3x"
LINUX_YOCTO_TINY_FEATURE_SHT3X_DTS = "sht3x.dtsi"
LINUX_YOCTO_TINY_FEATURE_SHT3X_CFG = "sht3x.cfg"

COMPATIBLE_MACHINE:beaglebone-black-optimal-tiny = "beaglebone-black-optimal-tiny"
KMACHINE:beaglebone-black-optimal-tiny ?= "beaglebone"

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
	${LINUX_YOCTO_TINY_FEATURE_SRC_URI} \
"
