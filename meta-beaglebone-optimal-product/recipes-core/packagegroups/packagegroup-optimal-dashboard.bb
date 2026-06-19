SUMMARY = "BeagleBone Optimal dashboard package group"
DESCRIPTION = "Minimal package group for the Qt dashboard product scaffold."

LICENSE = "MIT"

inherit packagegroup

RDEPENDS:${PN} = " \
	i2c-tools \
	qt-dashboard \
"
