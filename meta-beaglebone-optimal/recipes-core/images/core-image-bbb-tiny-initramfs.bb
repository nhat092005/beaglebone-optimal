SUMMARY = "Tiny BeagleBone Black initramfs image"
DESCRIPTION = "Phase 1 tiny initramfs image for BeagleBone Black. This image exists to produce the bundled initramfs payload used by the tiny kernel boot path."

IMAGE_FEATURES = ""
IMAGE_LINGUAS = ""
IMAGE_NAME_SUFFIX ?= ""
IMAGE_FSTYPES = "${INITRAMFS_FSTYPES}"

LICENSE = "MIT"

PACKAGE_INSTALL = " \
	base-files \
	base-passwd \
	busybox \
	busybox-mdev \
	beaglebone-optimal-tiny-init \
"
ROOTFS_BOOTSTRAP_INSTALL = ""

inherit core-image

IMAGE_ROOTFS_SIZE = "8192"
IMAGE_ROOTFS_EXTRA_SPACE = "0"

COMPATIBLE_HOST = "(i.86|x86_64|aarch64|arm).*-linux"
