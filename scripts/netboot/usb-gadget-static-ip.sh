#!/usr/bin/env bash

set -euo pipefail

RULE_FILE="/etc/udev/rules.d/98-netboot-gadget-static-ip.rules"
HOST_IP="192.168.7.1"

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
    die "usage: usb-gadget-static-ip.sh <on|off>"
}

main() {
    local mode="${1:-}" ip_bin

    require_command udevadm
    ip_bin="$(command -v ip)" || die "missing required command: ip"

    case "$mode" in
        on)
            printf 'ACTION=="add|move", SUBSYSTEM=="net", ATTRS{idVendor}=="0451", ATTRS{idProduct}=="d022", RUN+="%s addr replace %s/24 dev %%k", RUN+="%s link set %%k up"\n' \
                "$ip_bin" "$HOST_IP" "$ip_bin" \
                | run_privileged tee "$RULE_FILE" > /dev/null
            run_privileged udevadm control --reload-rules
            note "usb-gadget-static-ip: on"
            note "every enx* interface will get ${HOST_IP}/24 + link up automatically on (re)connect"
            ;;
        off)
            run_privileged rm -f "$RULE_FILE"
            run_privileged udevadm control --reload-rules
            note "usb-gadget-static-ip: off"
            note "enx* interfaces no longer get an automatic static IP on (re)connect"
            ;;
        *)
            usage
            ;;
    esac
}

main "$@"
