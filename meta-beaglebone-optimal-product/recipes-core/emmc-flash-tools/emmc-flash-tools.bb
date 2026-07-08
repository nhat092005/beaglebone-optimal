SUMMARY = "Userspace tool to provision the onboard eMMC from a running SD-booted image"
DESCRIPTION = "flash-emmc.sh writes a core-image-optimal-qt-dashboard .wic image \
onto the onboard eMMC while the board is temporarily booted from an SD card, \
for initial bring-up or full re-provisioning. Replaces the manual dd procedure \
in docs/boot-contract.md."

LICENSE = "MIT"

LIC_FILES_CHKSUM = "file://LICENSE;md5=7ae2be7fb1637141840314b51970a9f7"

SRC_URI = " \
    file://LICENSE \
    file://flash-emmc.sh \
"
S = "${WORKDIR}"

do_install() {
    install -d ${D}${sbindir}
    install -m 0755 ${S}/flash-emmc.sh ${D}${sbindir}/flash-emmc.sh
}

FILES:${PN} += "${sbindir}/flash-emmc.sh"
RDEPENDS:${PN} = "bmaptool"
