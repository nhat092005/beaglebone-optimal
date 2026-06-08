FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI:append:beaglebone-black-optimal-tiny = " \
	file://0001-am335x-evm-drop-finduuid-and-use-canonical-tiny-dtb.patch \
	file://0002-am335x-guard-board-mac-setup-when-net-is-disabled.patch \
	file://tiny-deterministic.cfg \
"
