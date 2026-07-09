FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# Applies to tiny and qt-dashboard via MACHINEOVERRIDES.
SRC_URI:append:beaglebone-black-optimal-tiny = " \
	file://0001-am335x-evm-drop-finduuid.patch \
	file://0002-am335x-guard-board-mac-setup-when-net-is-disabled.patch \
	file://tiny-deterministic.cfg \
"

do_configure:append:beaglebone-black-optimal-tiny() {
    ${S}/scripts/kconfig/merge_config.sh -m ${B}/.config ${WORKDIR}/tiny-deterministic.cfg
}

# DEV-ONLY TFTP/NFS netboot, gated on DISTRO_FEATURES tokens.
OPTIMAL_NETBOOT_DEV_ENABLED = "${@bb.utils.contains('DISTRO_FEATURES', 'optimal-netboot-dev', '1', '0', d)}"
OPTIMAL_USB_GADGET_ENABLED = "${@bb.utils.contains('DISTRO_FEATURES', 'optimal-usb-gadget', '1', '0', d)}"

SRC_URI:append = "${@bb.utils.contains('DISTRO_FEATURES', 'optimal-netboot-dev', ' file://dev-netboot.cfg', '', d)}"
SRC_URI:append = "${@bb.utils.contains('DISTRO_FEATURES', 'optimal-usb-gadget', ' file://usb-gadget.cfg', '', d)}"

do_configure:append() {
    if [ "${OPTIMAL_NETBOOT_DEV_ENABLED}" = "1" ] && [ "${OPTIMAL_USB_GADGET_ENABLED}" = "1" ]; then
        ${S}/scripts/kconfig/merge_config.sh -m ${B}/.config ${WORKDIR}/dev-netboot.cfg ${WORKDIR}/usb-gadget.cfg
    elif [ "${OPTIMAL_NETBOOT_DEV_ENABLED}" = "1" ]; then
        ${S}/scripts/kconfig/merge_config.sh -m ${B}/.config ${WORKDIR}/dev-netboot.cfg
    elif [ "${OPTIMAL_USB_GADGET_ENABLED}" = "1" ]; then
        ${S}/scripts/kconfig/merge_config.sh -m ${B}/.config ${WORKDIR}/usb-gadget.cfg
    fi
}

# A/B repartition + bootcount failsafe, gated on optimal-ab-update.
OPTIMAL_AB_UPDATE_ENABLED = "${@bb.utils.contains('DISTRO_FEATURES', 'optimal-ab-update', '1', '0', d)}"

SRC_URI:append = "${@bb.utils.contains('DISTRO_FEATURES', 'optimal-ab-update', ' file://bootcount.cfg file://bootcount.env file://fw_env.config', '', d)}"

do_configure:append() {
    if [ "${OPTIMAL_AB_UPDATE_ENABLED}" = "1" ]; then
        install -m 0644 ${WORKDIR}/bootcount.env ${S}/board/ti/am335x/bootcount.env
        ${S}/scripts/kconfig/merge_config.sh -m ${B}/.config ${WORKDIR}/bootcount.cfg
    fi
}
