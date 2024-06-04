#define USER
#include "stddef.h"
#include "unistd.h"
#include "stdio.h"
// #include "string.h"

char *tests[] = {
"times",
"execve",
"dup",
"read",
"exit",
"fork",
"sleep",
"mmap",
"munmap",
"getdents",
"mkdir_",
"chdir",
"dup2",
"waitpid",
"fstat",
"getpid",
"wait",
"uname",
"open",
"gettimeofday",
"getppid",
"openat",
"brk",
"umount",
"unlink",
"mount",
"getcwd",
"write",
"close",
"yield",
"clone",
"pipe",
};
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
    shutdown();
    return 0;
}
