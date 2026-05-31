-include local.mk

SHELL := /bin/bash

DOCKER_IMAGE ?= beaglebone-optimal-builder
DOCKER_TAG ?= dev
WORKSPACE_NAME ?= default
DOCKER_USER ?= $(shell id -u):$(shell id -g)
YOCTO_ROOT ?= $(PROJECT_STORAGE_ROOT)/workspaces/$(WORKSPACE_NAME)/yocto
YOCTO_SOURCES_DIR ?= $(YOCTO_ROOT)/sources
YOCTO_POKY_DIR ?= $(YOCTO_SOURCES_DIR)/poky
YOCTO_BUILD_DIR ?= $(YOCTO_ROOT)/build
YOCTO_DOWNLOADS_DIR ?= $(PROJECT_STORAGE_ROOT)/shared/downloads
YOCTO_SSTATE_DIR ?= $(PROJECT_STORAGE_ROOT)/shared/sstate
YOCTO_IMAGE ?= core-image-minimal

export DOCKER_IMAGE
export DOCKER_TAG
export WORKSPACE_NAME
export DOCKER_USER
export PROJECT_STORAGE_ROOT
export YOCTO_ROOT
export YOCTO_SOURCES_DIR
export YOCTO_POKY_DIR
export YOCTO_BUILD_DIR
export YOCTO_DOWNLOADS_DIR
export YOCTO_SSTATE_DIR
export YOCTO_IMAGE
export CMD

.PHONY: help docker-build docker-shell docker-run doctor yocto-init yocto-build

help:
	@printf '%s\n' \
		'Available targets:' \
		'  make docker-build                 Build builder image with Docker Compose.' \
		'  make docker-shell                 Start interactive shell inside builder container.' \
		'  make docker-run CMD='\''uname -a'\''   Run command inside builder container.' \
		'  make doctor                       Validate Docker phase 1 setup.' \
		'  make yocto-init                   Create Yocto build dir and validate poky checkout.' \
		'  make yocto-build                  Build YOCTO_IMAGE inside the builder container.' \
		'' \
		'Derived Yocto paths from PROJECT_STORAGE_ROOT:' \
		'  YOCTO_SOURCES_DIR                 Host path for Yocto source checkouts.' \
		'  YOCTO_POKY_DIR                    Host path for the poky checkout used by Yocto.' \
		'  YOCTO_BUILD_DIR                   Host path for Yocto build directory.' \
		'  YOCTO_DOWNLOADS_DIR               Host path for shared Yocto downloads cache.' \
		'  YOCTO_SSTATE_DIR                  Host path for shared Yocto sstate cache.' \
		'  YOCTO_IMAGE                       Yocto image target, default: core-image-minimal.'

docker-build:
	@docker compose build builder

docker-shell:
	@bash -lc 'source scripts/docker/lib.sh && preflight_run_target && docker compose run --rm builder bash'

docker-run:
	@bash -lc 'source scripts/docker/lib.sh && require_cmd && preflight_run_target && docker compose run --rm builder bash -lc "$$CMD"'

doctor:
	@bash scripts/docker/doctor.sh

yocto-init:
	@bash -lc 'source scripts/docker/lib.sh && preflight_run_target && require_yocto_poky_tree && docker compose run --rm builder bash -lc '\''cd "$$YOCTO_POKY_DIR" && source oe-init-build-env "$$YOCTO_BUILD_DIR" >/dev/null && printf "%s\n" "yocto-init: ok" "Project local.conf example: /workspace/yocto/conf/local.conf.example" "Project bblayers.conf example: /workspace/yocto/conf/bblayers.conf.example" "Next: manually apply the example files into $$YOCTO_BUILD_DIR/conf/ before building."'\'''

yocto-build:
	@bash -lc 'source scripts/docker/lib.sh && require_yocto_image && preflight_run_target && require_yocto_poky_tree && require_yocto_build_conf && docker compose run --rm builder bash -lc '\''cd "$$YOCTO_POKY_DIR" && source oe-init-build-env "$$YOCTO_BUILD_DIR" >/dev/null && bitbake "$$YOCTO_IMAGE"'\'''
