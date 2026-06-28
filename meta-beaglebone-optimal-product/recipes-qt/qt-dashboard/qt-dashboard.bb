SUMMARY = "BeagleBone Optimal Qt dashboard scaffold"
DESCRIPTION = "Fullscreen Qt Quick dashboard scaffold wired for the product image path."

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=7ae2be7fb1637141840314b51970a9f7"

SRC_URI = " \
	file://qt-dashboard.sh \
	file://shell-timing.sh \
"

DEPENDS = "qtbase qtdeclarative qtdeclarative-native"

inherit qt6-cmake externalsrc

EXTERNALSRC ??= "${BSPDIR}/qt-dashboard-app"
S = "${EXTERNALSRC}"

do_install:append() {
	install -d ${D}${bindir}
	install -m 0755 ${WORKDIR}/qt-dashboard.sh ${D}${bindir}/qt-dashboard.sh
	install -m 0755 ${WORKDIR}/shell-timing.sh ${D}${bindir}/shell-timing.sh
}

FILES:${PN} += " \
	${bindir}/shell-timing.sh \
	${bindir}/qt-dashboard.sh \
"
