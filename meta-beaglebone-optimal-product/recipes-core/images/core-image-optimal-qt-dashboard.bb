SUMMARY = "Qt dashboard product image scaffold"
DESCRIPTION = "Minimal product-side scaffold for the fullscreen Qt dashboard path."

LICENSE = "MIT"

IMAGE_LINGUAS = ""
IMAGE_NAME_SUFFIX ?= ""
IMAGE_FSTYPES = "tar.gz wic"

IMAGE_INSTALL:append = " packagegroup-optimal-dashboard"

# A/B-only tooling, gated on optimal-ab-update.
IMAGE_INSTALL:append = "${@bb.utils.contains('DISTRO_FEATURES', 'optimal-ab-update', ' u-boot-fw-utils u-boot-env swupdate swupdate-local-tools emmc-flash-tools', '', d)}"

inherit core-image

do_image_wic[file-checksums] += " \
    ${BEAGLEBONE_OPTIMAL_PRODUCT_LAYERDIR}/wic/beaglebone-qt-dashboard-extlinux.conf:True \
    ${BEAGLEBONE_OPTIMAL_PRODUCT_LAYERDIR}/wic/beaglebone-qt-dashboard-noab-extlinux.conf:True \
"

# See docs/boot-contract.md "Feature Toggle Contract".
python () {
    required = (d.getVar("OPTIMAL_REQUIRED_FEATURES") or "").split()
    have = (d.getVar("DISTRO_FEATURES") or "").split()
    missing = [token for token in required if token not in have]
    if missing:
        bb.fatal(
            "MACHINE %s requires DISTRO_FEATURES to include: %s (missing: %s). "
            "This must come from machine.conf's OPTIMAL_REQUIRED_FEATURES "
            "contract, not local.conf - see docs/boot-contract.md."
            % (d.getVar("MACHINE"), " ".join(required), " ".join(missing))
        )
}
