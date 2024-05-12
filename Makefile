## 1. Basic

#comment：makefile的默认目标，如果在控制台输入了make，实际执行的目标就是make all
.DEFAULT_GOAL = all

# ####### configuration #######
PLATFORM ?= qemu_virt
# PLATFORM ?= qemu_sifive_u
#comment：RUNTEST是一个标志位，这个标志位会通过宏的方式传递到源码中，也就是pcb_lift.c文件，有一个RUNTEST的判定
#comment：如果RUNTEST=1，那么就代表提交到评测系统进行评测，也就是不需要执行image这个目标，直接编译内核，调用评测用例
#comment：如果进行本地调试和运行，需要将RUNTEST设置为0
RUNTEST ?= 1
###############################

# debug options
#comment：这些参数都是标志位，内核代码会根据这些标志位进行输出的控制，默认是0，说明不会输出调试信息
#comment：举例：STRACE=1的情况，内核有一些逻辑会判定，这个标志位等于1，就会输出调试信息
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

#comment：这些是工程的目录结构，包含user目录等，为了在后面的makefile中进行变量的替换
USER = user
OSCOMPU = oscomp_user
BUILD = build
FSIMG = fsimg
ROOT = $(shell pwd)
SCRIPTS = $(ROOT)/scripts
GENINC = include/syscall_gen
#comment：这句代码是创建一个include/syscall_gen代码
$(shell mkdir -p $(GENINC))
MNT_DIR = build/mnt
$(shell mkdir -p $(MNT_DIR))

#comment：BIN这个变量是代表一组用户程序，包括ls等，代码是在user目录下，生成后，会将这些程序copy到sdcard.img中
# utility in user dir, cp these binaries into fsimg/bin
BIN=ls echo cat mkdir rawcwd rm shutdown wc kill grep sh sysinfo true

#comment：init也是一个用户程序，不提交评测系统的时候，在本地运行，init就是内核启动后的第一个用户程序，这个程序可以是sh.c
#comment：也可以是busybox sh命令，总之，进入交互模式，等待用户输入命令
# cp init into fsimg/boot
BOOT=init

#comment：BINFILE=fsimg/ls fsimg/echo fsimg/cat，BIN就是上面行定义的变量，addprefix是makefile提供的內建函数
#comment：将FSIMG作为前缀进行字符串的连接
BINFILE = $(addprefix $(FSIMG)/, $(BIN))
BOOTFILE = $(addprefix $(FSIMG)/, $(BOOT))

#comment：创建4个目录，这些目录都是在fsimg目录下，后续将fsimg目录的内容copy到build/mnt目录下，build/mnt目录作为sdcard.img的挂载点
$(shell mkdir -p $(FSIMG)/oscomp)
$(shell mkdir -p $(FSIMG)/bin)
$(shell mkdir -p $(FSIMG)/boot)

# tmp
$(shell mkdir -p $(FSIMG)/var/tmp)


#comment：我们的内核要在x86下进行编译，但是目标机器是RISCV64体系结构，所以要通过交叉编译工具进行编译，
#comment：由于交叉编译工具链是一组工具，比如说gcc,ld,objdump等等，他们的共通前缀在这里定义
## 2. Compilation flags
TOOLPREFIX = riscv64-linux-gnu-

#comment：本地测试时，qemu的启动命令程序，评测机实际也是使用这个命令进行内核的启动
QEMU = qemu-system-riscv64

#coment：这里的cc=riscv64-linux-gnu-gcc，其他以此类推
CC = $(TOOLPREFIX)gcc
AS = $(TOOLPREFIX)gcc
LD = $(TOOLPREFIX)ld
OBJCOPY = $(TOOLPREFIX)objcopy
OBJDUMP = $(TOOLPREFIX)objdump

#comment：LDFLAGS是链接器的参数，不用管每个参数具体的含义，知道是链接器的参数就可以
LDFLAGS = -z max-page-size=4096
#comment：CFLAGSS是编译器的参数，不用管每个参数的具体含义，知道是编译器的参数就可以
CFLAGS = -Wall -Werror -O2 -fno-omit-frame-pointer -ggdb -gdwarf-2

#comment：KCSAN不用管，他负责内核数据竞争的检查，我们没有启用
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

#comment：以下这些if条件的判断不用管，主要作用是添加CFLAGS的宏定义参数
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

ifeq ($(RUNTEST), 1)
	CFLAGS += -DRUNTEST
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

#comment：shell find命令执行之后，会将src/filelist.mk文件引入到这个makefile
#comment：filelist.mk包含"DIRS-y += src/atomic src/fs src/kernel src/mm src/driver src/proc src/lib src/ipc"
#comment：实际的作用是包含src下的和内核相关的源文件，为后续编译做准备
# Include all filelist.mk to merge file lists
FILELIST_MK = $(shell find ./src -name "filelist.mk")
include $(FILELIST_MK)

#comment：BLACKLIST主要是源文件的黑名单机制，我们的工程没有黑名单，所以不用管黑名单变量
# Filter out directories and files in blacklist to obtain the final set of source files
# There are not files in blacklist, so SRCS=DIRS-y(*.c|*.S)
DIRS-BLACKLIST-y += $(DIRS-BLACKLIST)
SRCS-BLACKLIST-y += $(SRCS-BLACKLIST) $(shell find $(DIRS-BLACKLIST-y) -name "*.c" -o -name "*.S")
SRCS-y += $(shell find $(DIRS-y) -name "*.c" -o -name "*.S")
#comment：filter-out是makefile的內建函数，srcs-y作为整体，如果这里面有srcs-blacklist-y（黑名单文件），就把黑名单剔除
#commnet：我们没有黑名单文件，所以SRCS=SRCS-y，也就是所有的*.c和*.S文件构成了源文件的集合
SRCS = $(filter-out $(SRCS-BLACKLIST-y),$(SRCS-y))

#comment：我们使用的是qemu_virt，因此就看qemu_virt，有4个参数了解就可以。-kernel kernel-qemu，我们的内核
#comment：编译完成后，名字就是kernel-qemu，所以-kernel参数就是指定内核的名称。file=sdcard.img，文件系统的镜像
#comment：名称是sdcard.img，需要在启动的时候指定，另外-m 128M代表内存布局是在128M空间内，-DNCPU=2代表虚拟机有2个CPU
#comment：这里面我们定义的参数就是评测系统启动内核的参数
##### PLATFORM ######

ifeq ($(PLATFORM), qemu_virt)
	QEMUOPTS = -machine virt -bios bootloader/opensbi-qemu -kernel kernel-qemu -m 128M -smp 2 -nographic
	QEMUOPTS += -drive file=sdcard.img,if=none,format=raw,id=x0
	QEMUOPTS += -device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0
	CFLAGS += -DVIRT -DNCPU=2
endif

ifeq ($(PLATFORM), qemu_sifive_u)
	QEMUOPTS = -machine sifive_u -bios bootloader/sbi-sifive -kernel kernel-qemu -m 128M -smp 5 -nographic
	QEMUOPTS += -drive file=sdcard.img,if=sd,format=raw
	CFLAGS += -DSIFIVE_U -DNCPU=5
endif


#comment：调试内核的时候，需要在内核启动的时候指定一个监听的端口号，这里面采用随机的方式指定，不用特别关心
# try to generate a unique GDB port
GDBPORT = $(shell expr `id -u` % 5000 + 25000)
# QEMU's gdb stub command line changed in 0.11
QEMUGDB = $(shell if $(QEMU) -help | grep -q '^-gdb'; \
	then echo "-gdb tcp::$(GDBPORT)"; \
	else echo "-s -p $(GDBPORT)"; fi)

#comment：以下部分是改动内容比较多的地方，重点完成2个场景。
#comment：场景1，本地测试，本地生成sdcard.img文件以及内核文件，2个文件生成后，本地执行qemu-system-riscv64命令，启动内核，make local完成场景1
#comment：场景2，提交评测系统，这个时候不需要生成sdcard.img文件，sdcard.img由评测机提供，该场景只需要执行内核的编译，make all完成场景2

#comment：上面的代码都是一些准备工作，下面这些目标，和整体的构建有关系，需要认真了解
#comment：local对应场景1，目标主要负责本地测试，local目标一共做了三件事情，make clean-all负责将所有中间产生的文件删除，目的为为了重新编译
#comment：image目标是生成sdcard.img文件，并将相关的测试用例copy到根目录，make kernel主要是编译内核文件，生成kernel-qemu文件
## 5. Targets
local:
	@make clean-all
	@make image
	@make kernel

#comment：all目标对应场景2，提交到评测机的时候，自动运行make all
all: kernel-qemu

#comment：本次进行完善的一个点，执行make format会进行代码的格式化，和本地运行、评测没有直接关系，仅仅是将代码规范化的一个动作
format:
	@which clang-format-15 > /dev/null 2>&1 || apt install -y clang-format-15
	clang-format-15 -i $(filter %.c, $(SRCS)) $(filter-out include/platform/hifive/pml_hifive.h, $(shell find include -name "*.c" -o -name "*.h"))

#comment：场景1（本地测试）的流程是 make local（包含make image和make kernel)，执行make kernel的时候，会首先执行“kernel-qemu”这个目标
#comment：“kernel-qemu”这个目标是在scripts/build.mk中进行了定义，“kernel-qemu”目标执行完，内核文件也就生成了
#comment：内核文件编译完成后，会自动执行$(QEMU) $(QEMUOOPTS)这个命令，也就是使用qemu-system-riscv64命令启动内核
kernel: kernel-qemu
	$(QEMU) $(QEMUOPTS)

#comment：make gdb目标主要是进行调试，和非调试相比，主要多了$(QEMUGDB)这个参数，也就是-gdb tcp::25000这个参数
#comment：gdb模式启动内核后，内核会挂起，等待另外一个窗口下达调试指令，比如说break在哪个文件的哪个函数上
#comment：gdb目标要依赖于kernel-qemu目标和.gdbinit这2个目标，也就是会递归触发依赖的2个目标构建完毕再执行gdb目标
gdb: kernel-qemu .gdbinit
	@echo "$(RED)*** Please make sure to execute 'make image' before attempting to run gdb$(RESET)" 1>&2
	@echo "*** Now run 'gdb' in another window" 1>&2
	$(QEMU) $(QEMUOPTS) -S $(QEMUGDB)

#comment：根据.gdbijnit.tmp-riscv文件的端口，替换成GDBPORT变量，了解即可:w

.gdbinit: .gdbinit.tmp-riscv
	sed "s/:1234/:$(GDBPORT)/" < $^ > $@

#comment：我们的编译过程是多层级的，export这些变量之后，子目录的makeifle也会得到这些变量的值
#comment：子目录的makefile执行的时候，就可以使用这些变量
export CC AS LD OBJCOPY OBJDUMP CFLAGS ASFLAGS LDFLAGS ROOT SCRIPTS USER

#comment：make image是local目标的依赖，image目标又依赖user目标和sdcard.img目标
image: user sdcard.img

#comment：user目标依赖oscomp目标，user目标会将user目录下的程序编译好，并且copy到fsimg对应的目录下
user: oscomp
	@echo "$(YELLOW)build user:$(RESET)"
	@cp README.md $(FSIMG)/
	@make -C $(USER)
	@cp busybox/busybox $(FSIMG)/busybox
	@mv $(BINFILE) $(FSIMG)/bin/
	@cp $(BOOTFILE) $(FSIMG)/boot/
# @mv $(TESTFILE) $(FSIMG)/test/
	@rm -rf $(FSIMG)/oscomp/*
	@rm -rf $(FSIMG)/mnt/*
	@mv $(OSCOMPU)/riscv64/* $(FSIMG)/
	@cp $(OSCOMPU)/src/oscomp/run-all.sh $(FSIMG)/

#comment：测试用例程序，主要是本地进行测试的时候使用
oscomp:
	@make -C $(OSCOMPU) -e all CHAPTER=7

#comment：sdcard.img目标主要是生成sdcard.img这个文件，利用linux下的dd命令生成128m的文件
#comment：然后利用linux下的mkfs.vfat命令制作成fat32格式
#comment：挂载到$(MNT_DIR)目录，之后将fsimg目录下的内容都copy到$(MNT_DIR)下，这样sdcard.img下就包含了所有fsimg下的文件(测试用例，用户程序等)
sdcard.img:
	@dd if=/dev/zero of=$@ bs=1M count=128
	@mkfs.vfat -F 32 $@
	@mount -t vfat $@ $(MNT_DIR)
	@cp -r $(FSIMG)/* $(MNT_DIR)/
	@sync $(MNT_DIR) && umount -v $(MNT_DIR)

#comment：本次重点改动的内容，runtest是一个单独执行的目标，使用的场景是，当修改了runtest.c这个文件，并且需要在本地测试，或者提交
#comment：到评测系统测试，都需要执行这个目标。runtest依赖image目标，也就是执行make runtest，首先会执行image目标，生成sdcard.img
#comment：然后会执行scripts/runtest.sh脚本（本次新增），将runtest.c生成的二进制转化为16进制，并且放置到initcode.h文件中
#comment：如果提测到评测系统，评测系统会执行make all，也就会将最新的runtest加载到内核，如果本地运行，执行make kernel，也可以
#comment：实现同样的逻辑，将最新的runtest加载到内核
runtest: image
	@./scripts/runtest.sh

clean-all: clean
	-@make -C $(USER)/ clean
	-@make -C $(OSCOMPU)/ clean
	-rm sdcard.img $(FSIMG)/* -rf

clean:
	-rm build/* kernel-qemu $(GENINC) -rf

.PHONY: qemu clean user clean-all format test oscomp image mount umount submit

## 6. Build kernel
include $(SCRIPTS)/build.mk

## 7. Misc
include $(SCRIPTS)/colors.mk


# 目标的依赖关系比较复杂，这里面梳理一下
# oscomp：生成测试用例
# user：生成用户程序，如ls，echo
# sdcard.img：生成sdcard.img文件，并将user目标，oscomp目标生成的程序copy到sdcard.img中

# 场景1，本地测试
# make local
# oscomp->user -|
#               |---image  ----|
# sdcard.img   -|              |----local
#                              |
# kernel-qemu  -|---kernel ----|


# 场景2，提交评测
# make all
# kernel-qemu  -|---kernel ----|----all


# 场景3，修改了runtest.c文件，提交评测
# make runtest
# make all

# oscomp->user -|
#               |---image  ----|---runtest
# sdcard.img   -|

# 提交
# kernel-qemu  -|---kernel ----|----all

