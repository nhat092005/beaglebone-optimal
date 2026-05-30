-include local.mk

SHELL := /bin/bash

DOCKER_IMAGE ?= beaglebone-optimal-builder
DOCKER_TAG ?= dev
WORKSPACE_NAME ?= default
HOST_UID := $(shell id -u)
HOST_GID := $(shell id -g)

export DOCKER_IMAGE
export DOCKER_TAG
export WORKSPACE_NAME
export HOST_UID
export HOST_GID
export PROJECT_STORAGE_ROOT
export CMD

.PHONY: help docker-build docker-shell docker-run doctor

help:
	@printf '%s\n' \
		'Available targets:' \
		'  make docker-build                 Build builder image with Docker Compose.' \
		'  make docker-shell                 Start interactive shell inside builder container.' \
		'  make docker-run CMD='\''uname -a'\''   Run command inside builder container.' \
		'  make doctor                       Validate Docker phase 1 setup.'

docker-build:
	@docker compose build builder

docker-shell:
	@bash -lc 'source scripts/docker/lib.sh && preflight_run_target && docker compose run --rm builder bash'

docker-run:
	@bash -lc 'source scripts/docker/lib.sh && require_cmd && preflight_run_target && docker compose run --rm builder bash -lc "$$CMD"'

doctor:
	@bash scripts/docker/doctor.sh
