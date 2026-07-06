# Ships fw_env.config for u-boot-fw-utils (provided by this recipe, not
# u-boot_2024.01.bb, in this project's pinned poky).
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI:append:beaglebone-black-optimal-qt-dashboard = " file://fw_env.config file://u-boot-initial-env"

do_install:append:beaglebone-black-optimal-qt-dashboard() {
    install -d ${D}${sysconfdir}
    install -m 0644 ${WORKDIR}/fw_env.config ${D}${sysconfdir}/fw_env.config
    install -m 0644 ${WORKDIR}/u-boot-initial-env ${D}${sysconfdir}/u-boot-initial-env
}

FILES:${PN}-bin:append:beaglebone-black-optimal-qt-dashboard = " ${sysconfdir}/fw_env.config ${sysconfdir}/u-boot-initial-env"
