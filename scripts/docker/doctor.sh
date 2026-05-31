#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/../.."
source scripts/docker/lib.sh

require_command docker
docker compose version > /dev/null

if [ ! -f local.mk.example ]; then
    warn "local.mk.example is missing"
fi

validate_docker_user
require_storage_root
prepare_storage_root

docker compose config > /dev/null
ensure_image
docker compose run --rm builder bash -lc 'touch /storage/.doctor-write && rm -f /storage/.doctor-write && echo doctor-ok' > /dev/null

note "doctor: ok"
