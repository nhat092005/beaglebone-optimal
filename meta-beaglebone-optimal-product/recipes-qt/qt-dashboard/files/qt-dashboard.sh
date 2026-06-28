#!/bin/sh

# Wait up to 30 seconds for framebuffer device before launching
i=0
until [ -c /dev/fb0 ]; do
    i=$((i + 1))
    if [ "$i" -ge 300 ]; then
        echo "qt-dashboard: /dev/fb0 not ready after 30s" >&2
        exit 1
    fi
    sleep 0.1
done

if [ -x /usr/bin/qt-splash ]; then
    /usr/bin/qt-splash >/dev/null 2>&1 || true
fi

# Runtime display policy lives here, not in the app source tree.
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-linuxfb:fb=/dev/fb0}"
export QT_QUICK_BACKEND="${QT_QUICK_BACKEND:-software}"

exec /usr/bin/qt-dashboard "$@"
