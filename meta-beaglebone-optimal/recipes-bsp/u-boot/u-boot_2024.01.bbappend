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

# DEV-ONLY: enable USB gadget TFTP/NFS netboot.
SRC_URI:append:beaglebone-black-optimal-qt-dashboard-dev = " file://dev-netboot.cfg file://usb-gadget.cfg"

do_configure:append:beaglebone-black-optimal-qt-dashboard-dev() {
    ${S}/scripts/kconfig/merge_config.sh -m ${B}/.config ${WORKDIR}/dev-netboot.cfg ${WORKDIR}/usb-gadget.cfg
}

# A/B repartition + bootcount failsafe, qt-dashboard product machine only.
# Keep fw_env.config with U-Boot so u-boot-env packages it alongside the
# auto-built u-boot-initial-env.
SRC_URI:append:beaglebone-black-optimal-qt-dashboard = " \
	file://bootcount.cfg \
	file://bootcount.env \
	file://fw_env.config \
"

do_configure:append:beaglebone-black-optimal-qt-dashboard() {
    install -m 0644 ${WORKDIR}/bootcount.env ${S}/board/ti/am335x/bootcount.env
    ${S}/scripts/kconfig/merge_config.sh -m ${B}/.config ${WORKDIR}/bootcount.cfg
}
