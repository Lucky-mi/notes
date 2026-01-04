#并行必考 
# 第一部分：OpenMP 简介与 Fork-Join 执行模型 (PPT 4-5)

### 1. 核心概念：什么是 OpenMP？(PPT P4)

**一句话定义**：OpenMP 是面向**共享存储系统 (Shared Memory Systems)** 的一套并行编程模型 。

- **架构师视角的解读**：
    
    - 它不是一种新的语言，而是对现有语言（Fortran, C, C++）的扩展 。
        
    - 它专门用于**多核 CPU** 并行（不同于 CUDA 这种 GPU 并行，也不同于 MPI 这种分布式内存并行）。这意味着所有线程都可以访问同一块内存（Shared Memory）。
        
    - **组成三要素**（考试必考点）：
        
        1. **编译制导语句 (Compiler Directives)**：代码里的 `#pragma omp ...`，告诉编译器哪里需要并行。
            
        2. **运行时库函数 (Runtime Library Routines)**：代码里的 `omp_get_thread_num()` 等，用于程序运行时控制。
            
        3. **环境变量 (Environment Variables)**：控制台里的 `export OMP_NUM_THREADS=4`，用于在该程序启动前配置环境。
            
- **优点** ：
    
    - **增量化并行**：你可以写好串行程序，然后一行行加 `#pragma` 让它逐步并行，不需要推倒重来（这是它最大的优势）。
        
    - **可移植性好**：代码在单核机器上也能跑（编译器忽略 `#pragma` 即可）。
        

### 2. 执行模型：Fork-Join 模型 (PPT P5)

这是 OpenMP 的灵魂。请看下图理解这个过程：

- **主线程 (Master Thread)**：程序启动时，只有一个线程在运行，我们叫它主线程（ID 通常为 0）。
    
- **Fork (分叉)**：当主线程遇到 **并行域 (Parallel Region)** 时，它会“派生”出一组线程（Team of threads）。
    
    - _注意_：这里利用了**线程池技术 (Thread Pool)** 。这意味着线程可能在程序启动时就已经创建好了，Fork 只是“唤醒”它们，而不是每次都昂贵地调用 OS 的 `pthread_create`。
        
- **Parallel Execution (并行执行)**：所有线程（主线程 + 派生线程）同时执行并行域内的代码。
    
- **Join (汇合)**：在并行域结束时，所有派生线程挂起或销毁，控制权回到主线程手中，继续串行执行 。
    

---

### 🎯 期末考题预测

根据这两页内容，期末考试极有可能出现以下题型：

**1. 选择题/填空题**

- **题目**：OpenMP 程序执行采用的是 ______ 模型。
    
    - **答案**：Fork-Join (或 分叉-汇合)
        
- **题目**：OpenMP 是基于 ______ 存储体系结构的并行编程模型。
    
    - A. 分布式 (Distributed)
        
    - B. 共享 (Shared)
        
    - C. 混合 (Hybrid)
        
    - **答案**：B
        
- **题目**：以下哪项**不是** OpenMP 的组成部分？
    
    - A. 编译制导语句
        
    - B. 运行时库函数
        
    - C. 消息传递接口 (MPI)
        
    - D. 环境变量
        
    - **答案**：C
        

**2. 简答题 (高频)**

- **题目**：简述 OpenMP 的 Fork-Join 执行模式，并说明“线程池技术”在这里起到了什么作用？
    
    - **参考答案要点**：
        
        1. 程序开始时只有主线程串行执行。
            
        2. 遇到并行域时，主线程 Fork 出一组线程并行执行任务。
            
        3. 并行域结束后，线程 Join，恢复主线程串行。
            
        4. **线程池作用**：线程在程序启动时创建或复用，Fork 时只需唤醒，避免了操作系统频繁创建和销毁线程的巨大开销，提高性能。

# 第二部分：OpenMP 程序示例与基础语法 (PPT 6-8)

这部分展示了最基础的 "Hello World" 程序。虽然代码简单，但包含了 OpenMP 编程的四大基石：**头文件、编译制导语句、数据属性子句、运行时库函数**。

### 1. C 语言程序结构详解 (PPT P6)

这是标准的 C 语言 OpenMP 程序模板。请注意代码中的注释部分，这些是核心考点。
```c
#include <omp.h>   // [考点1] 必须包含 OpenMP 头文件
#include <stdio.h>

int main() {
    int nthreads, tid;

    /* * [考点2] 编译制导语句格式：
     * #pragma omp <directive> [clause ...]
     * * parallel: 指定接下来的代码块为并行域
     * private(nthreads, tid): 数据属性子句，声明这两个变量是"私有的"
     */
    #pragma omp parallel private(nthreads, tid)
    {
        // [考点3] 运行时库函数：获取当前线程号 (0 到 N-1)
        tid = omp_get_thread_num();
        
        printf("Hello World from OpenMP thread %d\n", tid);

        // 只有 0 号线程（主线程）执行打印线程总数的操作
        if (tid == 0) {
            // [考点3] 运行时库函数：获取线程总数
            nthreads = omp_get_num_threads();
            printf("Number of threads %d\n", nthreads);
        }
    } // 并行域结束，所有线程在此同步（Join）

    return 0;
}
```

#### 关键知识点深度解析

1. **标识符 `#pragma omp`**：
    
    - 所有的 OpenMP 指令在 C/C++ 中都以 `#pragma omp` 开头。
        
    - **作用**：如果是支持 OpenMP 的编译器，它会处理这一行；如果是不支持的编译器，它会直接忽略这一行（当作普通注释），保证了代码的可移植性。
        
2. **`private(nthreads, tid)` 的含义（难点）**：
    
    - **为什么要设为私有？**
        
        - 如果不加 `private`，默认情况下 `tid` 变量是**共享**的。
            
        - 如果共享，线程 A 刚把 `tid` 赋值为 1，还没来得及打印，线程 B 就把 `tid` 改成了 2。那么线程 A 打印出来的也是 2，这就叫**数据竞争 (Data Race)**。
            
    - **私有的效果**：每个线程都在自己的栈空间里复制了一份 `nthreads` 和 `tid`，互不干扰。
        
3. **编译命令**：
    
    - GCC 编译器：`gcc -fopenmp hello.c` (考研或上机考试常考参数 `-fopenmp`)
        
    - Intel 编译器：`icc -openmp hello.c`
        

### 2. 程序执行结果分析 (PPT P7)

PPT 展示了类似以下的输出结果：
```
Hello World from OpenMP thread 2
Hello World from OpenMP thread 0
Number of threads 4
Hello World from OpenMP thread 3
Hello World from OpenMP thread 1
```

#### 现象与本质（重要）

- **乱序输出**：你会发现线程 0, 1, 2, 3 的打印顺序是**随机**的，甚至每次运行都不一样。
    
    - **原因**：操作系统的线程调度是不确定的。
        
- **逻辑确定性**：虽然打印顺序乱了，但 `Number of threads 4` 这句话一定是由线程 0 打印的（因为有 `if(tid==0)` 判断），且线程号一定是 0~3 各出现一次。
    

### 3. Fortran 程序示例 (PPT P8)

虽然你是计算机系主要用 C/C++，但 PPT 提到了 Fortran，为了不遗漏知识点，我们简单看一下区别（考试通常只考 C，但也可能考选择题区分语法）：

- **标识符**：C 是 `#pragma omp`，Fortran 是 `!$omp`。
    
- **库模块**：C 是 `#include <omp.h>`，Fortran 是 `use omp_lib`。
    
- **结构**：Fortran 需要显式的 `!$omp end parallel` 来结束并行域，而 C 依靠花括号 `{}`。
    

---

### 🎯 期末考题预测

**1. 代码改错题 (高频)**

- **题目**：以下代码有什么严重问题？
    ```c
    int tid;
    #pragma omp parallel
    {
        tid = omp_get_thread_num();
        printf("Thread %d\n", tid);
    }
    ```
    
- **答案**：**数据竞争**。变量 `tid` 在并行域外定义，默认为共享变量。多个线程同时写入同一个 `tid` 内存地址，导致逻辑错误。
    
- **修改**：应改为 `#pragma omp parallel private(tid)` 或在并行域内部定义 `int tid;`。
    

**2. 填空题**

- 在 Linux 环境下使用 gcc 编译 OpenMP 程序，需要添加的参数是 `________`。
    
    - **答案**：`-fopenmp`
        
- 获取当前执行线程编号的函数是 `________`，获取当前并行域中线程总数的函数是 `________`。
    
    - **答案**：`omp_get_thread_num()`，`omp_get_num_threads()`
        

**3. 简答题**

- **题目**：为什么 OpenMP 程序多次运行的输出顺序可能不同？
    
    - **答案**：因为并行域内的多个线程是由操作系统并发调度的，线程之间的执行快慢和先后顺序是不确定的（非确定性），取决于 CPU 的负载和调度策略。

### 🔍 核心概念：结构块 (Structured Block)

根据 PPT 定义，**结构块**是指：**“仅有一个入口（顶端）和一个出口（底端）的一块语句，没有跳转到块外的分支”** 。

- **例外**：只有 `exit()` (C/C++) 或 `STOP` (Fortran) 是允许的，因为它们直接结束整个程序进程 。
    
---

### 🐞 Goto Bug 深度解析

为什么我在并行域里写 `goto` 会出 Bug？这要从**“编译器实际上做了什么”**说起。

当你写下 `#pragma omp parallel` 时，编译器并不是简单地把代码放进去，它在背后做了大量**“隐式”工作**：

1. **入口处 (Setup)**：初始化线程池、分配线程私有栈空间、设置共享变量映射。
    
2. **出口处 (Teardown)**：设置**隐式同步点 (Implicit Barrier)**，等待所有线程到达，回收资源，合并数据。
    

#### 1. 禁止跳入 (Illegal Jump In)

如果你用 `goto` 从并行域**外面**直接跳到**里面**：

- **Bug 现象**：程序崩溃（Segfault）或行为未定义。
    
- **原因**：你绕过了“入口处”的 Setup 过程。线程没有被创建，上下文环境没建立，变量内存没分配。就像你没买票直接空降到电影院座位上，保安（操作系统）会把你踢出去。
    

#### 2. 禁止跳出 (Illegal Jump Out)

如果你用 `goto` 从并行域**里面**直接跳到**外面**：

- **Bug 现象**：**死锁 (Deadlock)** 或内存泄漏。
    
- **原因**：你绕过了“出口处”的 Teardown 过程。
    
    - **死锁风险**：OpenMP 要求并行域结束时所有线程都要集合（Barrier）。如果你用 `goto` 让一个线程偷偷溜了（跳出去了），其他 N-1 个线程还在傻傻地等它来集合，结果永远等不到，程序就卡死了。
        

---

### 📝 PPT 案例对比分析 (Page 12)

PPT 第 12 页给出了两个极其相似的代码片段，通过对比告诉你什么是合法的，什么是不合法的 。

#### ✅ 合法的情况 (左图：A structured block)
```c
#pragma omp parallel
{
    int id = omp_get_thread_num();
    more: res[id] = do_big_job(id); // 标号在这里
    if (conv(res[id])) goto done;   // 试图跳到 done
    else goto more;                 // 试图跳回 more
    
    done: printf("Done\n");         // 标号在这里
} 
```

- **分析**：
    
    - 这里的 `goto more` 和 `goto done` 都在**同一个**大花括号 `{ ... }` 内部。
        
    - **入口**：只有一个（`#pragma` 开始处）。
        
    - **出口**：只有一个（花括号结束处）。
        
    - 虽然内部跳来跳去，但没有跨越边界，所以是**合法**的 。
        

#### ❌ 非法的情况 (右图：Not a structured block)
```c
// ❌ 错误1：试图跳入
if (go_now()) goto more; 

#pragma omp parallel
{
    int id = omp_get_thread_num();
    // 标号在并行域内部
    more: res[id] = do_big_job(id); 
    
    // ❌ 错误2：试图跳出
    if (conv(res[id])) goto done; 
}

// 标号在并行域外部
done: if (!really_done()) goto more; 
```

- **分析**：
    
    - `goto more;` 试图从外部直接**跳入**并行域，绕过了线程初始化。
        
    - `goto done;` 试图从内部直接**跳出**并行域，绕过了隐式同步（Barrier），可能导致死锁。
        
    - 这就是 PPT 上写的 **"两个入口、一个出口"**（或者是多个出口），破坏了单一性，所以是**非法**的 。
        

---

### 🎯 考试避坑指南

如果期末考试出现 **“代码改错题”** 或 **“判断下列代码是否正确”**，看到 `goto` 关键字要立刻警觉：

1. 检查 `goto` 的目标标签（Label）是否在**同一个** `#pragma omp` 块内。
    
2. 如果在同一块内 -> **正确**。
    
3. 如果跨越了块边界（一里一外） -> **错误**（违反结构块定义）。

# 第五部分：工作共享 (Work-sharing) (PPT 17-21)

弄懂了怎么造线程（Parallel），现在我们要学怎么**指挥线程干活**。这是 OpenMP 最精华、最实用的部分。

### 1. 什么是工作共享？(PPT 18)

核心定义：

工作共享（Work-sharing）指令不产生新线程，它的作用是将一个大的任务（比如 1000 次循环），合理地切分（Divide）并分发（Distribute）给线程池里现有的线程去执行。

1 OpenMP 通过工作共享的编译制导指令将任务划分和分配给多个线程并行执行。

**三大主力指令** 2：

1. **`omp for`**：最常用！负责把 `for` 循环的迭代次数切分给线程。
    
2. **`omp sections`**：负责把几块不同的代码段（Section A, Section B...）分给不同线程。
    
3. **`omp task`** (3.0 新特性)：显式定义任务，放入队列动态调度（适合递归、不规则循环）。
    

### 2. 使用规则与“隐式栅栏” (PPT 19)

这里有两个**绝对考点**：

1. **依附性**：工作共享指令自己不造线程，所以它**必须**位于一个并行域（`#pragma omp parallel`）的内部 3。
    
    - _如果单独写 `omp for` 而外面没有 `parallel` 会怎样？_ -> 任务会被一个线程（主线程）串行执行 4。
        
2. **隐式同步 (Implicit Barrier)**：在工作共享结构块的结尾（比如 `for` 循环结束的大括号处），默认有一个隐式同步点 5。
    
    - 这意味着：跑得快的线程做完自己的那部分循环后，**不能直接溜走**，必须等所有人都做完，才能一起往下走。
        
    - _例外_：如果你想让它做完就走，必须显式加上 `nowait` 子句。
        

### 3. `omp for` 深度图解 (PPT 20)

PPT 第 20 页展示了一个经典的各种 $i$ 值分配图。

场景：假设 $N=12$（循环跑 12 次），线程池有 3 个线程。

执行流程：

1. `#pragma omp parallel`：创建线程组（假设 3 个线程）。
    
2. `#pragma omp for`：系统将 $i=1 \dots 12$ 的任务分配给它们。
    
    - **线程 0** 领走：$i = 1, 2, 3, 4$
        
    - **线程 1** 领走：$i = 5, 6, 7, 8$
        
    - **线程 2** 领走：$i = 9, 10, 11, 12$
        
3. **Implicit Barrier**：大家在终点线集合。
    

**关键特性**：

- **无依赖性**：循环的每一次迭代之间不能有依赖（比如 `a[i] = a[i-1] + 1` 是不能并行的），否则结果是错的 6。
    

### 4. 语法与简写 (PPT 21-22)

**语法格式**：
```c
#pragma omp for [clause ...]
for (int i=0; i<N; i++) { ... }
```

**常用子句 (Clauses)** 7：

- `schedule(type, chunk)`：**这是下一节的重难点**，决定了是“平均分”还是“谁抢到谁做”。
    
- `ordered`：保证某段代码按循环顺序执行。
    
- `nowait`：取消结尾的等待。
    
- `private`, `reduction` 等数据属性。
    

懒人写法 (PPT 22)：

你可以把“造线程”和“分任务”合二为一：
```c
#pragma omp parallel for
for (int i=0; i<N; i++) { ... }
```

这等价于先写 `#pragma omp parallel` 再写 `#pragma omp for`，代码更简洁 8。

---

### 💡 重点总结 (Key Points Summary)

1. **定位**：`work-sharing` 指令（如 `for`）**不创建线程**，只负责**分派任务**。必须配合 `parallel` 使用。
    
2. **隐式同步**：`omp for` 结束时默认有 Barrier，除非加 `nowait`。
    
3. **简写技巧**：`#pragma omp parallel for` 是最高频使用的语句，同时完成线程创建和循环划分。
    
4. **数据要求**：并行化的循环迭代之间**不能有数据依赖**（Data Dependency）。
    

---

### 🎯 期末考题预测

**1. 填空题**

- OpenMP 中，用于循环并行化的指令是 `________`，它必须在 `________` 构造内使用才能实现并行。
    
    - **答案**：`#pragma omp for`（或 `omp for`），`parallel`（或并行域）
        
- 在 `omp for` 结构块的末尾，默认存在一个 `________`，除非使用 `________` 子句消除它。
    
    - **答案**：隐式同步（或 Implicit Barrier），`nowait`
        

**2. 简答题 (必考)**

- **题目**：请解释 `#pragma omp parallel` 和 `#pragma omp parallel for` 的区别。
    
    - **答案**：
        
        - `#pragma omp parallel` 仅创建一个并行域（线程组），如果里面直接写 `for` 循环，每个线程都会完整执行一遍该循环（重复计算）。
            
        - `#pragma omp parallel for` 是组合指令，它先创建线程组，然后立刻将紧随其后的 `for` 循环的迭代任务划分给各个线程执行（协同计算）。
            

**3. 代码分析题**

- **题目**：如果循环中有 `a[i] = a[i-1] + b[i]`，能否直接用 `#pragma omp parallel for`？为什么？
    
    - **答案**：**不能**。因为存在**循环依赖（Loop Dependency）**。计算 `a[i]` 需要用到 `a[i-1]` 的值，如果并行执行，处理 `i` 的线程可能比处理 `i-1` 的线程跑得快，读取到错误的（旧的）`a[i-1]` 值，导致结果错误。

# 第六部分：循环调度策略 (Schedule) (PPT 23-26)

在讲调度之前，PPT 第 23 页先插播了一个非常重要的数据属性概念，为后面的并行做铺垫。

### 1. `private` 子句在循环中的应用 (PPT 23)

**核心问题**：在 `for` 循环里定义的临时变量，默认是共享的还是私有的？

- **循环控制变量 (Loop Control Variable)**：即 `for(int i=0...)` 里的 `i`。
    
    - OpenMP **默认**它是**线程私有**的 1。这很好理解，如果 `i` 是共享的，线程 A 把它加到 10，线程 B 刚读到 10 准备做计算，结果 `i` 变成 11 了，这就乱套了。
        
- **其他变量**：
    
    - 如果在并行域外部定义，在内部使用，默认是**共享 (Shared)** 的。
        
    - **必须私有化**：如果每个线程都需要一个临时的中间变量（比如 PPT 例子中的 `x, y`），必须显式用 `private(x, y)` 声明 2。
        
    - **后果**：不加 `private` 会导致严重的数据竞争（Data Race），计算结果错误。
        

---

### 2. `schedule` 子句详解 (PPT 24)

这是今天的重头戏。

**语法**：`schedule(type [, chunk_size])` 3

- **type**：调度策略（static, dynamic, guided, runtime）。
    
- **chunk_size**：块大小（可选），即一次分给线程多少个循环迭代。
    

我们一个一个拆解：

#### A. Static 调度 (静态调度) (PPT 25)

**特点**：在编译/程序启动时就分好了，**雷打不动**。

- **不带 chunk_size** (`schedule(static)`):
    
    - **分配方式**：**平均分块**。系统把总迭代次数 $N$ 除以线程数 $T$，每个人拿连续的一大块 4。
        
    - _例子_：12 个任务，3 个线程。T0 拿 [0-3]，T1 拿 [4-7]，T2 拿 [8-11]。
        
- **带 chunk_size** (`schedule(static, 4)`):
    
    - **分配方式**：**轮转分配 (Round-Robin)**。先把任务按 `chunk_size` 切成小块，然后像发扑克牌一样分给线程 5。
        
    - _例子_：任务 T0, T1, T2, T3... 轮流领。如果总任务 40，`chunk=4`，线程数 4。
        
        - 第一轮：Thread 0 领 [0-3]，Thread 1 领 [4-7]...
            
        - 第二轮：Thread 0 又领到了新的一块... 6
            

**适用场景**：每个循环迭代的计算量差不多（负载均衡），且不需要额外的调度开销。这是**开销最小**的方式。

#### B. Dynamic 调度 (动态调度) (PPT 26)

**特点**：**先到先得**，谁干得快谁多干。

- **机制**：维持一个任务队列。线程干完手里的活，就去队列里领 `chunk_size` 这么大的一块任务 7。
    
- **默认 chunk**：如果不写 `size`，默认为 1 8。
    
- **适用场景**：**负载不均衡**的情况。
    
    - _例子_：`for (i=0; i<N; i++) { do_work(i); }`，如果 `do_work(0)` 只需要 1ms，而 `do_work(1)` 需要 100ms。用 Static 可能会导致忙的线程累死，闲的线程早早没事干（饥饿）；用 Dynamic 就能让闲的线程多帮点忙。
        
- **缺点**：运行时调度有**额外开销**（线程要去抢锁领任务）。
    

#### C. Guided 调度 (启发式/向导式调度) (PPT 26)

**特点**：**先大后小**。Dynamic 的改良版。

- **机制**：刚开始分给线程的任务块很大，随着任务队列变少，分发的块越来越小，直到达到 `chunk_size` 指定的最小值（默认为 1） 9。
    
- **优点**：
    
    - 刚开始块大 -> 减少了“领任务”的次数（减少调度开销）。
        
    - 后来块小 -> 保证了最后阶段的负载均衡（避免这就剩一点任务了，还分给某一个线程一大块，导致它干不完别人都在等）。
        

#### D. Runtime 调度 (PPT 26)

**特点**：**推迟决定**。

- **机制**：代码里不写死，程序运行时读取环境变量 `OMP_SCHEDULE` 来决定 10。
    
- _Linux 命令_：`export OMP_SCHEDULE="dynamic, 4"`
    

---

### 💡 重点总结 (必背)

|**调度策略**|**分配时机**|**块大小 (Chunk)**|**开销 (Overhead)**|**适用场景**|
|---|---|---|---|---|
|**Static**|编译/启动时|固定 (默认 N/T 或指定)|**最低**|迭代计算量均匀，可预测|
|**Dynamic**|运行时|固定 (默认 1)|高|迭代计算量差异巨大|
|**Guided**|运行时|**动态递减** (默认 min=1)|中等|需要负载均衡但想减少开销|

---

### 🎯 期末考题预测 (高能预警)

**1. 计算与作图题 (必考)**

- **题目**：假设有 4 个线程（T0, T1, T2, T3），总共有 16 次循环迭代（0-15）。请分别画出或描述在 `schedule(static)` 和 `schedule(static, 2)` 下，每个线程分到的具体迭代编号。
    
- **参考答案**：
    
    - **`schedule(static)`** (平均分):
        
        - T0: 0, 1, 2, 3
            
        - T1: 4, 5, 6, 7
            
        - T2: 8, 9, 10, 11
            
        - T3: 12, 13, 14, 15
            
    - **`schedule(static, 2)`** (轮转分，块大小为2):
        
        - T0: {0, 1}, {8, 9}
            
        - T1: {2, 3}, {10, 11}
            
        - T2: {4, 5}, {12, 13}
            
        - T3: {6, 7}, {14, 15}
            

**2. 选择题**

- 对于一个计算负载极不均衡的循环（例如某些迭代极快，某些极慢），为了获得最短的执行时间，应该选择哪种调度策略？
    
    - A. `static`
        
    - B. `dynamic`
        
    - C. `master`
        
    - D. `ordered`
        
    - **答案**：B (Dynamic 能做到最好的负载均衡)。
        

**3. 简答题**

- **题目**：简述 Guided 调度相比 Dynamic 调度的优势。
    
    - **答案**：Guided 调度采用了“分块大小指数递减”的策略。开始时分发大块任务，减少了线程频繁访问任务队列的互斥锁开销（Overhead）；结束前分发小块任务，保证了各个线程能几乎同时结束，实现了良好的负载均衡。相比 Dynamic，它在保持均衡的同时降低了调度开销。

# 第七部分：工作共享 —— Sections 分段并行 (PPT 27-30)

### 1. `omp sections` 是什么？ (PPT 27-28)

**核心定义**：

`omp sections` 用于定义一个并行区域，其中包含多个 **不同的** 结构块（每个块叫一个 `section`）。这些块会被分发给线程组中的线程去执行 。

**语法结构**：
```c
#pragma omp parallel sections // 1. 创建线程并开启分段任务
{
    #pragma omp section       // 2. 定义第一个任务
    { 任务A(); }

    #pragma omp section       // 3. 定义第二个任务
    { 任务B(); }
    
    // ... 可以有任意多个 section
}
```

**执行规则（必考点）** ：

1. **一次性**：每个 `section` 仅被一个线程执行**一次**。
    
2. **分配机制**：
    
    - **线程数 > section 数**：多出来的线程会闲置（Idle），等着大家干完。
        
    - **线程数 < section 数**：有的线程干完手里的活，会接着干下一个 `section`（一个线程执行多个任务）。
        
3. **同步**：和 `omp for` 一样，`sections` 结构块结束处有**隐式栅栏 (Implicit Barrier)**，除非使用 `nowait`。
    

### 2. 实战案例：函数并行 (PPT 29-30)

PPT 30 给出了一个非常经典的**任务依赖图（Task Graph）**，这是理解并行逻辑的好例子。

**任务依赖关系** ：

- **Alice** 和 **Bob** 是独立的。
    
- **Boss** 必须等 Alice 和 Bob 都干完才能开始（依赖 A, B）。
    
- **Cy** 是独立的。
    
- **BigBoss** 必须等 Boss 和 Cy 都干完才能开始。
    

**代码实现分析** ：
```c
#pragma omp parallel sections
{
    // --- 并行阶段 ---
    // Alice, Bob, Cy 三个任务互不依赖，可以同时跑
    #pragma omp section
    a = alice();

    #pragma omp section
    b = bob();

    #pragma omp section
    c = cy();
} // <--- 隐式同步点 (Barrier)
// 关键点：这里所有线程都会等待，直到 Alice, Bob, Cy 全部执行完毕！

// --- 串行阶段 ---
// 此时 a, b, c 都计算好了，安全地执行后续依赖任务
s = boss(a, b);
result = bigboss(s, c);
```

**架构师视角的优缺点分析**：

- **优点**：代码极其简单，逻辑清晰。
    
- **缺点（性能隐患）**：
    
    - 这里有一个**不必要的等待**。注意 `Boss` 只依赖 `Alice` 和 `Bob`。如果 `Cy` 执行得特别慢，`Alice` 和 `Bob` 早就干完了，但程序还是会卡在 `sections` 的结尾等待 `Cy`。
        
    - 这导致 `Boss` 无法利用 `Cy` 还在跑的这段时间提前开始工作。这是 `sections` 这种“同步并行”模式的局限性（后面的 `omp task` 会解决这个问题）。
        

---

### 💡 重点总结 (Key Points)

1. **适用场景**：适用于**任务数固定**、且任务之间**没有顺序依赖**（或者只有简单的并行-串行依赖）的场景。
    
2. **依附性**：`omp sections` 必须放在 `omp parallel` 里面（或者直接合并写成 `#pragma omp parallel sections`）。
    
3. **区别**：
    
    - `omp for`: 同一段代码（循环体），处理不同的数据（下标 i）。（**数据并行**）
        
    - `omp sections`: 不同的代码（函数 A, 函数 B），处理不同的逻辑。（**功能并行**）
        

---

### 🎯 期末考题预测

**1. 代码填空题**

- **题目**：现有函数 `void funcA()`, `void funcB()` 和 `void funcC()`。`funcA` 和 `funcB` 可以并行执行，但 `funcC` 必须在它们都结束后才能执行。请补全 OpenMP 代码。
    
- **答案**：
    ```c
    #pragma omp parallel sections
    {
        #pragma omp section
        funcA();
        #pragma omp section
        funcB();
    } // 隐式同步，保证 A 和 B 都做完
    funcC();
    ```
    

**2. 简答/分析题**

- **题目**：如果有 4 个线程，但是代码中只定义了 3 个 `#pragma omp section`，OpenMP 运行时系统会怎么处理？
    
- **答案**：OpenMP 会分配 3 个线程分别执行这 3 个 section，剩下的 **1 个线程会处于空闲状态 (Idle)**，直到那 3 个线程执行完毕并在 `sections` 块的结尾处同步。
    

**3. 选择题**

- `omp sections` 编译制导语句主要用于实现哪种类型的并行？
    
    - A. 数据并行 (Data Parallelism)
        
    - B. 任务/功能并行 (Task/Functional Parallelism)
        
    - C. 细粒度并行
        
    - D. 指令级并行
        
    - **答案**：B

# 第八部分：任务并行 (Task Parallelism) (PPT 31-38)

### 1. 为什么需要 `omp task`？ (PPT 31)

在此之前，OpenMP 的并行非常依赖“计算量可知”和“随机访问”：

- `omp for` 需要知道循环次数 $N$，且通常用于数组（可以直接跳到第 $i$ 个元素）。
    
- 但如果你处理的是一个 **链表 (Linked List)**，你不知道它有多长，必须顺着指针一个一个找。
    
- 或者你在做 **递归**，你不知道递归树有多深。
    

这时，你需要 **任务 (Task)**：

- **定义**：任务是一个独立的工作单元。
    
- **机制**：我不指定谁来做，我只负责**产生**任务，扔到一个“任务池”里。线程池里的空闲线程（谁有空谁来）会自动去池子里抢任务执行 1。
    

### 2. 标准代码模板：生产者-消费者模式 (PPT 32-33)

这是 PPT P32 的核心代码，也是**考研/期末最喜欢考的链表并行化代码**。请务必背诵这个结构。
```c
// 假设我们要遍历一个链表并处理每个节点
#pragma omp parallel  // 1. 创建线程池（比如8个线程）
{
    // 2. 只需要一个人来发任务！否则大家一起遍历链表，任务就重复了。
    #pragma omp single private(p) 
    {
        p = head;
        while (p) {
            // 3. 显式创建一个任务
            #pragma omp task 
            {
                processwork(p); // 具体的计算任务
            }
            p = p->next; // 继续找下一个节点
        }
    } // End of single
    // 注意：这里没有隐式同步，'single' 线程发完任务可能就去干别的了
    // 或者加入到执行任务的队伍中
}
```

**逻辑解析**：

1. **Single 线程 (生产者)**：它跑得很快，它的唯一工作就是遍历链表，不断生成 `task` 扔到池子里。
    
2. **其他线程 (消费者)**：它们刚开始没事干，看到池子里有任务了，就取出来执行 `processwork(p)`。
    
3. **负载均衡**：如果某个节点的处理很慢，处理它的线程就会忙很久；处理快的线程就会多领几个任务。系统自动实现了负载均衡。
    

### 3. 任务同步：`taskwait` (PPT 34)

任务是异步的，发出去就不管了。但有时我们需要等待任务做完（比如递归求和，必须等子节点算完才能算父节点）。

- **`#pragma omp barrier`**：**重量级**。等待**所有**线程到达。太慢了，且容易死锁。
    
- **`#pragma omp taskwait`**：**轻量级**。只等待**当前任务**所产生的**直接子任务**（一级子任务）完成 2。
    

**递归并行示例（快速排序/斐波那契）：**
```c
int fib(int n) {
    int x, y;
    if (n < 2) return n;
    
    #pragma omp task shared(x) // 创建任务算 x
    x = fib(n-1);
    
    #pragma omp task shared(y) // 创建任务算 y
    y = fib(n-2);
    
    #pragma omp taskwait       // 关键！必须等 x 和 y 都算出来
    return x + y;
}
```

### 4. 进阶概念：绑定与切换 (PPT 36-38)

这部分属于“高手进阶”，了解概念应对选择题即可。

- **绑定任务 (Tied Task)** 3：
    
    - 默认模式。
        
    - 一旦某个线程开始执行这个任务，就必须由这个线程负责到底。哪怕它中途被挂起了（比如去处理子任务了），回头还得它来接着做。
        
- **非绑定任务 (Untied Task)** 4：
    
    - `#pragma omp task untied`
        
    - 任务可以在执行过程中“换手”。线程 A 也就是做了一半累了（挂起），线程 B 可以接手继续做。适合极度负载不均衡的场景。
        
- **任务切换 (Task Switching)** 5：
    
    - 当一个线程遇到 `taskwait` 或者 `barrier` 必须等待时，它不会傻等（Idle），它会利用这段时间去任务池里找其他任务做。这就是为什么 OpenMP 效率高。
        

---

### 💡 重点总结

1. **适用场景**：`omp task` 适用于**链表、树、图**的遍历，以及**递归**算法。
    
2. **黄金搭档**：`#pragma omp parallel` + `#pragma omp single` + `#pragma omp task`。这是处理链表的标准套路。
    
3. **同步**：使用 `taskwait` 来等待子任务完成，而不是 `barrier`。
    

---

### 🎯 期末考题预测

**1. 代码填空题 (必考)**

- **题目**：以下是并行处理链表的代码，请在横线上填入正确的 OpenMP 指令。
    ```c
    #pragma omp parallel
    {
        #pragma omp ___________ // (1)
        {
            node* p = head;
            while(p) {
                #pragma omp ___________ // (2)
                process(p);
                p = p->next;
            }
        }
    }
    ```
    
- **答案**：
    
    - (1) `single` (必须保证只有一个线程在生成任务)
        
    - (2) `task` (将具体计算封装为任务)
        

**2. 选择题**

- 在递归函数的并行化中（例如计算 Fibonacci 数列），为了等待子任务返回结果，应该使用哪条指令？
    
    - A. `#pragma omp barrier`
        
    - B. `#pragma omp taskwait`
        
    - C. `#pragma omp flush`
        
    - D. `#pragma omp ordered`
        
    - **答案**：B
        

**3. 简答题**

- **题目**：在 `omp task` 模型中，为什么通常需要把生成任务的代码放在 `single` 块中？
    
    - **答案**：如果不用 `single`，并行域内的所有线程（例如 4 个线程）都会执行 `while` 循环，导致同一个链表被重复遍历 4 次，每个任务被重复生成 4 次，造成极大的浪费和潜在的逻辑错误。使用 `single` 确保只有一个“生产者”负责分发任务。


# 第九部分：数据环境基础与数据竞争 (PPT 39-42)

这一部分不仅仅是语法，更是并行程序正确性的**生死线**。如果不理解这里，写出来的并行程序结果全是错的。

### 1. 数据的“户口”：作用范围 (Scoping) (PPT 39-40)

在 OpenMP 并行域中，每一个变量都有一个“身份”，要么是**共享 (Shared)**，要么是**私有 (Private)**。

#### A. 共享变量 (Shared Variables)

- **定义**：所有线程都访问**同一个**内存地址。
    
- **哪些变量默认是共享的？**
    
    - 在 C/C++ 中，定义在并行域**外部**（`#pragma omp parallel` 之前）的变量。
        
    - 全局变量 (Global variables)。
        
    - 静态变量 (`static` variables)。
        
    - 堆上的动态内存（`malloc`/`new` 出来的）。
        
- **用途**：用于线程间通信（比如大家都往一个 `sum` 变量里累加）。
    

#### B. 私有变量 (Private Variables)

- **定义**：每个线程都有自己**独立的一份**拷贝（在各自的栈 Stack 上）。线程 A 修改自己的 `x`，线程 B 的 `x` 不会变。
    
- **哪些变量默认是私有的？**
    
    - **显式声明**：在 `#pragma omp` 子句中用 `private(list)` 指定的变量。
        
    - **局部定义**：在并行域代码块 `{ ... }` **内部定义**的变量。
        
    - **循环变量**：`#pragma omp for` 紧随其后的那个循环索引（如 `for(int i...)` 中的 `i`），默认必须是私有的（否则大家抢同一个 `i` 就乱套了）。
        

---

### 2. 核心考点：数据竞争 (Data Race) (PPT 41)

这是期末考试代码改错题的**头号杀手**。

PPT 第 41 页给出了一个经典的**错误示范**：

#### ❌ 错误代码分析
```c
// 假设 array[] 是共享数组
#pragma omp parallel for
for(k=0; k<100; k++) {
    x = array[k];        // <--- 致命错误点！
    array[k] = do_work(x);
}
```

- **为什么错？**
    
    - 变量 `x` 是在循环外面定义的（或者没在并行域内声明），根据规则，它默认是 **共享 (Shared)** 的。
        
    - **场景还原**：
        
        1. **线程 A** 执行 `x = array[0]`（假设 `array[0]=10`），此时内存里的 `x` 变成了 10。
            
        2. 就在这时，**线程 B** 抢占执行，执行 `x = array[1]`（假设 `array[1]=99`），内存里的 `x` 被覆盖成了 99。
            
        3. **线程 A** 继续执行 `do_work(x)`。它以为 `x` 还是 10，但实际上读到的却是 99！
            
        4. **结果**：计算结果完全错误，且每次运行结果都不一样。
            

#### ✅ 正确的两种改法

PPT 41 给出了两种标准解决方案：

**方案一：使用 `private` 子句（推荐）**
```c
// 显式告诉编译器：虽然 x 在外面定义，但在并行域里给我每个线程弄个私有的
#pragma omp parallel for private(x) 
for(k=0; k<100; k++) {
    x = array[k]; 
    array[k] = do_work(x);
}
```

**方案二：在内部定义变量**

C

```
#pragma omp parallel for
for(k=0; k<100; k++) {
    int x; // 在这里定义，作用域仅限当前线程的当前迭代，天然私有
    x = array[k];
    array[k] = do_work(x);
}
```

---

### 3. 控制数据环境的手段 (PPT 42)

PPT 42 页是一个目录页，列出了所有我们需要掌握的武器。为了做笔记方便，我这里做一个功能分类总结（接下来的几节课我们会一个个详细讲）：

- **独立的指令**：
    
    - `threadprivate(list)`：用于处理全局/静态变量的私有化（下一节细讲）。
        
- **数据属性子句 (Clauses)**：
    
    - **基础**：`private` (私有), `shared` (共享), `default` (默认属性)。
        
    - **初始化相关**：`firstprivate` (带初值的私有), `lastprivate` (带终值的私有), `copyin` (拷贝全局私有值)。
        
    - **归约计算**：`reduction` (求和、求积等)。
        

---

### 🎯 重点总结 (可直接复制到笔记)

1. **默认规则**：
    
    - **外部变量 = Shared**（共享）。
        
    - **内部变量 = Private**（私有）。
        
    - **循环索引 i = Private**（私有）。
        
2. **数据竞争 (Data Race)**：
    
    - **成因**：多个线程同时读写同一个 **Shared** 变量，且至少有一个是写操作。
        
    - **后果**：结果不可预测。
        
    - **解决**：将临时变量声明为 **Private**。
        

---

### 📝 期末考题预测

**1. 代码分析题（必考）**

- **题目**：以下代码中，变量 `temp` 导致了数据竞争。请说明原因并提供修改代码。
    
    C
    
    ```
    int temp;
    #pragma omp parallel for
    for (int i = 0; i < N; i++) {
        temp = A[i] * 2;
        B[i] = temp + 1;
    }
    ```
    
- **答案**：
    
    - **原因**：`temp` 定义在并行域外，默认为共享变量。多个线程同时写入 `temp` 会导致覆盖，一个线程可能读取到另一个线程写入的值。
        
    - **修改**：将 `#pragma omp parallel for` 改为 `#pragma omp parallel for private(temp)`。
        

**2. 选择题**

- 在 OpenMP 的 `#pragma omp parallel` 区域内部定义的局部变量（不含 `static` 关键字），其默认的数据共享属性是：
    
    - A. shared
        
    - B. private
        
    - C. firstprivate
        
    - D. lastprivate
        
    - **答案**：B

# 第十部分：Threadprivate 与 Copyin (PPT 43-45)

### 1. 什么是 `threadprivate`？(PPT 43)

我们之前学的 `private(x)` 是把一个临时的局部变量变成私有的，它的生命周期只在这个并行域 `{ ... }` 里面。一出了大括号，这个私有的 `x` 就没了。

但如果我们想要一个变量：

1. **是全局的**（Global）或者**静态的**（Static），本来生命周期就很长。
    
2. **每个线程都要有一份独立的拷贝**（像私有变量一样互不干扰）。
    
3. **持久化**：即使现在的并行域结束了，下一个并行域开始时，这个变量里的值**还能保留**（这是 `private` 做不到的）。
    

这就是 **`threadprivate` (线程私有)** 的用途。

**语法格式**：

C

```
int alpha; // 全局变量
#pragma omp threadprivate(alpha) // 必须紧跟在变量声明之后
```

**执行机制** ：

- 当程序第一次遇到并行域时，OpenMP 会为每个线程创建一个 `alpha` 的副本。
    
- **注意**：除了主线程（Master）的副本保留了原来的值，其他线程副本的**初始值是未定义的**（随机乱码），除非你用 `copyin`。
    

### 2. 代码实战分析 (PPT 44)

PPT 第 44 页的代码非常经典，展示了 `threadprivate` 的**持久性**。
```c
int global_var = 20; // 1. 定义全局变量
#pragma omp threadprivate(global_var) // 2. 标记为线程私有

int main() {
    // --- 第一个并行域 ---
    #pragma omp parallel num_threads(4)
    {
        // 每个线程修改自己的 global_var
        // 假设 Thread 1: 20 + 1 + 1 = 22
        global_var = global_var + tid + 1; 
    }

    // --- 串行区域 ---
    // 这里只有主线程在跑，global_var 是主线程的那份拷贝

    // --- 第二个并行域 ---
    #pragma omp parallel num_threads(4)
    {
        // 关键点！Thread 1 进来时，它的 global_var 还是 22！
        // 并没有被重置，它记住了上次并行域结束时的值。
        global_var = global_var + tid + 1; 
        // Thread 1: 22 + 1 + 1 = 24
    }
}
```

**对比 `private`**： 如果是 `#pragma omp parallel private(x)`，每次进入新的并行域，`x` 都是一个新的、未初始化的变量，根本记不住上次的值。

### 3. `copyin` 子句 (PPT 45)

**问题**： 在 `threadprivate` 中，只有主线程（Thread 0）的那份拷贝继承了全局变量的初始值（比如 20），其他线程（Thread 1, 2...）的那份拷贝虽然创建了，但里面的值是垃圾值（未定义）。

**解决**： 使用 **`copyin(list)`** 子句。

**功能**： 在进入并行域的那一刻，把**主线程**中 `threadprivate` 变量的值，**拷贝**（广播）给所有其他线程的同名变量 。

**语法示例**：
```c
int A = 100;
#pragma omp threadprivate(A)

int main() {
    // 加上 copyin，所有线程的 A 初始值都是 100
    // 不加 copyin，只有主线程是 100，别人可能是 0 或乱码
    #pragma omp parallel copyin(A) 
    {
        ...
    }
}
```

---

### 💡 重点总结 (Key Points)

1. **适用对象**：`threadprivate` 只能用于**全局变量**或**静态变量 (static)**。
    
2. **生命周期**：与线程的生命周期一致。线程死，它才死。
    
3. **区别 `private`**：
    
    - `private`：作用域局限于当前并行块，无法跨块保持数据。
        
    - `threadprivate`：像每个线程的“私有全局变量”，可以**跨并行域保持数据**。
        
4. **初始化**：必须配合 `copyin` 子句，否则子线程的初始值不可用。
    

---

### 🎯 期末考题预测

**1. 概念辨析题（必考）**

- **题目**：请简述 `private` 和 `threadprivate` 的主要区别。
    
- **答案**：
    
    1. **适用范围**：`private` 用于局部变量或在并行域子句中声明的变量；`threadprivate` 仅用于全局变量或静态变量。
        
    2. **生命周期/持久性**：`private` 变量在并行域结束时失效（值丢失）；`threadprivate` 变量的值在不同的并行域之间可以**保持（Persist）**，只要线程没有被销毁。
        

**2. 代码改错题**

- **题目**：以下代码希望所有线程都从 `counter=10` 开始递增，但结果部分线程输出了奇怪的负数。请修正。
    ```c
    int counter = 10;
    #pragma omp threadprivate(counter)
    
    void work() {
        #pragma omp parallel 
        {
            counter++; // 错误：子线程的 counter 未初始化
            printf("%d\n", counter);
        }
    }
    ```
    
- **修正**：在 `#pragma omp parallel` 后面加上 `copyin(counter)`。即 `#pragma omp parallel copyin(counter)`。
    

**3. 填空题**

- 若要将主线程中 `threadprivate` 变量的值在并行域开始时复制给其他所有线程，必须使用 `________` 子句。
    
    - **答案**：`copyin`

# 第十一部分：Private 的进阶 —— Firstprivate 与 Lastprivate (PPT 46-50)

### 1. 基础回顾：Private 的缺陷 (PPT 46-47)

PPT 46 页给出了一个**典型的反面教材**，展示了 `private` 变量的危险性。

**代码分析** ：
```c
int A = 100;
int B, C = 0;

#pragma omp parallel for private(A, B) // A 和 B 都是私有的
for (int i = 0; i < 10; i++) {
    // 错误 1：试图读取 A
    //虽然外面 A=100，但这里面的 A 是私有副本，初始值是随机垃圾值！
    B = A + i; 

    // ... 
}
// 错误 2：试图读取 B
// 虽然里面算出了 B，但那是私有副本。一出循环，私有 B 销毁，外面的 B 还是原来的值（未初始化）。
C = B; 
```

**结论**：`private` 变量在进入和退出并行区域时都是 **“未定义” (Undefined)** 的 。

### 2. Firstprivate：带初始值的私有 (PPT 48-49)

如果你希望每个线程的私有变量，在刚开始都有一个确定的初始值（比如都等于外面的 `A=100`），就用 **`firstprivate`**。

**机制** ：

- 在进入并行域时，系统会自动把**并行域外同名变量的值**，拷贝给每个线程的私有副本。
    
- _注意_：这只管“进”，不管“出”。出来后外面的变量值还是不会变。
    

**代码示例 (PPT 49)** ：
```c
int A = 100;
// 使用 firstprivate(A)
#pragma omp parallel for firstprivate(A) 
for (int i = 0; i < 8; i++) {
    // 此时 A 的初始值保证是 100，不会报错
    A = A + i + 1; 
    printf("Thread %d: A=%d\n", omp_get_thread_num(), A);
}
// 退出后，外面的 A 依然是 100，没有被里面的计算改变
printf("After: A=%d\n", A); 
```

### 3. Lastprivate：带返回值的私有 (PPT 48, 50)

如果你希望把并行计算的结果“带出来”，更新到外面的共享变量里，就用 **`lastprivate`**。

**机制** 5：

- 在退出并行域时，系统会将**逻辑上最后一次循环迭代**（Logically last iteration）或者**最后一个 section** 中的私有变量的值，赋值给外面的同名共享变量。
    
- _注意_：
    
    - 它是“最后一次迭代”，不是“最后一个执行完的线程”。比如循环 `i=0..9`，不管线程 2 跑得快不快，只要它负责的是 `i=9`，那它的结果就是最终结果。
        
    - 它只管“出”，不管“进”。除非你同时用 `firstprivate` 和 `lastprivate`。
        

**代码示例 (PPT 50)** ：
```c
int A = 100;
// 使用 lastprivate(A)
#pragma omp parallel for lastprivate(A)
for (int i = 0; i < 8; i++) {
    // 注意：这里如果读 A，A 是未初始化的（除非加 firstprivate）
    // 这里直接赋值，所以没问题
    A = 10 + i; 
}
// 循环结束，逻辑上最后一次迭代是 i=7，此时 A = 10 + 7 = 17
// 所以外面的 A 变成了 17
printf("After: A=%d\n", A); // 输出 17
```

---

### 💡 重点总结：三者对比 (必背表)

|**子句**|**进入并行域时 (In)**|**退出并行域时 (Out)**|**典型应用场景**|
|---|---|---|---|
|**`private`**|**未定义** (垃圾值)|**未定义** (丢失)|纯粹的临时变量，如循环内部计算用的中间量 `temp`|
|**`firstprivate`**|**初始化** (等于外部值)|**未定义** (丢失)|需要基于外部初值进行计算，但结果不需要带回|
|**`lastprivate`**|**未定义** (垃圾值)|**赋值** (取最后迭代的值)|需要把循环的最终结果赋值给外部变量|

---

### 🎯 期末考题预测

**1. 代码预测题 (高频)**

- **题目**：写出下列代码执行后 `x` 的值。
    ```c
    int x = 5;
    #pragma omp parallel for firstprivate(x) lastprivate(x)
    for (int i = 0; i < 4; i++) {
        x = x + i;
    }
    printf("%d", x);
    ```
    
- **分析**：
    
    - `firstprivate(x)`：每个线程里的 `x` 初始都是 5。
        
    - 最后一次迭代是 `i=3`。
        
    - 负责 `i=3` 的那个线程计算：`x = 5 + 3 = 8`。
        
    - `lastprivate(x)`：把 `i=3` 时的结果 8 赋给外面的 `x`。
        
- **答案**：**8**
    

**2. 填空题**

- 在 OpenMP 中，如果希望并行域内的私有变量继承外部变量的初值，应使用 `________` 子句；如果希望将并行循环最后一次迭代的值赋给外部变量，应使用 `________` 子句。
    
    - **答案**：`firstprivate`，`lastprivate`
        

**3. 简答题**

- **题目**：为什么 `lastprivate` 强调是“逻辑上最后一次迭代”而不是“时间上最后执行完的线程”？
    
    - **答案**：因为并行执行的时间是不确定的，谁最后跑完是随机的。为了保证程序的**确定性**（即并行结果与串行结果一致），必须规定以循环的逻辑顺序（即 `i` 最大的那次）为准，这样每次运行的结果才是一样的。

# 第十二部分：Shared、Default 与 Reduction (PPT 51-54)

### 1. `shared` 与 `default` 子句 (PPT 51)

这两位通常是配角，但了解它们能帮你避开编译错误。

#### A. `shared(list)`

- **含义**：显式声明列表中的变量是**共享**的。所有线程读写同一个内存地址。
    
- **注意**：一旦用了 `shared`，你就要自己负责防止数据竞争（Data Race）。通常需要配合锁（Critical）或原子操作（Atomic），否则结果不可信。
    

#### B. `default` 子句

这是懒人神器，用来设置并行域内变量的默认属性。

- **`default(shared)`**：**默认值**。如果你不写 `default` 子句，OpenMP 默认所有外部变量都是共享的。
    
- **`default(none)`**：**“严格模式”**。
    
    - **作用**：强迫程序员显式地为并行域内用到的每一个变量指定属性（是 private 还是 shared）。
        
    - **优点**：写代码时很麻烦，但调试时非常有用！它能防止你意外地把一个本该私有的变量弄成了共享，或者反之。**考试如果问如何通过编译手段减少 Bug，选这个。**
        

---

### 2. 核武器：`reduction` (归约) (PPT 52-53)

这是本章**最重要的知识点**。

**场景**：我们要计算 $Sum = \sum_{i=0}^{N} A[i]$。

- **错误写法**：如果不加保护，多个线程同时做 `Sum = Sum + A[i]`，会发生严重的数据竞争。
    
- **低效写法**：用 `atomic` 或 `critical` 加锁。虽然对了，但这会让并行变成串行（一次只能一个人加），完全没有加速效果。
    
- **高效写法**：使用 `reduction`。
    

#### A. 工作原理 (必考机制)

当编译器看到 `reduction(+:sum)` 时，它在幕后做了三件事：

1. **私有化 (Fork)**：为每个线程创建一个 `sum` 的**私有拷贝**。
    
2. **初始化 (Init)**：根据操作符给私有拷贝赋初值。
    
    - 如果是 `+` (加法)，初值是 **0**。
        
    - 如果是 `*` (乘法)，初值是 **1**。
        
3. **合并 (Join)**：所有线程算完自己的局部累加后，在退出并行域时，将所有私有拷贝的值和原始的全局值进行**合并运算**（做一次总加法）。
    

#### B. 语法

`reduction(operator : list)`

- **支持的操作符**：`+`, `-`, `*`, `&`, `|`, `^`, `&&`, `||`, `min`, `max` (部分版本支持)。
    

#### C. 代码示例 (PPT 53)
```c
int sum = 0; // 原始变量
#pragma omp parallel for reduction(+:sum) // 归约求和
for (int i = 0; i < 1000; i++) {
    // 这里的 sum 其实是线程的私有变量
    sum = sum + 1; 
}
// 退出后，OpenMP 自动把大家算出来的局部 sum 加到了全局 sum 上
printf("%d\n", sum); // 输出 1000
```

---

### 3. 综合大题：数值积分法求 Pi (PPT 54)

这是并行计算领域的“Hello World”，也是期末考试**代码填空题/综合分析题**的满分模板。它综合运用了我们之前学的 `private`、`shared` 和 `reduction`。

数学原理：

利用公式 $\int_{0}^{1} \frac{4}{1+x^2} dx = \pi$，通过将 [0, 1] 区间切分成无数个小矩形来近似计算面积。

**代码深度解析 (重点背诵)**：
```c
static long num_steps = 100000; // 切成 10万份
double step;

void main() {
    int i; 
    double x, pi, sum = 0.0;
    
    // 计算步长（每个矩形的宽）
    step = 1.0 / (double)num_steps;

    // [考点] 综合指令解析：
    // 1. private(x): 中间变量 x 必须私有，否则数据竞争。
    // 2. reduction(+:sum): 累加器 sum 必须归约，否则数据竞争且用锁太慢。
    // 3. i 默认是 private 的，step 默认是 shared 的（只读不写，安全）。
    #pragma omp parallel for private(x) reduction(+:sum)
    for (i = 0; i < num_steps; i++) {
        // 计算当前矩形的中点 x 坐标
        x = (i + 0.5) * step; 
        // 计算高度 4/(1+x^2) 并累加
        sum = sum + 4.0 / (1.0 + x * x);
    }
    
    // 最后再乘以宽，得到面积
    pi = step * sum;
    printf("Pi = %f\n", pi);
}
```

**关键问题**：

- **为什么 `x` 必须是 private？**
    
    - 因为 `x` 取决于 `i`。如果 `x` 是共享的，线程 A 刚算出 `i=1` 时的 `x`，还没来得及算 `sum`，就被线程 B 改成了 `i=2` 时的 `x`，导致线程 A 的 `sum` 算错。
        
- **为什么 `step` 可以是 shared？**
    
    - 因为 `step` 在并行域之前就计算好了，并行域内大家**只读不写**，是只读变量，绝对安全。
        

---

### 💡 重点总结 (Key Points)

1. **Reduction 优势**：它是实现并行累加/累乘**性能最高**且**代码最简**的方法，完全消除了手动加锁的必要。
    
2. **默认值 (Init Value)**：记住加法对应 0，乘法对应 1。考试可能会问“如果是 `reduction(*:p)`，内部私有变量初始化为多少？”
    
3. **变量分类**：
    
    - **只读变量** -> `shared`
        
    - **循环中间变量** -> `private`
        
    - **累加/汇总变量** -> `reduction`
        

---

### 🎯 期末考题预测

**1. 代码改错题 (必考)**

- **题目**：以下计算阶乘的并行代码有误，请指出并修改。
    ```c
    int fact = 0; // 错误点1
    #pragma omp parallel for reduction(*:fact)
    for (int i = 1; i <= n; i++) fact *= i;
    ```
    
- **答案**：
    
    1. 初始化错误：阶乘（乘法）的初始值不能是 0，否则结果永远是 0。应改为 `int fact = 1;`。
        
    2. 虽然 reduction 会把内部私有变量初始化为 1，但最终合并时是 `Global_Fact * Local_Fact`，如果外部是 0，结果还是错的。
        

**2. 代码填空题 (Pi 计算)**

- 题目：请补全求 Pi 的并行指令。
    
    #pragma omp parallel for __________(x) __________(+:sum)
    
- **答案**：`private`，`reduction`
    

**3. 选择题**

- 在使用 `reduction(op:list)` 子句时，如果操作符是逻辑与 (`&&`)，则私有变量的初始化值通常是：
    
    - A. 0 (False)
        
    - B. 1 (True)
        
    - C. -1
        
    - D. 随机值
        
    - **答案**：B (True)。因为 `True && X = X`，它是逻辑与运算的单位元。
# 第十三部分：同步 —— Master, Single 与 Critical (PPT 55-60)

### 1. 概述：OpenMP 的红绿灯 (PPT 56)

PPT 56 列出了所有同步指令，我们先有个印象：

- `master`: 大师兄（主线程）专享。
    
- `single`: 随便谁，反正只许一个人做。
    
- `critical`: 独木桥，排队通过。
    
- `barrier`: 集合点，人齐了再走。
    
- `atomic`: 原子操作（极速版 critical）。
    
- `ordered`: 按顺序来。
    

接下来我们细讲前三个。

### 2. `master` 指令：主线程特权 (PPT 57)

**功能**： 指定一段代码**仅由主线程 (Master Thread, ID=0)** 执行。其他线程（Thread 1, 2...）到了这里，直接**跳过**这段代码，继续往下跑，根本不管主线程做完了没有 。

**语法**：
```c
#pragma omp master 
{
    // 只有主线程做这里的事，比如打印日志、IO操作
    printf("I am Master\n");
}
```

**核心细节（必考！）** ：

- **无隐式同步 (No Implicit Barrier)**：`master` 块结束的大括号处，**没有**栅栏！
    
- 这意味着：主线程还在里面吭哧吭哧干活时，其他线程已经跳过去跑后面的代码了。如果你后面的代码依赖主线程的结果，这就出大事了（需要手动加 `barrier`）。
    

### 3. `single` 指令：抢单模式 (PPT 32, 57-58)

虽然 PPT 57 把这两个放一起讲，但 `single` 和 `master` 经常混淆。

**功能**： 指定一段代码**仅由某一个线程**执行。

- **谁来做？** **第一个到达**这里的线程。可能是主线程，也可能是线程 3。谁跑得快谁做（First come, first served）。
    
- **其他人呢？** 其他没抢到单的线程，必须在代码块结束处**等待**（除非加了 `nowait`）。
    

**核心细节（必考对比）**：

- **隐式同步 (Implicit Barrier)**：`single` 块结束处**有**一个栅栏。大家必须等那个干活的人做完，才能一起往下走。
    

#### 📊 Master vs Single 对比表 (PPT 58 代码分析)

PPT 58 用一段代码展示了两者的区别：
```c
#pragma omp parallel 
{
    // 任务 A：大家一起做
    
    #pragma omp master 
    { 
        // 只有主线程做，其他人直接去做任务 B
        printf("I am master\n"); 
    } 
    
    // 任务 B：大家一起做（可能主线程还没做完上面的打印，别人已经开始做任务B了）

    #pragma omp single 
    { 
        // 第一个到的人做，做完之前，其他人都在门口等着
        printf("Only one thread prints this\n"); 
    }
    
    // 任务 C：大家一起做（这里一定很安全，因为 Single 有同步，大家都等齐了）
}
```

### 4. `critical` 指令：临界区 (PPT 59-60)

这是解决数据竞争的通用（但较慢）手段。

**功能**： 指定一段代码，在同一时刻**只能被一个线程**执行。其他试图进入的线程必须被**阻塞 (Blocked)**，在外面排队 。

**语法**：
```c
#pragma omp critical [(name)] // name 是可选的，但建议写上
{
    // 临界区：比如修改全局变量 sum
    sum = sum + local_sum;
}
```

**核心细节：命名临界区 (Named Critical Section)**

- 如果不写名字，所有 `critical` 区共用一把大锁（全局互斥）。
    
- **为什么要命名？**
    
    - 假设你有两个独立的全局变量 `X` 和 `Y`。
        
    - 线程 A 想改 `X`，线程 B 想改 `Y`。
        
    - 如果用无名 `critical`，B 必须等 A 改完 `X` 才能改 `Y`（无辜被锁）。
        
    - 如果用 `#pragma omp critical(LockX)` 和 `#pragma omp critical(LockY)`，他俩就可以同时进行，互不干扰，性能更高。
        

**PPT 60 代码分析**： 代码演示了用 `critical` 保护加法操作。虽然正确，但就像我们之前讲的，对于简单加法，用 `reduction` 效率吊打 `critical`。`critical` 更适合复杂的逻辑（比如写文件、操作复杂的树结构）。

---

### 💡 重点总结 (可以直接复制到笔记)

1. **Default(none)**：调试神器，强制程序员显式声明所有变量属性，防止意外共享。
    
2. **Master vs Single**：
    
    - **Master**：指定主线程做，**无等待**（No Barrier）。
        
    - **Single**：指定任意一个线程做，**有等待**（Implicit Barrier）。
        
3. **Critical**：
    
    - **作用**：互斥访问，解决数据竞争。
        
    - **优化**：给 Critical 起名字 (`name`)，可以实现更细粒度的锁，防止不必要的等待。
        

---

### 🎯 期末考题预测

**1. 简答/辨析题 (高频)**

- **题目**：请说明 `#pragma omp master` 和 `#pragma omp single` 的两个主要区别。
    
- **答案**：
    
    1. **执行者不同**：`master` 指定由主线程（Thread 0）执行；`single` 由第一个到达代码块的线程执行（不一定是主线程）。
        
    2. **同步机制不同**：`master` 块结束处**没有**隐式同步（Implicit Barrier），其他线程会直接跳过；`single` 块结束处**默认有**隐式同步，其他线程必须等待执行者结束后才能继续。
        

**2. 代码分析题**

- **题目**：以下代码存在潜在的逻辑错误，请指出。
    ```c
    #pragma omp parallel
    {
        #pragma omp master
        init_data(); // 初始化共享数据
    
        process_data(); // 所有线程处理数据
    }
    ```
    
- **答案**：`master` 没有隐式同步。如果主线程初始化数据较慢，其他线程会跳过 `master` 块直接执行 `process_data()`，此时数据可能尚未初始化完毕，导致错误。
    
- **修改**：在 `master` 块后显式添加 `#pragma omp barrier`，或者改用 `#pragma omp single`（自带同步）。
    

**3. 选择题**

- 在 OpenMP 中，为了保护对不同共享变量的互斥访问，避免不必要的阻塞，应该使用：
    
    - A. `#pragma omp atomic`
        
    - B. `#pragma omp critical` (不带名字)
        
    - C. `#pragma omp critical (name)` (带名字)
        
    - D. `#pragma omp barrier`
        
    - **答案**：C
