#define USER
#include "stddef.h"
#include "unistd.h"
#include "stdio.h"
#include "string.h"
#include "stdlib.h"

#define handle_error(msg)    \
    do {                     \
        printf("%s\n", msg); \
        exit(-1);            \
    } while (0)

#define BUF_SIZE 4096

int main(int argc, char *argv[]) {
    int fd, nread;
    char *buf = (char *)malloc(BUF_SIZE);
    struct linux_dirent64 *d;
    int bpos;
    unsigned char d_type;

    fd = open(argc > 1 ? argv[1] : ".", O_RDONLY | O_DIRECTORY);
    if (fd == -1) {
        handle_error("open fd failed");
    }

    for (;;) {
        nread = getdents(fd, (struct linux_dirent64 *)buf, BUF_SIZE);
        if (nread == -1)
            handle_error("getdents failed");

        if (nread == 0)
            break;

        int ctr = 0;
        for (bpos = 0; bpos < nread;) {
            d = (struct linux_dirent64 *)(buf + bpos);
            d_type = d->d_type;
            switch (d_type) {
                case DT_DIR:
                    printf("\033[34;1m%s\t\033[0m", d->d_name);
                    break;
                case DT_CHR:
                case DT_BLK:
                    printf("\033[38;5;214m%s\t\033[0m", d->d_name);
                    break;
                default:
                    printf("%s\t", d->d_name);
                    break;
            }

            bpos += d->d_reclen;
            if (++ctr == 6) {
                write(STDOUT, "\n", 1);
                ctr = 0;
            }
        }
        write(STDOUT, "\n", 1);
    }
    free(buf);
    return 0;
    exit(0);
}