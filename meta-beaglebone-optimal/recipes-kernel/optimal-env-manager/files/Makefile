# SPDX-License-Identifier: MIT
#
# Build optimal_env_manager as an out-of-tree kernel module.
obj-m += optimal_env_manager.o
optimal_env_manager-y := optimal_env_core.o optimal_env_sysfs.o optimal_env_chardev.o optimal_env_sensors.o

SRC := $(shell pwd)

all:
	$(MAKE) -C $(KERNEL_SRC) M=$(SRC) modules

modules_install:
	$(MAKE) -C $(KERNEL_SRC) M=$(SRC) modules_install

clean:
	$(MAKE) -C $(KERNEL_SRC) M=$(SRC) clean
