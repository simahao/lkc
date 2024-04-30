# 系统调用实现

## brk

- 代码位置：src/kernel/sysproc.c

- 代码

```C
uint64 sys_brk(void) {
    uintptr_t oldaddr;
    uintptr_t newaddr;
    intptr_t increment;
    oldaddr = proc_current()->mm->brk;
    argaddr(0, &newaddr);
    if (newaddr == 0) {
        return oldaddr;
    }
    increment = (intptr_t)newaddr - (intptr_t)oldaddr;
    if (growheap(increment) < 0) {
        return -1;
    }
    return newaddr;
}
```

系统调用 `brk` 是 Unix 和类 Unix 系统中用于改变数据段（也称为 BSS 段）的大小的函数。它属于内存管理相关的系统调用，用于控制进程的堆（heap）的大小。

### 函数原型

在 C 语言中，`brk` 的函数原型通常如下：

```c
int brk(void *end);
```

### 参数

- `end`：一个指针，指向进程数据段的新的结束地址。

### 描述

`brk` 函数设置进程数据段的新的结束地址。如果新的结束地址比当前结束地址要大，那么在两个地址之间的内存区域将被分配给堆，这会增大堆的大小。相反，如果新的结束地址比当前结束地址要小，那么堆的大小将减小。

### 使用场景

`brk` 通常由低级内存分配函数（如 `malloc` 的底层实现）使用，以动态地增加或减少进程的堆空间。程序员通常不会直接调用 `brk`，而是使用更高级别的内存分配函数。

### 注意事项

- `brk` 只能用于改变堆的大小，不能用于栈。
- 使用 `brk` 时需要小心，因为它可能会影响内存分配器的状态，不当使用可能导致内存泄漏或其他问题。

### 示例

```c
#include <sys/types.h>
#include <unistd.h>

int main() {
    // 设置堆的新的结束地址为当前结束地址加 1000 字节
    if (brk((void *)(sbrk(0) + 1000)) == -1) {
        perror("brk: cannot allocate memory");
        return 1;
    }
    return 0;
}
```

在上面的示例中，我们首先使用 `sbrk(0)` 获取当前堆的结束地址，然后尝试通过 `brk` 增加 1000 字节的堆空间。

### 与其他内存管理函数的关系

- `sbrk`：与 `brk` 类似，`sbrk` 也用于改变堆的大小，但是它通过指定要改变的字节数而不是新的结束地址。
- `malloc` / `free`：更高级的内存分配函数，通常内部使用 `brk` 或 `sbrk` 来管理内存。

`brk` 和 `sbrk` 是较底层的内存管理工具，现代操作系统和编程语言通常提供了更高级的内存管理机制。



## chdir

- 代码位置：src/kernel/sysfile.c

- 代码

```C
uint64 sys_chdir(void) {
    char path[MAXPATH];
    struct inode *ip;
    struct proc *p = proc_current();
    if (argstr(0, path, MAXPATH) < 0 || (ip = namei(path)) == 0) {
        return -1;
    }
    ip->i_op->ilock(ip);
    if (!S_ISDIR(ip->i_mode)) {
        ip->i_op->iunlock_put(ip);
        return -1;
    }
    ip->i_op->iunlock(ip);
    p->cwd = ip;
    return 0;
}
```

系统调用 `chdir`（change directory）在 Unix 和类 Unix 系统中用于改变当前工作目录。工作目录是文件系统中的一个特殊目录，它用作文件路径的起始点，当打开文件或执行命令时，如果没有提供完整路径，就会相对于当前工作目录进行解析。

### 函数原型

在 C 语言中，`chdir` 的函数原型通常如下：

```c
#include <unistd.h>

int chdir(const char *path);
```

### 参数

- `path`：一个指向以 null 结尾的字符数组的指针，指定了要切换到的目录的路径。

### 返回值

- 如果调用成功，`chdir` 返回 0。
- 如果调用失败，返回 -1 并设置 `errno` 以指示错误类型。

### 描述

`chdir` 函数将当前工作目录改变为 `path` 指定的目录。如果 `path` 是相对路径，它将相对于当前工作目录进行解析。如果 `path` 是绝对路径，它将直接指定新的工作目录。

### 使用场景

- 改变程序的当前工作目录，以便能够访问相对于该目录的文件。
- 在执行需要文件路径参数的命令之前，切换到适当的目录。

### 示例

```c
#include <stdio.h>
#include <unistd.h>

int main() {
    if (chdir("/home/user") == -1) {
        perror("chdir failed");
        return 1;
    }
    // 现在当前工作目录已经改变到 "/home/user"
    return 0;
}
```

### 注意事项

- 如果 `path` 指定的目录不存在，或者程序没有权限访问该目录，`chdir` 将失败。
- `chdir` 只影响调用它的进程及其子进程。如果需要改变整个系统的根目录，应使用 `chroot` 系统调用。

### 相关函数

- `getcwd`：获取当前工作目录的路径。
- `chroot`：改变根目录，并可用来创建一个隔离的文件系统环境。

`chdir` 是一个常用的系统调用，它对于文件系统导航和文件操作非常重要。通过改变工作目录，程序可以轻松地在文件系统中移动并执行任务。

## close

- 代码位置：src/kernel/sysfile.c
- 代码
```c
void generic_fileclose(struct file *f) {
    // 语义：自减 f 指向的file的引用次数，如果为0，则关闭
    // 对于管道文件，调用pipeclose
    // 否则，调用iput归还inode节点
    struct file ff;
    acquire(&_ftable.lock);
    if (f->f_count < 1)
        panic("generic_fileclose");
    if (--f->f_count > 0) {
        release(&_ftable.lock);
        return;
    }
    ff = *f;
    f->f_count = 0;
    f->f_type = FD_NONE;
    release(&_ftable.lock);
    if (ff.f_type == FD_PIPE) {
        int wrable = F_WRITEABLE(&ff);
        pipe_close(ff.f_tp.f_pipe, wrable);
    } else if (ff.f_type == FD_INODE || ff.f_type == FD_DEVICE) {
        ff.f_tp.f_inode->i_op->iput(ff.f_tp.f_inode);
    } else if (ff.f_type == FD_SOCKET) {
        free_socket(ff.f_tp.f_sock);
    }
}
uint64 sys_close(void) {
    int fd;
    struct file *f;
    if (argfd(0, &fd, &f) < 0) {
        return -1;
    }
    proc_current()->ofile[fd] = 0;
    generic_fileclose(f);
    return 0;
}
```

系统调用 `close` 在 Unix 和类 Unix 系统中用于关闭一个已经打开的文件描述符（file descriptor）。文件描述符是操作系统用于标识打开文件的整数，每个进程都有一组文件描述符，它们通常用于文件 I/O 操作。

### 函数原型

在 C 语言中，`close` 的函数原型通常如下：

```c
#include <unistd.h>

int close(int fd);
```

### 参数

- `fd`：一个整数值，表示要关闭的文件描述符。

### 返回值

- 如果调用成功，`close` 返回 0。
- 如果调用失败，返回 -1 并设置 `errno` 以指示错误类型。

### 描述

`close` 函数关闭与文件描述符 `fd` 相关的文件。一旦文件被关闭，该文件描述符不再与任何文件关联，可以被系统回收并用于后续的文件打开操作。

关闭文件是一个重要的操作，因为它可以：

- 释放系统资源，如文件表项（file table entry）。
- 确保所有挂起的写操作被刷新到磁盘。
- 遵守文件访问权限和锁定规则。

### 使用场景

- 在文件操作完成后，关闭文件以释放资源。
- 在文件传输或管道通信结束后，关闭连接。

### 示例

```c
#include <stdio.h>
#include <unistd.h>

int main() {
    int fd = open("example.txt", O_RDONLY);
    if (fd == -1) {
        perror("open failed");
        return 1;
    }
    // 执行文件操作
    if (close(fd) == -1) {
        perror("close failed");
        return 1;
    }
    return 0;
}
```

### 注意事项

- 确保在不再需要文件描述符时关闭它，以避免文件描述符泄露。
- 对于管道和套接字等特殊文件，`close` 还可能涉及特定的协议级别的关闭操作。
- 默认情况下，标准输入（stdin）、标准输出（stdout）和标准错误（stderr）的文件描述符（0、1、2）通常在程序结束时自动关闭，但在某些情况下，你可能需要手动关闭它们。

### 相关函数

- `open`：打开文件并获取文件描述符。
- `read` / `write`：从文件描述符读取或写入数据。
- `dup` / `dup2`：复制文件描述符。

`close` 是文件 I/O 操作中的基本系统调用，正确管理文件描述符对于编写稳定和高效的系统程序至关重要。


## dup

- 代码位置：src/kernel/sysfile.c
- 代码
```C
uint64 sys_dup(void) {
    struct file *f;
    int fd;
    if (argfd(0, 0, &f) < 0)
        return -1;
    if ((fd = fdalloc(f)) < 0)
        return -EMFILE;
    f->f_op->dup(f);
    return fd;
}
```

系统调用 `dup`（duplicate file descriptor）在 Unix 和类 Unix 系统中用于复制一个已经打开的文件描述符，创建一个新的文件描述符，并且与原文件描述符关联相同的文件。这个调用常用于需要对同一个文件进行多次访问或需要在不同的文件描述符上进行操作的场景。

### 函数原型

在 C 语言中，`dup` 的函数原型通常如下：

```c
#include <unistd.h>

int dup(int fd);
```

### 参数

- `fd`：一个整数值，表示要复制的已打开文件的文件描述符。

### 返回值

- 如果调用成功，`dup` 返回一个新的非负整数文件描述符。
- 如果调用失败，返回 -1 并设置 `errno` 以指示错误类型。

### 描述

`dup` 函数会复制参数 `fd` 指定的文件描述符，返回一个新的文件描述符，这个新的文件描述符是一个高于或等于 0 的最小未使用的文件描述符。新旧文件描述符都引用同一个文件，并且共享文件指针和文件状态标志。

### 使用场景

- 当需要在不同的代码路径中访问同一个文件，但又不希望影响彼此的文件操作时。
- 在需要临时保存一个文件描述符的副本以供后续使用，例如在调用可能会关闭文件描述符的函数之前。

### 示例

```c
#include <stdio.h>
#include <unistd.h>

int main() {
    int fd = open("example.txt", O_RDONLY);
    if (fd == -1) {
        perror("open failed");
        return 1;
    }
    // 复制文件描述符
    int dup_fd = dup(fd);
    if (dup_fd == -1) {
        perror("dup failed");
        return 1;
    }
    // 使用 dup_fd 进行文件操作
    // ...
    // 关闭文件描述符
    close(fd);
    close(dup_fd);
    return 0;
}
```

### 注意事项

- `dup` 返回的文件描述符通常是当前进程中未使用的最小整数。如果你需要特定的文件描述符，可以使用 `dup2` 系统调用。
- 使用 `dup` 创建的文件描述符应该在不再需要时使用 `close` 系统调用关闭，以避免文件描述符泄露。

### 相关函数

- `dup2`：与 `dup` 类似，但允许你指定新的文件描述符。
- `close`：关闭一个文件描述符。
- `open`：打开文件并返回一个文件描述符。

`dup` 是一个有用的系统调用，它提供了一种简单的方式来复制文件描述符，使得在不同的上下文中可以独立地操作同一个文件。





## dup2

- 代码位置：src/kernel/sysfile.c
- 代码
```C
//系统调用是dup2，但是本内核是sys_dup3进行对应
uint64 sys_dup3(void) {
    struct file *f;
    int oldfd, newfd, flags;
    if (argfd(0, &oldfd, &f) < 0) {
        return -1;
    }
    argint(1, &newfd);
    if (newfd < 0 || newfd >= NOFILE) {
        return -1;
    }
    argint(2, &flags);
    newfd = assist_setfd(f, oldfd, newfd);
    return newfd;
}
```
系统调用 `dup2` 在 Unix 和类 Unix 系统中用于复制一个已经打开的文件描述符（file descriptor），并将它关联到另一个指定的文件描述符。与 `dup` 不同的是，`dup2` 允许你指定新的文件描述符，而 `dup` 则返回一个新的最小未使用的文件描述符。

### 函数原型

在 C 语言中，`dup2` 的函数原型通常如下：

```c
#include <unistd.h>

int dup2(int fd, int fd2);
```

### 参数

- `fd`：一个整数值，表示要复制的已打开文件的原始文件描述符。
- `fd2`：一个整数值，指定新的文件描述符，`dup2` 会尝试将原始文件描述符 `fd` 复制到这个文件描述符上。

### 返回值

- 如果调用成功，`dup2` 返回新的文件描述符（即 `fd2`）。
- 如果调用失败，返回 -1 并设置 `errno` 以指示错误类型。

### 描述

`dup2` 函数关闭（如果需要的话）并复制文件描述符 `fd` 到 `fd2`。之后，`fd2` 将引用与 `fd` 相同的文件，并且它们的文件指针和文件状态标志是共享的。如果 `fd2` 已经打开，它会被关闭。

### 使用场景

- 当你想要将一个文件描述符重定向到一个特定的文件描述符上时，例如重定向标准输入、输出或错误流。
- 在需要覆盖一个已经打开的文件描述符时。

### 示例

```c
#include <stdio.h>
#include <unistd.h>

int main() {
    int fd = open("example.txt", O_RDONLY);
    if (fd == -1) {
        perror("open failed");
        return 1;
    }
    // 将文件描述符 3 指向 example.txt
    if (dup2(fd, 3) == -1) {
        perror("dup2 failed");
        return 1;
    }
    // 现在可以通过文件描述符 3 读取 example.txt
    // ...
    // 关闭原始文件描述符 fd
    close(fd);
    // 文件描述符 3 仍然打开，并且指向 example.txt
    return 0;
}
```

### 注意事项

- 如果 `fd2` 已经打开，`dup2` 会关闭它，这意味着你不应该使用 `dup2` 来复制文件描述符，除非你想要覆盖现有的文件描述符。
- `dup2` 通常用于重定向标准 I/O 流，例如，你可以将一个文件的描述符复制到标准输出（文件描述符 1）。

### 相关函数

- `dup`：复制文件描述符，返回一个新的文件描述符。
- `close`：关闭一个文件描述符。
- `open`：打开文件并返回一个文件描述符。

`dup2` 是一个重要的系统调用，它在需要重定向文件描述符或在不同的文件描述符之间共享文件访问时非常有用。


## execve
- 代码位置：src/kernel/sysproc.c
- 代码
```C
uint64 sys_execve(void) {
    struct binprm bprm;
    memset(&bprm, 0, sizeof(struct binprm));
    char path[MAXPATH];
    vaddr_t uargv, uenvp;
    paddr_t argv, envp;
    vaddr_t temp;
    if (argstr(0, path, MAXPATH) < 0) {
        return -1;
    }
    sigmask_limit = 0;
    argaddr(1, &uargv);
    argaddr(2, &uenvp);
    if (uargv == 0) {
        argv = 0;
    } else {
        int i;
        for (i = 0;; i++) {
            if (i >= MAXARG) {
                return -1;
            }
            if (fetchaddr(uargv + sizeof(vaddr_t) * i, (vaddr_t *)&temp) < 0) {
                return -1;
            }
            if (temp == 0) {
                bprm.argc = i;
                break;
            }
            paddr_t cp;
            if ((cp = getphyaddr(proc_current()->mm->pagetable, temp)) == 0 || strlen((const char *)cp) > PGSIZE) {
                return -1;
            }
            if (i == 5 && strcmp((char *)cp, "lat_sig") == 0) {
                return -1;
            }
            if (i == 1 && strcmp((char *)cp, "bw_pipe") == 0) {
                return -1;
            }
        }
        argv = getphyaddr(proc_current()->mm->pagetable, uargv);
    }
    bprm.argv = (char **)argv;

    if (uenvp == 0) {
        envp = 0;
    } else {
        /* check if the envp parameters is legal */
        for (int i = 0;; i++) {
            if (i >= MAXENV) {
                return -1;
            }
            if (fetchaddr(uenvp + sizeof(vaddr_t) * i, (vaddr_t *)&temp) < 0) {
                return -1;
            }
            if (temp == 0) {
                bprm.envpc = i;
                break;
            }
            vaddr_t cp;
            if ((cp = getphyaddr(proc_current()->mm->pagetable, temp)) == 0 || strlen((const char *)cp) > PGSIZE) {
                return -1;
            }
        }

        envp = getphyaddr(proc_current()->mm->pagetable, uenvp);
    }
    bprm.envp = (char **)envp;

    int len = strlen(path);
    if (strncmp(path + len - 3, ".sh", 3) == 0) {
        // a rough hanler for sh interpreter
        char *sh_argv[10] = {"/busybox/busybox", "sh", path};
        for (int i = 1; i < bprm.argc; i++) {
            sh_argv[i + 2] = (char *)getphyaddr(proc_current()->mm->pagetable, (vaddr_t)((char **)argv)[i]);
        }
        bprm.sh = 1;
        bprm.argv = sh_argv;
        return do_execve("/busybox", &bprm);
    }
    int ret = do_execve(path, &bprm);

    extern char *lmpath[];
    if (strcmp(path, lmpath[0]) == 0 || strcmp(path, lmpath[1]) == 0) {
        return 0;
    } else {
        return ret;
    }
}
```

系统调用 `execve` 在 Unix 和类 Unix 系统中用于执行一个全新的程序。`execve` 不仅替换当前进程的地址空间，还会替换当前进程的执行内容，使得进程开始执行新的程序。

### 函数原型

在 C 语言中，`execve` 的函数原型通常如下：

```c
#include <unistd.h>

int execve(const char *path, char *const argv[], char *const envp[]);
```

### 参数

- `path`：一个字符串，指定了可执行文件的路径。
- `argv`：一个字符串数组，包含了传递给新程序的命令行参数。通常，`argv[0]` 是新程序的名称，`argv[1]` 到 `argv[n-1]` 是传递给程序的参数，`argv[n]` 必须是一个空指针。
- `envp`：一个字符串数组，包含了传递给新程序的环境变量。每个元素都是一个字符串，格式为 `"VARIABLE=VALUE"`，最后一个元素必须是空指针。

### 返回值

- `execve` 调用成功后不会返回，因为当前进程的执行上下文已经被新程序所替换。
- 如果调用失败，它将返回 -1 并设置 `errno` 以指示错误类型。

### 描述

`execve` 执行时，首先会检查 `path` 指定的文件是否存在，并且是否具有执行权限。如果文件检查通过，`execve` 会加载该文件到当前进程的地址空间中，并开始执行该文件的代码。在 `execve` 成功执行后，当前进程的执行流将转移到新程序的入口点。

### 使用场景

- 在 shell 或脚本中，当你需要启动一个新的程序或命令时。
- 在程序中，当你需要根据用户输入或其他条件动态地加载并执行不同的程序时。

### 示例

```c
#include <stdio.h>
#include <unistd.h>

int main() {
    char *argv[] = { "ls", "-l", "/tmp", NULL };
    char *envp[] = { "PATH=/usr/bin", "HOME=/home/user", NULL };
    if (execve("/bin/ls", argv, envp) == -1) {
        perror("execve failed");
        return 1;
    }
    return 0; // 这行代码永远不会执行，除非 execve 调用失败
}
```

### 注意事项

- 一旦 `execve` 成功，当前进程的代码、数据和堆栈都会被新程序所替换，因此 `execve` 调用之后不会有任何返回值。
- 如果你需要在程序中多次执行新程序，应该在每次调用 `execve` 之前保存和恢复进程的状态。
- `execve` 是一个原子操作，如果调用失败，当前进程的状态不会被改变。

### 相关函数

- `execv`：`execve` 的一个变体，它使用一个参数数组而不是指针数组。
- `execle`、`execlp`：`execve` 的变体，它们允许你在不指定环境变量的情况下执行程序。

`execve` 是一个强大的系统调用，它使得进程能够完全改变其执行的程序，这在脚本解释器和系统工具中非常有用。



## exit
- 代码位置：src/kernel/sysproc.c
- 代码
```C
uint64 sys_exit(void) {
    int n;
    argint(0, &n);
    do_exit(n);
    return 0;
}
```
系统调用 `exit` 在 Unix 和类 Unix 系统中用于终止当前运行的进程。当一个进程调用 `exit` 时，它将停止执行，释放它所占用的资源，并返回一个退出状态码给其父进程。

### 函数原型

在 C 语言中，`exit` 的函数原型通常如下：

```c
#include <stdlib.h>

void exit(int status);
```

### 参数

- `status`：一个整数值，表示进程的退出状态。这个状态码可以被父进程捕获，通常用于指示程序是否成功完成，或者在发生错误时提供错误代码。

### 返回值

`exit` 函数不会返回。一旦调用，当前进程将终止。

### 描述

当 `exit` 被调用时，操作系统会执行以下操作：

1. 调用所有注册的终止函数（如通过 `atexit` 注册的函数）。
2. 关闭所有打开的文件描述符，并执行任何必要的清理工作。
3. 释放分配的内存和其他资源。
4. 将退出状态码返回给父进程。

如果 `exit` 被调用时没有提供退出状态码，通常默认状态码为 0。

### 使用场景

- 在程序正常结束时，表明程序成功执行。
- 在捕获到错误或异常情况时，提前终止程序并返回非零状态码，指示发生了错误。

### 示例

```c
#include <stdio.h>
#include <stdlib.h>

int main() {
    // 执行程序逻辑...
    if (error_condition) {
        fprintf(stderr, "Error occurred, exiting with status 1.\n");
        exit(1); // 非零状态码表示发生了错误
    }
    exit(0); // 零状态码表示成功结束
}
```

### 注意事项

- 一旦 `exit` 被调用，进程的执行将立即停止，所有未保存的数据将丢失。
- `exit` 应该谨慎使用，确保在退出前已经完成了所有必要的清理工作。
- 在多线程程序中，调用 `exit` 将终止整个进程，包括所有其他线程。

### 相关函数

- `atexit`：注册一个函数，该函数将在程序退出时被调用。
- `_exit`：一个与 `exit` 类似的函数，但它不会调用注册的终止函数，也不会调用 `SIGTERM` 处理程序，它立即终止进程。

`exit` 是程序控制流程中的一个重要部分，它允许程序在完成其任务或在发生错误时优雅地退出。


## fork,
- 代码位置：src/kernel/sysproc.c
- 代码
```C
//fork是通过调用clone实现的
sys_clone(void) {
    int flags;
    uint64 stack;
    uint64 ptid_addr;
    uint64 tls_addr;
    uint64 ctid_addr;
    argint(0, &flags);
    argaddr(1, &stack);
    argaddr(2, &ptid_addr);
    argaddr(3, &tls_addr);
    argaddr(4, &ctid_addr);
    return do_clone(flags, stack, ptid_addr, tls_addr, ctid_addr);
}
```

系统调用 `fork` 在 Unix 和类 Unix 系统中用于创建一个与当前进程（也称为父进程）几乎完全相同的新进程，这个新进程称为子进程。`fork` 调用非常有用，因为它生成了一个与父进程有着相同地址空间、打开文件和环境的进程，这使得进程间通信和执行相同程序的多个副本变得容易。

### 函数原型

在 C 语言中，`fork` 的函数原型通常如下：

```c
#include <unistd.h>

pid_t fork(void);
```

### 返回值

- 在父进程中，`fork` 返回新创建子进程的进程标识符（PID）。
- 在子进程中，`fork` 返回 0。
- 如果调用失败，`fork` 返回 -1 并设置 `errno` 以指示错误类型。

### 描述

当一个进程调用 `fork` 时，操作系统会执行以下操作：

1. 创建一个新的进程控制块（PCB）。
2. 复制父进程的地址空间到子进程，包括代码段、数据段和堆栈。
3. 为子进程分配一个唯一的进程标识符。
4. 返回两次：一次在父进程中，带有子进程的 PID；一次在子进程中，返回 0。

### 使用场景

- 在需要并行执行任务时创建多个进程。
- 实现进程间通信，例如管道或信号。
- 创建一个新进程来执行一个独立的任务，而不影响父进程。

### 示例

```c
#include <stdio.h>
#include <unistd.h>

int main() {
    pid_t pid = fork();
    if (pid == -1) {
        // fork failed
        perror("fork failed");
        return 1;
    } else if (pid == 0) {
        // child process
        printf("I am the child process with PID: %d\n", getpid());
    } else {
        // parent process
        printf("I am the parent process with PID: %d, and my child has PID: %d\n", getpid(), pid);
    }
    return 0;
}
```

### 注意事项

- `fork` 调用后，父进程和子进程将继续执行 `fork` 之后的代码，这可能导致它们执行相同的操作，除非采取一些措施来区分它们（例如使用返回值）。
- 子进程通常会修改其行为，例如通过调用 `exec` 系列函数来加载一个新的程序。
- 父进程通常负责监控子进程的状态，例如等待子进程结束或收集它们的退出状态。

### 相关函数

- `wait` 或 `waitpid`：等待子进程结束。
- `execve`、`execv`、`execle`、`execl`：执行一个新程序，常用于子进程中，以替换当前程序。
- `exit`：终止进程。

`fork` 是 Unix 和类 Unix 系统中进程控制的基础，它允许程序员编写能够利用多核处理器并行能力的程序。


## fstat
- 代码位置：src/kernel/sysfile.c
- 代码
```C
uint64 sys_fstat(void) {
    struct file *f;
    uint64 st;
    argaddr(1, &st);
    if (argfd(0, 0, &f) < 0)
        return -1;
    return f->f_op->fstat(f, st);
}
```
系统调用 `fstat` 在 Unix 和类 Unix 系统中用于获取打开文件的状态信息。它类似于 `stat` 系统调用，但 `fstat` 操作的是已经通过文件描述符打开的文件，而 `stat` 操作的是指定路径的文件。

### 函数原型

在 C 语言中，`fstat` 的函数原型通常如下：

```c
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

int fstat(int fd, struct stat *buf);
```

### 参数

- `fd`：一个整数值，表示已打开文件的文件描述符。
- `buf`：指向 `stat` 结构体的指针，该结构体用于接收文件的状态信息。

### 返回值

- 如果调用成功，`fstat` 返回 0。
- 如果调用失败，返回 -1 并设置 `errno` 以指示错误类型。

### 描述

`fstat` 函数填充了 `buf` 指针指向的 `stat` 结构体，提供了关于文件的详细信息，包括文件的类型、大小、权限、创建和修改时间等。

### 使用场景

- 获取已打开文件的详细信息，比如在文件操作过程中需要了解文件的具体属性。
- 在打开文件后，确定文件的类型或权限，以进行后续操作。

### 示例

```c
#include <stdio.h>
#include <unistd.h>
#include <sys/stat.h>

int main() {
    int fd = open("example.txt", O_RDONLY);
    if (fd == -1) {
        perror("open failed");
        return 1;
    }

    struct stat file_stats;
    if (fstat(fd, &file_stats) == -1) {
        perror("fstat failed");
        return 1;
    }

    printf("File size: %ld\n", file_stats.st_size);
    printf("File type: ");
    switch (file_stats.st_mode & S_IFMT) {
        case S_IFREG: printf("Regular file\n"); break;
        case S_IFDIR: printf("Directory\n"); break;
        // ... other cases
        default: printf("Unknown type\n");
    }

    close(fd);
    return 0;
}
```

### 注意事项

- `fstat` 只能用于已经打开的文件描述符。
- `fstat` 不会跟随符号链接，如果 `fd` 是对符号链接打开的，那么 `fstat` 会获取符号链接的信息，而不是链接指向的文件的信息。

### 相关函数

- `stat`：获取指定路径文件的状态信息。
- `lstat`：类似于 `stat`，但会获取符号链接本身的信息，而不是它指向的文件的信息。
- `close`：关闭一个文件描述符。

`fstat` 是一个有用的系统调用，它允许程序在不改变当前工作目录或使用文件路径的情况下获取文件的详细信息。



## getcwd
- 代码位置：src/kernel/sysfile.c
- 代码
```C
uint64 sys_getcwd(void) {
    uint64 buf;
    size_t size;
    struct proc *p = proc_current();
    argaddr(0, &buf);
    argulong(1, &size);
    char kbuf[MAXPATH];
    assist_getcwd(kbuf);
    if (!buf && (buf = (uint64)kalloc()) == 0) {
        return (uint64)NULL;
    }
    if (copyout(p->mm->pagetable, buf, kbuf, strnlen(kbuf, MAXPATH) + 1) < 0) {
        return (uint64)NULL;
    } else {
        return buf;
    }
}
```
系统调用 `getcwd` 在 Unix 和类 Unix 系统中用于获取当前工作目录（current working directory）的路径。工作目录是文件系统中的起点，用于解析相对路径。

### 函数原型

在 C 语言中，`getcwd` 的函数原型通常如下：

```c
#include <unistd.h>

char *getcwd(char *buf, size_t size);
```

### 参数

- `buf`：一个字符数组的指针，用于存储当前工作目录的路径。如果传入 `NULL`，`getcwd` 将分配一个足够大的缓冲区。
- `size`：一个 `size_t` 类型的值，指定 `buf`（如果 `buf` 不是 `NULL`）的大小。如果传入 0，`getcwd` 将返回所需的缓冲区大小（不包括空字符）。

### 返回值

- 如果调用成功，`getcwd` 返回一个指向包含当前工作目录路径的字符串的指针。
- 如果调用失败，返回 `NULL` 并设置 `errno` 以指示错误类型。

### 描述

`getcwd` 函数将当前工作目录的完整路径复制到 `buf` 指向的缓冲区中。如果 `buf` 是 `NULL`，`getcwd` 会使用 `malloc` 分配一个缓冲区，调用者需要在适当的时候使用 `free` 释放这个缓冲区。

### 使用场景

- 获取当前工作目录的完整路径，以便进行文件系统操作或改变工作目录。
- 在程序开始时记录当前的工作目录，以便后续操作可以相对于这个目录进行。

### 示例

```c
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>

int main() {
    char *cwd = getcwd(NULL, 0);
    if (cwd == NULL) {
        perror("getcwd failed");
        return 1;
    }

    printf("Current working directory: %s\n", cwd);

    free(cwd); // 如果使用了 NULL 指针，需要释放内存
    return 0;
}
```

### 注意事项

- 如果 `buf` 不是 `NULL`，你必须确保它有足够的空间来存储完整的路径。如果空间不足，`getcwd` 会失败并设置 `errno` 为 `ERANGE`。
- 使用 `getcwd(NULL, 0)` 可以安全地获取工作目录的路径长度，然后你可以分配适当大小的缓冲区再次调用 `getcwd`。

### 相关函数

- `chdir`：改变当前工作目录。
- `pwd`：在某些系统中，`pwd` 命令调用 `getcwd` 来显示当前工作目录。

`getcwd` 是一个基本的系统调用，它在文件操作和目录管理中非常有用，特别是当你需要知道当前位置以便进行相对路径解析时。


## getdents
- 代码位置：src/kernel/sysfile.c
- 代码
```C
#define END_DIR -1
uint64 sys_getdents64(void) {
    struct file *f;
    uint64 buf;
    int len;
    ssize_t nread, sz;
    char *kbuf;
    struct inode *ip;
    if (argfd(0, 0, &f) < 0) {
        return -1;
    }
    if (f->f_type != FD_INODE) {
        return -1;
    }
    ip = f->f_tp.f_inode;
    ASSERT(ip);
    ip->i_op->ilock(ip);
    if (!S_ISDIR(ip->i_mode)) {
        goto bad_ret;
    }
    if (f->f_pos == END_DIR) {
        ip->i_op->iunlock(ip);
        return 0;
    }
    ip->i_op->iunlock(ip);
    argaddr(1, &buf);
    argint(2, &len);
    if (len < 0) {
        goto bad_ret;
    }
    sz = len;
    if ((kbuf = kzalloc(sz)) == 0) {
        goto bad_ret;
    }
    if ((nread = f->f_op->readdir(ip, (char *)kbuf, 0, sz)) < 0) {
        kfree(kbuf);
        goto bad_ret;
    }

    if (either_copyout(1, buf, kbuf, nread) < 0) {
        kfree(kbuf);
        goto bad_ret;
    }
    kfree(kbuf);

    f->f_pos = END_DIR;
    return nread;
bad_ret:
    return -1;
}
```
系统调用 `getdents` 在 Unix 和类 Unix 系统中用于读取目录项的信息。它用于获取一个打开目录流中的一个或多个目录项。

### 函数原型

在 C 语言中，`getdents` 的函数原型通常如下：

```c
#include <sys/types.h>
#include <dirent.h>
#include <unistd.h>

struct dirent *getdents(int fd, struct dirent *buf, size_t nbytes);
```

### 参数

- `fd`：一个整数值，表示已打开目录的文件描述符。
- `buf`：一个指向 `struct dirent` 的指针，该结构用于接收读取到的目录项信息。
- `nbytes`：一个 `size_t` 类型的值，指定 `buf` 的大小。

### 返回值

- 如果调用成功，`getdents` 返回一个指向 `struct dirent` 的指针，该结构包含了读取到的目录项的信息。
- 如果到达目录流的末尾，返回 `NULL`。
- 如果调用失败，返回 `NULL` 并设置 `errno` 以指示错误类型。

### 描述

`getdents` 函数从文件描述符 `fd` 指向的目录中读取一个或多个目录项，并将它们存储在 `buf` 指向的缓冲区中。每个目录项都包含了文件名、文件类型等信息，这些信息被封装在 `struct dirent` 中。

### 使用场景

- 列出一个目录下的所有文件和子目录。
- 遍历目录内容，进行文件系统导航。

### 示例

```c
#include <stdio.h>
#include <unistd.h>
#include <dirent.h>
#include <stdlib.h>

int main() {
    int fd;
    struct dirent *dirent;
    struct dirent *buf;
    char *dirname = "."; // 也可以是其他目录路径

    fd = open(dirname, O_RDONLY | O_DIRECTORY);
    if (fd == -1) {
        perror("open directory failed");
        return EXIT_FAILURE;
    }

    buf = (struct dirent *)malloc(sizeof(struct dirent) + 256);
    if (!buf) {
        perror("malloc failed");
        return EXIT_FAILURE;
    }

    while ((dirent = getdents(fd, buf, sizeof(struct dirent) + 256)) != NULL) {
        printf("%s\n", dirent->d_name);
    }
    close(fd);
    free(buf);
    return EXIT_SUCCESS;
}
```

### 注意事项

- `getdents` 通常用于底层的文件系统操作，而用户级程序通常使用更高级别的库函数，如 `opendir`、`readdir` 和 `closedir`。
- 读取操作是增量进行的，可能需要多次调用 `getdents` 才能读取完所有目录项。

### 相关函数

- `opendir`：打开一个目录流。
- `readdir`：从目录流中读取一个目录项。
- `closedir`：关闭一个目录流。

`getdents` 是一个底层系统调用，它为文件系统导航和目录内容遍历提供了基础支持。


## getpid
- 代码位置：src/kernel/sysproc.c
- 代码
```C
uint64 sys_getpid(void) {
    return proc_current()->pid;
}
```
系统调用 `getpid` 在 Unix 和类 Unix 系统中用于获取当前进程的进程标识符（Process Identifier，PID）。每个运行中的进程都有一个唯一的 PID，用于区分不同的进程。

### 函数原型

在 C 语言中，`getpid` 的函数原型通常如下：

```c
#include <unistd.h>

pid_t getpid(void);
```

### 参数

`getpid` 函数不接受任何参数。

### 返回值

- 返回当前进程的 PID。
- 如果调用失败，返回 -1 并设置 `errno` 以指示错误类型。

### 描述

`getpid` 函数简单地返回调用它的进程的 PID。这个 PID 可以用于各种目的，包括但不限于：

- 在 shell 命令中标识进程。
- 在进程间通信（IPC）中标识消息的发送者。
- 在调试或监控工具中跟踪进程。

### 使用场景

- 在多进程应用程序中，跟踪和标识不同的进程。
- 在需要知道当前进程的 PID 时，比如在日志记录、错误报告或调试信息中。

### 示例

```c
#include <stdio.h>
#include <unistd.h>

int main() {
    pid_t pid = getpid();
    printf("The process ID is: %ld\n", pid);
    return 0;
}
```

### 注意事项

- `getpid` 是一个快速的系统调用，因为它只返回一个存储在进程控制块（PCB）中的值。
- `getpid` 不会失败，除非实现中存在严重错误，通常它的返回值总是有效的 PID。

### 相关函数

- `getppid`：获取当前进程的父进程的 PID。
- `getuid`：获取当前进程的用户标识符（User Identifier）。
- `getgid`：获取当前进程的组标识符（Group Identifier）。

`getpid` 是一个基本的系统调用，它为进程管理、监控和调试提供了关键的信息。


## getppid,
- 代码位置：src/kernel/sysproc.c
- 代码
```C
uint64 sys_getppid(void) {
    uint64 ppid = proc_current()->parent->pid;
    return ppid;
}
```
系统调用 `getppid` 在 Unix 和类 Unix 系统中用于获取当前进程的父进程标识符（Process Identifier，PID）。父进程是创建当前进程的进程。

### 函数原型

在 C 语言中，`getppid` 的函数原型通常如下：

```c
#include <unistd.h>

pid_t getppid(void);
```

### 参数

`getppid` 函数不接受任何参数。

### 返回值

- 返回当前进程的父进程的 PID。
- 如果调用失败，返回 -1 并设置 `errno` 以指示错误类型。

### 描述

`getppid` 函数简单地返回调用它的进程的父进程的 PID。这个 PID 可以用于多种场景，包括：

- 跟踪进程的家族树。
- 在调试或监控工具中确定进程的起源。
- 实现某些类型的进程管理或调度策略。

### 使用场景

- 在需要知道当前进程的父进程 PID 时，比如在系统管理脚本或程序中。
- 在调试或分析程序的执行流程时。

### 示例

```c
#include <stdio.h>
#include <unistd.h>

int main() {
    pid_t ppid = getppid();
    printf("The parent process ID is: %ld\n", ppid);
    return 0;
}
```

### 注意事项

- `getppid` 是一个快速的系统调用，因为它只返回一个存储在进程控制块（PCB）中的值。
- `getppid` 通常不会失败，除非实现中存在严重错误。

### 相关函数

- `getpid`：获取当前进程的 PID。
- `getuid`：获取当前进程的用户标识符（User Identifier）。
- `getgid`：获取当前进程的组标识符（Group Identifier）。

`getppid` 是一个基本的系统调用，它为进程的监控、调试和管理提供了重要的信息。在需要了解进程间的父子关系时，这个调用特别有用。


## gettimeofday
- 代码位置：src/kernel/sysmisc.c
- 代码
```C
uint64 sys_gettimeofday(void) {
    uint64 addr;
    argaddr(0, &addr);
    uint64 time = rdtime();
    struct timeval tv_buf = TIME2TIMEVAL(time);
    if (copyout(proc_current()->mm->pagetable, addr, (char *)&tv_buf, sizeof(tv_buf)) < 0) {
        return -1;
    }
    return 0;
}
```
系统调用 `gettimeofday` 在 Unix 和类 Unix 系统中用于获取当前的时间。它提供了一种方法来获取系统的时间，包括当前的日期和时间。

### 函数原型

在 C 语言中，`gettimeofday` 的函数原型通常如下：

```c
#include <sys/time.h>

int gettimeofday(struct timeval *tv, struct timezone *tz);
```

### 参数

- `tv`：一个指向 `struct timeval` 的指针，该结构用于接收当前时间的时间值。如果 `tv` 是 `NULL`，则不返回时间。
- `tz`：一个指向 `struct timezone` 的指针，该结构用于接收有关当前时区的信息。如果 `tz` 是 `NULL`，则不返回时区信息。

### 返回值

- 如果调用成功，`gettimeofday` 返回 0。
- 如果调用失败，返回 -1 并设置 `errno` 以指示错误类型。

### 描述

`gettimeofday` 函数填充了 `tv` 和 `tz` 指向的结构体，提供了以下信息：

- `tv`：包含当前时间的时间值，通常包括秒和微秒。
- `tz`：包含时区信息，包括时区的偏移量。

### 使用场景

- 获取当前的日期和时间，用于日志记录、性能测量或其他需要时间戳的应用。

### 示例

```c
#include <stdio.h>
#include <sys/time.h>

int main() {
    struct timeval tv;
    if (gettimeofday(&tv, NULL) == -1) {
        perror("gettimeofday failed");
        return 1;
    }

    printf("Current time: %ld seconds and %ld microseconds\n", tv.tv_sec, tv.tv_usec);
    return 0;
}
```

### 注意事项

- `gettimeofday` 可能受到系统时间源的影响，不同的系统可能有不同的实现和精度。
- 在某些系统中，`gettimeofday` 调用可能被废弃，推荐使用 `clock_gettime`，这是一个更通用和灵活的时间获取接口。

### 相关函数

- `clock_gettime`：提供更精确的时间获取功能，包括对不同时钟的访问。
- `time`：获取自 Unix 纪元以来的秒数。

`gettimeofday` 是一个基本的系统调用，它允许程序获取当前的日期和时间，这对于需要时间信息的应用程序非常有用。


## mkdir,
- 代码位置：src/kernel/sysfile.c
- 代码
```C
//mkdir调用通过sys_mkdirat函数支持
uint64 sys_mkdirat(void) {
    char path[MAXPATH];
    int dirfd;
    mode_t mode;
    struct inode *ip;
    argint(0, &dirfd);
    if (argint(2, (int *)&mode) < 0) {
        return -1;
    }
    if (argstr(1, path, MAXPATH) < 0) {
        return -1;
    }
    if ((ip = assist_icreate(path, AT_FDCWD, S_IFDIR, 0, 0)) == 0) {
        return -1;
    }
    ip->i_op->iunlock_put(ip);
    return 0;
}
```
系统调用 `mkdir` 在 Unix 和类 Unix 系统中用于创建一个新的目录。这个调用为用户和程序提供了一种在文件系统中组织文件的方式。

### 函数原型

在 C 语言中，`mkdir` 的函数原型通常如下：

```c
#include <sys/stat.h>

int mkdir(const char *path, mode_t mode);
```

### 参数

- `path`：一个字符串，指定了要创建的目录的路径。它可以是绝对路径或相对路径。
- `mode`：一个模式位掩码，用于设置目录的访问权限。这个掩码通常由文件权限宏（如 `S_IRWXU`、`S_IRWXG` 等）组合而成。

### 返回值

- 如果调用成功，`mkdir` 返回 0。
- 如果调用失败，返回 -1 并设置 `errno` 以指示错误类型。

### 描述

`mkdir` 函数尝试在文件系统中创建一个名为 `path` 的新目录。如果 `path` 指定的位置已经存在一个同名的目录，`mkdir` 将失败，并设置 `errno` 为 `EEXIST`。

### 使用场景

- 在文件系统中创建结构化的层次结构，组织文件。
- 在写入文件之前，确保所需的目录结构已经存在。

### 示例

```c
#include <stdio.h>
#include <sys/stat.h>

int main() {
    if (mkdir("new_directory", 0755) == -1) {
        perror("mkdir failed");
        return 1;
    }
    printf("Directory created successfully.\n");
    return 0;
}
```

### 注意事项

- `mkdir` 只能创建一级目录，即它不能递归创建多级目录结构。
- 在创建目录之前，需要确保其父目录已经存在，除非 `path` 是一个绝对路径，从根目录开始。
- `mode` 参数定义了目录的权限，如果不提供，通常默认为当前进程的 umask 掩码的补码。

### 相关函数

- `rmdir`：删除一个空目录。
- `opendir`：打开一个目录流，用于读取目录内容。
- `stat`：获取文件或目录的状态信息。

`mkdir` 是一个基本的系统调用，它在文件系统操作中非常重要，用于创建和管理目录结构。


## mmap
- 代码位置：src/mm/mmap.c
- 代码
```C
void *sys_mmap(void) {
    vaddr_t addr;
    size_t length;
    int prot;
    int flags;
    int fd;
    off_t offset;
    struct file *fp;
    argaddr(0, &addr);
    argulong(1, &length);
    argint(2, &prot);
    argint(3, &flags);
    if (argfd(4, &fd, &fp) < 0) {
        fp = NULL;
        if ((flags & MAP_ANONYMOUS) == 0) {
            Log("hit");
        }
    }
    arglong(5, &offset);
    if (offset != 0) {
        Warn("mmap: not support");
        return MAP_FAILED;
    }
    struct mm_struct *m = proc_current()->mm;
    acquire(&m->lock);
    void *retval = do_mmap(addr, length, prot, flags, fp, offset);
    release(&m->lock);
    return retval;
}
```
系统调用 `mmap` 在 Unix 和类 Unix 系统中用于将文件或其他对象映射到内存中。这个调用允许应用程序创建一个内存映射，它可以用于实现文件的懒加载、共享内存、内存映射的 I/O 操作等。

### 函数原型

在 C 语言中，`mmap` 的函数原型通常如下：

```c
#include <sys/mman.h>

void *mmap(void *addr, size_t length, int prot, int flags, int fd, off_t offset);
```

### 参数

- `addr`：映射区域的起始地址。通常设置为 `NULL`，让系统选择映射区域的地址。
- `length`：映射区域的长度。
- `prot`：映射区域的保护方式，可以是 `PROT_EXEC`（可执行）、`PROT_READ`（可读）、`PROT_WRITE`（可写）和 `PROT_NONE`（不可访问）的组合。
- `flags`：控制映射区域的特性，如 `MAP_SHARED`（对映射区域的修改会反映到文件上）、`MAP_PRIVATE`（私有的 copy-on-write 映射）等。
- `fd`：被映射文件的文件描述符。
- `offset`：在文件中的偏移量，通常为文件大小的整数倍。

### 返回值

- 如果调用成功，`mmap` 返回指向映射区域的指针。
- 如果调用失败，返回 `MAP_FAILED`（通常是 `(void *)-1`）并设置 `errno` 以指示错误类型。

### 描述

`mmap` 函数为以下用途提供了一种有效的方法：

- 实现文件的懒加载：程序可以访问一个比物理内存大得多的文件，而不需要一次性将整个文件加载到内存中。
- 共享内存：通过 `MAP_SHARED` 标志，多个进程可以共享同一块内存区域，这在进程间通信（IPC）中非常有用。
- 内存映射的 I/O：通过内存映射进行文件 I/O 可以提高性能，因为操作系统可以优化磁盘和内存之间的数据传输。

### 使用场景

- 读取大型文件，但只需要处理文件的一部分。
- 实现进程间的内存共享。
- 创建或修改文件时，避免不必要的数据复制。

### 示例

```c
#include <stdio.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

int main() {
    int fd, status;
    char *map;

    fd = open("example.txt", O_RDWR);
    if (fd == -1) {
        perror("open failed");
        return 1;
    }

    map = mmap(NULL, 128, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (map == MAP_FAILED) {
        perror("mmap failed");
        return 1;
    }

    // 执行文件操作
    // ...

    status = munmap(map, 128); // 释放映射区域
    if (status == -1) {
        perror("munmap failed");
        return 1;
    }

    close(fd);
    return 0;
}
```

### 注意事项

- 使用 `mmap` 创建的映射应该在不再需要时使用 `munmap` 释放。
- `mmap` 可以用于实现复杂的内存管理策略，但也需要谨慎使用，以避免内存泄漏或映射区域重叠。

### 相关函数

- `munmap`：解除内存映射。
- `msync`：将映射区域的数据同步到文件。
- `mprotect`：改变已映射内存区域的保护。

`mmap` 是一个强大的系统调用，它为文件 I/O 和进程间通信提供了高效的机制。


## munmap
- 代码位置：src/kernel/mmap.c
- 代码
```C
uint64 sys_munmap(void) {
    vaddr_t addr;
    size_t length;
    argaddr(0, &addr);
    argulong(1, &length);
    struct proc *p = proc_current();
    struct tcb *t = thread_current();
    struct vma *v2 = find_vma_for_va(p->mm, addr);
    if ((strcmp(p->name, "entry-dynamic.exe") == 0 || strcmp(p->name, "entry-static.exe") == 0) && t->tidx != 0 && v2->type == VMA_ANON) {
        return 0;
    }
    acquire(&p->mm->lock);
    if (vmspace_unmap(p->mm, addr, length) != 0) {
        release(&p->mm->lock);
        return -1;
    }
    release(&p->mm->lock);
    return 0;
}
```
系统调用 `munmap` 在 Unix 和类 Unix 系统中用于解除之前通过 `mmap` 系统调用建立的内存映射。当一个内存映射不再需要时，`munmap` 允许操作系统回收资源，并可以选择性地将映射区域的更改写回到对应的文件中。

### 函数原型

在 C 语言中，`munmap` 的函数原型通常如下：

```c
#include <sys/mman.h>

int munmap(void *addr, size_t length);
```

### 参数

- `addr`：内存映射的起始地址，这个地址必须是先前通过 `mmap` 返回的地址。
- `length`：内存映射的长度，必须与创建映射时指定的长度一致。

### 返回值

- 如果调用成功，`munmap` 返回 0。
- 如果调用失败，返回 -1 并设置 `errno` 以指示错误类型。

### 描述

`munmap` 函数的作用是通知操作系统，应用程序已经完成了对指定内存映射区域的使用。如果映射是通过 `mmap` 与文件相关联的，并且使用了写权限（例如，通过 `PROT_WRITE`），那么在解除映射之前，操作系统可能会将映射区域的更改同步回文件。

### 使用场景

- 在不再需要内存映射时，释放系统资源。
- 在程序结束前清理，确保所有挂起的更改被写回到文件。

### 示例

```c
#include <sys/mman.h>
#include <stdio.h>
#include <unistd.h>

int main() {
    void *mapped_area = mmap(NULL, sizeof(int), PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (mapped_area == MAP_FAILED) {
        perror("mmap failed");
        return 1;
    }

    // 使用映射区域进行操作
    // ...

    if (munmap(mapped_area, sizeof(int)) == -1) {
        perror("munmap failed");
        return 1;
    }

    return 0;
}
```

### 注意事项

- 必须确保 `munmap` 的 `addr` 和 `length` 参数与 `mmap` 的调用匹配，否则可能会导致未定义的行为。
- 如果映射区域是共享的（使用了 `MAP_SHARED` 标志），那么解除映射不会影响文件，除非所有共享该映射的进程都解除了映射。
- 未写入的私有映射（使用了 `MAP_PRIVATE` 标志）在解除映射时将丢失，不会写回到文件中。

### 相关函数

- `mmap`：创建内存映射。
- `mprotect`：改变内存映射区域的保护。
- `madvise`：为内存映射区域提供建议，影响页面的优化策略。

`munmap` 是内存管理中的一个重要系统调用，它确保了内存资源的有效回收，并且在使用内存映射进行文件 I/O 或进程间通信时，保证了数据的一致性。

## openat
- 代码位置：src/kernel/sysfile.c
- 代码
```C
uint64 sys_openat(void) {
    char path[MAXPATH];
    int dirfd, flags, omode, fd;
    struct inode *ip;
    argint(0, &dirfd);
    if (argstr(1, path, MAXPATH) < 0) {
        return -1;
    }
    argint(2, &flags);
    flags = flags & (~O_LARGEFILE); // bugs!!
    argint(3, &omode);
    if ((flags & O_CREAT) == O_CREAT) {
        if ((ip = assist_icreate(path, dirfd, S_IFREG, 0, 0)) == 0) {
            return -1;
        }
    } else {
        if ((ip = find_inode(path, dirfd, 0)) == 0) {
            return -1;
        }
        ip->i_op->ilock(ip);

        if (((flags & O_DIRECTORY) == O_DIRECTORY) && !S_ISDIR(ip->i_mode)) {
            ip->i_op->iunlock_put(ip);
            return -1;
        }
    }

    if ((S_ISCHR(ip->i_mode) || S_ISBLK(ip->i_mode))
        && (MAJOR(ip->i_rdev) < 0 || MAJOR(ip->i_rdev) >= NDEV)) {
        ip->i_op->iunlock_put(ip);
        return -1;
    }

    fd = assist_openat(ip, flags, omode, 0);
    return fd;
}
```
系统调用 `openat` 在 Unix 和类 Unix 系统中用于在指定目录文件描述符的上下文中打开一个文件。这个调用是 `open` 系统调用的扩展，它允许你打开一个相对于给定目录的文件路径，而不是相对于当前工作目录。

### 函数原型

在 C 语言中，`openat` 的函数原型通常如下：

```c
#include <fcntl.h>
#include <unistd.h>

int openat(int dirfd, const char *pathname, int flags, mode_t mode);
```

### 参数

- `dirfd`：一个文件描述符，表示一个已经打开的目录。
- `pathname`：一个以 null 结尾的字符串，指定了相对于 `dirfd` 目录的文件路径。
- `flags`：控制文件打开方式的标志，如 `O_RDONLY`、`O_WRONLY`、`O_RDWR` 等。
- `mode`：如果创建了新文件，这个参数定义了文件的权限模式。

### 返回值

- 如果调用成功，`openat` 返回一个新的文件描述符。
- 如果调用失败，返回 -1 并设置 `errno` 以指示错误类型。

### 描述

`openat` 函数在 `dirfd` 指定的目录上下文中打开 `pathname` 指定的文件。这允许你避免使用相对路径或需要更改当前工作目录。

### 使用场景

- 当需要在不改变当前工作目录的情况下打开文件时。
- 在处理文件系统时，可以减少对当前工作目录的依赖，使程序更加健壮。

### 示例

```c
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>

int main() {
    int dirfd = open(".", O_RDONLY); // 打开当前目录
    if (dirfd == -1) {
        perror("open failed");
        return 1;
    }

    int fd = openat(dirfd, "example.txt", O_RDONLY, 0644);
    if (fd == -1) {
        perror("openat failed");
        return 1;
    }

    // 使用文件描述符 fd 进行文件操作
    // ...

    close(dirfd); // 关闭目录文件描述符
    close(fd);    // 关闭文件文件描述符
    return 0;
}
```

### 注意事项

- `dirfd` 参数可以是 `AT_FDCWD`，表示当前工作目录。
- `pathname` 参数是一个相对路径，相对于 `dirfd` 指定的目录。
- `openat` 是 `open` 的原子操作版本，它不会涉及到对当前工作目录的改变。

### 相关函数

- `open`：打开一个文件。
- `close`：关闭一个文件描述符。
- `fopen`：在 C 标准库中打开一个文件流（相对于当前工作目录）。

`openat` 是一个有用的系统调用，它提供了一种更加灵活和安全的方式来打开文件，特别是在需要处理相对路径或在不同的目录上下文中工作时。


## open
- 代码位置：src/kernel/sysfile.c
- 代码
```C
//open系统调用是通过sys_openat函数实现
uint64 sys_openat(void) {
    char path[MAXPATH];
    int dirfd, flags, omode, fd;
    struct inode *ip;
    argint(0, &dirfd);
    if (argstr(1, path, MAXPATH) < 0) {
        return -1;
    }
    argint(2, &flags);
    flags = flags & (~O_LARGEFILE); // bugs!!
    argint(3, &omode);
    // 如果是要求创建文件，则调用 create
    if ((flags & O_CREAT) == O_CREAT) {
        if ((ip = assist_icreate(path, dirfd, S_IFREG, 0, 0)) == 0) {
            printf("openat:669\n");
            return -1;
        }
    } else {
        // 否则，我们先调用 find_inode 找到 path 对应的文件 inode 节点
        if ((ip = find_inode(path, dirfd, 0)) == 0) {
            return -1;
        }
        ip->i_op->ilock(ip);
        if (((flags & O_DIRECTORY) == O_DIRECTORY) && !S_ISDIR(ip->i_mode)) {
            ip->i_op->iunlock_put(ip);
            return -1;
        }
    }
    if ((S_ISCHR(ip->i_mode) || S_ISBLK(ip->i_mode))
        && (MAJOR(ip->i_rdev) < 0 || MAJOR(ip->i_rdev) >= NDEV)) {
        ip->i_op->iunlock_put(ip);
        return -1;
    }
    fd = assist_openat(ip, flags, omode, 0);
    return fd;
}
```
系统调用 `open` 在 Unix 和类 Unix 系统中用于打开一个文件，并根据指定的标志（flags）和权限（mode）返回一个文件描述符（file descriptor）。这个文件描述符用于后续的文件操作，如读取、写入和文件属性修改。

### 函数原型

在 C 语言中，`open` 的函数原型通常如下：

```c
#include <fcntl.h>

int open(const char *path, int flags, ... /* mode_t mode */);
```

### 参数

- `path`：一个以 null 结尾的字符串，指定了要打开的文件的路径。
- `flags`：一个或多个标志，用于控制文件打开的行为。常见的标志包括 `O_RDONLY`（只读）、`O_WRONLY`（只写）和 `O_RDWR`（读写）。还可以包括其他标志，如 `O_CREAT`（如果文件不存在则创建）、`O_TRUNC`（截断文件大小为 0）等。
- `mode`（可选）：当 `flags` 包含 `O_CREAT` 时，这个参数指定了创建新文件的权限模式。它是一个模式位掩码，通常由文件权限宏（如 `S_IRUSR`、`S_IWUSR` 等）组合而成。

### 返回值

- 如果调用成功，`open` 返回一个新的文件描述符。
- 如果调用失败，返回 -1 并设置 `errno` 以指示错误类型。

### 描述

`open` 函数尝试打开 `path` 指定的文件，并根据 `flags` 参数指定的方式打开。如果文件成功打开，`open` 返回一个非负的文件描述符，该文件描述符可以用于后续的文件 I/O 操作。

### 使用场景

- 读取或写入文件。
- 创建新文件或修改已存在文件的权限。

### 示例

```c
#include <fcntl.h>
#include <stdio.h>

int main() {
    int fd = open("example.txt", O_RDONLY);
    if (fd == -1) {
        perror("open failed");
        return 1;
    }

    // 使用文件描述符 fd 进行文件操作
    // ...

    close(fd); // 完成操作后关闭文件
    return 0;
}
```

### 注意事项

- 文件描述符通常是一个整数，用于标识一个打开的文件。
- 使用 `open` 返回的文件描述符应该在不再需要时使用 `close` 系统调用关闭。

### 相关函数

- `close`：关闭一个文件描述符。
- `read`：从文件描述符读取数据。
- `write`：向文件描述符写入数据。
- `openat`：在指定目录上下文中打开文件。

`open` 是文件 I/O 的基础系统调用，它为后续的文件操作提供了必要的文件描述符。


## pipe
- 代码位置：src/kernel/sysfile.c
- 代码
```c
// 用于保存2个文件描述符。其中，fd[0]为管道的读出端，fd[1]为管道的写入端。
uint64 sys_pipe2(void) {
    uint64 fdarray; // user pointer to array of two integers
    struct file *rf, *wf;
    int fd0, fd1;
    struct proc *p = proc_current();

    argaddr(0, &fdarray);
    if (pipe_alloc(&rf, &wf) < 0) // 分配两个 pipe 文件
        return -1;
    fd0 = -1;
    if ((fd0 = fdalloc(rf)) < 0 || (fd1 = fdalloc(wf)) < 0) { // 给当前进程分配两个文件描述符，代指那两个管道文件
        if (fd0 >= 0)
            p->ofile[fd0] = 0;
        generic_fileclose(rf);
        generic_fileclose(wf);
        return -EMFILE;
    }
    if (copyout(p->mm->pagetable, fdarray, (char *)&fd0, sizeof(fd0)) < 0
        || copyout(p->mm->pagetable, fdarray + sizeof(fd0), (char *)&fd1, sizeof(fd1)) < 0) {
        p->ofile[fd0] = 0;
        p->ofile[fd1] = 0;
        generic_fileclose(rf);
        generic_fileclose(wf);
        return -1;
    }
    return 0;
}
```
系统调用 `pipe` 在 Unix 和类 Unix 系统中用于创建一个管道（pipe），管道是一种特殊的文件系统对象，用于进程间通信（IPC）。通过管道，一个进程可以向另一个进程发送数据，通常是父子进程之间或相关进程之间的通信。

### 函数原型

在 C 语言中，`pipe` 的函数原型通常如下：

```c
#include <unistd.h>

int pipe(int fd[2]);
```

### 参数

- `fd`：一个整数数组，其大小至少为 2。`pipe` 函数将返回两个文件描述符，分别用于管道的读端和写端。

### 返回值

- 如果调用成功，`pipe` 返回 0。
- 如果调用失败，返回 -1 并设置 `errno` 以指示错误类型。

### 描述

`pipe` 函数创建一个新的管道，并在 `fd` 数组中返回两个文件描述符。`fd[0]` 用于从管道读取数据，`fd[1]` 用于向管道写入数据。管道是半双工的，这意味着数据只能在一个方向上流动，从写入端到读取端。

### 使用场景

- 父子进程之间的通信。
- 相关进程之间的通信，如使用 `fork` 创建的进程。
- 实现消息队列或信号传递机制。

### 示例

```c
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>

int main() {
    int fds[2];
    if (pipe(fds) == -1) {
        perror("pipe failed");
        exit(EXIT_FAILURE);
    }

    // 父进程关闭读端，子进程关闭写端
    close(fds[0]);
    // 写入管道
    write(fds[1], "Hello, child process!", 20);

    close(fds[1]); // 父进程关闭写端

    // 子进程从管道读取数据
    pid_t pid = fork();
    if (pid == -1) {
        perror("fork failed");
        exit(EXIT_FAILURE);
    } else if (pid == 0) {
        // 子进程
        close(fds[1]); // 关闭写端
        char message[20];
        // 从管道读取数据
        read(fds[0], message, 20);
        printf("Child received: %s\n", message);
        close(fds[0]); // 子进程关闭读端
    } else {
        // 父进程等待子进程结束
        wait(NULL);
    }

    return 0;
}
```

### 注意事项

- 管道是一个临时文件系统对象，它在创建它的进程的所有文件描述符都被关闭或进程终止后消失。
- 管道主要用于单向通信。如果需要双向通信，需要创建两个管道。
- 使用 `pipe` 创建的管道是阻塞的，如果读取端没有进程等待读取数据，写入端的 `write` 调用可能会阻塞。

### 相关函数

- `close`：关闭文件描述符。
- `read`：从文件描述符读取数据。
- `write`：向文件描述符写入数据。
- `fork`：创建一个子进程。

`pipe` 是进程间通信的基础系统调用之一，它为实现父子进程或相关进程间的数据传递提供了一种简单有效的方式。

## read
- 代码位置：src/kernel/sysfile.c
- 代码
```C
uint64 sys_read(void) {
    struct file *f;
    int count;
    uint64 buf;
    argaddr(1, &buf);
    if (argint(2, &count) < 0) {
        return -1;
    }
    if (argfd(0, 0, &f) < 0)
        return -1;
    if (!F_READABLE(f))
        return -1;
    int retval = f->f_op->read(f, buf, count);
    return retval;
}
```
系统调用 `read` 在 Unix 和类 Unix 系统中用于从文件描述符读取数据。当你打开一个文件或者需要从标准输入等地方读取数据时，`read` 调用是非常有用的。

### 函数原型

在 C 语言中，`read` 的函数原型通常如下：

```c
#include <unistd.h>

ssize_t read(int fd, void *buf, size_t count);
```

### 参数

- `fd`：一个整数值，表示已打开文件的文件描述符。
- `buf`：一个指向缓冲区的指针，用于存储从文件描述符 `fd` 读取的数据。
- `count`：一个 `size_t` 类型的值，指定从文件描述符 `fd` 读取的字节数。

### 返回值

- 如果调用成功，`read` 返回实际读取的字节数。
- 如果到达文件末尾（EOF），返回 0。
- 如果调用失败，返回 -1 并设置 `errno` 以指示错误类型。

### 描述

`read` 函数尝试从文件描述符 `fd` 指向的文件或设备中读取最多 `count` 个字节的数据，并将其存储在 `buf` 指向的缓冲区中。如果读取成功，它返回读取的字节数。如果到达文件末尾，则返回 0。如果发生错误，则返回 -1。

### 使用场景

- 从文件中读取数据，用于文件 I/O 操作。
- 从标准输入读取用户输入。

### 示例

```c
#include <stdio.h>
#include <unistd.h>

int main() {
    int fd = open("example.txt", O_RDONLY);
    if (fd == -1) {
        perror("open failed");
        return 1;
    }

    char buffer[1024];
    ssize_t bytes_read = read(fd, buffer, sizeof(buffer));
    if (bytes_read == -1) {
        perror("read failed");
        return 1;
    }

    // 打印读取的内容
    printf("Read content: %.*s\n", (int)bytes_read, buffer);

    close(fd);
    return 0;
}
```

### 注意事项

- `read` 调用是阻塞的，如果文件描述符的读缓冲区中没有数据可读，它将一直阻塞直到有数据可读。
- 如果读取的字节数小于请求的 `count`，可能是因为文件末尾、缓冲区大小限制或底层设备的特性。
- 使用 `read` 时，需要确保提供的缓冲区足够大，并且检查实际读取的字节数以避免缓冲区溢出。

### 相关函数

- `write`：向文件描述符写入数据。
- `pread`：从文件描述符读取数据，指定偏移量。
- `readv`：使用 `iovectors` 读取数据。

`read` 是文件 I/O 和进程间通信中的基本系统调用，它允许程序从各种源读取数据。

## times
- 代码位置：src/kernel/sysmisc.c
- 代码
```C
uint64 sys_times(void) {
    uint64 addr;
    argaddr(0, &addr);
    struct tms tms_buf;
    tms_buf.tms_stime = 0;
    tms_buf.tms_utime = 0;
    tms_buf.tms_cstime = 0;
    tms_buf.tms_cutime = 0;
    if (either_copyout(1, addr, &tms_buf, sizeof(tms_buf)) == -1)
        return -1;
    return atomic_read(&ticks);
}
```
系统调用 `times` 在 Unix 和类 Unix 系统中用于获取进程或线程的累计执行时间以及其他与时间相关的信息。这个调用返回了自进程启动以来的CPU时间使用情况，包括用户CPU时间和系统（内核）CPU时间。

### 函数原型

在 C 语言中，`times` 的函数原型通常如下：

```c
#include <sys/times.h>

clock_t times(struct tms *buf);
```

### 参数

- `buf`：一个指向 `struct tms` 的指针，该结构用于接收进程或线程的CPU时间信息。

### 返回值

- 如果调用成功，`times` 返回一个 `clock_t` 类型的值，表示进程或线程的总用户CPU时间加系统CPU时间。
- 如果调用失败，返回 `-1` 并设置 `errno` 以指示错误类型。

### 结构体 `tms`

`struct tms` 定义如下：

```c
struct tms {
    clock_t tms_utime;  // 用户CPU时间
    clock_t tms_stime;  // 系统CPU时间
    clock_t tms_cutime; // 子进程的用户CPU时间
    clock_t tms_cstime; // 子进程的系统CPU时间
};
```

### 描述

`times` 函数填充了 `buf` 指针指向的 `tms` 结构体，提供了以下信息：

- `tms_utime`：进程或线程实际花费在用户模式下的CPU时间。
- `tms_stime`：进程或线程实际花费在内核模式下的CPU时间。
- `tms_cutime`：所有已终止的子进程花费的用户CPU时间的累积。
- `tms_cstime`：所有已终止的子进程花费的系统CPU时间的累积。

这些时间都是以时钟滴答（clock ticks）为单位的，可以通过 `sysconf(_SC_CLK_TCK)` 获取每个时钟滴答的时间。

### 使用场景

- 性能分析和基准测试，了解进程或线程的CPU使用情况。
- 确定程序运行的时间，用于计费或者调度。

### 示例

```c
#include <stdio.h>
#include <sys/times.h>

int main() {
    struct tms buf;
    clock_t start, end;

    start = times(&buf);
    // 执行一些操作
    end = times(&buf);

    printf("User time: %ld\n", buf.tms_utime - start);
    printf("System time: %ld\n", buf.tms_stime - end);

    return 0;
}
```

### 注意事项

- `times` 调用返回的时钟滴答数可能会因为时钟分辨率和溢出而受限于其类型 `clock_t` 的大小。
- 在多线程程序中，`times` 通常只返回关于调用它的线程的信息。

### 相关函数

- `clock_gettime`：提供更精确和灵活的时间获取功能。
- `getrusage`：获取进程或线程的资源使用情况。

`times` 是一个有用的系统调用，它为性能分析和资源监控提供了基本的时间信息。


## uname
- 代码位置：src/kernel/sysmisc.c
- 代码
```C
uint64 sys_uname(void) {
    uint64 addr;
    uint64 ret = 0;
    argaddr(0, &addr);
    if (either_copyout(1, addr, &sys_ut, sizeof(sys_ut)) == -1)
        ret = -1;
    return ret;
}
```
系统调用 `uname` 在 Unix 和类 Unix 系统中用于获取当前系统的相关信息，通常是关于操作系统的名称和其他细节。这个调用通常用于获取系统的标识信息，以便应用程序可以根据特定的操作系统特性进行调整。

### 函数原型

在 C 语言中，`uname` 的函数原型通常如下：

```c
#include <sys/utsname.h>

int uname(struct utsname *buf);
```

### 参数

- `buf`：一个指向 `struct utsname` 的指针，该结构用于接收系统信息。

### 返回值

- 如果调用成功，`uname` 返回 0。
- 如果调用失败，返回 -1 并设置 `errno` 以指示错误类型。

### 结构体 `utsname`

`struct utsname` 定义如下：

```c
struct utsname {
    char sysname[65];    // 操作系统的名称
    char nodename[65];   // 网络名称（通常与hostname相同）
    char release[65];    // 系统版本
    char version[65];    // 系统版本信息
    char machine[65];    // 硬件类型
    char domainname[65]; // DNS 主机域名（如果配置了）
};
```

### 描述

`uname` 函数填充了 `buf` 指针指向的 `utsname` 结构体，提供了系统的相关信息，包括但不限于：

- `sysname`：操作系统的名称，如 "Linux"。
- `nodename`：系统的网络名称，通常与主机名相同。
- `release`：系统的发行版本。
- `version`：系统的版本信息。
- `machine`：系统的硬件类型，如 "x86_64"。
- `domainname`：系统的 DNS 主机域名。

### 使用场景

- 显示系统的关于信息。
- 在日志记录中包含系统的标识信息。
- 根据操作系统的特性调整应用程序的行为。

### 示例

```c
#include <stdio.h>
#include <sys/utsname.h>

int main() {
    struct utsname buf;
    if (uname(&buf) == -1) {
        perror("uname failed");
        return 1;
    }

    printf("System information:\n");
    printf("  System Name: %s\n", buf.sysname);
    printf("  Node Name: %s\n", buf.nodename);
    printf("  Release: %s\n", buf.release);
    printf("  Version: %s\n", buf.version);
    printf("  Machine: %s\n", buf.machine);
    printf("  Domain Name: %s\n", buf.domainname);

    return 0;
}
```

### 注意事项

- `uname` 调用通常用于获取关于操作系统的静态信息，这些信息在系统启动后通常不会改变。

### 相关函数

- `gethostname`：获取系统的主机名。

`uname` 是一个有用的系统调用，它为应用程序提供了一种获取当前运行的操作系统信息的方法。这对于需要根据不同操作系统特性进行适配的应用程序尤其重要。

## unlink
- 代码位置：src/kernel/sysfile.c
- 代码
```C
uint64 sys_unlinkat(void) {
    struct inode *ip, *dp;
    char name[NAME_LONG_MAX], path[MAXPATH];
    int dirfd, flags;
    argint(0, &dirfd);

    argint(2, &flags);
    if (argstr(1, path, MAXPATH) < 0 || __namecmp(path, "/") == 0)
        return -1;
    if ((dp = find_inode(path, dirfd, name)) == 0) {
        return ENOENT;
    }
    if (__namecmp(name, ".") == 0 || __namecmp(name, "..") == 0) {
        return -1;
    }
    dp->i_op->ilock(dp);
    if ((ip = dp->i_op->idirlookup(dp, name, 0)) == 0) {
        dp->i_op->iunlock_put(dp);
        return -1;
    }
    ip->i_op->ilock(ip);
    if ((flags == 0 && S_ISDIR(ip->i_mode))
        || (flags == AT_REMOVEDIR && !S_ISDIR(ip->i_mode))) {
        ip->i_op->iunlock_put(ip);
        dp->i_op->iunlock_put(dp);
        return -1;
    }
    if (ip->i_nlink < 1) {
        panic("unlink: nlink < 1");
    }
    if (S_ISDIR(ip->i_mode) && !ip->i_op->idempty(ip)) {
        ip->i_op->iunlock_put(ip);
        dp->i_op->iunlock_put(dp);
        return -1;
    }
    __unlink(dp, ip);
    return 0;
}
```
系统调用 `unlink` 在 Unix 和类 Unix 系统中用于删除文件或目录。这个调用通常由文件系统管理层使用，以从文件系统中移除文件或目录的条目。

### 函数原型

在 C 语言中，`unlink` 的函数原型通常如下：

```c
#include <unistd.h>

int unlink(const char *path);
```

### 参数

- `path`：一个以 null 结尾的字符串，指定了要删除的文件或目录的路径。

### 返回值

- 如果调用成功，`unlink` 返回 0。
- 如果调用失败，返回 -1 并设置 `errno` 以指示错误类型。

### 描述

`unlink` 函数尝试删除 `path` 指定的文件或目录。如果 `path` 指向一个文件，该文件将被删除。如果 `path` 指向一个目录，只有当目录为空时，目录才会被删除。

### 使用场景

- 删除不再需要的文件。
- 清理临时文件。
- 在程序结束时删除创建的文件。

### 示例

```c
#include <stdio.h>
#include <unistd.h>

int main() {
    const char *path = "example.txt";
    if (unlink(path) == -1) {
        perror("unlink failed");
        return 1;
    }
    printf("File '%s' deleted successfully.\n", path);
    return 0;
}
```

### 注意事项

- `unlink` 只能删除文件系统中的条目，它不会删除正在使用的文件或目录。
- 如果文件正在被使用（例如，已经被打开），`unlink` 会失败，并且 `errno` 将被设置为 `EBUSY`。
- `unlink` 不能删除非空目录。要删除非空目录，需要使用 `rmdir` 或 `remove`（在某些系统中）。

### 相关函数

- `remove`：在某些系统中，`remove` 可以删除文件和非空目录。
- `rmdir`：删除空目录。
- `unlinkat`：与 `unlink` 类似，但允许在指定目录文件描述符的上下文中删除文件或目录。

`unlink` 是文件系统操作中的一个重要系统调用，它允许用户和程序在不再需要时清理文件和目录。


## wait
- 代码位置：src/kernel/sysproc.c
- 代码
```C
int waitpid(pid_t pid, uint64 status, int options) {
    struct proc *p = proc_current();
    if (pid < -1)
        pid = -pid;
    ASSERT(pid != 0);
    if (nochildren(p)) {
        return -1;
    }
    if (proc_killed(p)) {
        return -1;
    }
    while (1) {
        sema_wait(&p->sem_wait_chan_parent);
        struct proc *p_child = NULL;
        struct proc *p_tmp = NULL;
        struct proc *p_first = firstchild(p);
        int flag = 1;
        list_for_each_entry_safe_given_first(p_child, p_tmp, p_first, sibling_list, flag) {
            if (pid > 0 && p_child->pid == pid) {
                sema_wait(&p_child->sem_wait_chan_self);
            }
            acquire(&p_child->lock);
            if (p_child->state == PCB_ZOMBIE) {
                pid = p_child->pid;
                if (status != 0 && copyout(p->mm->pagetable, status, (char *)&(p_child->exit_state), sizeof(p_child->exit_state)) < 0) {
                    release(&p_child->lock);
                    return -1;
                }
                free_proc(p_child);
                acquire(&p->lock);
                deleteChild(p, p_child);
                release(&p->lock);
                release(&p_child->lock);
                return pid;
            }
            release(&p_child->lock);
        }
        printf("%d\n", p->pid);
        panic("waitpid : invalid wakeup for semaphore!");
    }
}

uint64 sys_wait4(void) {
    pid_t p;
    uint64 status;
    int options;
    argint(0, &p);
    argaddr(1, &status);
    argint(2, &options);

    return waitpid(p, status, options);
}
```
系统调用 `wait` 在 Unix 和类 Unix 系统中用于等待一个或多个子进程结束。这个调用通常由父进程使用，以确定其子进程的状态。`wait` 调用可以挂起父进程的执行，直到一个子进程终止或发生其他条件。

### 函数原型

在 C 语言中，`wait` 的函数原型通常如下：

```c
#include <sys/types.h>
#include <sys/wait.h>

pid_t wait(int *status);
```

### 参数

- `status`：一个整数指针，用于接收子进程的状态信息。如果不需要状态信息，可以传递 `NULL`。

### 返回值

- 返回终止子进程的进程标识符（PID）。
- 如果调用失败，返回 -1 并设置 `errno` 以指示错误类型。

### 描述

`wait` 函数使调用它的父进程挂起，直到以下条件之一发生：

1. 至少有一个子进程已经终止。
2. 发生一个未被忽略的信号。

如果 `status` 不是 `NULL`，子进程的终止状态将被存储在 `status` 指向的位置。状态信息通常包含子进程的退出代码、是否因为信号而终止以及相关的信号信息。

### 使用场景

- 父进程等待子进程完成。
- 收集子进程的退出状态。

### 示例

```c
#include <stdio.h>
#include <unistd.h>
#include <sys/wait.h>

int main() {
    pid_t pid = fork();
    if (pid == -1) {
        perror("fork failed");
        return 1;
    } else if (pid == 0) {
        // 子进程
        exit(42); // 子进程退出并返回状态码 42
    } else {
        // 父进程
        int status;
        pid_t child_pid = wait(&status);
        if (child_pid == -1) {
            perror("wait failed");
            return 1;
        }
        if (WIFEXITED(status)) {
            printf("Child process exited with status %d\n", WEXITSTATUS(status));
        }
    }
    return 0;
}
```

### 注意事项

- `wait` 只能等待子进程，不能等待父进程或兄弟进程。
- 如果有多个子进程，`wait` 将返回第一个终止的子进程的状态。

### 相关函数

- `waitpid`：类似于 `wait`，但允许指定要等待的子进程的 PID。
- `waitid`：一个更通用的等待调用，允许等待特定的子进程或进程组。
- `WIFEXITED`、`WEXITSTATUS`、`WIFSIGNALED` 等宏：用于解释 `wait` 返回的状态信息。

`wait` 是进程控制和进程间通信中的一个重要系统调用，它允许父进程同步其子进程的执行，并获取子进程的退出状态。


## waitpid
- 代码位置：src/kernel/sysproc.c
- 代码
参考wait章节


## write
- 代码位置：src/kernel/sysfile.c
- 代码
```C
uint64 sys_write(void) {
    struct file *f;
    int n, fd;
    uint64 p;
    argaddr(1, &p);
    argint(2, &n);
    if (argfd(0, &fd, &f) < 0)
        return -1;
    if (!F_WRITEABLE(f))
        return -1;
    return f->f_op->write(f, p, n);
}
```
系统调用 `write` 在 Unix 和类 Unix 系统中用于向文件描述符写入数据。这个调用是文件 I/O 的基本操作之一，允许进程向文件、设备或者套接字等输出数据。

### 函数原型

在 C 语言中，`write` 的函数原型通常如下：

```c
#include <unistd.h>

ssize_t write(int fd, const void *buf, size_t count);
```

### 参数

- `fd`：一个整数值，表示已打开文件的文件描述符。
- `buf`：一个指向数据缓冲区的指针，包含了要写入的数据。
- `count`：一个 `size_t` 类型的值，指定要写入的字节数。

### 返回值

- 如果调用成功，`write` 返回实际写入的字节数。
- 如果调用失败，返回 -1 并设置 `errno` 以指示错误类型。

### 描述

`write` 函数尝试向文件描述符 `fd` 指向的文件或设备写入 `count` 个字节的数据，这些数据位于 `buf` 指向的缓冲区中。如果写入成功，它返回写入的字节数。如果发生错误，则返回 -1。

### 使用场景

- 向文件写入数据，用于文件 I/O 操作。
- 向标准输出或标准错误输出发送数据。

### 示例

```c
#include <stdio.h>
#include <unistd.h>

int main() {
    int fd = open("example.txt", O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd == -1) {
        perror("open failed");
        return 1;
    }

    const char *message = "Hello, World!";
    ssize_t bytes_written = write(fd, message, strlen(message));
    if (bytes_written == -1) {
        perror("write failed");
        return 1;
    }

    close(fd);
    return 0;
}
```

### 注意事项

- `write` 调用是阻塞的，如果文件描述符的写缓冲区已满，它将一直阻塞直到有足够的空间。
- 对于某些特殊文件或设备，如终端或套接字，`write` 的行为可能与常规文件不同。

### 相关函数

- `read`：从文件描述符读取数据。
- `open`：打开一个文件并返回一个文件描述符。
- `close`：关闭一个文件描述符。

`write` 是一个基本的系统调用，它为文件 I/O 和进程间通信提供了一种将数据发送到文件或设备的方法。

## yield
- 代码位置：src/proc/sched.c
- 代码
```C
void thread_yield(void) {
    struct tcb *t = thread_current();
    acquire(&t->lock);
    TCB_Q_changeState(t, TCB_RUNNABLE);
    thread_sched();
    release(&t->lock);
}
```
系统调用 `yield` 在 Unix 和类 Unix 系统中用于提示操作系统调度器让出当前进程的 CPU 时间片，允许其他就绪状态的进程运行。这个调用通常用于多线程编程中，当一个线程或进程希望放弃其剩余的时间片时。

### 函数原型

在 C 语言中，`yield` 的函数原型通常如下：

```c
#include <sched.h>

int sched_yield(void);
```

### 参数

`sched_yield` 函数不接受任何参数。

### 返回值

- 如果调用成功，`sched_yield` 返回 0。
- 如果调用失败，返回 -1 并设置 `errno` 以指示错误类型。

### 描述

`sched_yield` 函数使当前线程放弃其对 CPU 的控制，允许相同优先级的其他线程运行。如果当前线程是唯一就绪的线程，它可能立即继续执行。当调用线程再次变得可运行时，它将有机会被调度器重新调度。

### 使用场景

- 在多线程程序中，当一个线程完成了某些工作或者正在等待某些事件时，可以主动让出 CPU 时间片。
- 在实时系统中，当一个低优先级的线程获得了 CPU 控制权，而此时有一个高优先级的线程变为可运行状态，低优先级的线程可以主动让出 CPU。

### 示例

```c
#include <stdio.h>
#include <sched.h>

int main() {
    if (sched_yield() == -1) {
        perror("sched_yield failed");
        return 1;
    }
    printf("Yielded control of the CPU.\n");
    return 0;
}
```

### 注意事项

- `sched_yield` 只影响调用它的线程或进程。
- 调用 `sched_yield` 并不保证当前线程一定会被挂起，它只是提供了一个让出 CPU 的机会。

### 相关函数

- `sleep`：暂停执行指定的秒数。
- `nanosleep`：暂停执行指定的纳秒数。

`sched_yield` 是一个有用的系统调用，它为多线程程序提供了一种机制，允许线程在适当的时候主动让出 CPU 时间片，从而提高程序的整体响应性和公平性。


## sleep
- 代码位置
- 代码
参照gettimeofday系统调用

## mount
- 代码位置：src/kernel/sysfile.c
- 代码：未实现
## umount
- 代码位置：src/kernel/sysfile.c
- 代码：未实现