## 一、 单项选择题

### 1. 硬件灵活性对比

> 题目：CPU、ASIC和FPGA中，灵活性最低的是？
> 
> A. CPU
> 
> B. ASIC
> 
> C. FPGA

- ✅ **答案**：**B. ASIC**
    
- **💡 解析**：
    
    - **CPU**：通用处理器，可以通过软件编程做任何事，**灵活性最高**，效率最低。
        
    - **FPGA** (Field Programmable Gate Array)：现场可编程门阵列，硬件电路可重构，灵活性居中。
        
    - **ASIC** (Application Specific Integrated Circuit)：专用集成电路。一旦生产出来电路就定死了（比如比特币矿机芯片），**灵活性最低**，但针对特定任务效率最高。
        

### 2. 开发难度对比

> 题目：GPU、ASIC和FPGA，编程开发难度从高到低依次是？
> 
> A. FPGA、GPU、ASIC
> 
> B. FPGA、ASIC、GPU
> 
> C. ASIC、GPU、FPGA
> 
> D. ASIC、FPGA、GPU

- ✅ **答案**：**D. ASIC、FPGA、GPU**
    
- **💡 解析**：
    
    - **ASIC**：需要设计芯片掩膜，涉及复杂的物理设计验证，周期极长，**难度最高**。
        
    - **FPGA**：需要使用 Verilog/VHDL 硬件描述语言，涉及时序收敛等硬件问题，难度次之。
        
    - **GPU**：使用 CUDA/OpenCL 等类 C 语言开发，属于软件范畴，**难度相对最低**。
        

### 3. 编程模型开源性

> 题目：下列哪个编程模型不是开源的？
> 
> A. CUDA
> 
> B. OpenMP
> 
> C. OpenACC
> 
> D. OpenCL

- ✅ **答案**：**A. CUDA**
    
- **💡 解析**：
    
    - **CUDA** 是 **NVIDIA 独家**的专有架构，不开源。
        
    - OpenMP, OpenACC, OpenCL 都是开放的工业标准。
        

### 4. GPU 存储层次速度 (必考)

> 题目：GPU的多级存储结构...按照访问速度从快到慢依次排序：
> 
> A. register、local memory、shared memory、global memory
> 
> B. register、shared memory、local memory、global memory
> 
> C. shared memory、register、local memory、global memory
> 
> D. shared memory、register、global memory、local memory

- ✅ **答案**：**B**
    
- **💡 解析**：
    
    - **Register (寄存器)**：最快（0周期延迟）。
        
    - **Shared Memory (共享内存)**：片上 L1 缓存速度（极快）。
        
    - **Local Memory**：虽然叫 Local，但物理上通常存储在显存（DRAM）中，只是它是线程私有的。速度较慢（同 Global）。
        
    - **Global Memory (全局内存)**：片外显存（DRAM），最慢（几百个周期延迟）。
        
    - _注：虽然 Local 和 Global 物理位置常在一起，但通常认为 Register > Shared >> Global/Local。选项 B 是最符合层级关系的。_
        

### 5. CUDA 程序执行流程

> 题目：使用GPU CUDA编写并行程序可以总结为以下几个步骤...
> 
> (1) CPU->GPU 传数据 (2) CPU准备数据 (3) 启动内核 (4) GPU->CPU 传回结果 (5) GPU申请显存

- ✅ **答案**：**C. (2)(5)(1)(3)(4)**
    
- **💡 解析**：
    
    1. Host (CPU) 准备数据。
        
    2. `cudaMalloc` (在 GPU 上挖坑)。
        
    3. `cudaMemcpy` (HostToDevice，把数据填进坑里)。
        
    4. `Kernel<<<...>>>` (启动 GPU 计算)。
        
    5. `cudaMemcpy` (DeviceToHost，把结果捞回来)。
        

### 6. 内核函数关键字

> 题目：...称为GPU的内核函数或核函数，该函数只能从CPU端调用，且运行在GPU上
> 
> A. __host__
> 
> B. __global__
> 
> C. __device__
> 
> D. __host__ __device__

- ✅ **答案**：**B. `__global__`**
    
- **💡 辨析**：
    
    - `__global__`：**Host 调用，Device 执行**（这就是 Kernel）。
        
    - `__device__`：Device 调用，Device 执行（GPU 内部的子函数）。
        
    - `__host__`：Host 调用，Host 执行（普通的 C++ 函数）。
        

### 7. 访存竞争 (Race Condition)

> 题目：下列代码中存在哪种访存竞争问题...
> 
> （代码逻辑：先读 Global 到 Shared temp，然后立刻读取 temp 计算，中间缺少了 __syncthreads()）

- ✅ **答案**：**A. RAW (先写后读 / Read-After-Write)**
    
- **💡 深度解析**：
    
    - **意图**：代码想先**写**数据到 `temp`（加载阶段），然后**读** `temp`（计算阶段）。
        
    - **问题**：如果没有 `__syncthreads()`，线程 A 可能还在**写** `temp[i]`，而线程 B 已经跑得很快，试图去**读** `temp[i]`（作为它的邻居数据）。
        
    - **后果**：线程 B **读**到的是旧数据或垃圾数据，因为它本该等待线程 A **写**完。这违反了“写完才能读”的依赖关系，即 RAW 依赖。
        

### 8. 互联总线

> 题目：目前CPU和GPU之间的互联总线主要是
> 
> A. QPI
> 
> B. UPI
> 
> C. PCI-E
> 
> D. NVLink

- ✅ **答案**：**C. PCI-E**
    
- **💡 解析**：
    
    - 大多数消费级和服务器 GPU 通过 **PCI-E** 插槽连接 CPU。
        
    - **NVLink** 通常用于 GPU 之间的高速互联（虽然现在也有 CPU 支持 NVLink，但 PCI-E 仍是主流标准）。
        

### 9. 合并访问 (Coalesced Access)

> **题目**：下列哪种全局内存访问方式不能由一次合并内存访问完成...（选项缺失，根据常识推断）

- ✅ **推断答案**：通常选 **“非对齐访问”** 或 **“跨步访问 (Strided Access)”**。
    
- **💡 解析**：
    
    - **合并访问 (Coalesced)**：一个 Warp 的 32 个线程，正好访问一段连续的内存地址（Thread 0 读地址 0，Thread 1 读地址 1...）。
        
    - **不合并**：线程访问的地址是跳跃的（比如 Thread 0 读地址 0，Thread 1 读地址 32...），或者结构体数组 (`Array of Structures`) 的访问模式。
        

### 10 & 11. CPU vs GPU 特性

- **Q10 (GPU)**：大量弱核心、高吞吐量、硬件切换上下文 $\rightarrow$ **B. GPU**。
    
- **Q11 (CPU)**：少量强核心、低延迟、逻辑控制强 $\rightarrow$ **A. CPU**。
    

---

## 二、 多选题

### 1. Warp 占用率 (Occupancy)

> 题目：每个流式多处理器（SM）上同时可以活跃的 warps 数量与哪些因素有关？
> 
> A. 每个线程使用的寄存器数量
> 
> B. 每个线程块使用的共享内存大小
> 
> C. 每个线程块包含的线程数量
> 
> D. 每个grid包含的线程块数量

- ✅ **答案**：**A, B, C**
    
- **💡 解析**：这是一个非常经典的 **Occupancy（占用率）** 问题。SM 的资源（寄存器文件大小、共享内存大小、最大线程槽位）是有限的。
    
    - **寄存器 (A)**：如果一个线程用的寄存器太多，SM 能容纳的线程总数就变少。
        
    - **共享内存 (B)**：如果一个 Block 用的 Shared Memory 太多，SM 能同时跑的 Block 就变少。
        
    - **Block大小 (C)**：硬件限制了每个 Block 的最大线程数和每个 SM 的最大 Block 数。
        
    - _D 选项无关_：Grid 大小是软件设定的总任务量，不影响 SM 硬件层面的**并发活跃**能力。
        

---

## 三、 填空题 (代码与概念)

### 1. 异构模型定义

> 异构并行编程模型是 `应用` 与 `底层硬件` 之间的桥梁。

### 2. 线程索引计算 (纠错!)

> 在CUDA编程中... `func<<<20, 512>>>` ...
> 
> - 获取块内编号：`threadIdx.x`
>     
> - 获取块编号：`blockIdx.x`
>     
> - **全局编号计算**：
>     
>     - 你的答案：`5122` (计算过程：$10 \times 512 + 2 = 5122$)。**答案正确！**
>         
>     - **公式**：`GlobalId = blockIdx.x * blockDim.x + threadIdx.x`
>         

### 3. 块内同步

> 哪个语句能够实现线程块内的所有线程同步：`__syncthreads();`

### 4. 代码填空 (重点纠错!)

> 题目代码片段：
> 
> int index = threadIdx.x + blockIdx.x * blockDim.x ;
> 
> - **❌ 你的提交**：`threadIdx.x+blockIdx.x+blockDim.x`
>     
> - **⚠️ 纠错**：注意中间是 **乘号 (`*`)** 不是加号！这是计算二维网格拉成一维索引的标准公式。
>     
> 
> cudaMemcpy(..., cudaMemcpyHostToDevice );
> 
> cudaMemcpy(..., cudaMemcpyDeviceToHost );

### 5. CUDA 内存 API

> - 申请内存：`cudaMalloc`
>     
> - 释放内存：`cudaFree`
>     
> - 内存拷贝：`cudaMemcpy`
>     

### 6. Warp Divergence (线程束分歧)

> 同一个warp中的线程遇到IF-ELSE...导致串行执行...这种现象称作：**`Warp Divergence`**。

### 7. Warp Size

> 在NVIDIA最近几代的GPU中，每个warp由 **`32`** 个线程组成。

### 8. Bank Conflict (存储体冲突)

> 下列哪种共享内存访问方式会发生bank conflict？
> 
> - 你的提交：`e` (可能是误触)
>     
> - **💡 正确概念**：**跨步访问 (Strided Access)** 或 **多个线程同时访问同一个 Bank 的不同地址**。
>     
> - _解释_：Shared Memory 被划分为 32 个 Bank。如果 Warp 里 Thread 0 访问 Bank 0 的地址 A，Thread 1 访问 Bank 0 的地址 B，它俩就得排队（串行），这就是 Conflict。
>