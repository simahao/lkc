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
#define USER
#include "stddef.h"
#include "unistd.h"
#include "stdio.h"

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

`initcode.h`代码片段如下

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
    ASSERT(p != NULL);
    t = p->tg->group_leader;
    ASSERT(t != NULL);
    initproc = p;

    // initcode就是我们通过shell脚本生成的initcode.h文件的内容，然后通过uchar initcode数组将头文件的
    // 文件内容加载的数组中，然后通过uvminit函数，将initcode加载到进程对象的内存管理对象上(p->mm)
    uvminit(p->mm, initcode, sizeof(initcode));

    t->trapframe->epc = 0;
    t->trapframe->sp = USTACK + 5 * PGSIZE;

    safestrcpy(p->name, "/init", 10);
    TCB_Q_changeState(t, TCB_RUNNABLE);
    release(&p->lock);
    Info("========== init finished! finish running testcase ==========\n");
    return;
}
```