#!/usr/bin/env bash

set -euo pipefail

TFTP_DIR="/srv/tftp"
NFS_ROOT_DIR="/srv/nfs/bbb-dev/rootfs"
HOST_IP="192.168.7.1"
BOARD_IP="192.168.7.2"

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

require_package() {
    dpkg -s "$1" > /dev/null 2>&1 || die "missing required package: $1. Install with: sudo apt install $1"
}

require_iface() {
    [ -n "${NETBOOT_IFACE:-}" ] || die "NETBOOT_IFACE is required. Example: make netboot-host-setup NETBOOT_IFACE=eth1"
    ip link show "$NETBOOT_IFACE" > /dev/null 2>&1 || die "no such network interface: $NETBOOT_IFACE"
}

ensure_line() {
    local file="$1" pattern="$2" line="$3"

    if run_privileged grep -qE "$pattern" "$file" 2> /dev/null; then
        run_privileged sed -i -E "s|$pattern|$line|" "$file"
    else
        printf '%s\n' "$line" | run_privileged tee -a "$file" > /dev/null
    fi
}

ensure_exact_line() {
    local file="$1" line="$2"

    run_privileged grep -qxF "$line" "$file" 2> /dev/null && return
    printf '%s\n' "$line" | run_privileged tee -a "$file" > /dev/null
}

main() {
    require_command dpkg
    require_command ip
    require_package tftpd-hpa
    require_package nfs-kernel-server
    require_iface

    ensure_line /etc/default/tftpd-hpa '^#?TFTP_DIRECTORY=.*' "TFTP_DIRECTORY=\"${TFTP_DIR}\""
    ensure_exact_line /etc/exports "${NFS_ROOT_DIR} ${BOARD_IP}(rw,sync,no_subtree_check,no_root_squash)"

    run_privileged mkdir -p "$TFTP_DIR" "$NFS_ROOT_DIR"

    run_privileged ip addr replace "${HOST_IP}/24" dev "$NETBOOT_IFACE"
    run_privileged ip link set "$NETBOOT_IFACE" up

    run_privileged exportfs -ra
    run_privileged systemctl restart tftpd-hpa nfs-kernel-server

    note "netboot-host-setup: ok"
    note "tftp dir: $TFTP_DIR"
    note "nfs export: $NFS_ROOT_DIR ($BOARD_IP)"
    note "host ip: $HOST_IP/24 on $NETBOOT_IFACE"
}

main "$@"
