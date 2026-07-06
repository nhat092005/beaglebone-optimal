#!/usr/bin/env bash

set -euo pipefail

TFTP_DIR="/srv/tftp"
KERNEL_IMAGE="zImage"
DTB_FILE="am335x-boneblack-optimal-qt-dashboard.dtb"

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
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

require_src_dir() {
    [ -n "${1:-}" ] || die "usage: sync-kernel.sh <deploy-dir-image-host-path>"
    [ -d "$1" ] || die "no such directory: $1. Run make yocto-bitbake BITBAKE_RECIPE=virtual/kernel first"
}

main() {
    local src_dir="${1:-}"

    require_src_dir "$src_dir"
    [ -f "${src_dir}/${KERNEL_IMAGE}" ] || die "missing ${KERNEL_IMAGE} in ${src_dir}"
    [ -f "${src_dir}/${DTB_FILE}" ] || die "missing ${DTB_FILE} in ${src_dir}"

    run_privileged mkdir -p "$TFTP_DIR"
    run_privileged cp -L "${src_dir}/${KERNEL_IMAGE}" "${TFTP_DIR}/${KERNEL_IMAGE}"
    run_privileged cp -L "${src_dir}/${DTB_FILE}" "${TFTP_DIR}/${DTB_FILE}"

    note "netboot-sync-kernel: ok"
    note "${TFTP_DIR}/${KERNEL_IMAGE}"
    note "${TFTP_DIR}/${DTB_FILE}"
}

main "$@"
