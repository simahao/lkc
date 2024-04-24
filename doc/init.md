# 用户程序和进程初始化

在操作系统完成一系列初始化任务后，它将启动第一个用户程序——`init`。以下是用户程序和进程初始化的关键步骤和组件的详细文档。

## 第一个用户程序`init`的启动

### `user_init`

操作系统通过`user_init`创建第一个进程——`init`的“壳子”。

```c
void user_init(void) {
    struct proc *p = create_proc();  // 创建进程的壳子
    initproc = p;
    safestrcpy(p->name, "/init", 10);
    TCB_Q_changeState(p->tg->group_leader, TCB_RUNNABLE); // 放入就绪队列
    release(&p->lock);
}
```

`user_init`完成的工作：

1. 通过`create_proc`创建进程的壳子，初始化上下文。
2. 将进程放入就绪队列。

### `thread_forkret`

操作系统运行调度器选择可运行的进程，切换上下文到`init`的上下文，开始执行`thread_forkret`。

```c
void thread_forkret(void) {
    release(&thread_current()->lock);
    if (thread_current() == initproc->tg->group_leader) {
        init_ret();
    }
    thread_usertrapret();
}
```

`thread_forkret`中：

- 判断是否是`init`进程，若是，则执行`init_ret`。
- 执行`thread_usertrapret`准备返回用户态。

### `init_ret`

`init_ret`中加载并初始化`init`进程，完成文件系统初始化。

```c
void init_ret(void) {
    fat32_fs_mount(ROOTDEV, &fat32_sb); // 初始化文件系统
    proc_current()->_cwd = fat32_inode_dup(fat32_sb.root);
    proc_current()->tg->group_leader->trapframe->a0 = do_execve("/boot/init", NULL, NULL);
}
```

## `init`做了什么

1. 创建设备文件`console.dev`。
2. 打开标准输出和标准错误输出。
3. 启动`shell`。
4. 执行收尸操作，等待没有父进程的进程。

## `shell`

当前`shell`支持的功能：

- 管道
- 重定向
- 列表命令执行
- 支持环境变量的使用
- 后台任务

## 用户程序

除了`shell`，还支持了一系列简单的用户程序，如`ls`、`rm`、`cat`、`mkdir`、`shutdown`、`wc`、`kill`、`echo`、`grep`等，这些程序放在文件系统镜像的`bin`目录中。

## 总结

操作系统内核通过`user_init`创建第一个用户进程`init`，并通过`init`加载和初始化文件系统，启动`shell`，从而允许用户与系统进行交互。`init`进程还负责创建设备文件、打开标准输出和标准错误输出，并在后台执行收尸操作。此外，系统还提供了一系列的用户程序，放置在`bin`目录中，并通过`shell`支持用户方便地使用这些程序。这些机制共同构成了操作系统用户程序和进程初始化的基础。