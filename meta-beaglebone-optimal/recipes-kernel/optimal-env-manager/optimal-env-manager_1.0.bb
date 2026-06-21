SUMMARY = "Optimal Environment and Power Manager Kernel Module"
DESCRIPTION = "Kernel space watchdog for SHT3x/BH1750 sensors and GPIO LED alert manager."
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=c65ff98a9804480685b8b5d5538d093b"

inherit module

SRC_URI = " \
    file://Makefile \
    file://optimal_env_manager.c \
    file://COPYING \
"

S = "${WORKDIR}"

# Automatically load the driver on boot
KERNEL_MODULE_AUTOLOAD += "optimal_env_manager"
