#!/bin/sh

# Wait for framebuffer device before launching
until [ -c /dev/fb0 ]; do sleep 1; done

# Wait until the HDMI connector reports a stable mode for 3 consecutive
# seconds.  This prevents Qt from starting during the HDMI re-negotiation
# that happens ~7 s after boot (second HPD), which would cause it to render
# into a framebuffer that is about to be reprogrammed to a different timing.
prev=""
stable=0
while [ "$stable" -lt 3 ]; do
    curr="$(cat /sys/class/drm/card0-HDMI-A-1/modes 2>/dev/null)"
    if [ -n "$curr" ] && [ "$curr" = "$prev" ]; then
        stable=$((stable + 1))
    else
        stable=0
    fi
    prev="$curr"
    sleep 1
done

# Runtime display policy lives here, not in the app source tree.
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-linuxfb:fb=/dev/fb0}"
export QT_QUICK_BACKEND="${QT_QUICK_BACKEND:-software}"

exec /usr/bin/qt-dashboard "$@"
