## 一、实验内容
#### GEMM多线程实现
1. 并行实现
- 使用 C/C++语言和 Pthreads 编写。
- 数据类型：double。接口：C = A × B（无需 α、β 扩展）
- 切分策略（建议两种均实现，分析优劣）
	- 按行块：将结果矩阵 C 的行区间划分给不同线程。
	- 2D 分块：将 C 划为 tile(i, j)，每个线程负责一个或多个 tile 的计算。
2.  正确性校验
- 随机初始化 A、B，可通过调用开源线性代数库中的 GEMM 接口计算得
- 到正确的结果矩阵，和自己实现的 GEMM 接口的计算结果进行对比，
- 以证明程序实现的正确性，校验不计入测算时间。
3. 计时、规模、线程设置
- 计时和问题规模保持与实验一相同
- 线程数：T ∈ {1,2,4,8,16}（视机器核数而定，最大不超过机器核数，且为 2 的整数幂，至少取两种不同线程数设置展示性能对比）。
1. 性能指标
- 运行时间
- GFLOPS，以及和理论 GFLOPS 的比值
5. 报告内容
- 将相关实验数据通过图表形式在实验报告中展示并进行分析
#### SpMV多线程实现
1. 并行实现
- 语言为 C/C++语言+Pthreads，数据类型选用 double，实现为 y = A × x（CSR）。
- 切分策略（建议两种均实现，分析优劣）
- 按行块（静态）：将行区间均分给线程；简单但遇到行非零分布不均时易失衡。
- 按非零数（近似均匀）：按非零元数量给线程划分任务，负载均衡更好。

2. 稀疏矩阵生成与输入
- 负载均衡矩阵：仍采用和上次实验相同的可调规模和稠密度，随机初始化。
- 负载不均衡矩阵：下节课前会将负载不均衡的矩阵给到大家，并提供读矩阵的源码。

1. 正确性校验
- 可通过调用开源线性代数库中的 SpMV 接口计算得到正确的结果矩阵，和自己实现的并行 SpMV 接口的计算结果进行对比，以证明程序实现的正确性。

4. 计时、规模、线程设置
- 计时和问题规模保持与实验一相同
- 线程数：T ∈ {1,2,4,8,16}（视机器核数而定，最大不超过机器核数，且为 2 的整数幂，至少取两种不同线程数设置展示性能对比）。

5. 性能指标
- 运行时间
- GFLOPS，以及和理论 GFLOPS 的比值

6. 报告内容
- 将相关实验数据通过图表形式在实验报告中展示并进行分析。
## 二、实验目的
#### GEMM多线程实现
- 理解 POSIX 线程（Pthreads）的基本使用方法，包含线程创建、回收、属性、同步等。
- 在串行 GEMM 的基础上，掌握数据并行切分与负载均衡方法，完成 C=A×B 的 Pthreads 并行实现。
- 评估并行化带来的加速比、并行效率与可扩展性。
#### SpMV多线程实现
- 结合 CSR 存储与访存特性，设计适合 SpMV 的并行切分与调度，理解带宽受限算子中的负载均衡与访存局部性，掌握稀疏矩阵常用存储格式CSR。
- 学会利用 Pthreads 的互斥/条件变量实现工作队列或动态调度，缓解非零元分布不均导致的负载倾斜。
## 三、实验环境
- **操作系统：** Windows 11 wsl ubuntu
- **cpu:** 12th Gen Intel(R) Core(TM) i9-12900H   2.50 GHz
- **线性代数库 (For Verification):** OpenBLAS 0.3.21
## 四、实验步骤
#### 1. 实验环境配置

1. **操作系统环境：** 使用 Windows 11 操作系统，并通过 **WSL** 运行 Ubuntu 发行版作为开发和编译环境。
    
2. **编译器环境：** 在 WSL 中安装 **GNU Compiler Collection (GCC)** 和必要的构建工具 (`build-essential`)。
    
3. **线性代数库安装：** 在 WSL 终端中使用包管理器安装 **OpenBLAS** 及其开发包，用于提供标准的 GEMM 接口进行结果验证和性能对比。

    ```bash
    # 在 WSL (Ubuntu) 终端中执行
    sudo apt update
    sudo apt install libopenblas-dev
    ```
4. **VS Code 配置：** 使用 **Remote - WSL** 扩展连接到 WSL 环境，确保编译和调试过程都在 Linux 子系统中进行。
### GEMM多线程实现
#### 2. 项目构建与多线程代码实现

1. **串行基准程序准备**
将实验一已编写的串行 GEMM 代码（gemm.c, gemm.h, gemm_main.c）作为本次优化的基准（Baseline）。核心算法为 gemm_serial 函数中的标准三重循环。

编译配置：编写 Makefile 文件，配置编译器 gcc，包含头文件路径 -I./inc，并链接 OpenBLAS 库 -lopenblas，用于后续的正确性验证。确保串行程序可以被正确编译和执行。

2. **“按行块”并行策略设计与实现**

定义线程数据结构：在 gemm.h 中，定义一个 struct（例如 gemm_thread_data_t）作为线程的“任务包”。该结构体包含线程执行计算所需的所有信息，如矩阵规模 N、矩阵 A/B/C 的指针、以及每个线程负责的起始行号 start_row 和结束行号 end_row。

实现“工人”函数：创建一个 void* gemm_worker(void* arg) 函数。此函数是每个子线程的执行体。
```c
void* gemm_worker(void* arg){
    gemm_thread_data_t* data=(gemm_thread_data_t*)arg;
    for(int i=data->start_row;i<data->end_row;i++){
        for(int j=0;j<data->N;j++){
            double sum=0.0;
            for(int k=0;k<data->N;k++){
                sum+=(data->A[i*(data->N)+k])*(data->B[k*(data->N)+j]);
            }
            data->C[i*(data->N)+j]=sum;
        }
    }
}
```
函数内部首先将 void* 类型的参数强制转换回 gemm_thread_data_t* 类型，以解析任务。

将 gemm_serial 中的三重循环代码复制过来，但将最外层的行遍历循环 for (int i = 0; ...) 修改为 for (int i = data->start_row; i < data->end_row; ++i)，确保每个线程只计算分配给它的行区间。

实现“管理者”逻辑：在主测试文件（gemm_row.c）的 main 函数中实现主线程的“管理者”逻辑。

任务划分：根据命令行传入的线程数 T，将矩阵 C 的 N 行任务进行切分。采用负载均衡策略，计算每个线程应分配的行数（rows_per_thread = N / T），并将余下的行（N % T）均匀分配给前面的线程，最终确定每个线程的 start_row 和 end_row。
```c
    int rows_per_thread=N/T
    for(int i=0;i<T;i++){
        thread_data[i].N=N;
        thread_data[i].A=A;
        thread_data[i].B=B;
        thread_data[i].C=C_parallel;
        thread_data[i].start_row=i*rows_per_thread;
        //让最后一个线程把没做完的部分都做完，防止无法整除

        if(i==T-1){
            thread_data[i].end_row=N;
        }
        else
            thread_data[i].end_row=(i+1)*rows_per_thread;
    }
```
线程创建 (Fork)：使用 pthread_create() 在一个循环中创建 T 个“工人”线程，并将打包好的任务包 gemm_thread_data_t 作为参数传入 gemm_worker 函数。
同步与回收 (Join)：在创建线程的循环之后，再用一个循环调用 pthread_join()，等待所有“工人”线程完成计算。这是保证最终结果完整的关键同步点。
```c
    //创建线程
    for(int i=0;i<T;i++){
        pthread_create(&threads[i],NULL,gemm_worker,(void*)&thread_data[i]);
    }
    for(int i=0;i<T;i++){
        pthread_join(threads[i],NULL);
    }
```

3. **“2d分块”并行策略设计与实现**

**设计思想：** “按行块”切分虽然简单，但存在性能瓶颈：在计算 $C$ 矩阵的每一行时，都需要完整地遍历（读取）整个 $B$ 矩阵。当 $N$ 增大时，$B$ 矩阵（大小为 $N \times N$）无法完全装入CPU缓存（L2/L3 Cache），导致计算每一行都需要从内存中重新读取 $B$ 矩阵的大部分数据，造成了极大的内存带宽压力和缓存未命中（Cache Miss）。
“2D分块”（或称为 Tiling）策略是对这一问题的经典优化。其核心思想是将 $C$ 矩阵（以及 $A$ 和 $B$）在逻辑上切分为若干个更小的子矩阵（称为 tile 或 block）。线程的任务不再是计算一整行，而是计算一个或多个 $C$ 矩阵的子块。
当计算一个 $C_{ij}$ 子块时，线程只需要访问 $A$ 矩阵对应的“行条带”和 $B$ 矩阵对应的“列条带”。通过合理设置块大小（`TILE_SIZE`），我们可以确保计算一个子块所需的数据（例如一个 $A$ 的子块和一个 $B$ 的子块）能够被高效地载入并复用在CPU缓存中，从而**极大提升数据局部性（Data Locality）**，减少对主内存的访问次数，进而提高计算性能。

**具体实现如下：**
**1. 定义线程数据结构：** 在 `gemm_2d.h` 中，定义一个新的 `gemm_thread_2d_t` 结构体作为 2D 分块任务的“任务包”。该结构体不仅包含基础信息（$N$, $A/B/C$ 指针），还特别定义了与分块相关的参数：
- `tile_size`：子块的边长（例如 16x16 或 32x32）。
- `num_dim`：在单个维度上切分出的 tile 数量（`N / tile_size` 向上取整）。
- `start_idx` 和 `end_idx`：线程负责计算的**起始 tile 索引号**和**结束 tile 索引号**。我们将 $C$ 矩阵的所有 $N \times N$ 个 tile 线性展开为一维任务队列。

**2. 实现“工人”函数：** 创建 `void* gemm_worker_2d(void* arg)` 函数作为 2D 分块策略的执行体。

```c
void* gemm_worker_2d(void* arg){
    gemm_thread_2d_t* data = (gemm_thread_2d_t*)arg;
    int N = data->N;
    int tile_size = data->tile_size;
    int num_dim = data->num_dim;
    int start_idx = data->start_idx;
    int end_idx = data->end_idx;

    // 1. 遍历分配给本线程的 *tile 索引*
    for (int k = start_idx; k < end_idx; k++) {
        int i_tile = k / num_dim; // 当前 tile 的行坐标
        int j_tile = k % num_dim; // 当前 tile 的列坐标
        
        // 2. 计算 tile 在 C 矩阵中的*元素*起止坐标
        int row_start = i_tile * tile_size;
        int col_start = j_tile * tile_size;
        // 处理矩阵边缘（N 不能被 tile_size 整除）的情况
        int row_end = (i_tile + 1) * tile_size > N ? N : (i_tile + 1) * tile_size;
        int col_end = (j_tile + 1) * tile_size > N ? N : (j_tile + 1) * tile_size;

        // 3. 对该 tile 执行标准的 GEMM 计算
        for (int i = row_start; i < row_end; i++) {
            for (int j = col_start; j < col_end; j++) {
                double sum = 0.0;
                for (int k_gemm = 0; k_gemm < N; k_gemm++) {
                    sum += (data->A[i * N + k_gemm]) * (data->B[k_gemm * N + j]);
                }
                data->C[i * N + j] = sum;
            }
        }
    }
    return NULL;
}
```

- 函数首先解析 `gemm_thread_2d_t` 任务包。
- 最外层循环 `for (int k = start_idx; ...)` 遍历的是分配给该线程的**任务（tile）列表**。
- 内部通过 `k / num_dim` 和 `k % num_dim` 将一维的 tile 索引 `k` 还原为二维的 tile 坐标 `(i_tile, j_tile)`。
- 接着，根据 tile 坐标计算出该 tile 在 $C$ 矩阵中对应的元素坐标范围（`row_start` 到 `row_end` 等），并正确处理了矩阵边缘无法填满一个 tile 的情况。
- 最后，内部的三重循环与串行版本一致，但遍历范围被限制在当前计算的 tile 内部。

**3. 实现“管理者”逻辑：** 在主测试文件（`gemm_2d.c`）的 `main` 函数中实现任务分发逻辑。

- **计算 Tile 数量：** 首先定义一个块大小 `TILE_SIZE`（例如 16 或 32）。根据 $N$ 和 `TILE_SIZE` 计算出维度上的 tile 数量 `num_dim` 和总的任务（tile）数量 `total_tiles`。
    ```c
    const int TILE_SIZE = 32;
    int num_dim = (N + TILE_SIZE - 1) / TILE_SIZE; // 向上取整
    int total_tiles = num_dim * num_dim;
    ```
    
- **任务划分：** 与“按行块”策略类似，我们将 `total_tiles` 个任务均分给 $T$ 个线程。计算 `tiles_per_thread`，并为每个线程的 `thread_data` 结构体分配 `start_idx` 和 `end_idx`。
    ```c
    int tiles_per_thread = total_tiles / T;
    
    for (int i = 0; i < T; i++) {
        thread_data[i].N = N;
        thread_data[i].A = A;
        thread_data[i].B = B;
        thread_data[i].C = C_parallel;
        thread_data[i].tile_size = TILE_SIZE;
        thread_data[i].num_dim = num_dim;
    
        // 分配 tile 索引
        thread_data[i].start_idx = i * tiles_per_thread;
    
        if (i == T - 1) {
            // 让最后一个线程把没做完的 tile 都做完
            thread_data[i].end_idx = total_tiles;
        } else {
            thread_data[i].end_idx = (i + 1) * tiles_per_thread;
        }
    }
    ```
    
- **线程创建 (Fork) 与回收 (Join)：** 此部分逻辑与“按行块”策略完全一致，只是在 `pthread_create` 时传入的“工人”函数是 `gemm_worker_2d`。
    ```c
    //创建线程
    for(int i=0;i<T;i++){
        pthread_create(&threads[i], NULL, gemm_worker_2d, (void*)&thread_data[i]);
    }
    
    // 同步与回收
    for(int i=0;i<T;i++){
        pthread_join(threads[i],NULL);
    }
    ```
### 3. 编写Makefile
为了支持“按行块” (`gemm_row`) 和“2D分块” (`gemm_2d`) 两种不同的并行策略在同一个项目中独立编译和测试，需要设计一个能正确处理多 `main` 函数文件的 Makefile。
#### 3.1 Makefile 设计
 采用基于特定规则的 Makefile，为两个策略分别生成独立的可执行文件。
1. **定义独立目标：** 在 Makefile 中定义两个独立的可执行文件目标，而不是一个。
    ```
    TARGETS=$(BINDIR)/gemm_row $(BINDIR)/gemm_2d
    ```
    
2. **指定 `all` 目标：** 使默认的 `make all` 命令依赖这两个独立目标。
    ```
    all: $(TARGETS)
    ```
    
3. **编写特定链接规则：** 为每个目标编写**特定规则**，使其只链接其必需的 `.o` 文件。
    ```
    $(BINDIR)/gemm_row: $(OBJDIR)/gemm_row.o
        $(CC) $^ -o $@ $(LDFLAGS)
    
    $(BINDIR)/gemm_2d: $(OBJDIR)/gemm_2d.o
        $(CC) $^ -o $@ $(LDFLAGS)
    ```
    - 此处 `$^` 自动变量代表规则中的所有依赖项（即对应的 `.o` 文件）。

1. **编写通用编译规则：** 使用模式规则处理所有的 `.c` 到 `.o` 的编译。
    ```
    $(OBJDIR)/%.o: $(SRCDIR)/%.c
        $(CC) $(CFLAGS) -c $< -o $@
    ```
    - 此处 `$<` 自动变量代表规则中的第一个依赖项（即对应的 `.c` 源文件）。
### 4. SpMV多线程实现
#### 4.1 “按行块” (静态) 并行策略
设计思想：
此策略是 SpMV 并行化最简单、最直接的方法，与 GEMM 的“按行块”策略完全相同。我们将矩阵的 $N$ 行静态地平均分配给 $T$ 个线程，每个线程负责计算一个固定的行区间 \[start_row, end_row)。
1. 定义线程数据结构：
在 spmv_pthreads.h 中，定义 spmv_thread_static_t 结构体，用于打包静态任务：
```c
typedef struct {
    const csr_matrix* A;
    const double* x;
    double* y;
    int start_row; // 负责的起始行
    int end_row;   // 负责的结束行 (不包含)
} spmv_thread_static_t;
```
2. 实现“工人”函数：
创建 spmv_worker_static 函数。线程启动后，只计算分配给它的行区间。
```c
void* spmv_worker_static(void* arg) {
    spmv_thread_static_t* data = (spmv_thread_static_t*)arg;
    const csr_matrix* A = data->A;
    const double* x = data->x;
    
    // 线程只遍历自己的行区间
    for (int i = data->start_row; i < data->end_row; ++i) {
        double sum = 0.0;
        // 内部 SpMV 计算逻辑与串行版本一致
        for (int j = A->row_ptr[i]; j < A->row_ptr[i+1]; ++j) {
            sum += A->values[j] * x[A->col_indices[j]];
        }
        data->y[i] = sum; // 写入y[i]
    }
    return NULL;
}
```
线程安全分析：
此策略是天然线程安全的。每个线程 t 只写入 y[i]，其中 i 属于该线程的 \[start_row, end_row) 区间。由于不同线程的行区间互不重叠，它们写入的 y 向量的位置也绝不会重叠，因此无需使用互斥锁 (Mutex) 。

3. 实现“管理者”逻辑：
在 spmv_static.c 的 main 函数中，实现与 gemm_row.c 完全一致的任务划分与线程管理逻辑。
```c
    int rows_per_thread = N / T;
    for (int i = 0; i < T; i++) {
        thread_data[i].A = &A;
        thread_data[i].x = x;
        thread_data[i].y = y_parallel;
        thread_data[i].start_row = i * rows_per_thread;
        
        if (i == T - 1) { // 最后一个线程包办余下的行
            thread_data[i].end_row = N;
        } else {
            thread_data[i].end_row = (i + 1) * rows_per_thread;
        }
    }
    
    // 创建 (Fork) 线程
    for (int i = 0; i < T; i++) {
        pthread_create(&threads[i], NULL, spmv_worker_static, (void*)&thread_data[i]);
    }
    // 同步 (Join) 线程
    for (int i = 0; i < T; i++) {
        pthread_join(threads[i], NULL);
    }
```
预期分析：
此方法实现简单，开销低。对于非零元分布“均匀”的矩阵，它能取得不错的性能。但对于“负载不均衡”的矩阵，其性能将受限于处理最“稠密”行块的那个线程，导致严重短板效应 。
#### 4.2 “按非零数” (动态调度) 并行策略
设计思想：
为解决静态策略的负载不均衡问题，我们采用“动态调度”策略，也称为“任务池”(Task Pool)模型 。我们将 $N$ 行中的每一行都视为一个独立的“任务”。所有 $T$ 个线程从一个共享的“任务池”中动态地领取任务（行号），完成一个就回来领下一个，直到所有行被处理完毕。
这能实现**近似按非零数均匀分配** ，因为处理稀疏行（任务快）的线程会自动回来领取更多任务，而处理稠密行（任务慢）的线程自然会领取较少任务，从而实现负载均衡。

1. 定义共享资源与线程数据：
此策略需要线程间共享数据，因此在 main 函数中定义：
- `int next_row = 0;`：一个全局共享的“任务计数器”，指向下一个待处理的行号。
- `pthread_mutex_t mutex;`：一个互斥锁，用于保护 `next_row` 计数器在被多个线程同时访问时的数据一致性 。
在 `spmv_pthreads.h` 中，定义 `spmv_thread_dynamic_t` 结构体。注意，所有线程都将持有指向**同一个** `next_row_ptr` 和 `mutex` 的**指针**.
```c
typedef struct {
    // ... A, x, y 指针 ...
    int N_rows;              // 总行数
    int* next_row_ptr;       // 指向 *同一个* next_row 计数器
    pthread_mutex_t* mutex;  // 指向 *同一个* 互斥锁
} spmv_thread_dynamic_t;
```
2. 实现“工人”函数:
创建 spmv_worker_dynamic 函数。其核心是一个 while(1) 循环，不断地“加锁-领任务-解锁-执行任务”。
```c
void* spmv_worker_dynamic(void* arg) {
    spmv_thread_dynamic_t* data = (spmv_thread_dynamic_t*)arg;
    const csr_matrix* A = data->A;
    const double* x = data->x;
    int my_row; // 线程私有的行号

    while (1) {
        // --- 1. 进入临界区：领取任务 ---
        pthread_mutex_lock(data->mutex);
        
        my_row = *(data->next_row_ptr); // 领取当前行号
        (*(data->next_row_ptr))++;      // 将全局行号+1
        
        pthread_mutex_unlock(data->mutex);
        // --- 离开临界区 ---

        // --- 2. 检查任务是否领完 ---
        if (my_row >= data->N_rows) {
            break; // 所有行都已分配，线程退出
        }

        // --- 3. 执行任务 (在锁外并行执行) ---
        double sum = 0.0;
        for (int j = A->row_ptr[my_row]; j < A->row_ptr[my_row+1]; ++j) {
            sum += A->values[j] * x[A->col_indices[j]];
        }
        data->y[my_row] = sum;
    }
    return NULL;
}
```
**线程安全分析：**
- 对 `next_row_ptr` 的读写操作（`my_row = *...` 和 `(*...)++`）是一个**“读-改-写”** (Read-Modify-Write) 序列，**不是原子操作**。必须使用 `pthread_mutex_lock` 和 `pthread_mutex_unlock` 将其保护在“临界区” (Critical Section) 内，否则会导致多个线程领到同一个行号（竞态条件 Race Condition）。
- 对 `y[my_row]` 的写入是线程安全的，因为 `my_row` 是通过互斥锁唯一分配的，保证了任意两个线程绝不会在同一时间写入 `y` 向量的相同位置。
3. 实现“管理者”逻辑：
在 spmv_dynamic.c 的 main 函数中，重点是初始化和销毁共享资源。
```c
    // 1. 定义共享资源
    int next_row = 0;
    pthread_mutex_t mutex;
    
    // 2. 初始化互斥锁
    pthread_mutex_init(&mutex, NULL);

    // 3. 任务划分 (所有线程指向同一组共享资源)
    for (int i = 0; i < T; i++) {
        thread_data[i].A = &A;
        thread_data[i].x = x;
        thread_data[i].y = y_parallel;
        thread_data[i].N_rows = N;
        thread_data[i].next_row_ptr = &next_row; // 传入地址
        thread_data[i].mutex = &mutex;         // 传入地址
    }
    
    // 4. 创建 (Fork) 线程
    for (int i = 0; i < T; i++) {
        pthread_create(&threads[i], NULL, spmv_worker_dynamic, (void*)&thread_data[i]);
    }
    // 5. 同步 (Join) 线程
    for (int i = 0; i < T; i++) {
        pthread_join(threads[i], NULL);
    }
    
    // 6. 销毁互斥锁
    pthread_mutex_destroy(&mutex);
```
预期分析：
此策略的同步开销（lock/unlock）会略高于静态版本。但在处理非零元分布极不均匀的矩阵时，其负载均衡带来的性能提升将远超这点开销，预期性能会显著优于静态“按行块”策略 。
#### 负载不均衡
在这里我将read.cpp程序的读取逻辑变成c语言融入到原本程序中
#### 1. 加载 `.bin` 文件的实现与调试

为了加载 `.bin` 文件，我们参照了提供的 `read.cpp` 示例代码，将其逻辑翻译为 C 语言，并集成到 `spmv_utils.c` 中，创建了 `load_matrix_from_bin` 函数。主要的实现步骤包括：

1. **修改 `csr_matrix` 结构体：** 根据 `read.cpp` 的模板，将 `row_ptr` 和 `col_indices` 的类型改为 `unsigned int*`，并将 `num_non_zeros` 改为 `long long`。`values` 的类型最初根据 `SpM<double>` 模板设为 `double*`。
2. **实现 `load_matrix_from_bin`：** 使用 C 标准库的 `fopen` 以二进制读取模式 (`"rb"`) 打开文件，然后使用 `fread` 依次读取 `nrows` (int), `ncols` (int), `nnz` (long long)。根据读取到的 `nrows` 和 `nnz` 分配 `row_ptr`, `col_indices`, 和 `values` 数组的内存。最后，使用 `fread` 将文件中的数组数据读入分配好的内存中。
3. **修改 `main` 函数：** 修改 `spmv_static.c` 和 `spmv_dynamic.c` 的 `main` 函数，使其接收 `.bin` 文件路径和线程数作为命令行参数，调用 `load_matrix_from_bin` 替代原来的 `generate_csr`，并在矩阵加载成功后根据 `A.num_rows` 和 `A.num_cols` 分配 `x` 和 `y` 向量。
**调试过程：**
在尝试加载 `mtx49.bin` 文件时，遇到了**一系列严峻的挑战**，揭示了 `.bin` 文件格式的复杂性和潜在的不规范性：
- **`fread` 失败 & `float` 假设：** 最初加载 `mtx49.bin` 时，在读取 `values` 数组时 `fread` 提前到达文件末尾。基于 `read.cpp` 代码有时可能被用于 `float` 类型的假设，我们将代码修改为按 `float` 读取 `values`。
- **`Segmentation fault` & `long long` 索引：** 即使改为 `float`，程序在并行计算时仍然崩溃。怀疑是 `row_ptr` 或 `col_indices` 中的 `unsigned int` 值过大导致 `int` 类型的循环变量 `j` 溢出变成负数。我们将 `worker` 函数和 `spmv_serial_csr` 中遍历 `values`/`col_indices` 的循环变量 `j` 改为 `long long` 类型。
- **`Segmentation fault` & 边界检查：** 问题依旧。怀疑 `col_indices` 中的值可能超出了 `x` 向量的边界（即 `[0, K_cols-1]`）。我们添加了 `if` 检查 `col_idx >= 0 && col_idx < K_cols`，但错误地使用了 `N = M_rows` 作为边界。
- **`Segmentation fault` & 正确边界：** 修正 `main` 函数中 `x` 向量的分配大小为 `K_cols = A.num_cols`，并在 `worker` 函数和 `serial` 函数中使用 `K_cols` 进行边界检查。
- **`Assertion failed` & 1-based 索引假设：** 崩溃点转移到了 `assert` 语句。调试信息显示从 `col_indices` 读取的原始值为 `0`，但我们（当时错误地）假设它是 1-based 并执行了 `-1` 操作，导致 `col_idx_0based` 变成 `-1`，违反了 `col_idx_0based >= 0` 的断言。
- **移除 `-1` 修正：** 认识到 `col_indices` 中存在 0 值，我们移除了 `-1` 的修正，直接使用原始读取的 `col_idx`。
- **`Assertion failed` & 文件数据错误：** 程序再次在 `assert(col_idx >= 0 && col_idx < K_cols)` 失败。调试信息显示，从 `mtx49.bin` 的 `col_indices` 中读出了 `1365885070` 这样的巨大数值，远超 `K_cols` (`102158`)。这表明 `mtx49.bin` 文件本身的数据存在问题或格式异常。
- **`row_ptr[0] != 0` 警告 & 4 字节偏移假设：** 同时，加载 `mtx49.bin` 时 `load_matrix_from_bin` 报告 `row_ptr[0]` 不为 0 且 `row_ptr[M]` 不等于 `nnz`。怀疑 `nnz` 和 `row_ptr` 之间存在 4 字节的未知数据。尝试在 `load_matrix_from_bin` 中跳过 4 字节。
- **内存损坏 & 再次尝试跳过：** 跳过 4 字节的尝试导致 `nnz` 值被破坏，引发内存分配失败。改进跳过逻辑，使用临时变量保护 `nnz` 并小心处理文件指针。
- **最终成功 (`mtx54.bin`) & 格式确认：** 在 `mtx49.bin` 上屡次失败后，尝试加载 `mtx54.bin`。发现之前的跳过 4 字节、`float` 类型假设、1-based 索引假设都是错误的（至少对于 `mtx54.bin` 不适用）。**最终成功加载 `mtx54.bin` 的代码版本确认了以下格式细节**：
    - `values` 数组确实是 `double` 类型。
    - `row_ptr` 和 `col_indices` 确实是 `unsigned int` 类型，并且是 **0-based** 索引。
    - 文件头 `nrows, ncols, nnz` 之后**没有**额外的 4 字节填充。
## 五、实验结果对比与分析
### GEMM多线程实现
##### 多线程与串行程序比较
线程为4，大小为1024：
![[{A2DE98BC-82CD-4611-B3D9-BC6C1AB3577D}.png]]
大小为1024的串行程序：
![[{E069BF2D-13F9-410E-AC72-CF1CCC94D53A}.png]]
从以上可以看出，几乎用4个线程就是快了4倍，性能也高了四倍
##### 按行与分块比较
根据实验要求，我们对“按行块”（`gemm_row`）和“2D分块”（`gemm_2d`）两种 Pthreads 并行策略进行了两组测试。
1. **可扩展性测试：** 固定矩阵规模 $N=1024$，测试线程数 $T$ 从 1 增长到 16 时的性能变化。
2. **规模伸缩性测试：** 固定线程数 $T=8$，测试矩阵规模 $N$ 从 256 增长到 2048 时的性能变化。
### 5.1 实验原始数据

**表 1：可扩展性测试（固定** $N=1024$**，改变** $T$**）**

| 实现策略       | 线程数 (T) | 运行时间 (s) | 性能 (GFLOPS) |
| ---------- | ------- | -------- | ----------- |
| `gemm_row` | 1       | 3.683    | 0.58        |
| `gemm_row` | 2       | 1.531    | 1.40        |
| `gemm_row` | 4       | 0.795    | 2.70        |
| `gemm_row` | 8       | 0.460    | 4.66        |
| `gemm_row` | 16      | 0.296    | 7.26        |
| `gemm_2d`  | 1       | 3.174    | 0.68        |
| `gemm_2d`  | 2       | 1.449    | 1.48        |
| `gemm_2d`  | 4       | 0.728    | 2.95        |
| `gemm_2d`  | 8       | 0.494    | 4.35        |
| `gemm_2d`  | 16      | 0.326    | 6.58        |

**表 2：规模伸缩性测试（固定** $T=8$**，改变** $N$**）**

| 实现策略       | 矩阵规模 (N) | 运行时间 (s) | 性能 (GFLOPS) |
| ---------- | -------- | -------- | ----------- |
| `gemm_row` | 256      | 0.017    | 1.98        |
| `gemm_row` | 512      | 0.079    | 3.42        |
| `gemm_row` | 1024     | 0.451    | 4.76        |
| `gemm_row` | 2048     | 11.448   | 1.50        |
| `gemm_2d`  | 256      | 0.010    | 3.40        |
| `gemm_2d`  | 512      | 0.083    | 3.23        |
| `gemm_2d`  | 1024     | 0.506    | 4.24        |
| `gemm_2d`  | 2048     | 11.045   | 1.56        |
### 5.2 数据分析与结论

#### 1. 正确性验证

在所有的测试中，`Verification error`（弗罗贝尼乌斯范数误差）均在 `e-09` 到 `e-12` 数量级。这是一个极小的浮点误差，**充分证明了 `gemm_row` 和 `gemm_2d` 两种并行实现均是正确的**。

#### 2. 可扩展性分析 (N=1024)

为了评估并行化效率，我们根据**表 1**的数据计算加速比（Speedup = $T_1 / T_P$）。
**表 3：加速比 (Speedup) 对比（**$N=1024$**）**

| 线程数 (T) | `gemm_row` 基准 (3.683s) | `gemm_2d` 基准 (3.174s) | 理想加速比  |
| ------- | ---------------------- | --------------------- | ------ |
| 1       | 1.00x                  | 1.00x                 | 1.00x  |
| 2       | 2.41x                  | 2.19x                 | 2.00x  |
| 4       | 4.63x                  | 4.36x                 | 4.00x  |
| 8       | **8.01x**              | 6.42x                 | 8.00x  |
| 16      | **12.44x**             | 9.74x                 | 16.00x |
**结论：**
1. **两种策略均展现了良好的并行可扩展性。** 随着线程数增加，GFLOPS 稳定提升，运行时间显著下降。
2. **`gemm_row`（按行块）的加速比表现惊人。** 在 8 线程时，它达到了 8.01x 的**超线性加速 (Superlinear Speedup)**，在 16 线程时也达到了 12.44x 的高效率。这可能是因为单线程（T=1）运行时 CPU 缓存效率极低，而多线程（T>1）时，多个核心协同工作，总的缓存使用效率（例如 L3 Cache）反而提高了，导致了超过核心数的加速。
3. **`gemm_2d`（2D分块）的加速比较为常规。** 其加速比始终低于理想值，呈现亚线性（Sublinear）增长，这符合 Amdahl 定律（线程创建、同步开销导致）。
4. **意外发现：** 在 $N=1024$ 这个规模下，**`gemm_row` 的性能和扩展性均意外地优于 `gemm_2d`**。在 8 线程和 16 线程时，`gemm_row` 的 GFLOPS 均高于 `gemm_2d`。这与我们“2D分块缓存效率更高”的理论**相悖**。这可能说明，对于 $N=1024$ 这个中等规模，`gemm_row` 简单的内存访问模式（连续读 A，B 在 L3 中被复用）已经足够高效，而 `gemm_2d` 额外的 tile 索引计算开销反而拖慢了速度。
#### 3. 规模伸缩性分析 (T=8)
**结论（来自表 2）：**
1. **`gemm_2d` 在小矩阵上优势明显。** 当 $N=256$ 时，`gemm_2d` (3.40 GFLOPS) 的性能远高于 `gemm_row` (1.98 GFLOPS)。这**符合理论预期**：当矩阵较小（易于装入 L2/L3 缓存）时，`gemm_2d` 策略（`TILE_SIZE=32`）能更好地利用缓存局部性。
2. **`gemm_row` 在中等矩阵上反超。** 当 $N=512$ 和 $N=1024$ 时，`gemm_row` 的 GFLOPS 反而更高，这与可扩展性测试的结论一致。
3. **两种策略在超大矩阵上均遭遇“内存墙”。** 当 $N=2048$ 时，两种策略的性能都发生了**断崖式下跌**（从 4.x GFLOPS 骤降至 1.5 GFLOPS）。这说明当矩阵过大（$N=2048$ 时，一个矩阵需要 $2048^2 \times 8 \approx 32\text{MB}$ 内存），问题完全转变为**内存带宽受限**。此时 CPU 核心大部分时间在等待数据从内存中读取，无法发挥计算能力。
4. 在 $N=2048$ 时，`gemm_2d` (1.56 GFLOPS) 的性能**终于**略微超过了 `gemm_row` (1.50 GFLOPS)，这也**符合理论预期**，即 Tiling 策略在数据远大于缓存时，能稍微缓解内存墙问题，但效果已不显著。
### 5.3 实验总结

1. Pthreads 并行化能显著提升 GEMM 的计算性能，两种策略都取得了成功。
2. “2D分块”并非在所有情况下都优于“按行块”。`gemm_2d` 的性能高度依赖于 `TILE_SIZE` 和矩阵规模 $N$ 的匹配。
3. 数据显示，`gemm_2d` 在**较小规模**（$N=256$）和**超大规模**（$N=2048$）时表现更优，而 `gemm_row` 在**中等规模**（$N=512, 1024$）时因其实现简单、开销小而获胜。
4. 当问题规模大到一定程度（$N=2048$），GEMM 会从**计算密集型**转变为**内存带宽密集型**，此时单纯增加线程数和优化计算策略已收效甚微。
### SpMV多线程实现
#### 负载均衡
##### 实验数据（负载均衡）

| **线程数 (T)** | **spmv_static (GFLOPS)** | **spmv_dynamic (GFLOPS)** |
| ----------- | ------------------------ | ------------------------- |
| 1           | 0.78                     | 0.72                      |
| 2           | 1.87                     | 0.78                      |
| 4           | 2.04                     | 0.74                      |
| 8           | **2.96**                 | 0.62                      |
| 16          | 2.23                     | 0.53                      |
##### 结论分析（负载均衡）

这张图表清晰地揭示了两个核心问题：
1. **`spmv_dynamic` (动态调度) 性能崩溃：**
    - `spmv_dynamic` 的性能随着线程数增加而**持续下降**（从 T=1 的 0.72 GFLOPS 降到 T=16 的 0.53 GFLOPS）。
    - **原因：互斥锁竞争 (Mutex Contention)**。由于负载是均衡的，且 SpMV 每行计算极快，所有线程都在疯狂抢夺**同一个锁**来获取下一个行号。CPU 绝大部分时间都花在了“排队等锁”上，而不是并行计算。线程越多，排队越长，性能越差。    
2. **`spmv_static` (静态行块) 遭遇瓶颈：**
    - `spmv_static` 表现好得多，因为它没有锁开销。性能从 T=1 (0.78) 提升到 T=8 (**2.96 GFLOPS**)，加速比明显。
    - **但是**，在 T=16 时，性能**反而下降**到了 2.23 GFLOPS。
    - **原因：内存带宽饱和 (Memory Bandwidth Saturation)**。SpMV 是一个典型的“内存带宽受限”算子。你的数据表明，**8 个线程**就已经基本**吃满了**机器的内存总带宽。再增加到 16 个线程，计算能力虽然翻倍了，但内存数据的供应速度没变，多出来的线程无事可做，反而因为线程调度开销拖慢了整体速度。
#### 负载不均衡
在初步测试中，原始的动态调度策略（每次加锁获取一行）因严重的互斥锁竞争而性能低下。为了缓解此问题，我们对动态调度策略进行了优化，采用了**块调度 (Chunk Scheduling)**：每个线程每次加锁时不再只获取一行的任务，而是获取一个包含 `CHUNK_SIZE`（本例中设为 128）行的任务块。这样**大大降低了线程访问临界区（加锁/解锁）的频率**，从而减少了锁竞争开销。

我们使用优化后的动态调度 (`spmv_dynamic` - 块调度修复版) 与静态行块 (`spmv_static`) 策略，对提供的三个 `.bin` 矩阵进行了性能对比。
#### 1. 实验原始数据（优化前）
**表 4：不同 `.bin` 矩阵 8 线程性能对比 (T=8)**

| **矩阵文件**    | **策略**         | **行数 (Rows)** | **列数 (Cols)** | **非零元 (NNZ)** | **运行时间 (秒)** | **性能 (GFLOPS)** |
| ----------- | -------------- | ------------- | ------------- | ------------- | ------------ | --------------- |
| `mtx49.bin` | `spmv_static`  | 102158        | 102158        | 711558        | **0.000845** | **1.68**        |
| `mtx49.bin` | `spmv_dynamic` | 102158        | 102158        | 711558        | 0.031470     | 0.05            |
| `mtx53.bin` | `spmv_static`  | 61349         | 61349         | 3381809       | **0.001846** | **3.66**        |
| `mtx53.bin` | `spmv_dynamic` | 61349         | 61349         | 3381809       | 0.017774     | 0.38            |
| `mtx54.bin` | `spmv_static`  | 125329        | 125329        | 2678750       | **0.001537** | **3.49**        |
| `mtx54.bin` | `spmv_dynamic` | 125329        | 125329        | 2678750       | 0.063493     | 0.08            |

**表 5：`mtx54.bin` 可扩展性测试**

|**策略**|**线程数 (T)**|**运行时间 (秒)**|**性能 (GFLOPS)**|
|---|---|---|---|
|`spmv_static`|1|0.005848|0.92|
|`spmv_static`|2|0.004568|1.17|
|`spmv_static`|4|0.002345|2.28|
|`spmv_static`|8|0.001537|3.49|
|`spmv_static`|16|0.001474|**3.63**|
|`spmv_dynamic`|1|0.006790|0.79|
|`spmv_dynamic`|2|0.032037|0.17|
|`spmv_dynamic`|4|0.042937|0.12|
|`spmv_dynamic`|8|0.063493|0.08|
|`spmv_dynamic`|16|0.025785|0.21|
#### 1. 实验原始数据 (优化后)
**表 6：不同 `.bin` 矩阵 8 线程性能对比 (T=8, Dynamic 优化后)**

| **矩阵文件**    | **策略**                 | **行数 (Rows)** | **列数 (Cols)** | **非零元 (NNZ)** | **平均运行时间 (秒)** | **性能 (GFLOPS)** |
| ----------- | ---------------------- | ------------- | ------------- | ------------- | -------------- | --------------- |
| `mtx49.bin` | `spmv_static`          | 102158        | 102158        | 711558        | **0.000673**   | **2.12**        |
| `mtx49.bin` | `spmv_dynamic (块=128)` | 102158        | 102158        | 711558        | 0.000881       | 1.62            |
| `mtx53.bin` | `spmv_static`          | 61349         | 61349         | 3381809       | **0.001715**   | **3.94**        |
| `mtx53.bin` | `spmv_dynamic (块=128)` | 61349         | 61349         | 3381809       | 0.002476       | 2.73            |
| `mtx54.bin` | `spmv_static`          | 125329        | 125329        | 2678750       | **0.001135**   | **4.72**        |
| `mtx54.bin` | `spmv_dynamic (块=128)` | 125329        | 125329        | 2678750       | 0.001496       | 3.58            |

**表 7：`mtx54.bin` 可扩展性测试 (Dynamic 优化后)**

|**策略**|**线程数 (T)**|**平均运行时间 (秒)**|**性能 (GFLOPS)**|
|---|---|---|---|
|`spmv_static`|1|0.003786|1.41|
|`spmv_static`|2|0.002766|1.94|
|`spmv_static`|4|0.002129|2.52|
|`spmv_static`|8|0.001135|4.72|
|`spmv_static`|16|0.001752|3.06|
|`spmv_dynamic (块=128)`|1|0.003677|1.46|
|`spmv_dynamic (块=128)`|2|0.003385|1.58|
|`spmv_dynamic (块=128)`|4|0.002754|1.95|
|`spmv_dynamic (块=128)`|8|0.002321|2.31|
|`spmv_dynamic (块=128)`|16|**0.001579**|**3.39**|
#### 2. 数据分析与结论 (优化后)

1. **块调度效果显著：** 对比表 6 和之前的 8 线程数据，优化后的 `spmv_dynamic` 性能**大幅提升**。例如，在 `mtx54.bin` 上，性能从之前的 0.08 GFLOPS 提升到 **3.58 GFLOPS**，运行时间从 0.063 秒缩短到 **0.0015 秒**。这**有力地证明了块调度有效减少了锁竞争开销**。
2. **静态策略 (`static`) 仍然领先：** 尽管动态策略性能大幅改善，但在所有三个 `.bin` 矩阵的 8 线程测试中（表 6），静态行块策略 (`static`) 的性能**仍然略优于或接近**优化后的动态策略 (`dynamic` 块=128)。例如，在 `mtx54.bin` 上，`static` (4.72 GFLOPS) 仍然比 `dynamic` (3.58 GFLOPS) 快约 30%。
3. **`.bin` 矩阵负载特性再评估：** 即使使用了块调度优化，动态策略也未能反超静态策略。这进一步支持了之前的判断：这些 `.bin` 文件（`mtx49`, `mtx53`, `mtx54`）的**负载不均衡程度可能并不严重**，不足以让动态调度的灵活性抵消其固有的（即使是优化后的）同步开销。静态划分在这种情况下依然高效。
4. **可扩展性对比 (`mtx54.bin`, 表 7)：**
    - 优化后的 `dynamic` 策略展现了**更好**的可扩展性。其性能随着线程数增加而**持续提升**，在 T=16 时达到了峰值 (3.39 GFLOPS)。这与之前性能随线程数下降形成鲜明对比。
    - `static` 策略在 T=8 时达到峰值 (4.72 GFLOPS)，但在 T=16 时性能**反而下降** (3.06 GFLOPS)。这再次印证了**内存带宽饱和**是 `static` 策略在高线程数下的主要瓶颈。
    - **有趣的反转：** 在 **T=16** 时，优化后的 `dynamic` (3.39 GFLOPS) **首次超过了** `static` (3.06 GFLOPS)。这可能是因为 16 线程下内存带宽竞争过于激烈，`static` 策略的简单划分导致某些核心等待时间增加，而 `dynamic` 的灵活性此时体现出微弱优势。
#### 3. 实验总结 
- 通过采用**块调度**优化，动态调度策略 (`spmv_dynamic`) 的性能相比原始的逐行调度有了**数量级的提升**，有效缓解了互斥锁竞争问题。
- 对于本实验提供的 `.bin` 矩阵，**静态行块策略 (`spmv_static`) 在中低线程数（1-8 线程）下通常能提供最佳性能**，表明这些矩阵的负载相对均衡。
- **动态调度策略（即使优化后）仍存在不可避免的同步开销**，只有在负载极度不均衡或高线程数下内存带宽竞争成为主要矛盾时，才可能显现优势（如本例中 T=16 的情况）。
- SpMV 作为内存带宽受限应用，两种策略在高线程数下都面临性能瓶颈。静态策略更早遭遇**内存带宽饱和**，而动态策略则受**同步开销**和内存带宽的双重制约。
- **优化锁策略是提升动态调度性能的关键**。块调度是一种行之有效的方法。
## 六、实验讨论和心得体会
本次实验收获颇丰。通过从零开始实现 GEMM 和 SpMV 的 Pthreads 并行化，我对并行计算的核心挑战有了更深刻的理解。
首先，我深入实践了 Pthreads 的核心API，包括 `pthread_create` 创建线程、`pthread_join` 等待同步，以及使用 `pthread_mutex_t` 互斥锁来保护“临界区”（如 SpMV 动态调度的任务计数器），掌握了多线程并行的基本SOP。
其次，实验深刻地揭示了**理论优化与实际性能之间的复杂关系**。
- 在 **GEMM（计算密集型）** 实验中，理论上缓存效率更优的“2D分块”策略，在 $N=1024$ 的中等规模下反而**输给**了实现更简单的“按行块”策略。这让我认识到，Tiling 带来的额外索引计算是一种开销，只有当缓存优化的收益足够大时（如 $N=256$ 的小规模或 $N=2048$ 的超大规模），这种开销才值得。同时，$N=2048$ 时两种策略的性能断崖式下跌，也让我直观地理解了“内存墙”瓶颈。
- 在 **SpMV（访存密集型）** 实验中，教训尤为深刻：**同步开销是并行的天敌**。最初的“逐行”动态调度策略，由于（每行）任务粒度过小，导致线程绝大部分时间都在等待同一个互斥锁，造成了严重的“锁竞争”，性能随线程增加反而下降。这让我深刻认识到，对于 SpMV 这种访存密集型算子，同步策略的设计至关重要。
最后，实验让我理解了**并行策略的权衡（Trade-off）**。
- 通过将 SpMV 动态调度优化为“块调度”（Chunk Scheduling），锁竞争的频率大幅降低，性能得到了数量级的提升，证明了**优化锁策略的有效性**。
- 然而，即使在优化后，静态策略（`static`）在大部分情况下依然凭借其“零开销”的优势胜出。这说明本实验提供的 `.bin` 矩阵，其负载不均衡程度还不足以抵消动态调度（即使是块调度）固有的同步开销。**“静态调度”在负载相对均衡时，永远是访存受限应用的高效选择**。
总结而言，并行程序设计没有银弹。最好的策略总是取决于问题的计算/访存特性、任务粒度、数据分布（负载均衡性）以及同步开销之间的精细权衡。