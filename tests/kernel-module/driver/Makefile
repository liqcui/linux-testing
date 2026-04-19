obj-m += test_driver.o test_device.o

# 内核构建目录
KDIR ?= /lib/modules/$(shell uname -r)/build

# 当前目录
PWD := $(shell pwd)

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean

install:
	$(MAKE) -C $(KDIR) M=$(PWD) modules_install
	depmod -a

help:
	@echo "Kernel Module Makefile"
	@echo "======================"
	@echo "Targets:"
	@echo "  all     - Build the kernel module"
	@echo "  clean   - Clean build artifacts"
	@echo "  install - Install the module"
	@echo "  load    - Load the module"
	@echo "  unload  - Unload the module"
	@echo "  test    - Quick load/unload test"
	@echo ""
	@echo "Current kernel: $(shell uname -r)"

load:
	sudo insmod test_driver.ko

unload:
	sudo rmmod test_driver

test: all
	@echo "Loading module..."
	-sudo insmod test_driver.ko
	@echo ""
	@echo "Module info:"
	lsmod | grep test_driver
	@echo ""
	@echo "Device node:"
	ls -l /dev/testdev 2>/dev/null || echo "Device not found"
	@echo ""
	@echo "Kernel messages:"
	dmesg | tail -10 | grep test_driver
	@echo ""
	@echo "Unloading module..."
	-sudo rmmod test_driver
	@echo ""
	@echo "Done"

.PHONY: all clean install load unload test help
