#!/bin/sh
set -u

BUNDLE="${1:-}"
if [ -z "$BUNDLE" ] || [ ! -f "$BUNDLE" ]; then
    echo "Usage: apply-update.sh <path-to-bundle.swu>"
    exit 1
fi
# Use /proc/cmdline as the running-slot truth.
# active_slot can drift after manual U-Boot overrides.
cmdline="$(cat /proc/cmdline)"
case "$cmdline" in
    *root=/dev/mmcblk0p2*) target=2; new_slot=b ;;
    *root=/dev/mmcblk0p3*) target=3; new_slot=a ;;
    *)
        echo "FATAL: cannot determine current root slot from /proc/cmdline:"
        echo "  $cmdline"
        echo "Refusing to guess a target - aborting."
        exit 1
        ;;
esac

echo "Targeting inactive slot: /dev/mmcblk0p${target}"
echo
echo "--- Currently installed (this rootfs) ---"
cat /etc/sw-versions 2>/dev/null || echo "(none found)"
echo
echo "--- Bundle version ---"
cpio -i --to-stdout sw-description < "$BUNDLE" 2>/dev/null | grep -m1 'version' \
    || echo "(could not read sw-description from bundle)"
echo

swupdate -i "$BUNDLE" -k /etc/swupdate.pem -e "stable,part${target}"
rc=$?

if [ "$rc" -eq 0 ]; then
    fw_setenv active_slot "$new_slot"
    echo
    echo "Update applied to /dev/mmcblk0p${target}. active_slot is now '${new_slot}'."
    echo "Run 'reboot' when ready to switch to the new slot."
else
    echo
    echo "Update FAILED (exit $rc). Still running the current slot; nothing changed."
fi
exit "$rc"
