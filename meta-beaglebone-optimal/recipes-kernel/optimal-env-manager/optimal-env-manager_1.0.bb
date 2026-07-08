SUMMARY = "Optimal Environment and Power Manager Kernel Module"
DESCRIPTION = "Kernel space watchdog for SHT3x/BH1750 sensors and GPIO LED alert manager."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=7ae2be7fb1637141840314b51970a9f7"

inherit module

SRC_URI = " \
    file://Makefile \
    file://optimal_env_core.h \
    file://optimal_env_core.c \
    file://optimal_env_sysfs.c \
    file://optimal_env_chardev.c \
    file://optimal_env_sensors.c \
    file://LICENSE \
"

S = "${WORKDIR}"

COMPATIBLE_MACHINE = "beaglebone-black-optimal-.*"
