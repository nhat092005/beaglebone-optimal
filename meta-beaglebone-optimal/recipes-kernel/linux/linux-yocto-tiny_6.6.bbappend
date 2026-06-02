FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}/phase1/dts:${THISDIR}/${PN}/phase1/scc:${THISDIR}/${PN}/phase1/cfg:"

COMPATIBLE_MACHINE:beaglebone-optimal-tiny = "beaglebone-optimal-tiny"
KMACHINE:beaglebone-optimal-tiny ?= "beaglebone"

SRC_URI:append:beaglebone-optimal-tiny = " \
	file://am335x-boneblack-optimal-tiny.dts \
	file://beaglebone-tiny.scc \
	file://kernel-policy.scc \
	file://core.cfg \
	file://disable.cfg \
	file://hw.cfg \
"

do_configure:prepend:beaglebone-optimal-tiny() {
	install -m 0644 ${WORKDIR}/am335x-boneblack-optimal-tiny.dts ${S}/arch/arm/boot/dts/ti/omap/
}
