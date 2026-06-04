FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI:append:beaglebone-black-optimal-tiny = " \
	file://0001-am335x-evm-drop-finduuid-and-use-canonical-tiny-dtb.patch \
	file://tiny-deterministic.cfg \
"
