#!/bin/sh
set -u

WIC="${1:-}"
if [ -z "$WIC" ] || [ ! -f "$WIC" ]; then
    echo "Usage: flash-emmc.sh <path-to-core-image-optimal-qt-dashboard.wic>"
    exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "FATAL: must run as root."
    exit 1
fi

# Refuse obviously truncated images.
wic_size="$(wc -c < "$WIC")"
min_size=$((300 * 1024 * 1024))
if [ "$wic_size" -lt "$min_size" ]; then
    echo "FATAL: $WIC is only $wic_size bytes - too small to be a real image."
    exit 1
fi

# Use /proc/cmdline as the running-root truth.
cmdline="$(cat /proc/cmdline)"
root_dev=""
case "$cmdline" in
    *root=/dev/mmcblk[0-9]*)
        root_dev="$(printf '%s\n' "$cmdline" | grep -o 'root=/dev/mmcblk[0-9]*' | head -n1 | sed 's/root=//')"
        ;;
esac
if [ -z "$root_dev" ]; then
    echo "FATAL: cannot determine current root device from /proc/cmdline:"
    echo "  $cmdline"
    echo "Refusing to guess a target - aborting."
    exit 1
fi
root_base="$(printf '%s\n' "$root_dev" | sed 's/p[0-9]*$//')"
root_name="$(basename "$root_base")"

# Target is the one other mmcblkN base device.
# mmcblk[0-9] excludes eMMC boot0/boot1/rpmb partitions.
candidates=""
count=0
for entry in /sys/block/mmcblk[0-9]; do
    [ -e "$entry" ] || continue
    name="$(basename "$entry")"
    if [ "$name" != "$root_name" ]; then
        candidates="$candidates /dev/$name"
        count=$((count + 1))
    fi
done

if [ "$count" -ne 1 ]; then
    echo "FATAL: expected exactly one other mmc device besides root ($root_base),"
    echo "found:$candidates"
    echo "Refusing to guess a target - aborting."
    exit 1
fi
target="$(printf '%s\n' "$candidates" | tr -d ' ')"

# Never write the running root device.
if [ "$target" = "$root_base" ]; then
    echo "FATAL: detected target ($target) is the same as the running root device."
    echo "Refusing to flash the device we are currently running from."
    exit 1
fi

echo "Currently running from: $root_base (root device)"
echo "eMMC flash target:      $target"
echo
echo "THIS WILL ERASE EVERYTHING ON $target."
printf 'Type the target device path exactly to continue: '
read -r reply
if [ "$reply" != "$target" ]; then
    echo "Confirmation did not match ($reply != $target) - aborting, nothing written."
    exit 1
fi

# Unmount mounted target partitions.
grep "^${target}p" /proc/mounts | cut -d' ' -f1 | while read -r part; do
    echo "unmounting $part"
    umount "$part"
done

echo
echo "Writing $WIC to $target ..."
bmap="${WIC}.bmap"
if command -v bmaptool > /dev/null 2>&1 && [ -f "$bmap" ]; then
    echo "write mode: bmaptool (block-verified)"
    bmaptool copy --bmap "$bmap" "$WIC" "$target"
    rc=$?
else
    if ! command -v bmaptool > /dev/null 2>&1; then
        echo "warn: bmaptool not available, falling back to dd (no block verify)"
    elif [ ! -f "$bmap" ]; then
        echo "warn: missing $bmap, falling back to dd (no block verify)"
    fi
    dd if="$WIC" of="$target" bs=4M conv=fsync
    rc=$?
fi

if [ "$rc" -ne 0 ]; then
    echo
    echo "FAILED (exit $rc) writing to $target."
    echo "Board is still running from $root_base - nothing else changed."
    echo "Investigate before retrying."
    exit "$rc"
fi

sync
echo
echo "Done. $target now holds the image."
echo "Powering off - remove the SD card, then power the board back on to boot from eMMC."
sleep 2
poweroff
