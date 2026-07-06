#!/usr/bin/env bash

set -euo pipefail

NFS_ROOT_DIR="/srv/nfs/bbb-dev/rootfs"

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
    [ -n "${1:-}" ] || die "usage: sync-app.sh <recipe-install-dir-host-path>"
    [ -d "$1" ] || die "no such directory: $1. Run make yocto-bitbake BITBAKE_RECIPE=qt-dashboard first"
}

main() {
    local src_dir="${1:-}"

    require_src_dir "$src_dir"
    require_command rsync

    run_privileged mkdir -p "$NFS_ROOT_DIR"
    run_privileged rsync -a "${src_dir}/" "${NFS_ROOT_DIR}/"

    note "netboot-sync-app: ok"
    note "synced ${src_dir} -> ${NFS_ROOT_DIR}"
}

main "$@"
