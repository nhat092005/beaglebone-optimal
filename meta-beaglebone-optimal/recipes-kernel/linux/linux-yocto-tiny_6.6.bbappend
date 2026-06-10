FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}/phase1/dts:${THISDIR}/${PN}/phase1/patches:${THISDIR}/${PN}/phase1/scc:${THISDIR}/${PN}/phase1/cfg:"

COMPATIBLE_MACHINE:beaglebone-black-optimal-tiny = "beaglebone-black-optimal-tiny"
KMACHINE:beaglebone-black-optimal-tiny ?= "beaglebone"

SRC_URI:append:beaglebone-black-optimal-tiny = " \
	file://am335x-boneblack-optimal-tiny.dts \
	file://0001-mmc-sdhci-omap-use-optional-regulators-for-capabilit.patch \
	file://0002-arm-omap2-skip-voltage-init-on-am33xx.patch \
	file://0003-driver-core-demote-fw-devlink-sync-state-link-failur.patch \
	file://beaglebone-tiny.scc \
	file://kernel-policy.scc \
	file://core.cfg \
	file://disable.cfg \
	file://hw.cfg \
"

do_configure:prepend:beaglebone-black-optimal-tiny() {
	install -m 0644 ${WORKDIR}/am335x-boneblack-optimal-tiny.dts ${S}/arch/arm/boot/dts/ti/omap/
}
