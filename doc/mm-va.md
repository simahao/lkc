# 内核内存管理

内核内存管理是操作系统的核心功能之一，它负责分配和管理内存资源，确保进程和线程能够有效地运行。以下是内核内存管理的关键组件和流程的详细文档。

## 初始化

在系统启动时，需要初始化内存管理相关的数据结构和页表。

### 内核页表创建

```c
pagetable_t kernel_pagetable = kvmmake();
```

`kvmmake` 函数创建并初始化内核的页表，它使用直接映射策略，即虚拟地址和物理地址一一对应。

### 内核页表初始化

```c
void kvminit(void) {
    kernel_pagetable = kvmmake();
    Info("kernel pagetable init [ok]\n");
}
```

`kvminit` 函数将内核页表设置为 `kvmmake` 创建的页表。

### 启用分页

```c
void kvminithart() {
    sfence_vma();
    w_satp(MAKE_SATP(kernel_pagetable));
    sfence_vma();
    Info("cpu %d, paging is enable\n", cpuid());
}
```

`kvminithart` 函数将硬件页表寄存器切换到内核页表，并启用分页。

## 物理内存布局

物理内存从 `0x80000000` 开始，分为多个区域：

- **SBI保留区**：用于opensbi-qemu。
- **Kernel Image区域**：存放内核映像。
- **Page Metadata区域**：存储页面元数据，大小可动态调整。
- **可用内存区域**：所有可分配的物理内存空间。

## 物理内存管理

物理内存管理使用伙伴系统，它将内存划分为不同大小的块进行管理。

### 伙伴系统配置

```c
#define BUDDY_MAX_ORDER 13
```

`BUDDY_MAX_ORDER` 定义了伙伴系统中最大的可分配块。

### 内存分配接口

- `kzalloc`：分配并清零内存。
- `kmalloc`：分配指定大小的内存。
- `kfree`：释放内存。
- `get_free_mem`：获取当前可用的物理内存大小。
- `share_page`：用于Copy-On-Write操作。

## 虚拟内存管理

虚拟内存管理采用RISC-V的Sv39分页策略，支持大页映射。

### 页表项权限位

- `PTE_RSW`：实现COW。
- `PTE_D`：标识脏页。

### 虚拟内存管理选项

- `COMMONPAGE`：普通页。
- `SUPERPAGE`：2MB大页。

## 地址空间管理

地址空间管理使用基于VMA的策略，VMA的数据结构定义了内存区域的类型、起始地址、大小和权限。

## 支持的特性及优化

### COW（写时复制）

COW优化了fork操作，通过仅复制页表而不分配物理内存，直到子进程尝试写入。

### 超级页

超级页减少了页表的级数，提高了TLB命中率和页表查询效率。

### 多核物理内存分配优化

通过将物理内存划分为多个内存池，允许多个核心并发分配物理页。

## 内存映射与虚拟地址转换

### 映射虚拟地址到物理地址

```c
uint64 walkaddr(pagetable_t pagetable, uint64 va) {
    pte_t *pte;
    uint64 pa;

    if (va >= MAXVA)
        return 0;

    int level = walk(pagetable, va, 0, 0, &pte);
    ASSERT(level <= 1);
    if (pte == 0)
        return 0;
    if ((*pte & PTE_V) == 0)
        return 0;
    if ((*pte & PTE_U) == 0)
        return 0;
    pa = PTE2PA(*pte);
    if (level == COMMONPAGE) {
        return pa;
    } else if (level == SUPERPAGE) {
        return pa + (PGROUNDDOWN(va) - SUPERPG_DOWN(va));
    } else {
        panic("can not reach here");
    }
}
```

`walkaddr` 函数查找虚拟地址 `va` 并返回对应的物理地址 `pa`。

### 内存映射

```c
void kvmmap(pagetable_t kpgtbl, uint64 va, uint64 pa, uint64 sz, int perm, int lowlevel) {
    if (mappages(kpgtbl, va, sz, pa, perm, lowlevel) != 0)
        panic("kvmmap");
}
```

`kvmmap` 函数在内核页表 `kpgtbl` 中添加一个新的映射，将虚拟地址 `va` 映射到物理地址 `pa`。

## 内存复制函数

### 从用户空间复制到内核空间

```c
int copyin(pagetable_t pagetable, char *dst, uint64 srcva, uint64 len) {
    // ...
    return 0;
}
```

`copyin` 函数从用户空间的虚拟地址 `srcva` 复制 `len` 字节到内核空间的 `dst`。

### 从内核空间复制到用户空间

```c
int copyout(pagetable_t pagetable, uint64 dstva, char *src, uint64 len) {
    // ...
    return 0;
}
```

`copyout` 函数从内核空间的 `src` 复制 `len` 字节到用户空间的虚拟地址 `dstva`。

## 调试与诊断

### 打印页表信息

```c
void vmprint(pagetable_t pagetable, int isroot, int level, uint64 start, uint64 end, uint64 vabase) {
    // ...
}
```

`vmprint` 函数用于打印页表的内容，有助于调试和理解内存映射情况。

## 线程栈与陷阱帧

### 创建用户线程栈

```c
int uvm_thread_stack(pagetable_t pagetable, int ustack_page) {
    // ...
    return 0;
}
```

`uvm_thread_stack` 函数为用户线程创建栈，并为其分配内存。

### 创建用户线程陷阱帧

```c
struct trapframe *uvm_thread_trapframe(pagetable_t pagetable, int thread_idx) {
    // ...
    return NULL;
}
```

`uvm_thread_trapframe` 函数为用户线程创建陷阱帧，并为其分配内存。

以上是内核内存管理的关键组件和接口的详细文档。通过这些组件和接口，操作系统能够有效地管理内存资源，支持进程和线程的运行。