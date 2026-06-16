# Phase 1
#FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}/phase1/dts:${THISDIR}/${PN}/phase1/patches:${THISDIR}/${PN}/phase1/scc:${THISDIR}/${PN}/phase1/cfg:"

# Phase2
#FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}/phase2/dts:${THISDIR}/${PN}/phase2/patches:${THISDIR}/${PN}/phase2/scc:${THISDIR}/${PN}/phase2/cfg:"

# Phase3
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}/phase3/dts:${THISDIR}/${PN}/phase3/patches:${THISDIR}/${PN}/phase3/scc:${THISDIR}/${PN}/phase3/cfg:"

# GPIO LEDS feature, default-off.
# Uncomment this block temporarily to verify BBB USR0 heartbeat support.
#FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}/features/gpio-leds/dts:${THISDIR}/${PN}/features/gpio-leds/cfg:"
#
#SRC_URI:append:beaglebone-black-optimal-tiny = " \
#	file://gpio-leds.dtsi \
#	file://leds.cfg \
#"

# RTC DS3231 feature, default-off.
# Uncomment this block temporarily to verify DS3231 RTC support over i2c2.
#FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}/features/rtc-ds3231/dts:${THISDIR}/${PN}/features/rtc-ds3231/cfg:"
#
#SRC_URI:append:beaglebone-black-optimal-tiny = " \
#	file://rtc-ds3231.dtsi \
#	file://rtc.cfg \
#"

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
"

do_configure:prepend:beaglebone-black-optimal-tiny() {
	base_dts="${WORKDIR}/am335x-boneblack-optimal-tiny.dts"
	dest_dts="${S}/arch/arm/boot/dts/ti/omap/am335x-boneblack-optimal-tiny.dts"
	include_file="${T}/am335x-boneblack-optimal-tiny.feature-includes"

	: > ${include_file}

	for feature_dtsi in gpio-leds rtc-ds3231; do
		if [ -f ${WORKDIR}/${feature_dtsi}.dtsi ]; then
			install -m 0644 ${WORKDIR}/${feature_dtsi}.dtsi ${S}/arch/arm/boot/dts/ti/omap/
			printf '#include "%s.dtsi"\n' "${feature_dtsi}" >> ${include_file}
		fi
	done

	if [ -s ${include_file} ]; then
		install -m 0644 ${base_dts} ${dest_dts}
		cat ${include_file} >> ${dest_dts}
	else
		install -m 0644 ${base_dts} ${dest_dts}
	fi
}
