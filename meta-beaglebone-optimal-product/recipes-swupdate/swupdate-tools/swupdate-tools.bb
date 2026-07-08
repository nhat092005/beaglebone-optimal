SUMMARY = "Local swupdate provisioning: hwrevision, public key, sw-versions, apply-update wrapper"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=7ae2be7fb1637141840314b51970a9f7"
PN = "swupdate-local-tools"

SRC_URI = " \
    file://LICENSE \
    file://hwrevision \
    file://sw-versions \
    file://apply-update.sh \
    file://swupdate.pem \
"
S = "${WORKDIR}"

do_install() {
    install -d ${D}${sysconfdir}
    install -m 0644 ${S}/hwrevision ${D}${sysconfdir}/hwrevision
    install -m 0644 ${S}/sw-versions ${D}${sysconfdir}/sw-versions
    install -m 0644 ${S}/swupdate.pem ${D}${sysconfdir}/swupdate.pem
    install -d ${D}${sbindir}
    install -m 0755 ${S}/apply-update.sh ${D}${sbindir}/apply-update.sh
}

FILES:${PN} += " \
    ${sysconfdir}/hwrevision ${sysconfdir}/sw-versions ${sysconfdir}/swupdate.pem \
    ${sbindir}/apply-update.sh \
"
RDEPENDS:${PN} = "swupdate u-boot-fw-utils"
