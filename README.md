# CRAY Linux

## 评测流程

1. 通过`make`命令生成kernel-qemu内核文件
2. 评测机会调用如下命令自动启动qemu模拟器

```shell
qemu-system-riscv64 -machine virt -kernel kernel-qemu -m 128M -nographic -smp 2 -bios default -drive file=sdcard.img,if=none,format=raw,id=x0 -device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0 -no-reboot -device virtio-net-device,netdev=net -netdev user,id=net
```

3. kernel-qemu的内核需要自动扫描评测机的sdcard.img所对应的镜像文件，镜像文件根目录下存放32个测试程序
4. 根据自己内核的实现情况，在内核进入用户态后主动调用这些测试程序
5. 调用完测试程序后，主动关机退出

## 模拟评测系统的sdcard.img

为了能够在本地模拟这个评测过程，我们需要自己生成sdcard.img镜像，并且将测试程序放置到镜像的根目录下

```makefile
sdcard.img:
	@dd if=/dev/zero of=$@ bs=1M count=128
	@mkfs.vfat -F 32 $@
	@mount -t vfat $@ $(MNT_DIR)
	@cp -r $(FSIMG)/* $(MNT_DIR)/
	@sync $(MNT_DIR) && umount -v $(MNT_DIR)
```

其中，`$(FSIMG)/*`下放置的是事先编译好的测试用例程序。

## 如何自动调用评测系统的测试用例

操作系统内核初始化结束后，会进入用户态模式，比如说调用`sh`程序，进入交互式模式。因此我们需要完成两项主要的工作。

1. 生成一个类似于shell的用户程序，我们这里命名为runtest，这个程序主要完成调用sdcard.img中测试用例

```c
char *tests[] = {
    "brk",
    "chdir",
    "close",
    "dup2",
    "dup",
    "execve",
    "exit",
    "fork",
    "fstat",
    "getcwd",
    "getdents",
    "getpid",
    "getppid",
    "gettimeofday",
    "mkdir_",
    "mmap",
    "mount",
    "munmap",
    "openat",
    "open",
    "pipe",
    "read",
    "times",
    "umount",
    "uname",
    "unlink",
    "wait",
    "waitpid",
    "write",
    "yield",
    "sleep"
};

//number of testcases
int counts = sizeof(tests) / sizeof((tests)[0]);

#define CONSOLE 1
#define AT_FDCWD -100
char *envp[] = {"PATH=/", 0};

int main(void) {
    int pid, wpid;
    mkdir("/dev", 0666);
    if (openat(AT_FDCWD, "/dev/tty", O_RDWR) < 0) {
        mknod("/dev/tty", S_IFCHR, CONSOLE << 8);
        openat(AT_FDCWD, "/dev/tty", O_RDWR);
    }
    dup(0); // stdout
    dup(0); // stderr
    printf("\nthere are %d testcases\n\n", counts);

    for (int i = 0; i < counts; i++) {
        pid = fork();
        if (pid < 0) {
            printf("init: fork failed\n");
            exit(1);
        }
        if (pid == 0) {
            execve(tests[i], 0, envp);
            printf("init: exec tests[i] failed\n");
            exit(1);
        }

        for (;;) {
            // this call to wait() returns if the shell exits,
            // or if a parentless process exits.
            wpid = wait((int *)0);
            if (wpid == pid) {
                break;
            } else if (wpid < 0) {
                printf("init: wait returned an error\n");
                exit(1);
            } else {
                // it was a parentless process; do nothing.
            }
        }
    }
    shutdown();
    return 0;
}

```

2. 将runtest的十六进形式加载到操作系统内核对应的内存中，并运行。为了提高效率，将runtest生成16进制代码的过程，形成了shell脚本。

```shell
riscv64-linux-gnu-objcopy -S -O binary fsimg/runtest oo
od -v -t x1 -An oo | sed -E 's/ (.{2})/0x\1,/g' > include/initcode.h
rm oo
```

其中`riscv64-linux-gnu-objcopy -S -O binary fsimg/runtest oo`是将gcc编译好的runtest程序，通过objcopy命令，保存符号表，并且以二进制的方式生成oo文件。`od -v -t x1 -An oo`命令将二进制文件，生成16进制，生成过程中去除地址，并且不要使用'*'来标注重复的信息。`sed -E 's/ (.{2})/0x\1,/g' > include/initcode.h`命令将每一个十六进制的数据前面添加`0x`前缀，字段间通过逗号间隔，然后将结果输出到`include/initcode.h`文件中。

initcode.h代码片段如下

```c
0x5d,0x71,0xa2,0xe0,0x86,0xe4,0x26,0xfc,0x4a,0xf8,0x4e,0xf4,0x52,0xf0,0x56,0xec,
0x5a,0xe8,0x5e,0xe4,0x62,0xe0,0x80,0x08,0x93,0x05,0x60,0x1b,0x17,0x15,0x00,0x00,
0x13,0x05,0x45,0xdf,0x97,0x10,0x00,0x00,0xe7,0x80,0xe0,0xbb,0x09,0x46,0x97,0x15,
0x00,0x00,0x93,0x85,0xa5,0xde,0x13,0x05,0xc0,0xf9,0x97,0x10,0x00,0x00,0xe7,0x80,
0x80,0x84,0x63,0x44,0x05,0x10,0x01,0x45,0x97,0x10,0x00,0x00,0xe7,0x80,0xc0,0xbe,
0x01,0x45,0x97,0x10,0x00,0x00,0xe7,0x80,0x20,0xbe,0x17,0x2a,0x00,0x00,0x13,0x0a,
0x6a,0xfa,0x83,0x25,0x0a,0x00,0x17,0x15,0x00,0x00,0x13,0x05,0x25,0xdc,0x97,0x00,
0x00,0x00,0xe7,0x80,0xa0,0x7b,0x83,0x27,0x0a,0x00,0x63,0x51,0xf0,0x08,0x97,0x29,
0x00,0x00,0x93,0x89,0x29,0xf9,0x01,0x49,0x97,0x2b,0x00,0x00,0x93,0x8b,0x0b,0x08,
0x17,0x1b,0x00,0x00,0x13,0x0b,0x0b,0xdd,0x17,0x1c,0x00,0x00,0x13,0x0c,0x0c,0xdb,
```

这段代码通过内核初始化最后的阶段进行加载，代码如下

```c
uchar initcode[] = {
#include "initcode.h"
};
void runtest(void) {
    struct proc *p;
    struct tcb *t;
    p = create_proc();
    t = p->tg->group_leader;
    initproc = p;
    // initcode就是我们通过shell脚本生成的initcode.h文件的内容，然后通过uchar initcode数组将头文件的
    // 文件内容加载的数组中，然后通过uvminit函数，将initcode加载到进程对象的内存管理对象上(p->mm)
    uvminit(p->mm, initcode, sizeof(initcode));
    t->trapframe->epc = 0;
    t->trapframe->sp = USTACK + 5 * PGSIZE;
    safestrcpy(p->name, "/init", 10);
    TCB_Q_changeState(t, TCB_RUNNABLE);
    release(&p->lock);
    return;
}
```

## 如何本地运行和调试

### 本地运行

本地运行依赖于交叉编译环境，qemu仿真环境命令，可以选择自行安装，也可以选择使用大赛的镜像容器。

1. 自行安装

```shell
https://github.com/riscv-collab/riscv-gnu-toolchain
```

因为编译交叉编译工具链耗时很长，也可以选择使用编译好的制品。

```shell
https://github.com/riscv-collab/riscv-gnu-toolchain/tags
```

在构建好本地的交叉编译工具链之后，安装qemu

```shell
apt install qemu-system-riscv64
```

2. 使用大赛的镜像

```shell
docker pull alphamj/os-contest:v7.7
```

3. makefile

makefile中的local目标包含了本地运行的所有依赖，通过运行`make local`可以实现重新生成sdcard.img和对应的测试用例，以及操作系统内核文件kernel-qemu

```shell
local:
	@make clean-all
	@make image
	@make kernel
```

其中 `make clean-all`会删除sdcard.img和相应的依赖，同时会删除kerenl-qemu和对应的依赖，如果只想删除kernel-qemu和对应的依赖，可以使用`make clean`命令。`make image`命令会编译生成sdcard.img，并将对应的测试用例放置到sdcard.img中，`make kernel`会生成kernel-qemu文件，也就是内核文件，同时利用qemu命令运行生成的内核文件。

对于提交评测的流程，因为评测机已经存在sdcard.img，因此，不需要再次生成，只需要编译好操作系统内核文件即可。我们把默认的目标设置为`make all`。

```shell
.DEFAULT_GOAL = all

all: kernel-qemu
```

4. runtest如何使用

在makefile中，有一个目标是`runtest`，这个目标的主要作用是根据`runtest.c`文件的变化，重新生成`initcode.h`文件。

```shell
runtest: image
	@./scripts/runtest.sh
```

因为runtest目标依赖于image，也就是当修改了`runtest.c`文件时，我们需要单独执行`make runtest`命令，这样会生成新的sdcard.img文件，同时也会利用`runtest.sh`脚本自动生成`initcode.h`文件，为后续的`make kernel`做好准备工作。

5. 如何调试

安装依赖库

```shell
apt-get install libncurses5
apt-get install libpython2.7
```

在启动gdb模式前，要执行`make image`保证sdcard.img文件生成，之后运行`make gdb`命令启动gdb模式，这个时候gdb模式下的`-S`参数会主动停止CPU运行，进入到挂起的状态，等待gdb进行连接，这个时候我们需要在新的终端窗口，运行如下命令进行连接。

```shell
# 调试kernel-qemu(elf)文件
riscv64-unknown-elf-gdb kernel-qemu
# 因为内核是在25000进行tcp的监听，所以我们连接该端口
(gdb) target remote :25000
Remote debugging using :25000
# 如果我们想从入口的main函数调试，可以通过下断点的方式进行逐步调试
(gdb) break main
# 继续执行下一语句
(gdb) continue
```

其中`25000`是启动qemu的时候gdb的参数，根据第一个启动内核窗口的日志决定`25000`具体是多少。通过以上步骤，就可以进行内核代码的调试工作。