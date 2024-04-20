#define USER
#include "stddef.h"
#include "unistd.h"
#include "stdio.h"
#include "string.h"

// char *argv[] = {"/busybox/busybox", "sh", 0};
char *envp[] = {
    "PATH=/",
    "LD_LIBRARY_PATH=/",
    "ENOUGH=3000",
    "TIMING_O=7",
    "LOOP_O=0",
    NULL,
};

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
    shutdown();
    print_vma();
    mkdir("/dev", 0666);
    if (openat(AT_FDCWD, "/dev/tty", O_RDWR) < 0) {
        mknod("/dev/tty", S_IFCHR, CONSOLE << 8);
        openat(AT_FDCWD, "/dev/tty", O_RDWR);
    }

    dup(0); // stdout
    dup(0); // stderr

    // after we create tty, we can use printf
    printf("submit start\n");
    runtest();
    return 0;
}

// char *testpath[] = {
//     "./run-all.sh"
// };

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
