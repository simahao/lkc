# 多核多线程

## 引言

本文档详细介绍了如何在操作系统内核中实现多核多线程的支持。我们将探讨线程的上下文切换、线程独有的`trapframe`的分配、以及对`trampoline`和写时复制（COW）的适配。

## 多核多线程执行流切换

### 线程上下文切换
在多核系统中，一个进程的多个线程可以并行地在不同的核心上执行。为了实现这一功能，每个线程必须拥有自己独立的`trapframe`，以确保在执行流切换时，线程的上下文不会被其他线程覆盖。

### `trapframe`的分配
为了避免多个线程同时写入同一个`trapframe`，我们的操作系统为每个线程创建了独立的`trapframe`。在创建线程时，通过调用`uvm_thread_trapframe`接口分配`trapframe`：

```c
if ((t->trapframe = uvm_thread_trapframe(p->mm->pagetable, t->tidx)) == 0) {
    // ...
    return -1;
}
```

`t->tidx`参数表示当前线程在进程中的索引。

### `trapframe`的定位
每个线程的`trapframe`地址可以通过计算得到。操作系统通过宏`TRAPFRAME`定义了第一个线程的`trapframe`地址，后续线程的`trapframe`地址则通过索引`idx`计算得出：

```c
TRAPFRAME - idx * PGSIZE
```

### 线程索引的保存
为了使线程能够在执行`trampoline`代码时找到自己的`trapframe`，线程索引`idx`必须保存在一个线程可访问的地方。在我们的系统中，索引`tidx`被保存在`sscratch`寄存器中：

```c
// write thread idx into sscratch
w_sscratch(t->tidx);
```

## `trampoline`的适配

### 上下文保存
在原始的xv6设计中，`sscratch`寄存器用于辅助上下文保存。在我们的多核多线程设计中，`sscratch`被用来保存线程索引`tidx`。因此，我们需要修改`trampoline`的上下文保存逻辑，将寄存器预先保存到用户栈中：

```asm
# save user a0 in stack
# so a0 can be used to get TRAPFRAME.
addi sp, sp, -32
sd a0, 0(sp)
sd a1, 8(sp)
sd a2, 16(sp)
```

## COW的适配

### 栈区域的COW处理
在写时复制（COW）的处理逻辑中，我们对栈区域进行了特别处理。由于`trampoline`设计中需要用到栈来保存寄存器，我们修改了COW逻辑，以确保栈区域的物理内存被正确分配和拷贝：

```c
/* for STACK VMA, copy both the pagetable and the physical memory */
if (pos->type == VMA_STACK) {
    for (uint64 offset = 0; offset < pos->size; offset += PGSIZE) {
        ...
        paddr_t new = (paddr_t)kzalloc(PGSIZE); // 分配物理内存
        ...
        memmove((void *)new, (void *)pa, PGSIZE); // 拷贝物理内存
        if (mappages(...) != 0) { // 填写页表
            panic("uvmcopy: map failed");
            return -1;
        }
    }
    continue;
}
```

## 总结

通过为每个线程分配独立的`trapframe`，并通过`sscratch`寄存器保存线程索引，我们的操作系统实现了在多个CPU核心上并行执行多个线程的能力。此外，通过对`trampoline`和COW逻辑的适配，我们的系统能够更高效地处理线程的上下文切换和内存管理。这些设计改进为开发高效的多核多线程应用程序提供了坚实的基础。