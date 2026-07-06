SUMMARY = "Qt dashboard product image scaffold"
DESCRIPTION = "Minimal product-side scaffold for the fullscreen Qt dashboard path."

LICENSE = "MIT"

IMAGE_LINGUAS = ""
IMAGE_NAME_SUFFIX ?= ""
IMAGE_FSTYPES = "tar.gz wic"

IMAGE_INSTALL:append = " packagegroup-optimal-dashboard"

# fw_setenv/fw_printenv for the persistent U-Boot env.
IMAGE_INSTALL:append = " u-boot-fw-utils"

# Local (USB/SD, manual) firmware update tooling.
IMAGE_INSTALL:append = " swupdate swupdate-local-tools"

inherit core-image

do_image_wic[file-checksums] += "${BEAGLEBONE_OPTIMAL_PRODUCT_LAYERDIR}/wic/beaglebone-qt-dashboard-extlinux.conf:True"
