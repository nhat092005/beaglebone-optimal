#
# Product-side QtBase trim for the fullscreen dashboard appliance path.
# Keep Qt Quick, fonts, and device discovery, but drop desktop, input, and
# network/security surfaces that are not part of the local-only dashboard.
#

PACKAGECONFIG:remove:beaglebone-black-optimal-qt-dashboard = " \
	accessibility \
	dbus \
	glib \
	icu \
	libinput \
	network \
	openssl \
	sql \
	vulkan \
	widgets \
	xkbcommon \
"
