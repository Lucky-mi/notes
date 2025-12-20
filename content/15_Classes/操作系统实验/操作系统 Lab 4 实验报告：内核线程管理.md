
**实验时间：** 2025年12月17日  
**实验环境：** wsl (QEMU + GCC)

## 一、 实验目的

1.  了解内核线程创建/执行的管理过程。
2.  了解内核线程与用户进程的区别与联系。
3.  熟悉利用 `do_fork` 创建新内核线程的流程。
4.  掌握内核线程上下文切换 (`context switch`) 的机制。

## 二、 实验内容与练习

本次实验主要在 `kern/process/proc.c` 中完成 `alloc_proc` 和 `do_fork` 函数，并分析 `proc_run` 的执行过程。

### 练习 1：分配并初始化进程控制块 (`alloc_proc`)

**任务描述：**  
`alloc_proc` 函数负责分配一个新的 `proc_struct` 结构，并对其成员变量进行必要的初始化。这是创建进程的第一步。

**代码实现 (`kern/process/proc.c`)：**

```c
static struct proc_struct *
alloc_proc(void) {
    struct proc_struct *proc = kmalloc(sizeof(struct proc_struct));
    if (proc != NULL) {
        // 初始化进程状态为未初始化
        proc->state = PROC_UNINIT;
        // PID 初始化为 -1，表示尚未分配有效 ID
        proc->pid = -1;
        proc->runs = 0;
        proc->kstack = 0;
        proc->need_resched = 0;
        proc->parent = NULL;
        proc->mm = NULL;
        // 清空上下文结构，这是后续 switch_to 的关键
        memset(&(proc->context), 0, sizeof(struct context));
        proc->tf = NULL;
        // 内核线程共享内核页表，故 cr3 指向 boot_cr3
        proc->cr3 = boot_cr3;
        proc->flags = 0;
        // 清空进程名
        memset(proc->name, 0, PROC_NAME_LEN);
    }
    return proc;
}
```

**设计思路与问题回答：**

*   **`struct context context` 的作用：**  
    `context` 用于保存进程在进行上下文切换（Context Switch）时的寄存器状态。当内核调度器决定暂停当前进程并运行新进程时，会调用 `switch_to`。`switch_to` 会将当前 CPU 的寄存器（如 `eip`, `esp`, `ebx`, `ebp` 等 callee-saved 寄存器）保存到当前进程的 `context` 中，并将新进程 `context` 中的值恢复到 CPU 寄存器中。其中 `context.eip` 至关重要，它决定了新进程被切换回来后从哪里开始执行（对于新创建的线程，通常指向 `forkret`）。

*   **`struct trapframe *tf` 的作用：**  
    `trapframe` 保存了进程在发生中断、异常或系统调用时刻的 CPU 现场（包括所有通用寄存器、段寄存器、EFLAGS、ESP、EIP 等）。  
    在 `do_fork` 创建新线程时，我们需要构造一个假的 `trapframe` 放在新线程内核栈的顶部。这是为了模拟新线程是“从中断返回”的。当线程第一次被调度运行时，它从 `forkret` 开始执行，`forkret` 会调用 `forkrets(tf)`，最终通过 `iret` 指令利用这个 `tf` 跳转到线程真正的入口函数（如 `kernel_thread_entry` -> `init_main`）。

### 练习 2：为新创建的内核线程分配资源 (`do_fork`)

**任务描述：**  
`do_fork` 是创建新进程/线程的核心函数。它负责分配 PCB、内核栈，复制内存管理结构（对于内核线程是共享），设置上下文，并将新进程加入调度队列。

**代码实现 (`kern/process/proc.c`)：**

```c
int
do_fork(uint32_t clone_flags, uintptr_t stack, struct trapframe *tf) {
    int ret = -E_NO_FREE_PROC;
    struct proc_struct *proc;
    if (nr_process >= MAX_PROCESS) {
        goto fork_out;
    }
    ret = -E_NO_MEM;

    // 1. 分配进程控制块
    if ((proc = alloc_proc()) == NULL) {
        goto fork_out;
    }

    // 设置父进程
    proc->parent = current;

    // 2. 分配内核栈 (8KB)
    if (setup_kstack(proc) != 0) {
        goto bad_fork_cleanup_proc;
    }

    // 3. 复制/共享内存管理信息 (Lab4中内核线程共享内核空间，此函数仅做占位或简单处理)
    if (copy_mm(clone_flags, proc) != 0) {
        goto bad_fork_cleanup_kstack;
    }

    // 4. 设置中断帧和上下文 (关键步骤)
    // 这里会设置 proc->context.eip = forkret，并构造栈顶的 trapframe
    copy_thread(proc, stack, tf);

    // 5. 将新进程加入全局链表 (临界区保护)
    bool intr_flag;
    local_intr_save(intr_flag); // 关中断
    {
        proc->pid = get_pid();  // 获取唯一 PID
        hash_proc(proc);        // 加入哈希表
        list_add(&proc_list, &(proc->list_link)); // 加入进程链表
        nr_process ++;
    }
    local_intr_restore(intr_flag); // 开中断

    // 6. 唤醒新进程，将其状态设为 RUNNABLE
    wakeup_proc(proc);

    // 7. 返回子进程 PID
    ret = proc->pid;

fork_out:
    return ret;

bad_fork_cleanup_kstack:
    put_kstack(proc);
bad_fork_cleanup_proc:
    kfree(proc);
    goto fork_out;
}
```

**设计思路与问题回答：**

*   **唯一 PID 的分配 (`get_pid`)：**  
    `get_pid` 函数维护了一个静态变量 `last_pid` 和 `next_safe`。它通过遍历 `proc_list` 链表来确保分配的 PID 是全局唯一的。如果当前候选 PID 已经被占用，它会递增并重新搜索，直到找到一个未被使用的 ID。
*   **为什么要关中断？**  
    在将新进程加入 `proc_list` 和 `hash_list`，以及更新 `nr_process` 计数的过程中，涉及对全局共享数据结构的修改。如果在修改过程中发生中断，调度器可能会访问这些处于中间状态的链表，导致系统崩溃或逻辑错误。使用 `local_intr_save` 可以在这段临界区代码执行期间屏蔽中断，保证操作的原子性。

### 练习 3：阅读代码，理解 `proc_run` 和上下文切换

`proc_run` 函数用于将 CPU 的控制权从 `current` 进程切换到 `proc` 进程。

```c
void proc_run(struct proc_struct *proc) {
    if (proc != current) {
        bool intr_flag;
        struct proc_struct *prev = current, *next = proc;
        local_intr_save(intr_flag); // 切换过程必须关中断
        {
            current = proc;
            // 1. 加载新进程的内核栈底地址到 TSS.esp0
            // 这样下次从用户态陷入内核态时，CPU 知道切换到哪个栈
            load_esp0(next->kstack + KSTACKSIZE);
            
            // 2. 切换页表基址寄存器 CR3
            // 对于内核线程，cr3 都是 boot_cr3，这步实际上没变，但在用户进程切换时至关重要
            lcr3(next->cr3);
            
            // 3. 执行真正的上下文切换
            switch_to(&(prev->context), &(next->context));
        }
        local_intr_restore(intr_flag);
    }
}
```

**执行过程分析：**
1.  **保存现场：** `switch_to` 是一段汇编代码。它首先将当前进程（`prev`）的 callee-saved 寄存器推入当前栈中，并将栈顶指针保存到 `prev->context.esp`。
2.  **切换栈：** 将 `next->context.esp` 加载到 CPU 的 ESP 寄存器。这一步完成了进程栈的切换。
3.  **恢复现场：** 从新的栈中弹出 `next` 进程之前保存的寄存器值。
4.  **跳转执行：** `switch_to` 最后执行 `ret` 指令。由于栈已经被切换，栈顶现在存放的是 `next->context.eip`（对于新进程是 `forkret`）。CPU 将跳转到该地址执行。

---

## 三、 实验中遇到的严重 Bug 与环境修复 (Debug Highlight)

在完成 Lab 4 核心代码后，系统启动时出现了严重的崩溃和行为异常。通过深入的调试，我们发现实验环境的基础设施（Lab 1-3 的部分代码）存在严重缺陷。以下是排查与修复过程记录：

### 1. 链接脚本缺失导致全局变量未初始化 (The Linker Script Bug)

*   **现象：** 系统启动日志显示 `memory management: (null)`。经调试发现，物理内存管理器 `default_pmm_manager` 结构体虽然有地址，但其成员（`name` 指针, `init` 函数指针）全为 0。
*   **原因分析：** 现代 GCC 编译器在某些优化级别下，会将包含指针初始化的全局变量放入 `.data.rel.local` 段。然而，`tools/kernel.ld` 链接脚本中 `.data` 段的定义仅包含 `*(.data)`，漏掉了 `*(.data.*)`。导致这些段被链接器处理为“孤儿段”，放置在 `edata` 符号之后，并在 BSS 清零或加载过程中丢失了数据。
*   **修复方法：** 修改 `tools/kernel.ld`，在 `.data` 段定义中显式包含所有 data 子段：
    ```ld
    .data : {
        *(.data)
        *(.data.*)
    }
    ```

### 2. 物理内存管理器的逻辑错误 (The PMM Bug)

*   **现象：** 系统 Panic 报错 `assertion failed: (p0 = alloc_pages(5)) != NULL`。尽管有 128MB 空闲内存，但无法分配连续的 5 页。
*   **原因分析：** `kern/mm/default_pmm.c` 中的 First-Fit 算法实现有两个严重问题：
    1.  **分配破坏有序性：** `default_alloc_pages` 在分割大块内存后，将剩余部分简单地用 `list_add` 插入链表头。这破坏了空闲链表的地址有序性。
    2.  **合并逻辑失效：** `default_free_pages` 依赖链表有序来进行前后块合并。由于分配器破坏了顺序，导致释放内存时产生大量无法合并的外部碎片。
*   **修复方法：**
    *   重写 `default_alloc_pages`：在分割内存块时，将剩余部分插入到原节点的位置（保持原有相对顺序），并确保正确设置 `PageProperty`。
    *   重写 `default_free_pages`：实现严格的有序插入，并检查前后相邻块进行合并。

### 3. TLB 未刷新导致的 Page Fault 缺失 (The TLB Bug)

*   **现象：** 在 `check_pgfault` 自检中，Panic 报错 `freeing page ... assertion failed: !PageReserved(p)`。调试发现 `pgdir[0]` 为 0，导致系统错误地释放了物理地址 0 (保留页)。原因是在之前的测试中 `boot_pgdir[0]` 被清零，但此时**并没有**触发 Page Fault 来重建映射。
*   **原因分析：** 在 `pmm_init` 的 `check_boot_pgdir` 函数中，代码手动修改了页表 (`boot_pgdir[0] = 0`) 来取消临时映射，但**忘记刷新 TLB**。导致 CPU 的 TLB 中依然缓存着旧的映射关系，后续对该地址的访问直接命中 TLB 而未触发缺页异常 (`do_pgfault`)，因此页表未按预期重建。
*   **修复方法：** 在 `kern/mm/pmm.c` 的 `check_boot_pgdir` 和 `check_pgdir` 函数末尾，修改页表后强制刷新 TLB：
    ```c
    boot_pgdir[0] = 0;
    tlb_invalidate(boot_pgdir, 0x0); // 修复点
    ```

## 四、 实验结果

在完成上述代码编写和环境修复后，运行 `make qemu`，系统成功完成了所有内存管理自检，并成功创建调度了 `init` 内核线程。

**最终运行截图日志：**
![[{49A750CE-DC9A-4DEC-BFED-7CDA95F546BA}.png]]
```q
(THU.CST) os is loading ...

Special kernel symbols:
  entry  0xc010002a (phys)
  etext  0xc010a7ce (phys)
  edata  0xc010fafc (phys)
  end    0xc0112c74 (phys)
Kernel executable memory footprint: 76KB
pmm_manager addr: c010fa90
pmm_manager->name addr: c010b39c
pmm_manager->init addr: c01035e5
memory management: default_pmm_manager
e820map:
  memory: 0009fc00, [00000000, 0009fbff], type = 1.
  memory: 00000400, [0009fc00, 0009ffff], type = 2.
  memory: 00010000, [000f0000, 000fffff], type = 2.
  memory: 07ee0000, [00100000, 07fdffff], type = 1.
  memory: 00020000, [07fe0000, 07ffffff], type = 2.
  memory: 00040000, [fffc0000, ffffffff], type = 2.
check_alloc_page() succeeded!
check_pgdir() succeeded!
check_boot_pgdir() succeeded!
-------------------- BEGIN --------------------
PDE(0e0) c0000000-f8000000 38000000 urw
  |-- PTE(38000) c0000000-f8000000 38000000 -rw
PDE(001) fac00000-fb000000 00400000 -rw
  |-- PTE(000e0) faf00000-fafe0000 000e0000 urw
  |-- PTE(00001) fafeb000-fafec000 00001000 -rw
--------------------- END ---------------------
use SLOB allocator
kmalloc_init() succeeded!
check_vma_struct() succeeded!
page fault at 0x00000100: K/W [no page found].
check_pgfault() succeeded!
check_vmm() succeeded.
ide 0:      10000(sectors), 'QEMU HARDDISK'.
ide 1:     262144(sectors), 'QEMU HARDDISK'.
SWAP: manager = fifo swap manager
BEGIN check_swap: count 1, total 31977
setup Page Table for vaddr 0X1000, so alloc a page
setup Page Table vaddr 0~4MB OVER!
set up init env for check_swap begin!
page fault at 0x00001000: K/W [no page found].
page fault at 0x00002000: K/W [no page found].
page fault at 0x00003000: K/W [no page found].
page fault at 0x00004000: K/W [no page found].
set up init env for check_swap over!
write Virt Page c in fifo_check_swap
write Virt Page a in fifo_check_swap
write Virt Page d in fifo_check_swap
write Virt Page b in fifo_check_swap
write Virt Page e in fifo_check_swap
page fault at 0x00005000: K/W [no page found].
swap_out: i 0, store page in vaddr 0x1000 to disk swap entry 2
write Virt Page b in fifo_check_swap
write Virt Page a in fifo_check_swap
page fault at 0x00001000: K/W [no page found].
swap_out: i 0, store page in vaddr 0x2000 to disk swap entry 3
swap_in: load disk swap entry 2 with swap_page in vadr 0x1000
write Virt Page b in fifo_check_swap
page fault at 0x00002000: K/W [no page found].
swap_out: i 0, store page in vaddr 0x3000 to disk swap entry 4
swap_in: load disk swap entry 3 with swap_page in vadr 0x2000
write Virt Page c in fifo_check_swap
page fault at 0x00003000: K/W [no page found].
swap_out: i 0, store page in vaddr 0x4000 to disk swap entry 5
swap_in: load disk swap entry 4 with swap_page in vadr 0x3000
write Virt Page d in fifo_check_swap
page fault at 0x00004000: K/W [no page found].
swap_out: i 0, store page in vaddr 0x5000 to disk swap entry 6
swap_in: load disk swap entry 5 with swap_page in vadr 0x4000
write Virt Page e in fifo_check_swap
page fault at 0x00005000: K/W [no page found].
swap_out: i 0, store page in vaddr 0x1000 to disk swap entry 2
swap_in: load disk swap entry 6 with swap_page in vadr 0x5000
write Virt Page a in fifo_check_swap
page fault at 0x00001000: K/R [no page found].
swap_out: i 0, store page in vaddr 0x2000 to disk swap entry 3
swap_in: load disk swap entry 2 with swap_page in vadr 0x1000
count is 0, total is 5
check_swap() succeeded!
++ setup timer interrupts
this initproc, pid = 1, name = "init"
To U: "Hello world!!".
To U: "en.., Bye, Bye. :)"
kernel panic at kern/process/proc.c:356:
    process exit!!.

Welcome to the kernel debug monitor!!
Type 'help' for a list of commands.
```

输出显示 `init` 线程正确打印了 "Hello world!!"，证明 Lab 4 实验圆满完成。

## 五、 实验总结

本次实验不仅让我掌握了 `alloc_proc` 和 `do_fork` 的实现细节，理解了内核线程从创建到调度的完整生命周期，更重要的是通过排查环境 Bug，深刻体会到了操作系统各个组件之间的紧密依赖关系：
1.  **编译链接的重要性：** 链接脚本微小的疏忽可能导致程序数据布局错误，引发难以调试的逻辑问题。
2.  **内存管理的基石作用：** PMM 的碎片问题会直接影响上层逻辑的正确性。
3.  **硬件缓存的一致性：** 页表修改后必须维护 TLB 一致性，否则 CPU 会使用过期的地址翻译，导致极其隐蔽的错误。
