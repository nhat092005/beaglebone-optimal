#!/usr/bin/env bash

set -euo pipefail

NFS_ROOT_DIR="/srv/nfs/bbb-dev/rootfs"
IMAGE_TARBALL="core-image-optimal-qt-dashboard-beaglebone-black-optimal-qt-dashboard-dev.tar.gz"

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
    [ -n "${1:-}" ] || die "usage: seed-rootfs.sh <deploy-dir-image-host-path>"
    [ -d "$1" ] || die "no such directory: $1. Run make yocto-build first"
}

main() {
    local src_dir="${1:-}"

    require_src_dir "$src_dir"
    require_command tar
    [ -f "${src_dir}/${IMAGE_TARBALL}" ] || die "missing ${IMAGE_TARBALL} in ${src_dir}. Ensure IMAGE_FSTYPES includes tar.gz"

    run_privileged mkdir -p "$NFS_ROOT_DIR"
    run_privileged tar --numeric-owner -xzpf "${src_dir}/${IMAGE_TARBALL}" -C "$NFS_ROOT_DIR"

    note "netboot-seed-rootfs: ok"
    note "seeded ${NFS_ROOT_DIR} from ${IMAGE_TARBALL}"
    note "run make netboot-sync-app afterwards to overlay the latest local app build"
}

main "$@"
