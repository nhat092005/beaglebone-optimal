SUMMARY = "Qt dashboard product image scaffold"
DESCRIPTION = "Minimal product-side scaffold for the fullscreen Qt dashboard path."

LICENSE = "MIT"

IMAGE_LINGUAS = ""
IMAGE_NAME_SUFFIX ?= ""
IMAGE_FSTYPES = "tar.gz wic"

IMAGE_INSTALL:append = " packagegroup-optimal-dashboard"

# fw_setenv/fw_printenv for the persistent U-Boot env.
IMAGE_INSTALL:append = " u-boot-fw-utils"

# Ship /etc/fw_env.config plus the compiled-in default U-Boot env so the
# first fw_setenv has real defaults to fall back on.
IMAGE_INSTALL:append = " u-boot-env"

# Local USB/SD firmware update tooling.
IMAGE_INSTALL:append = " swupdate swupdate-local-tools"

# Provision the onboard eMMC from a running SD-booted image.
IMAGE_INSTALL:append = " emmc-flash-tools"

inherit core-image

do_image_wic[file-checksums] += "${BEAGLEBONE_OPTIMAL_PRODUCT_LAYERDIR}/wic/beaglebone-qt-dashboard-extlinux.conf:True"
