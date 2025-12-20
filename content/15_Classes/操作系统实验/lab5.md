## 1. 实验目的

*   了解第一个用户进程创建过程。

*   了解系统调用框架的实现机制。

*   了解用户进程创建、执行、切换和结束的动态管理过程。

*   掌握用户进程的生命周期管理 (`fork`, `exec`, `wait`, `exit`)。


## 2. 练习 0：填写已有实验

本实验依赖于 Lab 1-4 的基础代码。我们需要将之前实验中修复和完成的代码迁移到 Lab 5 中。

**2.1 主要修复工作**

在迁移过程中，我们发现 Lab 4 的 `kern/mm/default_pmm.c` 在处理内存释放时存在逻辑缺陷，导致在 Lab 5 环境下触发内核 Panic。

*   **问题分析**：原 `default_free_pages` 函数在将释放的内存块插入空闲链表时，未严格遵守“地址升序”排列规则，且合并逻辑存在漏洞，导致 First-Fit 算法在分配时无法找到正确的块。

*   **修复代码**：我们重写了 `default_free_pages`，使用了 `list_next` 遍历寻找正确的插入位置，并分别处理了向前合并和向后合并的逻辑。

```c

// kern/mm/default_pmm.c 修复片段

static void default_free_pages(struct Page *base, size_t n) {

    // ... (初始化和属性设置)

    // 1. 严格按地址升序寻找插入位置

    list_entry_t *le = list_next(&free_list);

    while (le != &free_list) {

        p = le2page(le, page_link);

        if (base < p) break; // 找到第一个地址比 base 大的节点

        le = list_next(le);

    }

    list_add_before(le, &(base->page_link)); // 插在它前面

  

    // 2. 向后合并 (base + base->size == next)

    if (le != &free_list) {

        p = le2page(le, page_link);

        if (base + base->property == p) {

            base->property += p->property;

            ClearPageProperty(p);

            list_del(&(p->page_link));

        }

    }

    // 3. 向前合并 ...

}

```


此外，我们还完善了 `kern/trap/trap.c` 中的 `idt_init`，添加了对系统调用中断门 (`T_SYSCALL`) 的初始化，权限设置为 `DPL_USER`，允许用户态通过 `int 0x80` 指令触发中断进入内核。


## 3. 练习 1：加载应用程序并执行 (do_execve)

`do_execve` 是执行用户程序的入口，其核心功能由 `load_icode` 函数完成。

### 3.1 `load_icode` 代码深度解析

`load_icode` 的功能是将一个 ELF 格式的二进制文件加载到进程的虚拟内存中，并为进程进入用户态做好一切准备。

**第一步：清理与重建**

```c

if (current->mm != NULL) panic("..."); // 确保当前进程内存空间已清空

if ((mm = mm_create()) == NULL) goto bad_mm; // 1. 创建新的内存管理器 mm

if (setup_pgdir(mm) != 0) goto bad_pgdir_cleanup_mm; // 2. 创建新的页表，并复制内核页表项

```

*解析*：`exec` 的语义是“替换”，所以必须彻底抛弃旧的内存布局。`setup_pgdir` 确保了新进程依然能访问内核空间（高 1GB），这是所有进程共享的。

**第二步：解析 ELF 并加载段**

```c

struct elfhdr *elf = (struct elfhdr *)binary;

struct proghdr *ph = (struct proghdr *)(binary + elf->e_phoff);

// 遍历所有 Program Header

for (; ph < ph_end; ph ++) {

    if (ph->p_type != ELF_PT_LOAD) continue; // 只关心需要加载的段 (TEXT, DATA)

    // 3. 建立虚拟内存映射 (VMA)

    mm_map(mm, ph->p_va, ph->p_memsz, vm_flags, NULL);

    // 4. 分配物理内存并复制数据

    // 这里使用了 pgdir_alloc_page 自动分配物理页并建立页表映射

    // memcpy 将 ELF 文件中的代码/数据复制到内存中

    // memset 处理 BSS 段（未初始化数据），将其清零

}

```

**第三步：建立用户栈**

```c

// 映射从 USTACKTOP 往下的一块区域作为用户栈

mm_map(mm, USTACKTOP - USTACKSIZE, USTACKSIZE, VM_READ | VM_WRITE | VM_STACK, NULL);

pgdir_alloc_page(mm->pgdir, USTACKTOP-PGSIZE , PTE_USER); // 实际分配物理页

// ...

```

**第四步：特权级切换准备 (TrapFrame 设置)**

这是本练习最关键的部分。为了让 CPU 从内核态（Ring 0）安全切换到用户态（Ring 3），我们需要伪造一个中断返回现场。

```c

struct trapframe *tf = current->tf;

memset(tf, 0, sizeof(struct trapframe));

  

// 1. 设置段寄存器 (Selector)

tf->tf_cs = USER_CS; // 代码段选择子：指向 GDT 中的用户代码段，RPL=3

tf->tf_ds = tf->tf_es = tf->tf_ss = USER_DS; // 数据段选择子：指向 GDT 中的用户数据段，RPL=3

  

// 2. 设置栈顶 (Stack Pointer)

tf->tf_esp = USTACKTOP; // 用户栈的栈顶地址，用户程序运行时从这里开始压栈

  

// 3. 设置入口地址 (Instruction Pointer)

tf->tf_eip = elf->e_entry; // ELF 文件头里记录的程序入口 (e_entry)

  

// 4. 设置标志寄存器 (EFLAGS)

tf->tf_eflags = FL_IF; // 重要！开启中断响应 (Interrupt Flag = 1)

```

### 3.2 问题回答

*   **TrapFrame 中的 values 分别反映了什么？**

    *   **`tf_cs` / `tf_ds` ... = USER_DS/CS**：反映了**特权级的切换**。当 `iret` 指令执行时，CPU 会检查 CS 的低两位 (RPL)，发现是 3，于是将 CPL (当前特权级) 从 0 切换到 3，完成“下海”过程。

    *   **`tf_esp` = USTACKTOP**：反映了**用户栈的布局**。用户程序的局部变量存储和函数调用栈帧管理都将基于此地址。

    *   **`tf_eip` = elf->e_entry**：反映了**控制流的转移**。CPU 知道下一条指令该去哪里取。

    *   **`tf_eflags` = FL_IF**：反映了**并发模型**。允许中断意味着该进程可以被时钟中断打断，从而支持多任务抢占式调度。

## 4. 练习 2：父进程复制自己的内存空间给子进程 (do_fork)

`do_fork` 实现了进程的克隆。

### 4.1 `do_fork` 代码深度解析

**1. 初始化 PCB (`alloc_proc`)**

我们在 `alloc_proc` 中补充了 Lab 5 所需的初始化：
```c

proc->wait_state = 0; // 初始化等待状态

proc->cptr = proc->optr = proc->yptr = NULL; // 初始化家族关系指针

```

**2. 核心克隆流程**

```c

// 1. 分配 PCB

proc = alloc_proc();

  

// 2. 分配内核栈

setup_kstack(proc);

  

// 3. 复制内存空间 (copy_mm)

// 这一步会根据 clone_flags 决定是共享 (CLONE_VM) 还是复制。

// 在 fork 语义下，我们需要复制。copy_mm -> dup_mmap -> copy_range

copy_mm(clone_flags, proc);

  

// 4. 复制上下文 (copy_thread)

// 将父进程的 TrapFrame 复制给子进程，但把返回值 eax 设为 0 (子进程 fork 返回 0)

copy_thread(proc, stack, tf);

  

// 5. 建立家族关系 (set_links)

// 将子进程加入 hash_list 和 proc_list

// 设置 proc->parent = current

// 维护 cptr (长子), yptr (弟弟), optr (哥哥) 的链表关系

set_links(proc);

  

// 6. 唤醒子进程

wakeup_proc(proc);

```
**3. 内存复制 (`copy_range`) 的基础实现**

在 Challenge 之前，我们使用的是全量复制：

```c

void *src_kvaddr = page2kva(page);

void *dst_kvaddr = page2kva(npage);

memcpy(dst_kvaddr, src_kvaddr, PGSIZE); // 直接内存拷贝

page_insert(to, npage, start, perm); // 建立映射

```
### 4.2 问题回答
*   **如何设计实现 ”Copy on Write (COW)“？**

    *   **设计思路**：利用页表的权限控制机制。`fork` 时不复制物理页，只复制页表项，并把父子双方的页表项都设为**只读 (Read-Only)**。

    *   **触发机制**：当任一方尝试**写**这些页面时，CPU 触发 Page Fault (错误码包含 Write 位)。

    *   **处理机制**：内核在缺页异常处理函数中，检测到这是 COW 页面，于是分配新页、复制内容、恢复写权限、更新页表。

## 5. 练习 3：进程生命周期管理 (wait/exit)
### 5.1 `do_wait` 解析

`do_wait` 的核心在于**查找**和**睡眠**。

```c

// 查找子进程

if (pid == 0) {

    // 遍历所有子进程：从长子 cptr 开始，顺着 optr (哥哥) 往回找

    proc = current->cptr;

    for (; proc != NULL; proc = proc->optr) {

        // ...

    }

}

```

如果找到了子进程，但它还没死 (`state != PROC_ZOMBIE`)：

```c

current->state = PROC_SLEEPING; // 1. 改变状态

current->wait_state = WT_CHILD; // 2. 标记原因：正在等孩子

schedule(); // 3. 主动让出 CPU，进入睡眠

// ... 当被唤醒后，代码从这里继续执行，跳转回循环头部重新检查

```

### 5.2 `do_exit` 解析

`do_exit` 的核心在于**释放**和**通知**。

  

1.  **释放资源**：`mm_destroy(mm)` 释放页表和虚拟内存结构。此时进程变成了“空壳”，只剩下 PCB 和内核栈。

2.  **变僵尸**：`current->state = PROC_ZOMBIE`。

3.  **唤醒父进程**：

```c
    struct proc_struct *parent = current->parent;

    if (parent->wait_state == WT_CHILD) {

        wakeup_proc(parent); // 叫醒正在 do_wait 中睡眠的父进程

    }
```

4.  **过继孤儿**：如果当前进程有子进程，必须把它们过继给 `initproc`，否则这些子进程死后将无人回收，变成“孤儿僵尸”。

  

### 5.3 问题回答

  

*   **do_exit 和 do_wait 如何配合？**

    *   它们构成了一个**同步闭环**。`do_exit` 是进程生命的终点，但它保留了最后的 `exit_code` 和 PCB 结构。`do_wait` 是父进程的责任点，它负责读取 `exit_code` 并释放这最后的 PCB 内存。

    *   这种配合确保了：

        1.  父进程能获知子进程的结果。

        2.  系统资源（PCB、内核栈）最终能被完全回收，防止内存泄漏。

  

## 6. 扩展练习 Challenge：Copy on Write (COW) 实现

  

在本实验中，我们成功实现了 COW 机制，极大地优化了 `fork` 的效率。

  

### 6.1 实现步骤详解

  

**Step 1: 修改缺页异常处理 (`kern/mm/vmm.c: do_pgfault`)**

我们需要让内核识别出“写只读页面”这种看似非法的行为，其实是合法的 COW 触发。

  

```c

// 在 do_pgfault 中添加

if ((error_code & 2) && (*ptep & PTE_P)) { // 写操作 && 页面存在

    struct vma_struct *vma = find_vma(mm, addr);

    // 关键判断：VMA 说是可写的，但页表是只读的 -> 判定为 COW

    if (vma != NULL && (vma->vm_flags & VM_WRITE)) {

        cprintf("COW: allocated real page for addr 0x%x\n", addr);

        // 1. 获取旧物理页

        struct Page *page = pte2page(*ptep);

        // 2. 分配新物理页

        struct Page *npage = alloc_page();

        // 3. 复制内容 (内核虚拟地址层面的 memcpy)

        memcpy(page2kva(npage), page2kva(page), PGSIZE);

        // 4. 建立新映射，并恢复 PTE_W 写权限

        page_insert(mm->pgdir, npage, addr, (*ptep & PTE_USER) | PTE_W);

        return 0; // 处理成功，CPU 将重新执行写指令

    }

}

```

  

**Step 2: 修改内存复制逻辑 (`kern/mm/pmm.c: copy_range`)**

在 `fork` 阶段，不再复制物理页，而是建立只读共享映射。

  

```c

if (share) {

    // 父子进程映射同一物理页，且都去除 PTE_W 权限

    page_insert(from, page, start, perm & (~PTE_W));

    page_insert(to, page, start, perm & (~PTE_W));

}

```

  

**Step 3: 启用 COW**

在 `kern/mm/vmm.c` 的 `dup_mmap` 函数中，将调用 `copy_range` 的参数 `share` 设为 `1`。

  

### 6.2 实验验证与结果

  

我们通过 `make qemu` 运行了 `exit` 测试程序，并捕获了 COW 触发的日志。

  

**验证逻辑**：

1.  父进程 `fork` 后，其栈变为只读。

2.  父进程尝试写栈，触发 Page Fault -> 打印 `COW: allocated...` -> 分配新栈页。

3.  子进程运行，尝试写栈，再次触发 Page Fault -> 打印 `COW: allocated...` -> 分配新栈页。

  

**运行结果**：

![[lab5.png]]
```

use SLOB allocator
kmalloc_init() succeeded!
check_vma_struct() succeeded!
page fault at 0x00000100: K/W [no page found].
check_pgfault() succeeded!
check_vmm() succeeded.
ide 0:      10000(sectors), 'QEMU HARDDISK'.
ide 1:     262144(sectors), 'QEMU HARDDISK'.
SWAP: manager = fifo swap manager
++ setup timer interrupts
kernel_execve: pid = 2, name = "exit".
I am the parent. Forking the child...
I am parent, fork a child pid 3
I am the parent, waiting now..
I am the child.
waitpid 3 ok.
exit pass.
all user-mode processes have quit.
init check memory pass.
kernel panic at kern/process/proc.c:439:
    initproc exit.

Welcome to the kernel debug monitor!!
Type 'help' for a list of commands.

```

这证明了我们的 COW 机制在真实的进程运行中被正确触发并处理，实现了写时复制的功能。

## 7. 实验总结

  

本次 Lab 5 实验是我们从“内核线程”迈向“用户进程”的关键一步。通过亲手实现 `fork`, `exec`, `wait`, `exit` 这一整套生命周期管理机制，我对操作系统如何管理进程有了从抽象到具象的认识。

  

**核心收获**：

1.  **特权级切换的祛魅**：以前觉得 Ring 0 到 Ring 3 的切换很神秘，通过 `load_icode` 中对 `TrapFrame` 的手动构建，我真正理解了“伪造中断现场”这一核心技巧。操作系统通过控制栈上的 CS/EIP/ESP，精准地操纵了 CPU 的执行流和权限。

2.  **内存管理的进阶**：在 Challenge 环节，我实现了 Copy on Write。这个过程让我深刻体会到了“软硬协同”的威力——利用硬件的页表权限机制（只读位）来触发软件的异常处理（Page Fault），从而实现高效的资源管理。这不仅优化了性能，更让我对虚拟内存的惰性分配思想有了直观的理解。

3.  **系统调试的感悟**：在实验初期，我们遇到了 `default_pmm.c` 中的内存分配断言失败。这让我意识到操作系统是一个高度耦合的系统，Lab 5 的进程管理完全依赖于 Lab 2 的物理内存管理。修复底层 Bug 的过程（First-Fit 排序逻辑）虽然痛苦，但对于理解系统整体稳定性至关重要。

  

**一点思考**：

uCore 的进程模型虽然简化，但已经包含了现代操作系统的核心骨架。通过这次实验，我发现操作系统的设计往往是在“隔离”与“共享”之间寻找平衡：通过页表实现隔离，通过 COW 实现共享。这种设计哲学在计算机系统的各个层面都具有普适性。