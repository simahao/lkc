#define USER
#include "stddef.h"
#include "unistd.h"
#include "stdio.h"
#include "string.h"
#include "stdlib.h"

int main(int argc, char *argv[]) {
    int i;

    if (argc < 2) {
        fprintf(2, "Usage: rm files...\n");
        exit(1);
    }

    for (i = 1; i < argc; i++) {
        if (unlink(argv[i]) < 0) {
            fprintf(2, "rm: %s failed to delete\n", argv[i]);
            break;
        }
    }

    exit(0);
    return 0;
}
