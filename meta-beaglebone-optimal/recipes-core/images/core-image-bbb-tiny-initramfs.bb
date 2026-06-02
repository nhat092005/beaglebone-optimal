SUMMARY = "Tiny BeagleBone Black initramfs image"
DESCRIPTION = "Phase 1 tiny initramfs image for BeagleBone Black. This image exists to produce the bundled initramfs payload used by the tiny kernel boot path."
TINY_INIT_SOURCE = "${THISDIR}/files/init"

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
"
ROOTFS_BOOTSTRAP_INSTALL = ""

inherit core-image

IMAGE_ROOTFS_SIZE = "8192"
IMAGE_ROOTFS_EXTRA_SPACE = "0"

ROOTFS_POSTPROCESS_COMMAND += "install_tiny_init; "

install_tiny_init() {
	install -d ${IMAGE_ROOTFS}/dev
	install -m 0755 ${TINY_INIT_SOURCE} ${IMAGE_ROOTFS}/init
	if [ ! -e ${IMAGE_ROOTFS}/dev/console ]; then
		mknod -m 622 ${IMAGE_ROOTFS}/dev/console c 5 1
	fi
}

COMPATIBLE_HOST = "(i.86|x86_64|aarch64|arm).*-linux"
