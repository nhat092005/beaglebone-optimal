#!/bin/bash
set -e

LOCAL_UID="${DOCKER_USER%%:*}"
LOCAL_GID="${DOCKER_USER#*:}"

if ! getent group "$LOCAL_GID" >/dev/null 2>&1; then
  groupadd --gid "$LOCAL_GID" builder
fi

if ! getent passwd "$LOCAL_UID" >/dev/null 2>&1; then
  useradd --uid "$LOCAL_UID" --gid "$LOCAL_GID" \
    --create-home --home-dir /home/builder \
    --shell /bin/bash builder
fi

export HOME=/home/builder

exec chroot --userspec="$LOCAL_UID:$LOCAL_GID" / "$@"
