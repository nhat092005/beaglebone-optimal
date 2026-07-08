#!/usr/bin/env bash
# Run `bitbake -c menuconfig <recipe>` inside the builder container.
#
# Bitbake filters TMUX from task env, so the "auto" terminal backend hangs.
# Force tmux, wait for the detached `devshell-*` session, then attach.
set -uo pipefail

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

[ -n "${1:-}" ] || die "recipe is required. Usage: menuconfig.sh <recipe>"
RECIPE="$1"

command -v tmux > /dev/null 2>&1 \
    || die "tmux not found in the builder image. Add tmux to docker/Dockerfile and run: make docker-build"

export BB_ENV_PASSTHROUGH_ADDITIONS="OE_TERMINAL"
export OE_TERMINAL="tmux"

bitbake -c menuconfig "$RECIPE" &
BB_PID=$!

BEFORE_SESSIONS="$(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep '^devshell-' || true)"
DEVSHELL=""
while kill -0 "$BB_PID" 2>/dev/null; do
    DEVSHELL="$(tmux list-sessions -F '#{session_name}' 2>/dev/null \
        | grep '^devshell-' \
        | grep -v -x -F "$BEFORE_SESSIONS" \
        | head -n1 || true)"
    [ -n "$DEVSHELL" ] && break
    sleep 0.3
done

if [ -n "$DEVSHELL" ]; then
    tmux attach -t "$DEVSHELL"
fi

wait "$BB_PID"
STATUS=$?
[ "$STATUS" = "0" ] || die "menuconfig failed for $RECIPE (bitbake exit $STATUS)"

printf '%s\n' \
    "menuconfig done for $RECIPE." \
    "This .config lives in WORKDIR only; cleansstate/cleanall wipes it." \
    "Persist the change before you rely on it:" \
    "  kernel:  bitbake -c diffconfig $RECIPE -> writes fragment.cfg, add it to a bbappend via SRC_URI" \
    "  u-boot:  diff the WORKDIR .config against the recipe defconfig and turn the delta into a patch (see AGENTS.md patch workflow)"
