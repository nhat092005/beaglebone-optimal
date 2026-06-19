SUMMARY = "BeagleBone Optimal Qt dashboard scaffold"
DESCRIPTION = "Fullscreen Qt Quick dashboard scaffold wired for the product image path."

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=7ae2be7fb1637141840314b51970a9f7"

SRC_URI = " \
	file://qt-dashboard.service \
	file://qt-dashboard.sh \
"

DEPENDS = "qtbase qtdeclarative qtdeclarative-native"

inherit qt6-cmake externalsrc systemd

EXTERNALSRC = "/workspace/qt-dashboard-app"
S = "${EXTERNALSRC}"

SYSTEMD_SERVICE:${PN} = "qt-dashboard.service"
SYSTEMD_AUTO_ENABLE = "enable"

do_install:append() {
	install -d ${D}${systemd_system_unitdir}
	install -m 0644 ${WORKDIR}/qt-dashboard.service ${D}${systemd_system_unitdir}/qt-dashboard.service

	install -d ${D}${bindir}
	install -m 0755 ${WORKDIR}/qt-dashboard.sh ${D}${bindir}/qt-dashboard.sh
}

FILES:${PN} += " \
	${bindir}/qt-dashboard.sh \
	${systemd_system_unitdir}/qt-dashboard.service \
"
