#!/usr/bin/env bash

set -euo pipefail

CONF_FILE="/etc/NetworkManager/conf.d/99-unmanaged-usb-gadget.conf"

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

usage() {
    die "usage: nm-unmanage.sh <on|off>"
}

main() {
    local mode="${1:-}"

    require_command systemctl

    case "$mode" in
        on)
            printf '[keyfile]\nunmanaged-devices=interface-name:enx*\n' \
                | run_privileged tee "$CONF_FILE" > /dev/null
            run_privileged systemctl reload NetworkManager
            note "nm-unmanage: on"
            note "NetworkManager will no longer manage enx* (USB gadget) interfaces"
            ;;
        off)
            run_privileged rm -f "$CONF_FILE"
            run_privileged systemctl reload NetworkManager
            note "nm-unmanage: off"
            note "NetworkManager will manage enx* interfaces again"
            ;;
        *)
            usage
            ;;
    esac
}

main "$@"
