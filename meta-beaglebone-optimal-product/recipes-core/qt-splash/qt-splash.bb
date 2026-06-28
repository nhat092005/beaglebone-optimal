SUMMARY = "Minimal framebuffer splash for the Qt dashboard product path"
DESCRIPTION = "Clears /dev/fb0 to black and draws a centered branded logo before the Qt dashboard starts."

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=7ae2be7fb1637141840314b51970a9f7"

SRC_URI = " \
    file://LICENSE \
    file://logo.ppm \
    file://qt-splash.c \
"

S = "${WORKDIR}"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} -o qt-splash qt-splash.c
}

do_install() {
    install -d ${D}${bindir}
    install -d ${D}${datadir}/qt-splash
    install -m 0755 qt-splash ${D}${bindir}/qt-splash
    install -m 0644 ${WORKDIR}/logo.ppm ${D}${datadir}/qt-splash/logo.ppm
}

FILES:${PN} = " \
    ${bindir}/qt-splash \
    ${datadir}/qt-splash/logo.ppm \
"
