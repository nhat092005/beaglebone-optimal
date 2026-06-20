#!/bin/sh

# Wait for framebuffer device before launching
until [ -c /dev/fb0 ]; do sleep 1; done

# Runtime display policy lives here, not in the app source tree.
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-linuxfb:fb=/dev/fb0}"
export QT_QUICK_BACKEND="${QT_QUICK_BACKEND:-software}"

exec /usr/bin/qt-dashboard "$@"
