# 设计

## 初始化阶段的内存管理

在操作系统的初始化阶段，内存管理的初始化工作至关重要，主要分为两个部分：

1. **物理内存分配器的初始化**：通过调用`mm_init()`函数，初始化伙伴系统，为物理内存的分配和回收打下基础。

2. **内核页表的建立和分页启动**：使用`kvminit()`创建内核页表，并采用直接映射策略，实现虚拟地址和物理地址的一一对应。之后，通过`w_satp(MAKE_SATP(kernel_pagetable))`为每个核心启动分页机制，由于内核页表的不变性，允许多核心共享。

## 物理内存布局

操作系统的物理内存布局如下：

- **SBI保留区**：从`0x80000000`开始，用于opensbi-qemu。
- **Kernel Image区域**：从`0x80200000`开始，存放内核映像。
- **Page Metadata区域**：位于内核映像之后，动态调整大小，用于存储页面元数据。
- **可用内存区域**：从`START_MEM`到`PHYSTOP`，是所有可分配的物理内存空间。

```shell
    +---------------------------+ <-- 0x80000000
    |           sbi             |
    +---------------------------+ <-- opensbi-qemu jump to 0x80200000
    |     kernel img region     |
    +---------------------------+ <-- kernel end
    |    page_metadata region   |
    +---------------------------+ <-- START_MEM
    |          MEMORY           |
    |           ...             |
    +---------------------------+ <-- PHYSTOP
```

## 物理内存管理

物理内存管理采用伙伴系统，其核心思想是将内存分为不同大小的块，以块为单位进行管理。通过定义`BUDDY_MAX_ORDER`，可以配置系统中最大的可分配内存块。物理内存的分配和释放通过`kmalloc`、`kzalloc`和`kfree`函数进行，同时`get_free_mem()`用于获取当前可用的物理内存大小，而`share_page`用于Copy-On-Write操作。

## 虚拟内存管理

操作系统采用RISC-V的Sv39分页策略，通过三级页表实现虚拟内存管理。虚拟地址空间被划分为多个部分，其中VPN[i]作为页表查找时的偏移量。此外，使用PTE的权限位，如PTE_RSW和PTE_D，分别支持COW和标识脏页。

## 地址空间管理

基于VMA的地址空间管理策略被引入mmap系统调用的实现中。VMA的数据结构定义了内存区域的类型、起始地址、大小和权限等信息，用于管理不同类型的内存区域。

## 支持的特性及优化

### COW（写时复制）

实现了支持COW的fork/clone系统调用，优化了内存分配，避免了在execve调用后重复分配内存的开销。COW的核心是在创建进程时复制父进程的页表，但不分配物理内存，直到子进程尝试写入时才分配，并设置页表为只读。

### 超级页（Superpage）

支持大页映射，特别是2MB的超级页，以提高内存访问效率和TLB命中率。超级页减少了页表的级数，降低了TLB缓存项的使用。

### 多核物理内存分配优化

为了提高多核环境下的内存分配效率，物理内存被划分为多个内存池，每个CPU核心拥有自己的内存池，允许并发分配物理页。当一个核心的内存池耗尽时，可以通过`steal_mem`接口从其他核心的内存池中“偷取”内存。

通过上述设计，操作系统内核实现了高效、灵活的内存管理机制，支持了物理内存和虚拟内存的有效管理，同时引入了COW、大页映射和多核优化等先进技术，以提高系统的整体性能和响应速度。