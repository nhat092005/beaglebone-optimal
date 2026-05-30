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
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

require_storage_root() {
  local value="${PROJECT_STORAGE_ROOT:-}"
  [ -n "$value" ] || die "PROJECT_STORAGE_ROOT is required. Copy local.mk.example to local.mk and set an absolute path."
  [[ "$value" = /* ]] || die "PROJECT_STORAGE_ROOT must be an absolute path: $value"
}

validate_docker_user() {
  local value="${DOCKER_USER:-}"
  [ -n "$value" ] || die "DOCKER_USER must not be empty"
  [[ "$value" =~ ^[0-9]+:[0-9]+$ ]] || die "DOCKER_USER must match uid:gid, got: $value"
}

workspace_root() {
  printf '%s/workspaces/%s' "$PROJECT_STORAGE_ROOT" "${WORKSPACE_NAME:-default}"
}

prepare_storage_root() {
  local ws
  require_storage_root
  ws="$(workspace_root)"
  mkdir -p \
    "$PROJECT_STORAGE_ROOT/shared/downloads" \
    "$PROJECT_STORAGE_ROOT/shared/sstate" \
    "$ws/out" \
    "$ws/tmp" \
    "$ws/logs" \
    "$ws/yocto/build"
}

ensure_image() {
  local image_ref="${DOCKER_IMAGE}:${DOCKER_TAG}"
  if ! docker image inspect "$image_ref" >/dev/null 2>&1; then
    note "builder image missing -> docker compose build builder"
    docker compose build builder
  fi
}

preflight_run_target() {
  require_command docker
  validate_docker_user
  require_storage_root
  prepare_storage_root
  ensure_image
}

require_cmd() {
  [ -n "${CMD:-}" ] || die "CMD is required. Example: make docker-run CMD='uname -a'"
}
