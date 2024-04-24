# 操作系统内核陷阱（Trap）和中断处理

内核陷阱（Trap）和中断处理是操作系统内核中的关键部分，它们负责处理来自用户态和内核态的异常和中断。以下是内核陷阱和中断处理的关键组件和流程的详细文档。

## 初始化

在系统启动时，0号CPU负责初始化陷阱处理。

### 陷阱向量初始化

设置`stvec`寄存器以指向`kernelvec`，这样当内核中发生异常时，处理器将跳转到这个地址。

```c
w_stvec((uint64)kernelvec);
```

启动S态的外部中断、时钟中断和软件中断。

```c
w_sie(r_sie() | SIE_SEIE | SIE_STIE | SIE_SSIE);
```

设置定时器。

```c
SET_TIMER();
```

### PLIC初始化

初始化PLIC以处理设备中断。

```c
void plicinit(void);
void plicinithart(void);
```

## 用户态异常入口地址初始化

当新线程分配后，将其`context`的`ra`寄存器设置为`thread_forkret`。当线程变为可运行状态时，它将跳转到`thread_forkret`，该函数设置用户态异常的跳转地址为`uservec`。

```c
uint64 trampoline_uservec = TRAMPOLINE + (uservec - trampoline);
w_stvec(trampoline_uservec);
```

## 用户态异常处理

当用户态程序发生异常时，会跳转到`uservec`。在`uservec`中，使用S态的特权级别但保持U态的页表。

### `uservec`中的操作

- 保存`a0`寄存器到`sscratch`。
- 从`TRAPFRAME`中恢复寄存器。
- 使用`sscratch`和`t0`寄存器保存`a0`的内容到`trapframe->a0`。
- 加载`sp`、`tp`寄存器。
- 读取`thread_usertrap`的地址和内核页表地址`satp`。
- 跳转到`thread_usertrap`。

### `thread_usertrap`

处理用户态异常的函数，包括：

- 确认异常来源为用户态。
- 设置`stvec`为`kernelvec`。
- 保存上下文信息到`trapframe`。
- 读取`sepc`和`scause`以确定异常原因。

#### 异常原因处理

- **SYSCALL**：系统调用，`scause`为8。
- **外部中断**：设置UART和VIRTIO中断。
- **时钟中断**：调用`thread_yield`让出CPU。
- **缺页异常**：处理指令、加载和存储缺页。

### 系统调用入口

如果异常原因是SYSCALL，执行内核中的`syscall`函数处理系统调用。

### `thread_usertrapret`

关闭中断，设置返回到用户态的寄存器和状态。

### `userret`

从内核态返回到用户态。

## 内核态陷阱处理

内核态异常跳转到`kernelvec`。

### `kernelvec`中的操作

- 保存寄存器到栈。
- 调用`kerneltrap`。

### `kerneltrap`

分析内核态异常，处理时钟中断和设备中断。

### 线程切换

在内核中发生时钟中断时，调用`thread_yield`进行线程切换。

### 恢复执行

在`thread_yield`结束后，恢复`sepc`和`sstatus`寄存器的内容。

### 返回内核态

在`kerneltrap`处理结束后，恢复寄存器并使用`sret`返回内核态。

以上是操作系统内核陷阱和中断处理的关键组件和流程的详细文档。通过这些机制，操作系统能够有效地响应和处理来自用户态和内核态的异常和中断，确保系统的稳定性和响应性。