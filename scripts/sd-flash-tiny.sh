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
    [ -n "${SDCARD:-}" ] || die "SDCARD is required. Example: make sd-flash-tiny SDCARD=/dev/sdX"
    [ -b "$SDCARD" ] || die "SDCARD must be an existing block device: $SDCARD"
}

require_whole_disk() {
    local device_type

    device_type="$(lsblk -dn -o TYPE "$SDCARD")"
    [ "$device_type" = "disk" ] || die "SDCARD must point to a whole-disk device, not a partition: $SDCARD"
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

require_tiny_deploy_dir() {
    [ -n "${TINY_DEPLOY_DIR:-}" ] || die "TINY_DEPLOY_DIR must not be empty"
    [ -d "$TINY_DEPLOY_DIR" ] || die "missing deploy dir: $TINY_DEPLOY_DIR. Run the tiny build first."
}

resolve_kernel_source() {
    local default_name="zImage-initramfs-${YOCTO_TINY_MACHINE}.bin"

    if [ -f "${TINY_DEPLOY_DIR}/${default_name}" ]; then
        printf '%s\n' "${TINY_DEPLOY_DIR}/${default_name}"
        return
    fi

    local first_match
    first_match="$(find "$TINY_DEPLOY_DIR" -maxdepth 1 -type f -name 'zImage-initramfs-*.bin' | sort | head -n 1)"
    [ -n "$first_match" ] || die "missing bundled tiny kernel artifact under $TINY_DEPLOY_DIR"
    printf '%s\n' "$first_match"
}

require_boot_sources() {
    [ -f "${TINY_DEPLOY_DIR}/MLO" ] || die "missing ${TINY_DEPLOY_DIR}/MLO"
    [ -f "${TINY_DEPLOY_DIR}/u-boot.img" ] || die "missing ${TINY_DEPLOY_DIR}/u-boot.img"
    [ -f "${TINY_DEPLOY_DIR}/${YOCTO_TINY_DTB}" ] || die "missing ${TINY_DEPLOY_DIR}/${YOCTO_TINY_DTB}"
    [ -f "${TINY_EXTLINUX_TEMPLATE}" ] || die "missing extlinux template: ${TINY_EXTLINUX_TEMPLATE}"
    [ -f "${TINY_UENV_TEMPLATE}" ] || die "missing uEnv template: ${TINY_UENV_TEMPLATE}"
}

partition_disk() {
    note "partitioning ${SDCARD} for tiny FAT boot media"
    printf 'label: dos\n, , c, *\n' | run_privileged sfdisk --wipe always "$SDCARD"
    run_privileged partprobe "$SDCARD" || true
    run_privileged udevadm settle || true
}

partition_path() {
    local part_path

    part_path="$(lsblk -ln -o PATH,TYPE "$SDCARD" | awk '$2 == "part" { print $1; exit }')"
    [ -n "$part_path" ] || die "failed to detect the new boot partition for $SDCARD"
    printf '%s\n' "$part_path"
}

format_partition() {
    local part_path="$1"

    note "formatting ${part_path} as FAT32"
    run_privileged mkfs.vfat -F 32 -n BBBTINY "$part_path"
}

populate_partition() {
    local part_path="$1"
    local kernel_source="$2"
    local mount_dir

    mount_dir="$(mktemp -d)"
    trap 'run_privileged umount "$mount_dir" >/dev/null 2>&1 || true; rmdir "$mount_dir" >/dev/null 2>&1 || true' RETURN

    run_privileged mount "$part_path" "$mount_dir"

    note "copying tiny boot artifacts into ${part_path}"
    run_privileged install -m 0644 "${TINY_DEPLOY_DIR}/MLO" "$mount_dir/MLO"
    run_privileged install -m 0644 "${TINY_DEPLOY_DIR}/u-boot.img" "$mount_dir/u-boot.img"
    run_privileged install -m 0644 "$kernel_source" "$mount_dir/zImage"
    run_privileged install -m 0644 "${TINY_DEPLOY_DIR}/${YOCTO_TINY_DTB}" "$mount_dir/am335x-boneblack.dtb"

    run_privileged mkdir -p "$mount_dir/extlinux"
    run_privileged install -m 0644 "${TINY_EXTLINUX_TEMPLATE}" "$mount_dir/extlinux/extlinux.conf"
    run_privileged install -m 0644 "${TINY_UENV_TEMPLATE}" "$mount_dir/uEnv.txt"

    run_privileged sync
    run_privileged umount "$mount_dir"
    rmdir "$mount_dir"
    trap - RETURN
}

main() {
    require_command awk
    require_command find
    require_command install
    require_command lsblk
    require_command mktemp
    require_command mount
    require_command mkfs.vfat
    require_command partprobe
    require_command sfdisk
    require_command sort
    require_command sync
    require_command udevadm
    require_sdcard
    require_whole_disk
    require_tiny_deploy_dir
    require_boot_sources

    note "tiny deploy dir: $TINY_DEPLOY_DIR"
    note "target: $SDCARD"

    unmount_child_partitions
    partition_disk

    local part_path
    local kernel_source

    part_path="$(partition_path)"
    kernel_source="$(resolve_kernel_source)"

    note "kernel source: $kernel_source"
    format_partition "$part_path"
    populate_partition "$part_path" "$kernel_source"

    note "sd-flash-tiny: ok"
}

main "$@"
