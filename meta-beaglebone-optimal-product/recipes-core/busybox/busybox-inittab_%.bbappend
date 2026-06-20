FILESEXTRAPATHS:prepend:beaglebone-black-optimal-qt-dashboard := "${THISDIR}/beaglebone-qt-dashboard:"

# busybox-inittab do_install appends a ttyrun getty line for each entry in
# SERIAL_CONSOLES. Our custom inittab already owns the console setup, so
# suppress the auto-append for this machine only.
SERIAL_CONSOLES:beaglebone-black-optimal-qt-dashboard = ""
