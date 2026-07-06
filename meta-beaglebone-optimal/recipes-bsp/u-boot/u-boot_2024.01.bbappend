FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# Applies to both machines: qt-dashboard prepends "beaglebone-black-optimal-tiny"
# into MACHINEOVERRIDES.
SRC_URI:append:beaglebone-black-optimal-tiny = " \
	file://0001-am335x-evm-drop-finduuid.patch \
	file://0002-am335x-guard-board-mac-setup-when-net-is-disabled.patch \
	file://tiny-deterministic.cfg \
"

do_configure:append:beaglebone-black-optimal-tiny() {
    ${S}/scripts/kconfig/merge_config.sh -m ${B}/.config ${WORKDIR}/tiny-deterministic.cfg
}

# DEV-ONLY: re-enables net/hush/bootdelay/bootcmd + USB gadget for TFTP/NFS netboot.
SRC_URI:append:beaglebone-black-optimal-qt-dashboard-dev = " file://dev-netboot.cfg file://usb-gadget.cfg"

do_configure:append:beaglebone-black-optimal-qt-dashboard-dev() {
    ${S}/scripts/kconfig/merge_config.sh -m ${B}/.config ${WORKDIR}/dev-netboot.cfg ${WORKDIR}/usb-gadget.cfg
}
