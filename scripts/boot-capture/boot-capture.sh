#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

BOOT_SERIAL_DEVICE="${BOOT_SERIAL_DEVICE:-/dev/ttyUSB0}"
BOOT_SERIAL_BAUD="${BOOT_SERIAL_BAUD:-115200}"
BOOT_CAPTURE_LOG="${BOOT_CAPTURE_LOG:-$PWD/tmp/boot-captures/latest.log}"
capture_pid=""

# shellcheck disable=SC2317
cleanup_capture() {
    if [ -n "$capture_pid" ] && kill -0 "$capture_pid" 2>/dev/null; then
        kill "$capture_pid" 2>/dev/null || true
        wait "$capture_pid" 2>/dev/null || true
    fi
}

# shellcheck disable=SC2317
print_summary() {
    note
    note "boot-capture: log saved to $BOOT_CAPTURE_LOG"
    note "Next:"
    printf '  rg -n "Starting kernel|console \\[ttyS0\\] enabled" %s\n' "$BOOT_CAPTURE_LOG"
}

# shellcheck disable=SC2317
handle_interrupt() {
    cleanup_capture
    print_summary
    exit 0
}

require_command perl
require_command stdbuf
require_command stty
require_command tee
require_command cat
require_command dirname
require_command date

[ -e "$BOOT_SERIAL_DEVICE" ] || die "serial device does not exist: $BOOT_SERIAL_DEVICE"
[ -r "$BOOT_SERIAL_DEVICE" ] || die "serial device is not readable: $BOOT_SERIAL_DEVICE"

mkdir -p "$(dirname "$BOOT_CAPTURE_LOG")"

started_at="$(date --iso-8601=seconds)"
cat > "$BOOT_CAPTURE_LOG" <<EOF
# boot-capture
# device=$BOOT_SERIAL_DEVICE
# baud=$BOOT_SERIAL_BAUD
# started_at=$started_at
EOF

stty -F "$BOOT_SERIAL_DEVICE" "$BOOT_SERIAL_BAUD" cs8 -cstopb -parenb -ixon -ixoff -echo raw

trap handle_interrupt INT TERM

note "boot-capture: capturing $BOOT_SERIAL_DEVICE at ${BOOT_SERIAL_BAUD} baud"
note "boot-capture: press Ctrl-C to stop"

stdbuf -o0 cat "$BOOT_SERIAL_DEVICE" \
    | perl "$SCRIPT_DIR/boot-capture-timestamp.pl" "$BOOT_SERIAL_DEVICE" \
    | tee -a "$BOOT_CAPTURE_LOG" &
capture_pid=$!

set +e
wait "$capture_pid"
status=$?
set -e

print_summary
exit "$status"
