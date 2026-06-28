SUMMARY = "BeagleBone Optimal dashboard package group"
DESCRIPTION = "Minimal package group for the Qt dashboard product scaffold."

LICENSE = "MIT"

inherit packagegroup

RDEPENDS:${PN} = " \
	qt-dashboard \
	qt-splash \
	rtcsync \
	optimal-env-manager \
"
