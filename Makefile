-include local.mk

SHELL := /bin/bash

# External tools
GIT          ?= git
CLANG_FORMAT ?= clang-format
SHFMT        ?= shfmt
SHELLCHECK   ?= shellcheck

# Quality tool file lists
C_FORMAT_FILES := $(shell $(GIT) ls-files -- '*.c' '*.cc' '*.cpp' '*.h' '*.hh' '*.hpp')
SHELL_FILES    := $(sort $(shell $(GIT) ls-files -- '*.sh') $(wildcard scripts/sd-flash/*))

# Input configuration (from local.mk or overridable)
WORKSPACE_NAME ?= default
DOCKER_USER    ?= $(shell id -u):$(shell id -g)

# Project constants
DOCKER_IMAGE ?= beaglebone-optimal-builder
DOCKER_TAG   ?= dev

# Yocto baseline
YOCTO_IMAGE ?= core-image-minimal
YOCTO_MACHINE ?= beaglebone-yocto

# Yocto tiny
YOCTO_TINY_MACHINE                 ?= beaglebone-black-optimal-tiny
YOCTO_TINY_DISTRO                  ?= optimal-tiny
YOCTO_TINY_IMAGE                   ?= core-image-optimal-tiny-initramfs
YOCTO_TINY_DTB                     ?= am335x-boneblack-optimal-tiny.dtb
YOCTO_TINY_BBLAYERS_TEMPLATE       ?= $(CURDIR)/yocto/conf/bblayers.conf.tiny.example
YOCTO_TINY_LOCALCONF_TEMPLATE      ?= $(CURDIR)/yocto/conf/local.conf.tiny.example
YOCTO_TINY_BOOT_EXTLINUX_TEMPLATE  ?= $(CURDIR)/yocto/boot/extlinux.conf.tiny.example
YOCTO_TINY_BOOT_UENV_TEMPLATE      ?= $(CURDIR)/yocto/boot/uEnv.txt.tiny.example

# Yocto Qt dashboard
YOCTO_QT_DASHBOARD_MACHINE             ?= beaglebone-black-optimal-qt-dashboard
YOCTO_QT_DASHBOARD_IMAGE               ?= core-image-optimal-qt-dashboard
YOCTO_QT_DASHBOARD_BBLAYERS_TEMPLATE   ?= $(CURDIR)/yocto/conf/bblayers.conf.qt-dashboard.example
YOCTO_QT_DASHBOARD_LOCALCONF_TEMPLATE  ?= $(CURDIR)/yocto/conf/local.conf.qt-dashboard.example

# Derived paths
YOCTO_ROOT          	?= $(PROJECT_STORAGE_ROOT)/workspaces/$(WORKSPACE_NAME)/yocto
YOCTO_SOURCES_DIR   	?= $(YOCTO_ROOT)/sources
YOCTO_POKY_DIR      	?= $(YOCTO_SOURCES_DIR)/poky
YOCTO_BUILD_DIR     	?= $(YOCTO_ROOT)/build
YOCTO_DOWNLOADS_DIR 	?= $(PROJECT_STORAGE_ROOT)/shared/downloads
YOCTO_SSTATE_DIR    	?= $(PROJECT_STORAGE_ROOT)/shared/sstate
IMAGE               	?= $(YOCTO_BUILD_DIR)/tmp/deploy/images/$(YOCTO_MACHINE)/$(YOCTO_IMAGE)-$(YOCTO_MACHINE).wic
YOCTO_TINY_DEPLOY_DIR	?= $(YOCTO_BUILD_DIR)/tmp/deploy/images/$(YOCTO_TINY_MACHINE)

# Runtime arguments
SDCARD         ?=
BITBAKE_RECIPE ?=
BITBAKE_TASK   ?=

# Boot capture arguments
BOOT_SERIAL_DEVICE ?= /dev/ttyUSB0
BOOT_SERIAL_BAUD   ?= 115200
BOOT_CAPTURE_LOG   ?= $(CURDIR)/tmp/boot-captures/latest.log

# Exported environment
export DOCKER_IMAGE DOCKER_TAG WORKSPACE_NAME DOCKER_USER \
       PROJECT_STORAGE_ROOT \
       YOCTO_ROOT YOCTO_SOURCES_DIR YOCTO_POKY_DIR YOCTO_BUILD_DIR \
       YOCTO_DOWNLOADS_DIR YOCTO_SSTATE_DIR \
       YOCTO_MACHINE \
       YOCTO_TINY_MACHINE YOCTO_TINY_DISTRO YOCTO_TINY_IMAGE YOCTO_TINY_DTB \
       YOCTO_TINY_BBLAYERS_TEMPLATE YOCTO_TINY_LOCALCONF_TEMPLATE \
       YOCTO_TINY_DEPLOY_DIR YOCTO_TINY_BOOT_EXTLINUX_TEMPLATE YOCTO_TINY_BOOT_UENV_TEMPLATE \
       YOCTO_QT_DASHBOARD_MACHINE YOCTO_QT_DASHBOARD_IMAGE YOCTO_QT_DASHBOARD_BBLAYERS_TEMPLATE YOCTO_QT_DASHBOARD_LOCALCONF_TEMPLATE \
       YOCTO_IMAGE IMAGE \
       SDCARD CMD BOOT_SERIAL_DEVICE BOOT_SERIAL_BAUD BOOT_CAPTURE_LOG

.PHONY: help yocto-list docker-build docker-shell docker-run doctor boot-capture
.PHONY: patch-check patch-apply patch-reword patch-finalize patch-abort
.PHONY: yocto-init yocto-layers yocto-parse yocto-qt-profile yocto-dry-run yocto-build yocto-bitbake
.PHONY: sd-flash sd-flash-tiny format format-check lint check

help:
	@printf '%s\n' \
		'Available targets:' \
		'' \
		'Docker builder:' \
		'  make docker-build                 Build builder image with Docker Compose.' \
		'  make docker-shell                 Start interactive shell inside builder container.' \
		'  make docker-run CMD='\''uname -a'\''    Run command inside builder container.' \
		'' \
		'BSP patch regeneration:' \
		'  make patch-check TREE=<path> DIFF=<file>' \
		'                                    Dry-run check that a diff still applies to a real source tree.' \
		'  make patch-apply TREE=<path> DIFF=<file> MESSAGE=<file> AUTHOR='\''Name <email>'\''' \
		'                                    Apply one diff and commit it for real; repeat per patch in a series.' \
		'  make patch-reword TREE=<path> COMMIT=<sha> MESSAGE=<file> [BASE=<ref>]' \
		'                                    Rebuild an existing commit with a corrected message, same tree, no diff/apply.' \
		'                                    BASE is required on the first call of a series; never touches TREE'\''s real HEAD.' \
		'  make patch-finalize TREE=<path> OUT=<dir> NAMES='\''0001-a.patch 0002-b.patch'\'' [BASE=<ref>]' \
		'                                    Emit the committed series as patch files, then reset TREE back to its base.' \
		'                                    BASE defaults to the patch-apply marker; pass BASE=HEAD~N if you committed by hand.' \
		'  make patch-abort TREE=<path>      Discard an in-progress apply series and reset TREE back to its base.' \
		'' \
		'Environment check:' \
		'  make doctor                       Validate Docker phase 1 setup.' \
		'  make boot-capture                Capture BBB UART boot log with host timestamps for tiny or Qt dashboard paths.' \
		'' \
		'Baseline path:' \
		'  make yocto-init                   Create Yocto build dir and validate poky checkout.' \
		'  make yocto-layers                 Show active Yocto layers for the current build dir.' \
		'  make yocto-parse                  Parse active Yocto metadata for the current build dir.' \
		'  make yocto-qt-profile             Show effective qtbase profile for the current build dir.' \
		'  make yocto-dry-run                Dry-run the current YOCTO_IMAGE dependency graph.' \
		'  make yocto-build                  Build YOCTO_IMAGE inside the builder container.' \
		'  make yocto-bitbake BITBAKE_RECIPE=<recipe> [BITBAKE_TASK=<task>]' \
		'                                    Run bitbake on a recipe (cleansstate, cleanall, clean, compile, install, package…).' \
		'  make sd-flash SDCARD='\''/dev/sdX'\''   Flash IMAGE to an SD card on the host.' \
		'' \
		'Tiny path:' \
		'  make yocto-list                   Show baseline and tiny public contract values.' \
		'  make yocto-build YOCTO_IMAGE='$(YOCTO_TINY_IMAGE)'  Build the tiny image plus kernel and bootloader artifacts.' \
		'  make sd-flash-tiny SDCARD='\''/dev/sdX'\''  Partition, format, and populate tiny FAT boot media.' \
		'' \
		'Qt dashboard path:' \
		'  make yocto-dry-run YOCTO_IMAGE='$(YOCTO_QT_DASHBOARD_IMAGE)'  Dry-run the Qt dashboard image dependency graph.' \
		'' \
		'Quality:' \
		'  make format                       Format tracked shell and C/C++ files.' \
		'  make format-check                 Check tracked shell and C/C++ formatting.' \
		'  make lint                         Lint tracked shell files.' \
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
		'  YOCTO_MACHINE                     Deploy machine name used by sd-flash, default: beaglebone-yocto.' \
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
		'  deploy dir: '$(YOCTO_TINY_DEPLOY_DIR) \
		'  tiny dtb deploy name: '$(YOCTO_TINY_DTB) \
		'  extlinux template: '$(YOCTO_TINY_BOOT_EXTLINUX_TEMPLATE) \
		'  uEnv template: '$(YOCTO_TINY_BOOT_UENV_TEMPLATE) \
		'  local.conf example: '$(YOCTO_TINY_LOCALCONF_TEMPLATE) \
		'  bblayers example: '$(YOCTO_TINY_BBLAYERS_TEMPLATE) \
		'  build: make yocto-build YOCTO_IMAGE='$(YOCTO_TINY_IMAGE) \
		'  flash: make sd-flash-tiny SDCARD=/dev/sdX' \
		'' \
		'Qt dashboard path:' \
		'  machine: '$(YOCTO_QT_DASHBOARD_MACHINE) \
		'  image: '$(YOCTO_QT_DASHBOARD_IMAGE) \
		'  local.conf example: '$(YOCTO_QT_DASHBOARD_LOCALCONF_TEMPLATE) \
		'  bblayers example: '$(YOCTO_QT_DASHBOARD_BBLAYERS_TEMPLATE) \
		'  parse: make yocto-parse' \
		'  dry-run: make yocto-dry-run YOCTO_IMAGE='$(YOCTO_QT_DASHBOARD_IMAGE) \
		'  build: make yocto-build YOCTO_IMAGE='$(YOCTO_QT_DASHBOARD_IMAGE) \
		'  flash: make sd-flash YOCTO_MACHINE='$(YOCTO_QT_DASHBOARD_MACHINE)' YOCTO_IMAGE='$(YOCTO_QT_DASHBOARD_IMAGE)' SDCARD=/dev/sdX' \
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

patch-check:
	@bash -lc 'source scripts/docker/lib.sh && preflight_run_target && docker compose run --rm builder bash -lc "/workspace/scripts/patch/patch-tool.sh check --tree \"$$TREE\" --diff \"$$DIFF\""'

patch-apply:
	@bash -lc 'source scripts/docker/lib.sh && preflight_run_target && docker compose run --rm builder bash -lc "/workspace/scripts/patch/patch-tool.sh apply --tree \"$$TREE\" --diff \"$$DIFF\" --message \"$$MESSAGE\" --author \"$$AUTHOR\""'

patch-reword:
	@bash -lc 'source scripts/docker/lib.sh && preflight_run_target && docker compose run --rm builder bash -lc "/workspace/scripts/patch/patch-tool.sh reword --tree \"$$TREE\" --commit \"$$COMMIT\" --message \"$$MESSAGE\" --base \"$$BASE\""'

patch-finalize:
	@bash -lc 'source scripts/docker/lib.sh && preflight_run_target && docker compose run --rm builder bash -lc "/workspace/scripts/patch/patch-tool.sh finalize --tree \"$$TREE\" --out \"$$OUT\" --names \"$$NAMES\" --base \"$$BASE\""'

patch-abort:
	@bash -lc 'source scripts/docker/lib.sh && preflight_run_target && docker compose run --rm builder bash -lc "/workspace/scripts/patch/patch-tool.sh abort --tree \"$$TREE\""'

doctor:
	@bash scripts/docker/doctor.sh

boot-capture:
	@bash scripts/boot-capture/boot-capture.sh

yocto-init:
	@bash -lc 'source scripts/docker/lib.sh && preflight_run_target && require_yocto_poky_tree && docker compose run --rm builder bash -lc '\''cd "$$YOCTO_POKY_DIR" && source oe-init-build-env "$$YOCTO_BUILD_DIR" >/dev/null && printf "%s\n" "yocto-init: ok" "Baseline local.conf example: /workspace/yocto/conf/local.conf.example" "Baseline bblayers example: /workspace/yocto/conf/bblayers.conf.example" "Tiny local.conf example: /workspace/yocto/conf/local.conf.tiny.example" "Tiny bblayers example: /workspace/yocto/conf/bblayers.conf.tiny.example" "Qt dashboard local.conf example: /workspace/yocto/conf/local.conf.qt-dashboard.example" "Qt dashboard bblayers example: /workspace/yocto/conf/bblayers.conf.qt-dashboard.example" "Next: manually apply the example files into $$YOCTO_BUILD_DIR/conf/ before building."'\'''

yocto-layers:
	@bash -lc 'source scripts/docker/lib.sh && preflight_run_target && require_yocto_poky_tree && docker compose run --rm builder bash -lc '\''cd "$$YOCTO_POKY_DIR" && source oe-init-build-env "$$YOCTO_BUILD_DIR" && bitbake-layers show-layers'\'''

yocto-parse:
	@bash -lc 'source scripts/docker/lib.sh && preflight_run_target && require_yocto_poky_tree && require_yocto_build_conf && docker compose run --rm builder bash -lc '\''cd "$$YOCTO_POKY_DIR" && source oe-init-build-env "$$YOCTO_BUILD_DIR" && bitbake -p'\'''

yocto-qt-profile:
	@bash -lc 'source scripts/docker/lib.sh && preflight_run_target && require_yocto_poky_tree && require_yocto_build_conf && docker compose run --rm builder bash -lc '\''cd "$$YOCTO_POKY_DIR" && source oe-init-build-env "$$YOCTO_BUILD_DIR" && bitbake -e qtbase | egrep "^(DISTRO_FEATURES=|PACKAGECONFIG=|QT_QPA_DEFAULT_PLATFORM=)"'\'''

yocto-dry-run:
	@bash -lc 'source scripts/docker/lib.sh && require_yocto_image && preflight_run_target && require_yocto_poky_tree && require_yocto_build_conf && docker compose run --rm builder bash -lc '\''cd "$$YOCTO_POKY_DIR" && source oe-init-build-env "$$YOCTO_BUILD_DIR" && bitbake "$$YOCTO_IMAGE" -n'\'''

ifneq ($(filter $(YOCTO_IMAGE),$(YOCTO_TINY_IMAGE)),)
yocto-build:
	@bash -lc 'source scripts/docker/lib.sh && require_yocto_image && preflight_run_target && require_yocto_poky_tree && require_yocto_build_conf && docker compose run --rm builder bash -lc '\''cd "$$YOCTO_POKY_DIR" && source oe-init-build-env "$$YOCTO_BUILD_DIR" >/dev/null && bitbake "$$YOCTO_IMAGE" virtual/kernel u-boot'\'''
else
yocto-build:
	@bash -lc 'source scripts/docker/lib.sh && require_yocto_image && preflight_run_target && require_yocto_poky_tree && require_yocto_build_conf && docker compose run --rm builder bash -lc '\''cd "$$YOCTO_POKY_DIR" && source oe-init-build-env "$$YOCTO_BUILD_DIR" >/dev/null && bitbake "$$YOCTO_IMAGE"'\'''
endif

yocto-bitbake:
	$(if $(BITBAKE_RECIPE),,$(error BITBAKE_RECIPE is required. Usage: make yocto-bitbake BITBAKE_RECIPE=<recipe> [BITBAKE_TASK=<task>]))
	@bash -lc 'source scripts/docker/lib.sh && preflight_run_target && require_yocto_poky_tree && require_yocto_build_conf && docker compose run --rm builder bash -lc '\''cd "$$YOCTO_POKY_DIR" && source oe-init-build-env "$$YOCTO_BUILD_DIR" >/dev/null && bitbake "$(BITBAKE_RECIPE)" $(if $(BITBAKE_TASK),-c $(BITBAKE_TASK))'\'''

sd-flash:
	@bash scripts/sd-flash/sd-flash.sh

sd-flash-tiny:
	@bash scripts/sd-flash/sd-flash-tiny.sh

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

check: format-check lint
