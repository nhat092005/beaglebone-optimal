FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

COMPATIBLE_MACHINE:beaglebone-optimal-tiny = "beaglebone-optimal-tiny"

KMACHINE:beaglebone-optimal-tiny ?= "beaglebone"

SRC_URI:append:beaglebone-optimal-tiny = " \
	file://am335x-boneblack-optimal-tiny.dts \
	file://beaglebone-tiny.scc \
	file://tiny.cfg \
"

do_configure:prepend:beaglebone-optimal-tiny() {
	install -m 0644 ${WORKDIR}/am335x-boneblack-optimal-tiny.dts ${S}/arch/arm/boot/dts/ti/omap/
}
