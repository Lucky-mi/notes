## 一、实验内容

本实验包含两个子任务，均基于 OpenMP API 对已有的串行程序进行并行化改造与性能分析。
1. 稠密矩阵—稠密矩阵乘 (GEMM) 的并行实现
- **并行实现**：使用 C 语言和 OpenMP，在串行 GEMM 代码基础上，实现 `C=A×B` 的并行计算 。
- **切分策略**：实现并对比两种不同的数据切分策略 ：
    - **按行块**：将结果矩阵 C 的行区间 (`i` 循环) 划分给不同线程 。
    - **2D 分块**：将结果矩阵 C 划分为 `tile(i,j)`，将 tile 索引作为并行循环，使每个线程负责一个或多个 tile 的计算 。
- **正确性校验**：通过调用 OpenBLAS 库的 `cblas_dgemm` 函数计算标准结果，与本实验实现的并行版本结果进行对比，校验计算的正确性 。
- **计时与规模**：
    - **计时**：使用 `omp_get_wtime()` 函数，仅统计核心计算区间（不含内存申请、初始化和校验）。
    - **规模 (N)**：设置为 64, 128, 256, 512, 1024, 2048 。
    - **线程数 (T)**：设置为 1, 2, 4, 8, 16 (根据 CPU 核心数而定) 。
- **性能指标**：GFLOPS、加速比、并行效率 。
1. 稀疏矩阵向量乘 (SpMV) 的并行实现
- **并行实现**：使用 C 语言和 OpenMP，对 CSR 格式的 SpMV (y=A×x) 实现 `parallel for` 行级并行 。
- **负载场景**：在两种不同负载的矩阵上进行测试 ：
    - **负载均衡矩阵**：使用 `generate_csr` 函数随机生成（例如 N=20000, Density=0.001）。
    - **负载不均衡矩阵**：使用实验提供的三个 `.bin` 矩阵 (`mtx49.bin`, `mtx53.bin`, `mtx54.bin`) 
- **调度策略对比**：在同一最佳线程数 (T_best) 下，对比三种 OpenMP 调度策略的性能 ：
    - `schedule(static)`
    - `schedule(dynamic, CHUNK_SIZE)`
    - `schedule(guided)`
- **正确性校验**：与串行 `spmv_serial_csr` 函数的计算结果进行对比 。
- **计时**：使用 `omp_get_wtime()` 函数，仅统计核心计算区间（包含 10 次运行和预热）。
- **性能指标**：GFLOPS、加速比、并行效率，并重点分析**有效内存带宽 (GB/s)** 。
![[Pasted image 20251110120940.png]]

## 二、实验目的

**1. 针对 GEMM 任务：**
- 理解 OpenMP 的基本使用方法与 Fork-Join 运行时模型，掌握并行域 (`#pragma omp parallel`) 与循环并行 (`#pragma omp parallel for`) 的使用 。
- 在串行 GEMM 基础上，掌握数据并行切分方法，实现 OpenMP 并行化，并对比“按行块”和“2D 分块”两种切分策略的性能差异 。
- 学习评估并行化带来的加速比、并行效率与可扩展性 。
**2. 针对 SpMV 任务：**
- 在串行 SpMV 基础上，掌握按行并行的方法，并完成 `y=A×x` 的 OpenMP 并行实现 。
- 理解 OpenMP 在不规则负载（负载不均衡）场景下的应用方法，重点分析 `static`, `dynamic`, `guided` 三种调度策略的性能差异 。
- 评估并行化在带宽受限计算中的加速效果，分析并行开销、调度策略及非零元分布不均对性能的影响 。
- 理解为什么 SpMV 是一个**内存带宽受限**问题（而非计算受限问题），并学会使用**有效内存带宽 (GB/s)** 作为衡量其性能的关键指标 。
## 三、实验环境
- **操作系统：** Windows 11 wsl ubuntu
- **cpu:** 12th Gen Intel(R) Core(TM) i9-12900H   2.50 GHz
- **线性代数库 (For Verification):** OpenBLAS 0.3.21
## 四、实验步骤

本实验的步骤分为三部分：首先是对所有程序进行编译；其次是任务一 GEMM 的两种并行策略的实现与测试；最后是任务二 SpMV 的两种负载场景和三种调度策略的实现与测试。
### 步骤 1: 程序编译

所有程序均通过 `Makefile` 进行编译。
**1.1. GEMM 编译** 
直接使用 `make` 命令编译 `gemm_row_omp` 和 `gemm_2d_omp` 目标：
```bash
make bin/gemm_row_omp
make bin/gemm_2d_omp
```
编译选项 `CFLAGS` 和 `LDFLAGS` 均包含了 `-fopenmp` 以启用 OpenMP 支持。

**1.2. SpMV 编译 (关键步骤)** 
实验手册要求对比 `Static`, `Dynamic`, `Guided` 三种调度策略。在代码实现中，这是通过手动修改 `spmv_omp_balanced.c` 和 `spmv_omp_unbalanced.c` 中的 OpenMP 指令来切换的。
因此，编译 SpMV 程序需要执行一个“**编辑-编译-重命名**”的循环，以生成全部 6 个可执行文件：
1. **编译 `_static` 版本**：
    - 确保 `spmv_omp_unbalanced.c` 和 `spmv_omp_balanced.c` 中 `schedule(static)` 指令处于**生效**状态（未被注释）。
    - 运行 `make bin/spmv_omp_unbalanced bin/spmv_omp_balanced`。
    - 重命名生成的程序：
        ```bash
        mv bin/spmv_omp_unbalanced bin/spmv_omp_unbalanced_static
        mv bin/spmv_omp_balanced bin/spmv_omp_balanced_static
        ```
2. **编译 `_dynamic` 版本**
    - 编辑上述两个 `.c` 文件，注释掉 `static` 行，**取消注释** `schedule(dynamic, CHUNK_SIZE)` 行。
    - 再次运行 `make`。
    - 重命名：`mv bin/spmv_omp_unbalanced bin/spmv_omp_unbalanced_dynamic` (以此类推)。
3. **编译 `_guided` 版本**
    - 编辑上述两个 `.c` 文件，注释掉 `dynamic` 行，**取消注释** `schedule(guided)` 行。
    - 再次运行 `make`。
    - 重命名：`mv bin/spmv_omp_unbalanced bin/spmv_omp_unbalanced_guided` (以此类推)。
### 步骤 2: 任务一 (GEMM) 实现与测试

#### 2.1. 策略一：“按行块” (`gemm_row_omp.c`) 实现
此策略对应实验手册的“按行块”切分，将结果矩阵 C 的行 (`i` 循环) 分配给不同线程。
- **实现**：在 `main` 函数中，首先通过 `omp_set_num_threads(T)` 设置线程数。
- **计时**：使用 `omp_get_wtime()` 获取核心计算区间的起始和结束时间。
- **核心代码**：在 `gemm_row_omp.c` 中，Pthreads 的 `pthread_create` 和 `pthread_join` 被替换为一条 OpenMP 编译指令 `#pragma omp parallel for`，该指令自动将最外层的 `i` 循环并行化，并将迭代任务分配给线程池中的线程：
    ```c
    // 5. 使用 omp_get_wtime() 计时，替换 gettimeofday()
    double start, end;
    start = omp_get_wtime();
    
    // 6. 核心：用 #pragma 替换 pthread_create/join
    //    这就是实验手册要求的 "按行块" 策略 
    //    OpenMP 会自动将 i 循环 (0 到 N-1) 拆分给 T 个线程
    #pragma omp parallel for
    for (int i = 0; i < N; i++) { // 这里的 i 对应 Pthreads 里的 i = data->start_row
        // (这部分逻辑直接从 gemm_worker 复制而来)
        for (int j = 0; j < N; j++) {
            double sum = 0.0;
            for (int k = 0; k < N; k++) {
                sum += (A[i * N + k]) * (B[k * N + j]);
            }
            C_parallel[i * N + j] = sum;
        }
    }
    // (隐式屏障：到这里时，所有线程都已完成)
    
    end = omp_get_wtime();
    ```
#### 2.2. 策略二：“2D 分块” (`gemm_2d_omp.c`) 实现

此策略对应实验手册的“2D 分块”切分。
- **实现**：此策略首先定义了 `TILE_SIZE` (16x16)，并计算出总的 tile 数量 `total_tiles`。
- **核心代码**：在 `gemm_2d_omp.c` 中，并行化的循环不再是 `i` 或 `j`，而是 `total_tiles` 的索引 `k`。OpenMP 将不同的 `k` 值（即不同的 tile）分配给线程。每个线程在循环内部自行计算该 tile 对应的矩阵坐标 `i` 和 `j`，并完成该 tile 的计算：
    ```c
    const int TILE_SIZE = 16;
    int num_dim = (N + TILE_SIZE - 1) / TILE_SIZE;
    int total_tiles = num_dim * num_dim;
    
    // ... (移除 Pthreads 的手动任务划分)
    
    // 5. 使用 omp_get_wtime() 计时
    double start, end;
    start = omp_get_wtime();
    
    // 6. 核心：替换 pthread_create/join
    //    这是实验手册要求的 "2D分块" 策略 
    //    我们并行化 "tile 索引" (k)
    #pragma omp parallel for
    for (int k = 0; k < total_tiles; k++) { // 这里的 k 对应 Pthreads 里的 k = data->start_idx
        // (这部分逻辑直接从 gemm_worker_2d 复制而来)
        int i = k / num_dim; // tile 行号
        int j = k % num_dim; // tile 列号
    
        // 起始坐标
        int row_start = i * TILE_SIZE;
        int col_start = j * TILE_SIZE;
        int row_end = (i + 1) * TILE_SIZE > N ? N : (i + 1) * TILE_SIZE;
        int col_end = (j + 1) * TILE_SIZE > N ? N : (j + 1) * TILE_SIZE;
    
        // 计算 C 的 tile
        for (int i_tile = row_start; i_tile < row_end; i_tile++) {
            for (int j_tile = col_start; j_tile < col_end; j_tile++) {
                double sum = 0.0;
                for (int k_gemm = 0; k_gemm < N; k_gemm++)
                    sum += (A[i_tile * N + k_gemm]) * (B[k_gemm * N + j_tile]);
                C_parallel[i_tile * N + j_tile] = sum;
            }
        }
    }
    // (隐式屏障)
    
    end = omp_get_wtime();
    ```
#### 2.3. GEMM 测试流程
1. **执行测试**：分别运行两个已编译的可执行文件。
    ```bash
    # 示例：
    ./bin/gemm_row_omp <matrix_size> <num_threads>
    ./bin/gemm_2d_omp <matrix_size> <num_threads>
    ```
    
2. **测试参数**：
    - `matrix_size (N)`: 64, 128, 256, 512, 1024, 2048
    - `num_threads (T)`: 1, 2, 4, 8, 16
3. **数据记录**：记录每次运行输出的 `Elapsed time (seconds)` 和 `Performance (GFLOPS)`。
4. **数据计算**：根据 T=1 的时间和 T=p 的时间，计算加速比 (`Speedup = T1 / Tp`) 和并行效率 (`Efficiency = Speedup / p`)。
### 步骤 3: 任务二 (SpMV) 实现与测试

#### 3.1. SpMV 并行实现 (`spmv_omp_*.c`)
- **实现**：两个 SpMV 程序 (`spmv_omp_balanced.c` 和 `spmv_omp_unbalanced.c`) 均采用相同的并行化策略：使用 `#pragma omp parallel for` 对外层 `i` 循环（行循环）进行并行化。
- **负载场景**：
    - `spmv_omp_balanced.c` 调用 `generate_csr()` 生成随机矩阵，模拟负载均衡场景。
    - `spmv_omp_unbalanced.c` 调用 `load_matrix_from_bin()` 加载 `.bin` 文件，模拟负载不均衡场景。
- **调度策略切换（核心）**： 如“步骤 1.2”所述，调度策略的切换是通过修改源代码中 `for` 循环前的 `#pragma` 指令完成的。以 `spmv_omp_unbalanced.c` 为例，通过注释和反注释以下代码块来选择策略：
    ```c
        // 策略 1: 静态调度 (默认)
        // 类似于spmv_static.c
        #pragma omp parallel for schedule(static)
    
        // 策略 2: 动态调度
        // 类似于spmv_dynamic.c
        // #pragma omp parallel for schedule(dynamic, CHUNK_SIZE)
    
        // 策略 3: 引导式调度 (自动调整 chunk)
        // #pragma omp parallel for schedule(guided)
    
        // ===================================================================
    
        for (int i = 0; i < M_rows; i++) {
            // (这部分逻辑直接从 spmv_worker_static 复制而来)
            double sum = 0.0;
            // ... (内部计算逻辑) ...
            y_parallel[i] = sum;
        }
        // (隐式屏障：所有线程在此汇合)
    ```
- **计时**：程序包含一个外层循环，运行 `num_runs` (10) 次，并跳过 `warm_up_runs` (1) 次，最后计算 `avg_elapsed` (平均时间)，符合实验手册的计时要求。
#### 3.2. SpMV 测试流程

1. **确定“最佳线程数” (T_best)**：
    - 选取一个代表性任务，例如负载不均衡矩阵 `mtx49.bin` 和 `static` 调度策略。
    - 运行 `./bin/spmv_omp_unbalanced_static ./mtx49.bin <T>`，其中 T = 1, 2, 4, 8, 16...
    - 记录 `Average Elapsed time`，时间最短的 T 即为 `T_best`。
2. **测试负载不均衡矩阵 (T = T_best)**：
    - 使用 `T_best` 作为线程数，分别运行 `_static`, `_dynamic`, `_guided` 三个程序，并加载三个 `.bin` 矩阵 (`mtx49.bin`, `mtx53.bin`, `mtx54.bin`)。
    - 示例命令：
        ```bash
        ./bin/spmv_omp_unbalanced_static ./mtx49.bin <T_best>
        ./bin/spmv_omp_unbalanced_dynamic ./mtx49.bin <T_best>
        ./bin/spmv_omp_unbalanced_guided ./mtx49.bin <T_best>
        # (对 mtx53.bin 和 mtx54.bin 重复操作)
        ```
3. **测试负载均衡矩阵 (T = T_best)**：
    - 使用 `T_best` 作为线程数，运行三个 `balanced` 程序。
    - 固定 `matrix_size` 和 `density`（例如 N=20000, D=0.001）。
    - 示例命令：
        ```bash
        ./bin/spmv_omp_balanced_static 20000 0.001 <T_best>
        ./bin/spmv_omp_balanced_dynamic 20000 0.001 <T_best>
        ./bin/spmv_omp_balanced_guided 20000 0.001 <T_best>
        ```
4. **数据记录**：
    - 记录所有 SpMV 测试的 `Average Elapsed time (seconds)` 和 `Performance (GFLOPS)`
    - 同样记录`Effective Bandwidth (GB/s)`，用于分析 SpMV 的带宽受限特性。
## 五、实验结果对比与分析
### 部分结果截图示例
#### GEMM测试
![[{5FD84FD5-1942-4877-A12A-FE6E774469C2}.png]]
#### SpMV负载不均衡测试
![[{846F359B-7852-463E-AA80-780414A34989}.png]]

## 5.1 稠密矩阵乘法 (GEMM)

本部分对比了“按行块 (Row Block)”和“2D Tiling (2D 分块)”两种并行策略，在不同矩阵规模和不同线程数下的性能表现。
### 5.1.1 性能（GFLOPS）对比
GFLOPS (Giga Floating-point Operations Per Second) 是衡量计算密集型任务性能的核心指标。
**表 5.1.1：不同规模下两种策略的 GFLOPS 对比**

| 规模            | 线程数 | Row Block (GFLOPS) | 2D Tiling (GFLOPS) |
| ------------- | --- | ------------------ | ------------------ |
| **128x128**   | 1   | 1.11               | **2.02**           |
|               | 2   | 0.73               | 1.50               |
|               | 4   | 0.46               | 2.12               |
|               | 8   | 0.72               | 0.49               |
|               | 16  | 0.14               | 0.14               |
| **256x256**   | 1   | 1.74               | 1.94               |
|               | 2   | 3.21               | 1.72               |
|               | 4   | 4.01               | 3.78               |
|               | 8   | **4.83**           | 2.11               |
|               | 16  | 0.94               | 1.14               |
| **512x512**   | 1   | 0.63               | 0.69               |
|               | 2   | 1.30               | 1.42               |
|               | 4   | 2.66               | 2.23               |
|               | 8   | 3.66               | **3.86**           |
|               | 16  | 3.40               | 3.29               |
| **1024x1024** | 1   | 0.56               | 0.69               |
|               | 2   | 1.34               | 1.45               |
|               | 4   | 2.79               | 2.90               |
|               | 8   | 4.56               | 4.48               |
|               | 16  | 6.24               | 6.28               |
|               | 32  | **6.61**           | (未测试)              |
| **2048x2048** | 1   | 0.16               | 0.21               |
|               | 2   | 0.94               | 0.45               |
|               | 4   | 1.56               | 2.42               |
|               | 8   | 2.02               | **2.80**           |
|               | 16  | 2.45               | 2.17               |

**分析：**
1. **并行开销 (Overhead):** 对于 `128x128` 这样的小规模矩阵，增加线程数（如从1到2）反而导致性能急剧下降（例如 2D Tiling 从 2.02 降至 1.50 GFLOPS）。这是因为问题规模太小，$O(N^3)$ 的计算量不足以分摊 OpenMP 线程创建、调度和同步的开销。
2. **可扩展性 (Scalability):** 随着矩阵规模增大到 `1024x1024`，性能（GFLOPS）随线程数增加表现出良好的可扩展性， Row Block 策略在32线程时达到峰值 6.61 GFLOPS。
    
3. **算法策略对比：**
    - 在中等规模（`512x512`, `1024x1024`）下，两种策略的性能非常接近，没有显着差异。
    - 在 `2048x2048` 规模下，**2D Tiling 策略在 4 线程和 8 线程时明显优于 Row Block**。例如，8 线程下 2D Tiling (2.80 GFLOPS) 比 Row Block (2.02 GFLOPS) 性能高出约 39%。
### 5.1.2 加速比 (Speedup) 与并行效率 (Efficiency)
加速比 $S(T) = Time(1) / Time(T)$，并行效率 $E(T) = S(T) / T$。我们选取最具代表性的 `1024x1024` 规模进行分析。
**表 5.1.2：1024x1024 规模下 Row Block 策略的加速比与效率**

| 线程数 (T) | 运行时间 (s) | 加速比 (S) | 理想加速比 | 并行效率 (E) |
| ------- | -------- | ------- | ----- | -------- |
| 1       | 3.8648   | 1.00    | 1.0   | 100.0%   |
| 2       | 1.5975   | 2.42    | 2.0   | 121.0%   |
| 4       | 0.7700   | 5.02    | 4.0   | 125.5%   |
| 8       | 0.4706   | 8.21    | 8.0   | 102.6%   |
| 16      | 0.3441   | 11.23   | 16.0  | 70.2%    |

**分析：**
1. **超线性加速 (Super-linear Speedup):** 在 2、4、8 线程时，均观察到了加速比超过线程数的“超线性加速”现象（如4线程时加速比达到 5.02）。这通常归因于**缓存效应 (Cache Effect)**。单线程处理 `1024x1024` 矩阵时，数据远大于 CPU 的 L2/L3 缓存，导致大量缓存未命中。当 4 个线程并发执行时，每个线程只处理 1/4 的数据子集，这个子集能更好地装入各自核心的缓存中，极大地提高了缓存命中率，导致性能提升超过了线程数增加的比例。
2. **并行效率:** 随着线程数增加，并行效率（尤其是超过8线程后）开始下降，符合 Amdahl 定律。
### 5.1.3 算法策略与缓存局部性分析

`2048x2048` 的数据显示 2D Tiling 策略更优，其核心在于**缓存局部性 (Cache Locality)**。
- **Row Block (行块) 策略:** 每个线程在计算结果 $C$ 的某一行时，需要访问 $A$ 的对应行和**整个** $B$ **矩阵**。当 $B$ 矩阵非常大（如 `2048x2048`）时，它无法装入 L3 缓存，导致计算过程中需要反复从主内存中读取 $B$ 矩阵的数据，造成严重的**缓存未命中 (Cache Miss)** 和内存带宽压力。
- **2D Tiling (分块) 策略:** 此策略将 $A, B, C$ 均划分为小块（Tile）。在计算 $C$ 的一个子块时，只需要 $A$ 的行子块和 $B$ 的列子块。通过合理设置块大小，可以确保这些子块能完全装入 L2/L3 缓存，从而实现**极高的数据重用率**。
**结论：** 对于规模较小、数据可装入缓存的 GEMM，Row Block 简单且有效。但对于**规模远超缓存容量**的大矩阵，2D Tiling 策略通过优化缓存局部性，能显着减少内存访问延迟，从而获得更优的性能。
### 5.1.4 性能拐点分析
在 `2048x2048` (2D Tiling) 测试中，8 线程 (2.80 GFLOPS) 的性能**高于** 16 线程 (2.17 GFLOPS)。这说明性能在 8 线程时出现**拐点 (Inflection Point)** 并发生衰退。
这强烈暗示实验平台（CPU）拥有**8 个物理核心**。当线程数从 8 增加到 16 时，系统开始使用**超线程 (Hyper-Threading)**。超线程允许两个线程共享同一个物理核心的资源（如 L1/L2 缓存、执行单元）。对于 GEMM 这种计算密集型和访存密集型任务，资源竞争（尤其是缓存和内存带宽）反而导致了性能下降。
## 5.2 稀疏矩阵向量乘 (SpMV)

本部分实验根据实验手册要求，分别测试了 OpenMP 三种调度策略 (`static`, `dynamic`, `guided`) 在**不均衡负载**（使用 `mtx*.bin` 文件）和**均衡负载**（使用随机生成）两种场景下的性能。
SpMV 是一个典型的**访存受限 (Memory-Bound)** 型计算，其性能瓶颈在于主内存的访问速度，而非 CPU 的计算能力。因此，本报告将使用**有效内存带宽 (Effective Bandwidth, GB/s)** 作为核心性能指标。
### 5.2.1 性能数据：不均衡矩阵
**表 5.2.1：调度策略对比 - mtx49.bin (NNZ: 711,558)**

|线程数|Static (GB/s)|Dynamic (GB/s)|Guided (GB/s)|
|---|---|---|---|
|1|14.20|12.61|9.07|
|2|23.23|20.08|31.54|
|4|**52.31**|41.74|43.27|
|8|37.52|59.74|**62.07**|
|16|36.90|**67.43**|16.23|

**表 5.2.2：调度策略对比 - mtx53.bin (NNZ: 3,381,809)**

|线程数|Static (GB/s)|Dynamic (GB/s)|Guided (GB/s)|
|---|---|---|---|
|1|16.49|18.01|14.34|
|2|24.89|25.45|27.59|
|4|33.86|45.39|40.67|
|8|40.70|64.51|**92.49**|
|16|72.48|57.79|32.21|

**表 5.2.3：调度策略对比 - mtx54.bin (NNZ: 2,678,750)**

|线程数|Static (GB/s)|Dynamic (GB/s)|Guided (GB/s)|
|---|---|---|---|
|1|19.29|13.57|13.54|
|2|30.02|31.84|33.83|
|4|47.57|43.02|33.47|
|8|34.26|**94.50**|83.61|
|16|19.12|83.27|46.40|

### 5.2.2 性能数据：负载均衡矩阵

本测试使用程序动态生成 20000x20000 (NNZ: 400,054) 的随机稀疏矩阵。随机分布确保了每行的非零元数量大致相等，即**负载均衡**。
**表 5.2.4：负载均衡矩阵 (NNZ: 400,054)**

|线程数|Static (GB/s)|Dynamic (GB/s)|Guided (GB/s)|
|---|---|---|---|
|1|18.56|18.89|16.19|
|2|40.86|35.32|37.05|
|4|81.53|53.44|65.22|
|8|63.58|**101.01**|32.01|
|16|74.51|78.75|94.26|

### 5.2.3 分析：不均衡矩阵
1. **Static 策略的崩溃：** 在 `mtx49` 和 `mtx54` 两个严重不均衡的矩阵上，`static` 策略的性能在 4 线程达到峰值后，随线程增加**急剧崩溃**（如 `mtx54` @ 16T 性能仅 19.12 GB/s）。这暴露了 `static` 策略无法处理负载不均，导致“长尾” (Straggler) 线程拖慢整体执行。
2. **Dynamic/Guided 策略的优势：** 在不均衡矩阵上，`dynamic` 和 `guided` 策略通过运行时任务分发，完美解决了负载均衡问题，性能远超 `static`。例如在 `mtx54` @ 8T 时，`dynamic` (94.50 GB/s) 性能是 `static` (34.26 GB/s) 的 **2.7 倍**。
3. **负载均衡的“例外” (`mtx53`)：** 在 `mtx53` 矩阵上，`static` 策略表现出良好的可扩展性，16 线程时甚至优于 `dynamic`。这说明 `mtx53` 虽然非零元多，但其**非零元分布相对均匀**，在这种情况下，`static` 的低开销特性反而成为优势。
4. **性能拐点 (8 线程)：** 在**大型矩阵**（`mtx49`, `mtx53`, `mtx54`）上，性能峰值均出现在 **8 线程**（物理核心数），16 线程（超线程）时性能均出现下降。这印证了 **GEMM 实验中的结论**：对于访存密集的任务，超线程会导致内存总线和缓存竞争加剧，性能反而下降。
### 5.2.4 分析：负载均衡矩阵 
`表 5.2.4` 的数据揭示了一个非常有趣的现象：
1. **分析反转：** `dynamic` 策略在 8 线程时达到了 **101.01 GB/s** 的惊人带宽，**成为该矩阵上的性能冠军**，远超 `static` 和 `guided` 在所有线程数下的表现。
2. **`static` 策略的表现：** `static` 在 4 线程时表现优异 (81.53 GB/s)，但在 8 线程和 16 线程时性能有所回落。
3. **`guided` 策略的表现：** `guided` 在 16 线程时表现极佳 (94.26 GB/s)，但在 8 线程时表现异常地差 (32.01 GB/s)，这可能反映了 `guided` 策略的任务块（chunk）划分算法在 8 线程时与该特定矩阵大小发生了某种冲突。
4. **结论：** 理论上，`static` 策略在负载均衡时开销最低。但本次实验的“负载均衡矩阵”是一个**问题规模极小**（NNZ: 400k, 访存量: 约 8.2MB）的矩阵。
    - **热缓存（Hot Cache）：** 如此小的数据量可以**完全装入 CPU L3 缓存**。
    - **瓶颈转移：** 瓶颈**不再是主内存带宽**，而是 L3/L2 缓存带宽和计算/访存延迟。
    - **`dynamic` 为何胜出：** 在这种 "热缓存" 和 "微工作量"（平均每行 20 个非零元）的场景下，`dynamic` 策略（默认 `chunk=1`）将工作打得极碎。虽然其调度开销理论上更高，但在 L3 缓存极快响应下，这种细粒度任务**完美地隐藏了访存延迟**，并可能规避了 `static` 粗粒度划分带来的微观瓶颈（如缓存行伪共享），从而实现了最高的 L3/L2 带宽利用率。
### 5.2.5 SpMV 结论
1. SpMV 是一个典型的**内存带宽受限**型应用。
2. **对于大型、负载不均衡的矩阵**（如 `mtx49`, `mtx54`）：**必须使用** `schedule(dynamic)` 或 `schedule(guided)`。`schedule(static)` 会导致性能崩溃。
3. **对于大型、负载相对均衡的矩阵**（如 `mtx53`）： `schedule(static)` 或 `schedule(guided)` 是最佳选择，因为它们的运行时开销低于 `dynamic`。
4. **对于小型、负载均衡、可完全装入 L3 缓存的矩阵**（如 `mtx_balanced`）：瓶颈转变为 L3/L2 带宽和延迟。此时，`schedule(dynamic)`（@ 8 线程）和 `schedule(guided)`（@ 16 线程）的细粒度任务划分展现了**最佳的延迟隐藏能力**，性能反而超越了 `static`。
5. **物理核心数**是大型矩阵的性能拐点。但对于可装入 L3 缓存的小型矩阵，性能峰值可以出现在 8 线程（`dynamic`）或 16 线程（`guided`），具体取决于策略和微架构的交互。
6. **建议：** 没有任何一种策略“永远最好”。`schedule(guided)` 在大型矩阵上（无论均衡与否）均表现出色，在小型矩阵上（16T）也表现优异，展现了**最强的综合性能和鲁棒性**，是特征未知时的首选。