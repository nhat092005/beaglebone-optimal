#!/usr/bin/env bash

set -euo pipefail

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

warn() {
    printf 'warn: %s\n' "$*" >&2
}

note() {
    printf '%s\n' "$*"
}

require_command() {
    command -v "$1" > /dev/null 2>&1 || die "missing required command: $1"
}

run_privileged() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
        return
    fi

    require_command sudo
    sudo "$@"
}

require_sdcard() {
    [ -n "${SDCARD:-}" ] || die "SDCARD is required. Example: make sd-flash SDCARD=/dev/sdX"
    [ -b "$SDCARD" ] || die "SDCARD must be an existing block device: $SDCARD"
}

require_whole_disk() {
    local device_type

    device_type="$(lsblk -dn -o TYPE "$SDCARD")"
    [ "$device_type" = "disk" ] || die "SDCARD must point to a whole-disk device, not a partition: $SDCARD"
}

require_image() {
    [ -n "${IMAGE:-}" ] || die "IMAGE must not be empty"
    [ -f "$IMAGE" ] || die "missing image: $IMAGE. Run make yocto-build first or override IMAGE=/path/to/file.wic"
}

unmount_child_partitions() {
    local path device_type mountpoints

    while read -r path device_type mountpoints; do
        [ -n "$path" ] || continue
        [ "$device_type" = "part" ] || continue
        [ -n "${mountpoints:-}" ] || continue
        note "unmounting ${path} from ${mountpoints}"
        run_privileged umount "$path"
    done < <(lsblk -ln -o PATH,TYPE,MOUNTPOINTS "$SDCARD")
}

flash_with_bmaptool() {
    local bmap_file="${IMAGE}.bmap"

    if command -v bmaptool > /dev/null 2>&1 && [ -f "$bmap_file" ]; then
        note "write mode: bmaptool"
        run_privileged bmaptool copy --bmap "$bmap_file" "$IMAGE" "$SDCARD"
        return
    fi

    if ! command -v bmaptool > /dev/null 2>&1; then
        warn "bmaptool not found on host; falling back to dd"
    elif [ ! -f "$bmap_file" ]; then
        warn "missing bmap file: $bmap_file; falling back to dd"
    fi

    note "write mode: dd"
    run_privileged dd if="$IMAGE" of="$SDCARD" bs=4M conv=fsync status=progress
}

main() {
    require_command lsblk
    require_sdcard
    require_whole_disk
    require_image

    note "image: $IMAGE"
    note "target: $SDCARD"

    unmount_child_partitions
    flash_with_bmaptool
    run_privileged sync
    note "sd-flash: ok"
}

main "$@"
