SUMMARY = "Tiny initramfs image"
DESCRIPTION = "Minimal Phase 1 initramfs for the BeagleBone Black tiny kernel boot path."

LICENSE = "MIT"

inherit core-image

TINY_INIT_SOURCE = "${THISDIR}/files/init"

IMAGE_FEATURES = ""
IMAGE_LINGUAS = ""
IMAGE_NAME_SUFFIX ?= ""
IMAGE_FSTYPES = "${INITRAMFS_FSTYPES}"

PACKAGE_INSTALL = " \
	base-files \
	base-passwd \
	busybox \
"
ROOTFS_BOOTSTRAP_INSTALL = ""

IMAGE_ROOTFS_SIZE = "8192"
IMAGE_ROOTFS_EXTRA_SPACE = "0"

ROOTFS_POSTPROCESS_COMMAND += "install_tiny_init; prune_legacy_device_managers; "

install_tiny_init() {
	install -d ${IMAGE_ROOTFS}/dev
	install -m 0755 ${TINY_INIT_SOURCE} ${IMAGE_ROOTFS}/init
	if [ ! -e ${IMAGE_ROOTFS}/dev/console ]; then
		mknod -m 620 ${IMAGE_ROOTFS}/dev/console c 5 1
	fi
}

prune_legacy_device_managers() {
	rm -f ${IMAGE_ROOTFS}/sbin/mdev
	rm -f ${IMAGE_ROOTFS}/usr/lib/opkg/alternatives/mdev
}

COMPATIBLE_HOST = "(i.86|x86_64|aarch64|arm).*-linux"
