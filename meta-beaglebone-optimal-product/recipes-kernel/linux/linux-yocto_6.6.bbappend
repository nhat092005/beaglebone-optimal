FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

COMPATIBLE_MACHINE:beaglebone-black-optimal-qt-dashboard = "beaglebone-black-optimal-qt-dashboard"

KBRANCH:beaglebone-black-optimal-qt-dashboard = "v6.6/standard/beaglebone"
KMACHINE:beaglebone-black-optimal-qt-dashboard ?= "beaglebone"
SRCREV_machine:beaglebone-black-optimal-qt-dashboard ?= "06644f0d7193d7ec39d7fe41939a21953e7a0c65"

LINUX_VERSION:beaglebone-black-optimal-qt-dashboard = "6.6.21"

KERNEL_FEATURES:append:beaglebone-black-optimal-qt-dashboard = " beaglebone-qt-dashboard-hdmi.scc"

SRC_URI:append:beaglebone-black-optimal-qt-dashboard = " \
	file://0001-drm-bridge-it66121-add-it66122-support-for-bbb-rev-.patch \
	file://0002-arm-dts-ti-omap-add-bbb-rev-d-hdmi-dtb-for-qt-dashb.patch \
	file://beaglebone-qt-dashboard-hdmi.cfg \
	file://beaglebone-qt-dashboard-hdmi.scc \
"
