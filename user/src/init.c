// init: The initial user-level program
#define USER
#include "stddef.h"
#include "unistd.h"
#include "stdio.h"
#include "string.h"

// char *argv[] = {"/busybox", "sh", 0};
char *argv[] = {0};
char *envp[] = {"PATH=/:/usr/bin:/bin", "LD_LIBRARY_PATH=/", 0};

#define CONSOLE 1
#define DEV_NULL 2
#define DEV_ZERO 3
#define DEV_RTC 3
#define DEV_CPU_DMA_LATENCY 0
#define DEV_URANDOM 4
#define AT_FDCWD -100

#define CHECK(c, ...) ((c) ? 1 : (printf(#c "fail" __VA_ARGS__), exit(-1)))
void runtest();


int main(void) {
    printf("hhhhhhhhhhhhhhhhh\n");

    mkdir("/dev", 0666);
    if (openat(AT_FDCWD, "/dev/tty", O_RDWR) < 0) {
        mknod("/dev/tty", S_IFCHR, CONSOLE << 8);
        openat(AT_FDCWD, "/dev/tty", O_RDWR);
    }
    dup(0); // stdout
    dup(0); // stderr

#ifdef RUNTEST
    // runtest();
    printf("aaaaaaaaaaaaaaaaaaaaaaa\n");
    shutdown();
    return 0;
#else
    int pid, wpid;
    // after we create tty, we can use printf
    CHECK(mkdir("/proc", 0666) == 0);
    CHECK(mkdir("/proc/mounts", 0666) == 0);
    CHECK(openat(AT_FDCWD, "/proc/meminfo", O_RDWR | O_CREAT) > 0);
    CHECK(mkdir("/tmp", 0666) == 0);
    CHECK(mknod("/dev/null", S_IFCHR, DEV_NULL << 8) == 0);
    CHECK(mknod("/dev/zero", S_IFCHR, DEV_ZERO << 8) == 0);
    CHECK(mknod("/dev/cpu_dma_latency", S_IFCHR, DEV_CPU_DMA_LATENCY << 8) == 0);
    CHECK(mkdir("/dev/shm", 0666) == 0);
    CHECK(mkdir("/dev/misc", 0666) == 0);
    CHECK(mknod("/dev/misc/rtc", S_IFCHR, DEV_RTC << 8) == 0);
    // for /dev/urandom(for iperf)
    // mknod("/dev/urandom", S_IFCHR, DEV_CPU_DMA_LATENCY << 8);

    printf("\n");
    printf("  ___ _ __ __ _ _   _\n");
    printf(" / __| '__/ _` | | | |\n");
    printf("| (__| | | (_| | |_| |\n");
    printf(" \\___|_|  \\__,_|\\__, |\n");
    printf("                |___/\n");

    printf("\n");

    for (;;) {
        printf("init: starting sh\n");

        pid = fork();
        if (pid < 0) {
            printf("init: fork failed\n");
            exit(1);
        }
        if (pid == 0) {
            printf("about to start sh\n");
            // execve("/bin/sh",argv,envp);
            execve("/busybox", argv, envp);
            // execve("/run-all.sh", argv, envp);
            printf("init: exec sh failed\n");
            exit(1);
        }

        for (;;) {
            // this call to wait() returns if the shell exits,
            // or if a parentless process exits.
            wpid = wait((int *)0);
            if (wpid == pid) {
                // the shell exited; restart it.
                break;
            } else if (wpid < 0) {
                printf("init: wait returned an error\n");
                exit(1);
            } else {
                // it was a parentless process; do nothing.
            }
        }
    }
#endif
}

char *testpath[] = {
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
    "yield"
};

// number of elements in fixed-size array
#define NELEM(x) (sizeof(x) / sizeof((x)[0]))

void runtest() {
    int pid;

    for (int i = 0; i < NELEM(testpath); i++) {
        pid = fork();
        if (pid < 0) {
            printf("fork failed\n");
            exit(-1);
        }
        if (pid == 0) {
            execve(testpath[i], NULL, envp);
            printf("never reach here");
            exit(-1);
        } else {
            while (1) {
                if (wait(0) < 0) {
                    break;
                }
            }
        }
    }
}
