SUMMARY = "Minimal init for beaglebone-optimal tiny path"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"

RDEPENDS:${PN} = "busybox busybox-mdev"

SRC_URI = "file://init"

S = "${WORKDIR}"

do_install() {
	install -m 0755 ${WORKDIR}/init ${D}/init
	install -d ${D}/dev
	mknod -m 622 ${D}/dev/console c 5 1
}

FILES:${PN} += " /init /dev "

PACKAGE_ARCH = "${MACHINE_ARCH}"
