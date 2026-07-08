SUMMARY = "Signed SWUpdate bundle for the A/B rootfs slots"
DESCRIPTION = "Wraps the built core-image-optimal-qt-dashboard .ext4 rootfs \
    artifact into a signed .swu with two selectable branches (part2/part3) \
    targeting /dev/mmcblk0p2 and /dev/mmcblk0p3 respectively."

LICENSE = "MIT"

PV = "1.0.0"

inherit swupdate

SRC_URI = "file://sw-description"

IMAGE_DEPENDS = "core-image-optimal-qt-dashboard"

ROOTFS_IMG = "core-image-optimal-qt-dashboard${IMAGE_MACHINE_SUFFIX}.ext4"

SWUPDATE_IMAGES = "core-image-optimal-qt-dashboard"
SWUPDATE_IMAGES_FSTYPES[core-image-optimal-qt-dashboard] = ".ext4"

SWUPDATE_SIGNING = "RSA"

