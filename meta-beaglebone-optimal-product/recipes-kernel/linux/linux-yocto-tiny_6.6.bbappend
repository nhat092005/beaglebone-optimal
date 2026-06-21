FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

COMPATIBLE_MACHINE:beaglebone-black-optimal-qt-dashboard = "beaglebone-black-optimal-qt-dashboard"
KMACHINE:beaglebone-black-optimal-qt-dashboard ?= "beaglebone"

LINUX_YOCTO_TINY_FEATURE_BASE_DTS:beaglebone-black-optimal-qt-dashboard = "am335x-boneblack-optimal-qt-dashboard.dts"
LINUX_YOCTO_TINY_FEATURE_GPIO_LEDS_ENABLED:beaglebone-black-optimal-qt-dashboard = "0"
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
	file://am335x-boneblack-optimal-qt-dashboard.dts \
	file://beaglebone-qt-dashboard-hdmi.cfg \
	file://beaglebone-qt-dashboard-hdmi.scc \
"
