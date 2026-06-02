-include local.mk

SHELL := /bin/bash

GIT ?= git
CLANG_FORMAT ?= clang-format
SHFMT ?= shfmt
SHELLCHECK ?= shellcheck
YAMLLINT ?= yamllint
HADOLINT ?= hadolint

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
YOCTO_TINY_MACHINE ?= beaglebone-optimal-tiny
YOCTO_TINY_DISTRO ?= beaglebone-optimal-tiny
YOCTO_TINY_IMAGE ?= core-image-bbb-tiny-initramfs
YOCTO_IMAGE ?= core-image-minimal
IMAGE ?= $(YOCTO_BUILD_DIR)/tmp/deploy/images/beaglebone-yocto/$(YOCTO_IMAGE)-beaglebone-yocto.rootfs.wic
TINY_DEPLOY_DIR ?= $(YOCTO_BUILD_DIR)/tmp/deploy/images/$(YOCTO_TINY_MACHINE)
YOCTO_TINY_DTB ?= am335x-boneblack-optimal-tiny.dtb
TINY_EXTLINUX_TEMPLATE ?= $(CURDIR)/yocto/boot/extlinux.tiny.conf
TINY_UENV_TEMPLATE ?= $(CURDIR)/yocto/boot/uEnv.tiny.txt
SDCARD ?=

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
export YOCTO_TINY_MACHINE
export YOCTO_TINY_DISTRO
export YOCTO_TINY_IMAGE
export YOCTO_IMAGE
export IMAGE
export TINY_DEPLOY_DIR
export YOCTO_TINY_DTB
export TINY_EXTLINUX_TEMPLATE
export TINY_UENV_TEMPLATE
export SDCARD
export CMD

C_FORMAT_FILES := $(shell $(GIT) ls-files -- '*.c' '*.cc' '*.cpp' '*.h' '*.hh' '*.hpp')
SHELL_FILES := $(sort $(shell $(GIT) ls-files -- '*.sh') $(wildcard scripts/sd-flash scripts/sd-flash-tiny))
YAML_LINT_FILES := $(shell $(GIT) ls-files -- 'compose.yaml' '.github/workflows/*.yml' '.github/workflows/*.yaml')
DOCKERFILES := $(shell $(GIT) ls-files -- 'docker/Dockerfile')

.PHONY: help yocto-list docker-build docker-shell docker-run doctor yocto-init yocto-build sd-flash sd-flash-tiny format format-check lint check

help:
	@printf '%s\n' \
		'Available targets:' \
		'' \
		'Docker builder:' \
		'  make docker-build                 Build builder image with Docker Compose.' \
		'  make docker-shell                 Start interactive shell inside builder container.' \
		'  make docker-run CMD='\''uname -a'\''    Run command inside builder container.' \
		'' \
		'Environment check:' \
		'  make doctor                       Validate Docker phase 1 setup.' \
		'' \
		'Baseline path:' \
		'  make yocto-init                   Create Yocto build dir and validate poky checkout.' \
		'  make yocto-build                  Build YOCTO_IMAGE inside the builder container.' \
		'  make sd-flash SDCARD='\''/dev/sdX'\''   Flash IMAGE to an SD card on the host.' \
		'' \
		'Tiny path:' \
		'  make yocto-list                   Show baseline and tiny public contract values.' \
		'  make yocto-build YOCTO_IMAGE='$(YOCTO_TINY_IMAGE)'  Build the tiny image plus kernel and bootloader artifacts.' \
		'  make sd-flash-tiny SDCARD='\''/dev/sdX'\''  Partition, format, and populate tiny FAT boot media.' \
		'' \
		'Quality:' \
		'  make format                       Format tracked shell and C/C++ files.' \
		'  make format-check                 Check tracked shell and C/C++ formatting.' \
		'  make lint                         Lint tracked shell, YAML, and Docker files.' \
		'  make check                        Run format-check and lint.' \
		'' \
		'Derived Yocto paths from PROJECT_STORAGE_ROOT:' \
		'' \
		'Core paths:' \
		'  YOCTO_SOURCES_DIR                 Host path for Yocto source checkouts.' \
		'  YOCTO_POKY_DIR                    Host path for the poky checkout used by Yocto.' \
		'  YOCTO_BUILD_DIR                   Host path for Yocto build directory.' \
		'' \
		'Shared cache:' \
		'  YOCTO_DOWNLOADS_DIR               Host path for shared Yocto downloads cache.' \
		'  YOCTO_SSTATE_DIR                  Host path for shared Yocto sstate cache.' \
		'' \
		'Build target:' \
		'  YOCTO_IMAGE                       Yocto image target, default: core-image-minimal.' \
		'' \
		'Boot contract docs:' \
		'  docs/boot-contract.md             Normative boot ownership rules.' \
		'  yocto/conf/*.tiny.example         Tiny path example config files.'

yocto-list:
	@printf '%s\n' \
		'Yocto contract surface:' \
		'' \
		'Baseline path:' \
		'  image: core-image-minimal (default)' \
		'  local.conf example: yocto/conf/local.conf.example' \
		'  bblayers example: yocto/conf/bblayers.conf.example' \
		'  build: make yocto-build' \
		'  flash: make sd-flash SDCARD=/dev/sdX' \
		'' \
		'Tiny path:' \
		'  machine: '$(YOCTO_TINY_MACHINE) \
		'  distro: '$(YOCTO_TINY_DISTRO) \
		'  image: '$(YOCTO_TINY_IMAGE) \
		'  deploy dir: '$(TINY_DEPLOY_DIR) \
		'  tiny dtb deploy name: '$(YOCTO_TINY_DTB) \
		'  extlinux template: '$(TINY_EXTLINUX_TEMPLATE) \
		'  uEnv template: '$(TINY_UENV_TEMPLATE) \
		'  local.conf example: yocto/conf/local.conf.tiny.example' \
		'  bblayers example: yocto/conf/bblayers.conf.tiny.example' \
		'  build: make yocto-build YOCTO_IMAGE='$(YOCTO_TINY_IMAGE) \
		'  flash: make sd-flash-tiny SDCARD=/dev/sdX' \
		'' \
		'Contract docs:' \
		'  docs/boot-contract.md' \
		'  docs/_RUNBOOK_EN.md'

docker-build:
	@docker compose build builder

docker-shell:
	@bash -lc 'source scripts/docker/lib.sh && preflight_run_target && docker compose run --rm builder bash'

docker-run:
	@bash -lc 'source scripts/docker/lib.sh && require_cmd && preflight_run_target && docker compose run --rm builder bash -lc "$$CMD"'

doctor:
	@bash scripts/docker/doctor.sh

yocto-init:
	@bash -lc 'source scripts/docker/lib.sh && preflight_run_target && require_yocto_poky_tree && docker compose run --rm builder bash -lc '\''cd "$$YOCTO_POKY_DIR" && source oe-init-build-env "$$YOCTO_BUILD_DIR" >/dev/null && printf "%s\n" "yocto-init: ok" "Baseline local.conf example: /workspace/yocto/conf/local.conf.example" "Baseline bblayers example: /workspace/yocto/conf/bblayers.conf.example" "Tiny local.conf example: /workspace/yocto/conf/local.conf.tiny.example" "Tiny bblayers example: /workspace/yocto/conf/bblayers.conf.tiny.example" "Next: manually apply the example files into $$YOCTO_BUILD_DIR/conf/ before building."'\'''

ifneq ($(filter $(YOCTO_IMAGE),$(YOCTO_TINY_IMAGE)),)
yocto-build:
	@bash -lc 'source scripts/docker/lib.sh && require_yocto_image && preflight_run_target && require_yocto_poky_tree && require_yocto_build_conf && docker compose run --rm builder bash -lc '\''cd "$$YOCTO_POKY_DIR" && source oe-init-build-env "$$YOCTO_BUILD_DIR" >/dev/null && bitbake "$$YOCTO_IMAGE" virtual/kernel u-boot'\'''
else
yocto-build:
	@bash -lc 'source scripts/docker/lib.sh && require_yocto_image && preflight_run_target && require_yocto_poky_tree && require_yocto_build_conf && docker compose run --rm builder bash -lc '\''cd "$$YOCTO_POKY_DIR" && source oe-init-build-env "$$YOCTO_BUILD_DIR" >/dev/null && bitbake "$$YOCTO_IMAGE"'\'''
endif

sd-flash:
	@bash scripts/sd-flash

sd-flash-tiny:
	@bash scripts/sd-flash-tiny

format:
	@if [ -n "$(C_FORMAT_FILES)" ]; then \
		command -v "$(CLANG_FORMAT)" >/dev/null 2>&1 || { printf 'error: missing required command: %s\n' "$(CLANG_FORMAT)" >&2; exit 1; }; \
		$(CLANG_FORMAT) -i $(C_FORMAT_FILES); \
	fi
	@if [ -n "$(SHELL_FILES)" ]; then \
		command -v "$(SHFMT)" >/dev/null 2>&1 || { printf 'error: missing required command: %s\n' "$(SHFMT)" >&2; exit 1; }; \
		$(SHFMT) -w -i 4 -ci -sr $(SHELL_FILES); \
	fi

format-check:
	@if [ -n "$(C_FORMAT_FILES)" ]; then \
		command -v "$(CLANG_FORMAT)" >/dev/null 2>&1 || { printf 'error: missing required command: %s\n' "$(CLANG_FORMAT)" >&2; exit 1; }; \
		$(CLANG_FORMAT) --dry-run -Werror $(C_FORMAT_FILES) || { printf '%s\n' 'error: C/C++ formatting differs. Run: make format' >&2; exit 1; }; \
	fi
	@if [ -n "$(SHELL_FILES)" ]; then \
		command -v "$(SHFMT)" >/dev/null 2>&1 || { printf 'error: missing required command: %s\n' "$(SHFMT)" >&2; exit 1; }; \
		$(SHFMT) -d -i 4 -ci -sr $(SHELL_FILES) || { printf '%s\n' 'error: shell formatting differs. Run: make format' >&2; exit 1; }; \
	fi

lint:
	@if [ -n "$(SHELL_FILES)" ]; then \
		command -v "$(SHELLCHECK)" >/dev/null 2>&1 || { printf 'error: missing required command: %s\n' "$(SHELLCHECK)" >&2; exit 1; }; \
		$(SHELLCHECK) $(SHELL_FILES); \
	fi
	@if [ -n "$(YAML_LINT_FILES)" ]; then \
		command -v "$(YAMLLINT)" >/dev/null 2>&1 || { printf 'error: missing required command: %s\n' "$(YAMLLINT)" >&2; exit 1; }; \
		$(YAMLLINT) -c .yamllint.yml $(YAML_LINT_FILES); \
	fi
	@if [ -n "$(DOCKERFILES)" ]; then \
		if command -v "$(HADOLINT)" >/dev/null 2>&1; then \
			$(HADOLINT) $(DOCKERFILES); \
		elif [ -n "$$CI" ] || [ -n "$$GITHUB_ACTIONS" ]; then \
			printf 'error: missing required command: %s\n' "$(HADOLINT)" >&2; \
			exit 1; \
		else \
			printf '%s\n' 'warn: hadolint not installed; Dockerfile lint is enforced in CI' >&2; \
		fi; \
	fi

check: format-check lint
