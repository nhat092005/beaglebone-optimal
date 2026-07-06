FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI:append:beaglebone-black-optimal-qt-dashboard = " file://swupdate-signing.cfg"

do_install:prepend() {
    unset LDFLAGS
}
