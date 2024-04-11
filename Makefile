## 1. Basic
.DEFAULT_GOAL = all

# ####### configuration #######
PLATFORM ?= qemu_virt
# PLATFORM ?= qemu_sifive_u
SUBMIT ?= 0
RUN ?= 1
###############################

# debug options
STRACE ?= 0
LOCKTRACE ?= 0
DEBUG_LDSO ?= 0
DEBUG_PROC ?= 0
DEBUG_FS ?= 0
DEBUG_RW ?= 0
DEBUG_INODE ?= 0
DEBUG_PIPE ?= 0
DEBUG_PAGE_CACHE ?= 0
DEBUG_SIGNAL ?= 0
DEBUG_FUTEX ?= 0
DEBUG_THREAD ?= 0

USER = user
OSCOMPU = oscomp_user
BUILD = build
FSIMG = fsimg
ROOT = $(shell pwd)
SCRIPTS = $(ROOT)/scripts
GENINC = include/syscall_gen
$(shell mkdir -p $(GENINC))
MNT_DIR = build/mnt
$(shell mkdir -p $(MNT_DIR))
$(shell mkdir -p mount_sd) # for sdcard.img

# Initial file in directory, cp these test utilities into fsimg/test
TEST=user_test kalloctest mmaptest \
	clock_gettime_test signal_test \
	writev_test readv_test lseek_test \
	sendfile_test renameat2_test

# utility in user dir, cp these binaries into fsimg/bin
BIN=ls echo cat mkdir rawcwd rm shutdown wc kill grep sh sysinfo true
# cp init into fsimg/boot
BOOT=init

TESTFILE = $(addprefix $(FSIMG)/, $(TEST))
BINFILE = $(addprefix $(FSIMG)/, $(BIN))
BOOTFILE = $(addprefix $(FSIMG)/, $(BOOT))

$(shell mkdir -p $(FSIMG)/test)
$(shell mkdir -p $(FSIMG)/oscomp)
$(shell mkdir -p $(FSIMG)/bin)
$(shell mkdir -p $(FSIMG)/boot)

# tests
$(shell mkdir -p $(FSIMG)/test/libc-test)
$(shell mkdir -p $(FSIMG)/test/lmbench)
$(shell mkdir -p $(FSIMG)/test/time-test)
$(shell mkdir -p $(FSIMG)/test/libc-bench)
$(shell mkdir -p $(FSIMG)/test/iozone)
$(shell mkdir -p $(FSIMG)/test/lua)
$(shell mkdir -p $(FSIMG)/test/netperf)
$(shell mkdir -p $(FSIMG)/test/iperf)
$(shell mkdir -p $(FSIMG)/test/netperf)
$(shell mkdir -p $(FSIMG)/test/cyclictest)
$(shell mkdir -p $(FSIMG)/test/unixbench)
$(shell mkdir -p $(FSIMG)/test/lmbench_test)

# tmp
$(shell mkdir -p $(FSIMG)/var/tmp)
$(shell touch $(FSIMG)/var/tmp/lmbench)


## 2. Compilation flags

# Try to infer the correct TOOLPREFIX if not set
ifndef TOOLPREFIX
TOOLPREFIX := $(shell if riscv64-unknown-elf-objdump -i 2>&1 | grep 'elf64-big' >/dev/null 2>&1; \
	then echo 'riscv64-unknown-elf-'; \
	elif riscv64-linux-gnu-objdump -i 2>&1 | grep 'elf64-big' >/dev/null 2>&1; \
	then echo 'riscv64-linux-gnu-'; \
	elif riscv64-unknown-linux-gnu-objdump -i 2>&1 | grep 'elf64-big' >/dev/null 2>&1; \
	then echo 'riscv64-unknown-linux-gnu-'; \
	else echo "***" 1>&2; \
	echo "*** Error: Couldn't find a riscv64 version of GCC/binutils." 1>&2; \
	echo "*** To turn off this error, run 'gmake TOOLPREFIX= ...'." 1>&2; \
	echo "***" 1>&2; exit 1; fi)
endif

QEMU = qemu-system-riscv64

CC = $(TOOLPREFIX)gcc
AS = $(TOOLPREFIX)gcc
LD = $(TOOLPREFIX)ld
OBJCOPY = $(TOOLPREFIX)objcopy
OBJDUMP = $(TOOLPREFIX)objdump

LDFLAGS = -z max-page-size=4096
CFLAGS = -Wall -Werror -O2 -fno-omit-frame-pointer -ggdb -gdwarf-2

ifdef KCSAN
CFLAGS += -DKCSAN
KCSANFLAG += -fsanitize=thread -fno-inline
OBJS_KCSAN = \
  build/src/driver/console.o \
  build/src/driver/uart.o \
  build/src/lib/printf.o \
  build/src/atomic/spinlock.o \
  build/src/lib/kcsan.o
endif

ifeq ($(DEBUG_LDSO), 1)
	CFLAGS += -D__DEBUG_LDSO__
endif
ifeq ($(STRACE), 1)
	CFLAGS += -D__STRACE__
endif
ifeq ($(LOCKTRACE), 1)
	CFLAGS += -D__LOCKTRACE__
endif
ifeq ($(DEBUG_PROC), 1)
	CFLAGS += -D__DEBUG_PROC__
endif
ifeq ($(DEBUG_FS), 1)
	CFLAGS += -D__DEBUG_FS__
endif
ifeq ($(DEBUG_PAGE_CACHE), 1)
	CFLAGS += -D__DEBUG_PAGE_CACHE__
endif
ifeq ($(DEBUG_SIGNAL), 1)
	CFLAGS += -D__DEBUG_SIGNAL__
endif
ifeq ($(DEBUG_PIPE), 1)
	CFLAGS += -D__DEBUG_PIPE__
endif
ifeq ($(DEBUG_RW), 1)
	CFLAGS += -D__DEBUG_RW__
endif
ifeq ($(DEBUG_FUTEX), 1)
	CFLAGS += -D__DEBUG_FUTEX__
endif
ifeq ($(DEBUG_THREAD), 1)
	CFLAGS += -D__DEBUG_THREAD__
endif
ifeq ($(DEBUG_INODE), 1)
	CFLAGS += -D__DEBUG_INODE__
endif

ifeq ($(SUBMIT), 1)
	CFLAGS += -DSUBMIT
endif

CFLAGS += -MD
# CFLAGS += -mcmodel=medany -march=rv64g -mabi=lp64f
CFLAGS += -mcmodel=medany -march=rv64gc -mabi=lp64d
CFLAGS += -ffreestanding -fno-common -nostdlib -mno-relax
CFLAGS += -I$(ROOT)/include
CFLAGS += $(shell $(CC) -fno-stack-protector -E -x c /dev/null >/dev/null 2>&1 && echo -fno-stack-protector)
ASFLAGS = $(CFLAGS)

# Disable PIE when possible (for Ubuntu 16.10 toolchain)
ifneq ($(shell $(CC) -dumpspecs 2>/dev/null | grep -e '[^f]no-pie'),)
	CFLAGS += -fno-pie -no-pie
endif
ifneq ($(shell $(CC) -dumpspecs 2>/dev/null | grep -e '[^f]nopie'),)
	CFLAGS += -fno-pie -nopie
endif

## 3. File list

# Include all filelist.mk to merge file lists
FILELIST_MK = $(shell find ./src -name "filelist.mk")
# DIRS-y += src/atomic src/fs src/kernel src/mm src/driver src/proc src/test src/lib src/ipc
include $(FILELIST_MK)

# Filter out directories and files in blacklist to obtain the final set of source files
# There are not files in blacklist, so SRCS=DIRS-y(*.c|*.S)
DIRS-BLACKLIST-y += $(DIRS-BLACKLIST)
SRCS-BLACKLIST-y += $(SRCS-BLACKLIST) $(shell find $(DIRS-BLACKLIST-y) -name "*.c" -o -name "*.S")
SRCS-y += $(shell find $(DIRS-y) -name "*.c" -o -name "*.S")
SRCS = $(filter-out $(SRCS-BLACKLIST-y),$(SRCS-y))

##### PLATFORM ######

ifeq ($(PLATFORM), qemu_virt)
	QEMUOPTS = -machine virt -bios bootloader/opensbi-qemu -kernel kernel-qemu -m 1G -smp 2 -nographic
	ifeq ($(RUN), 1)
		QEMUOPTS += -drive file=sdcard.img,if=none,format=raw,id=x0
	else
		QEMUOPTS += -drive file=fat32.img,if=none,format=raw,id=x0
	endif
	QEMUOPTS += -device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0
	CFLAGS += -DVIRT -DNCPU=2
endif

ifeq ($(PLATFORM), qemu_sifive_u)
	QEMUOPTS = -machine sifive_u -bios bootloader/sbi-sifive -kernel kernel-qemu -m 1G -smp 5 -nographic
	ifeq ($(SUBMIT), 1)
		QEMUOPTS += -drive file=sdcard.img,if=sd,format=raw
	else
		QEMUOPTS += -drive file=fat32.img,if=sd,format=raw
	endif
	CFLAGS += -DSIFIVE_U -DNCPU=5
endif


# try to generate a unique GDB port
GDBPORT = $(shell expr `id -u` % 5000 + 25000)
# QEMU's gdb stub command line changed in 0.11
QEMUGDB = $(shell if $(QEMU) -help | grep -q '^-gdb'; \
	then echo "-gdb tcp::$(GDBPORT)"; \
	else echo "-s -p $(GDBPORT)"; fi)

dst=/mnt

## 5. Targets
all: sudo
	@make clean-all
	@make image
	@make sd
	@make kernel

sd:
	@if [ ! -d "$(dst)/bin" ]; then sudo mkdir $(dst)/bin; fi
	@sudo cp $(FSIMG)/boot/init $(dst)/
	@sudo cp $(FSIMG)/run-all.sh $(dst)/

sudo:
	@if ! which sudo > /dev/null; then \
		apt install sudo; \
	fi

format:
	@which clang-format-15 > /dev/null 2>&1 || apt install -y clang-format-15
# pml_hifive.h is not be formatted by clang-format
	clang-format-15 -i $(filter %.c, $(SRCS)) $(filter-out include/platform/hifive/pml_hifive.h, $(shell find include -name "*.c" -o -name "*.h"))

kernel: kernel-qemu
	$(QEMU) $(QEMUOPTS)

gdb: kernel-qemu .gdbinit
	@echo "$(RED)*** Please make sure to execute 'make image' before attempting to run gdb$(RESET)" 1>&2
	@echo "*** Now run 'gdb' in another window" 1>&2
	$(QEMU) $(QEMUOPTS) -S $(QEMUGDB)

.gdbinit: .gdbinit.tmp-riscv
	sed "s/:1234/:$(GDBPORT)/" < $^ > $@

export CC AS LD OBJCOPY OBJDUMP CFLAGS ASFLAGS LDFLAGS ROOT SCRIPTS USER

# image: user fat32.img
image: user fat32.img

# apps:
# 	@cp apps/musl-1.2.4/lib/libc.so fsimg/
# 	@cp apps/libc-test/disk/* fsimg/libc-test
# 	@cp apps/lmbench/bin/riscv64/lmbench_all fsimg/lmbench
# 	@cp sdcard/lmbench_testcode.sh fsimg/lmbench
# 	@cp apps/lmbench/bin/riscv64/hello fsimg/lmbench
# 	@cp apps/libc-bench/libc-bench fsimg/libc-bench
# 	@cp apps/time-test/time-test fsimg/time-test
# 	@cp apps/iozone/iozone fsimg/iozone
# 	@cp apps/scripts/iozone/* fsimg/iozone
# 	@cp apps/lua/src/lua fsimg/lua
# 	@cp apps/scripts/lua/* fsimg/lua
# 	@cp apps/netperf/src/netperf apps/netperf/src/netserver fsimg/netperf/
# 	@cp apps/scripts/netperf/* fsimg/netperf/
# 	@cp sdcard/cyclictest sdcard/hackbench fsimg/cyclictest
# 	@cp sdcard/cyclictest_testcode.sh fsimg/cyclictest
# 	@cp sdcard/lmbench_all fsimg/lmbench_test
# 	@cp sdcard/hello fsimg/lmbench_test
# 	@cp sdcard/lmbench_testcode.sh fsimg/lmbench_test
# 	@cp sdcard/unixbench/* fsimg/unixbench
# 	@cp sdcard/iperf3 fsimg/iperf
# 	@cp sdcard/iperf_testcode.sh fsimg/iperf


# user: oscomp busybox
# user: apps
user: oscomp
	@echo "$(YELLOW)build user:$(RESET)"
	@cp README.md $(FSIMG)/
	@make -C $(USER)
	@cp busybox/busybox $(FSIMG)/busybox
	@mv $(BINFILE) $(FSIMG)/bin/
	@cp $(BOOTFILE) $(FSIMG)/boot/
	@mv $(TESTFILE) $(FSIMG)/test/
	@rm -rf $(FSIMG)/oscomp/*
	@mv $(OSCOMPU)/riscv64/* $(FSIMG)/
	@cp $(OSCOMPU)/src/oscomp/run-all.sh $(FSIMG)/
# @cp support/* $(FSIMG)/ -r

oscomp:
	@make -C $(OSCOMPU) -e all CHAPTER=7

fat32.img:
	@dd if=/dev/zero of=$@ bs=1M count=128
	@mkfs.vfat -F 32 -s 2 -a $@
	@sudo mount -t vfat $@ $(MNT_DIR)
	@sudo cp -r $(FSIMG)/* $(MNT_DIR)/
	@sync $(MNT_DIR) && sudo umount -v $(MNT_DIR)

# for sdcard.img(local test)
mount:
	@sudo mount -t vfat fat32.img mount_sd
umount:
	@sudo umount -v mount_sd

submit: image
	@riscv64-linux-gnu-objcopy -S -O binary fsimg/submit tmp
	@xxd -ps tmp > submit
	@rm tmp
	@cat submit | ./scripts/convert.sh | ./scripts/code.sh > include/initcode.h
	@rm submit

clean-all: clean
	-@make -C $(USER)/ clean
	-@make -C $(OSCOMPU)/ clean
# -rm $(SCRIPTS)/mkfs fs.img fat32.img $(FSIMG)/* -rf
	-rm fat32.img $(FSIMG)/* -rf

clean:
	-rm build/* kernel-qemu $(GENINC) -rf

.PHONY: qemu clean user clean-all format test oscomp image mount umount submit

## 6. Build kernel
include $(SCRIPTS)/build.mk

## 7. Misc
include $(SCRIPTS)/colors.mk
