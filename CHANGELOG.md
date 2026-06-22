# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Features

- **distro:** Introduce optimal-qt-dashboard distro
- **rtcsync:** Add RTC sync recipe and wire into dashboard init
- **qt-dashboard:** Add SensorBackend to display live sensor data
- **qt-dashboard:** Redesign UI to a clean white minimalist layout
- **qt-dashboard:** Decrease sensor polling interval to 1s
- **yocto:** Autoload optimal_env_manager module at boot via inittab

### Bug Fixes

- **product-layer:** Address P2 Yocto compliance issues
- **qt-dashboard:** Add missing DISTRO and document WKS partition size
- **qt-dashboard:** Set IMAGE_FSTYPES for wic SD image output
- **kernel:** Enable CONFIG_FB_DEVICE for Qt linuxfb /dev/fb0
- **kernel:** Fix IT66122 EDID retry and LCDC max-width for HDMI
- **boot:** Force HDMI connector on to prevent early no-mode at fbdev init
- **init:** Fix BusyBox console and suppress duplicate getty
- **qt-dashboard:** Wait for HDMI mode stability before launching Qt
- **kernel:** Debounce IT66121 HPD and clean up HDMI boot config
- **conf:** Correct yocto-bsp layer dependency name
- **config:** Restore /workspace paths in product bblayers template
- **kernel:** Enable COMPAT_32BIT_TIME and clean up DT feature overrides
- **kernel:** Resolve duplicate led device tree definition and enable CONFIG_LEDS
- **wic:** Force digital HDMI 1280x720@60D mode at boot
- **dts:** Silence card-detect debounce warning in product DTS

### Other

- Optimize boot by disabling unused peripherals in product DTS
- Enable custom GPIO LEDs feature for product build
- Am335x-boneblack: Disable TPS backlight driver
- Add patch to silence memfd_create warning
- Handle machine-specific DTB patch without MACHINEOVERRIDES leakage
- Qt-dashboard: Run kiosk app on /dev/null to avoid serial conflict
- Dts: add device tree labels for bh1750 and sht3x
- Add optimal-env-manager recipe and driver
- Enable loadable kernel modules and optimal-env-manager
- Boneblack: remove USR3 LED configuration from optimal-env
- Optimal-env-manager: refactor alarm logic, threshold limits, and LED bindings
- SensorBackend: integrate custom kernel sysfs attributes and historical binary logs
- Qml: redesign dashboard interface and draw real-time charts with Canvas

### Refactor

- **kernel:** Consolidate recipe files and simplify bbappend
- **config:** Generalize workspace paths and clean up product layers
- **yocto:** Restructure layers to separate BSP enablement from product config
- **qt-dashboard:** Optimize startup script and enable extlinux
- **driver:** Modularize optimal_env_manager using private state struct

### Documentation

- **boot:** Add manual eMMC flashing guide from SD card
- Update runbooks and README for layer restructuring
- Update README with fast-boot and hardware support info
- Update product contract and README for environment manager features

### Styling

- Format codebase C/C++ and shell files

### Miscellaneous

- **qt-dashboard-app:** Update oe-workdir and oe-logs symlinks
- **beads:** Close task for adding sensor data backend to Qt dashboard
- **qtbase:** Optimize Qt6 package configuration and cleanup packagegroup
- **beads:** Update issue tracker state
- **tiny:** Update machine description and config format

## [0.1.1] - 2026-06-20

### Features

- **docker:** Add phase 1 builder workflow
- **yocto:** Add storage-backed init/build workflow
- **tooling:** Add coding-style quality contract
- **yocto:** Add host sd-flash target
- **tiny-boot:** Add buildable BBB tiny Yocto path
- **kernel:** Add strict BBB tiny phase2 path
- **dts:** Add backlight node to am335x-boneblack-optimal-tiny.dts
- **kernel:** Add phase3 power-rail baseline
- Add MIT License file
- **kernel:** Add optional gpio-leds heartbeat feature
- **kernel:** Add optional rtc-ds3231 feature
- **kernel:** Complete optional rtc-ds3231 feature
- **kernel:** Add optional i2c2 and sht3x features
- **kernel:** Add optional bh1750 feature
- **makefile:** Enhance Yocto support with Qt dashboard and additional templates
- **yocto:** Standardize Yocto contract naming and add parse/dry-run targets
- **product:** Add beaglebone-black-optimal-qt-dashboard machine
- **kernel:** Add BeagleBone Black Rev D HDMI bridge support
- **qt-dashboard:** Add Qt dashboard image, app skeleton, and config examples
- **tiny:** Enable all hardware features in tiny kernel

### Bug Fixes

- **yocto:** Export builder env for storage-backed builds
- **docker:** Add missing yocto host tools
- **docker:** Update local.mk check in doctor script and fix formatting in Makefile
- **codex:** Wrap SessionStart hook output
- **codex:** Wrap PreCompact hook output
- **tiny-boot:** Move kernel metadata into phase1 tree
- **image:** Canonicalize tiny init ownership
- **tiny-boot:** Canonicalize deterministic contract
- Remove tiny U-Boot network boot noise
- Skip tiny AM33xx arch misc init
- Use absolute tiny extlinux boot path
- Disable tiny U-Boot watchdog
- Enable tiny AM335x EDMA support
- Silence tiny MMC debounce warning
- Disable unused tiny TPS65217 backlight
- Model tiny SD IO voltage rail
- Avoid tiny pbias dummy regulator warning
- Skip AM33xx voltage late init warning
- Remove tiny pinmux self dependency
- Demote fw_devlink sync-state warnings
- Avoid TPS65217 PMIC of-node warning
- **docker:** Resolve 'I have no name' in container shell
- **kernel:** Complete Rev D HDMI bridge bring-up
- **product:** Own qt dashboard SD boot layout
- **qt-dashboard:** Embed fonts for HDMI text rendering
- **kernel:** Enable systemd runtime support for qt dashboard
- **qt-dashboard:** Replace systemd with BusyBox init + inittab ([#0](https://github.com/nhat092005/beaglebone-optimal/issues/0))

### Other

- Delete CLAUDE.md file containing project instructions and guidelines
- Delete unnecessary analysis configuration files
- Enable CONFIG_STRICT_KERNEL_RWX for tiny profile

### Refactor

- **docker:** Simplify user override contract
- **hooks:** Remove pre-compact hook and update documentation structure
- **Makefile:** Reorganize variables into logical groups
- **kernel:** Share tiny feature dts contract
- **scripts:** Normalize sd-flash-tiny variable names to YOCTO_TINY_* prefix
- **qt-dashboard:** Promote DTS from patch to standalone file

### Documentation

- Update AGENTS and README with Docker instructions and examples; add new assets
- **yocto:** Extend local.conf example for uart debug
- **tmp-docs:** Lock tiny yocto phase 1 and phase 2
- **tiny-boot:** Record continuation verification evidence
- **tiny-boot:** Record missing hardware proof devices
- **datasheets:** Add AM3358, BeagleBone Black, and SPRUH73Q datasheets
- **tiny-boot:** Lock canonical tiny naming rules
- **tiny-boot:** Split deterministic cleanup from mmc investigation
- **agents:** Prefer generated yocto patches
- **agents:** Forbid manual yocto patch writing
- **agents:** Add rtk-first shell rule
- **tiny-boot:** Expand runtime debug inventory
- **assets:** Add Yocto initialization and build GIFs
- **readme:** Update Yocto initialization and build sections with images
- **tiny-boot:** Complete debug log inventory
- Document kernel memory protection warning in runbooks
- Update AGENTS.md to clarify tmp directory usage and GitNexus indexing details
- Enhance README.md with detailed setup instructions and project features
- Add license
- Add Qt dashboard product path and yocto-parse/dry-run workflow

### Miscellaneous

- Add understand-anything graph artifacts
- Add codex and gitnexus repo scaffolding
- **beads:** Export yocto issue closures
- **tooling:** Add repo metadata and changelog config
- **sd-flash:** Rename add .sh
- Refresh GitNexus metadata
- Close tiny U-Boot cleanup issues
- Close tiny MMC DMA issue
- Record TPS65217 warning investigation
- Close voltage init warning issue
- Track pinmux cycle investigation
- Track ti-sysc warning investigation
- Close verified boot warning investigations
- Track kernel memory protection warning
- **beads:** Close strict phase2 DTS task
- Remove ai assistants files
- **docs:** Remove tmp docs
- **kernel:** Prune stale phase3 config disables
- **u-boot:** Prune tiny boot command surface
- **beads:** Sync gpio-leds task notes
- **beads:** Update issue tracking state
- **beads:** Close hdmi dashboard bring-up issue

<!-- generated by git-cliff -->
