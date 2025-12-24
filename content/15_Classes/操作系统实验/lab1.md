## 练1
列出本实验各练习中对应的OS原理的知识点，并说明本实验中的实现部分如何对应和体现了原理中的基本概念和关键知识点。
练习一
本联系中对应的知识点有操作系统开机过程
 **1. 操作系统镜像文件ucore.img是如何一步一步生成的？**
生成ucore.img文件，从Makefile文档中看主要是从两方面进行：构建工具sign，内核kernel与引导程序bootblock，根据makefile的命令一步步解析如下（我将从构建img处开始分析）（并且每一句重要命令直接注释进行解释）：
```c
# create ucore.img

UCOREIMG    := $(call totarget,ucore.img)

$(UCOREIMG): $(kernel) $(bootblock)

    $(V)dd if=/dev/zero of=$@ count=10000
//创建一个10000个扇区大小内容为0的空镜像文件
    $(V)dd if=$(bootblock) of=$@ conv=notrunc
//将bootblock.out引导扇区写在img文件开头，并不截断输出文件
    $(V)dd if=$(kernel) of=$@ seek=1 conv=notrunc
//将kernel写入img文件中，但是跳过第一个扇区，也就是写在bootblock后面
$(call create_target,ucore.img)
```
根据以上程序，创造ucore.img依赖于kernel和bootblock程序，从上到下的dd磁盘操作命令依次为：
dd创建一个10000个扇区大小内容为0的空镜像文件
dd将bootblock.out写在img文件开头，并不截断输出文件
dd将kernal写入img文件中，但是跳过第一个扇区，也就是写在bootblock后面
由此，寻找bootblock.out的生成规则：
```c
# create bootblock

bootfiles = $(call listf_cc,boot)
//查找boot目录下所有的.c和.S文件，把文件名列表赋值给变量bootfiles,(根据listf_cc的定义listf_cc = $(call listf,$(1),$(CTYPE))，调用function.mk中的listf函数)
//listf = $(filter $(if $(2),$(addprefix %.,$(2)),%),\ $(wildcard $(addsuffix $(SLASH)*,$(1))))


$(foreach f,$(bootfiles),$(call cc_compile,$(f),$(CC),$(CFLAGS) -Os -nostdinc))
//这是一个循环语句，f是赋予bootfiles列表的一个文件名，
bootblock = $(call totarget,bootblock)
//明确生成路径
$(bootblock): $(call toobj,$(bootfiles)) | $(call totarget,sign)
//依赖于这些文件，同时注意到创建bootblock之前要创建好sign工具
    @echo + ld $@

    $(V)$(LD) $(LDFLAGS) -N -e start -Ttext 0x7C00 $^ -o $(call toobj,bootblock)
//将普通依赖链接输出一个临时的包含调试信息等信息的ELF格式可执行文件，并且代码起始地址为0x7C00位置（BIOS加载并执行引导扇区的起始地址）
    @$(OBJDUMP) -S $(call objfile,bootblock) > $(call asmfile,bootblock)
//生成bootblock.asm文件，便于进行调试
    @$(OBJCOPY) -S -O binary $(call objfile,bootblock) $(call outfile,bootblock)
//生成一个纯二进制文件bootblock.bin，能直接加载到内存执行
    @$(call totarget,sign) $(call outfile,bootblock) $(bootblock)
//用sign工具读取bin文件，在文件末尾添加“签名”0x55AA，可使引导扇区启动程序
$(call create_target,bootblock)
```
自此，由汇编语言启动程序转为了c语言可用，接下来将主用c语言启动内核程序kernel
**构建kernel**：
```c
# create kernel target

kernel = $(call totarget,kernel)
//加上bin前缀
$(kernel): tools/kernel.ld
//依赖于该文件
$(kernel): $(KOBJS)
    @echo + ld $@
    $(V)$(LD) $(LDFLAGS) -T tools/kernel.ld -o $@ $(KOBJS)
    //链接器
    @$(OBJDUMP) -S $@ > $(call asmfile,kernel)
    //反汇编
    @$(OBJDUMP) -t $@ | $(SED) '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $(call symfile,kernel)
    
$(call create_target,kernel)
```

 **2. 一个被系统认为是符合规范的硬盘主引导扇区的特征是什么？**
根据程序中主引导扇区程序bootasm.s以及sign.c等，可知符合规范的主引导扇区为起始地址为0x7c00，并且应有硬盘有效标志：结尾应由0x55AA组成，大小等于512字节
## 练2
由于我使用了win自带的linux子系统wsl，而不是在虚拟机中进行实验，所以出了小小的bug，wsl仅提供命令行环境，不包含gnome-terminal，所以分别在一个终端中启动qemu，在另一个终端里启动gdb连接，开始进行调试
手动启动qemu：
```shell
qemu-system-i386 -S -s -parallel stdio -hda bin/ucore.img -serial null
#打开qemu
gdb bin/kernel
#启动gdb
```
![[{35B0CC3D-F808-47BF-B1B5-0799BCE242CA}.png]]
```shell
target remote :1234
```
远程连接qemu运行端口
![[{5CD67F17-93E0-46F8-89B1-DB2977601EA1} 1.png]]
```shell
source tools/gdbinit
```
加载gdb初始化命令，将qemu暂停在cpu开始执行指令的入口点，BIOS ROM上，准备开始追踪
*注意一个重要的事，运行source tools/gdbinit前不要运行连接远程的命令，否则会因为重复连接断开*
![[{D1707AC8-9735-4B25-8DEB-0749E14A4143}.png]]
![[{6D00F048-E616-4297-969A-86F6955205E5}.png]]

**1. 从CPU加电后执行的第一条指令开始，单步跟踪BIOS的执行。**
```bash
i r
x/i $pc
si
#不断重复，进行跟踪
```
发现一条条执行bootasm.S中的汇编命令
![[{38249590-993E-4519-B802-7E9FC5A6BD81}.png]]
初始eip指向0x7c00开始的地方

**2. 在初始化位置0x7c00设置实地址断点,测试断点正常。**
![[{945B63AC-83BB-4782-A640-3583B1B2E17D}.png]]
设置断点
**3. 从0x7c00开始跟踪代码运行,将单步跟踪反汇编得到的代码与bootasm.S和bootblock.asm进行比较。**
**跟踪与分析过程**：
GDB 已经成功停在 `0x7c00`。我们使用 `si`（单步指令）、`x/i $pc`（显示当前指令）、`i r [reg]`（查看寄存器）命令，并对照 `bootasm.S` 源代码进行分析。
#### 1. 16 位实模式初始化
**目的**：关闭中断，设置段寄存器为 0，为后续操作（特别是A20开启和GDT加载）准备一个干净、可预测的 16 位环境。
**GDB 跟踪与分析**：
![[{4C83254C-30FB-402D-BC00-AA14E61937BB}.png]]
**分析**：
- GDB 显示的 `cli` 指令与 `bootasm.S`的 `cli` 一致。
- **关键观察**：执行 `si` 前后，`eflags` 寄存器的 `IF` (中断允许) 标志位消失了。这**验证**了 `cli` 指令成功禁用了中断，防止在初始化过程中被外部设备打扰。
![[{05903F6F-D3A6-44F9-8950-CEF4BD44EE00}.png]]
**分析**：
- GDB 显示的指令序列与 `bootasm.S` 完全对应。
- **关键观察**：通过 5 次 `si` 执行后，我们检查 `ax`, `ds`, `es`, `ss` 寄存器，发现它们的值**全部变为了 0**。这**验证**了代码的意图：通过 `ax` 寄存器中转，成功将所有数据段和堆栈段寄存器清零，建立了平坦的 16 位内存模型（所有段都从地址0开始）。
#### 2. 开启 A20 地址线
**目的**：A20 地址线是历史遗留问题，默认关闭时，超过 1MB 的地址会回绕到 0。必须开启它，才能访问 1MB 以上的内存（内核就加载在那里）。这段代码通过 8042 键盘控制器来开启 A20。
**GDB 跟踪与分析**： (我们使用 `ni` (Next Instruction) 命令跳过 `jnz` 循环，否则单步 `si` 会在循环里卡住)

```
# 1. 查看 seta20.1 循环
(gdb) x/3i $pc
=> 0x7c0a:  in     $0x64,%al
   0x7c0c:  test   $0x2,%al
   0x7c0e:  jnz    0x7c0a <seta20.1>

# 2. 在循环后设置断点，然后继续执行
(gdb) b *0x7c10
Breakpoint 2 at 0x7c10
(gdb) c
Continuing.

Breakpoint 2, 0x00007c10 in ?? ()

# 3. 跟踪后续 I/O 指令
(gdb) x/4i $pc
=> 0x7c10:  mov    $0xd1,%al
   0x7c12:  out    %al,$0x64
   0x7c14:  in     $0x64,%al
   0x7c16:  test   $0x2,%al
(gdb) si 4
0x00007c18 in ?? ()

# 4. 再次在循环后设置断点并继续
(gdb) b *0x7c1b
Breakpoint 3 at 0x7c1b
(gdb) c
Continuing.

Breakpoint 3, 0x00007c1b in ?? ()

# 5. 跟踪最后的 A20 开启指令
(gdb) x/2i $pc
=> 0x7c1b:  mov    $0xdf,%al
   0x7c1d:  out    %al,$0x60
(gdb) si 2
0x00007c1f in ?? ()
```
**分析**：

- GDB 显示的指令与 `bootasm.S` [cite: `lab1/boot/bootasm.S`] 中 `seta20.1` 到 `seta20.2` 部分的代码完全一致。
- `in $0x64, %al` 和 `out %al, $0x64` 等指令是 CPU 与外部硬件（键盘控制器）进行 I/O 通信的方式。
- 通过设置断点跳过了 `jnz` 循环（等待键盘控制器就绪），我们跟踪了向 `0x64` 和 `0x60` 端口写入特定命令（`0xd1` 和 `0xdf`）的过程，这**验证**了 `bootloader` 正在执行开启 A20 的标准流程。
在 GDB 步骤 7 (`b *0x7c1b`) 之后，如果继续使用 `c` (Continue) 命令，我们会观察到如截图 所示的现象：程序不断地重新停在 Breakpoint 3 (或者 Breakpoint 1)。
![[{7ECD91B5-03AF-4A35-B8F4-5605BDED4372}.png]]
> **【截图点 2】**：可以截取一张 GDB 正在显示 `in`/`out` 指令的界面，展示与硬件的交互。

#### 3. 切换到 32 位保护模式
**目的**：这是 `bootloader` 最核心的任务之一。通过加载 GDT、修改 `cr0` 寄存器并执行长跳转，将 CPU 从 16 位实模式切换到 32 位保护模式。
**GDB 跟踪与分析**：
```
# 1. 加载 GDT
(gdb) x/i $pc
=> 0x7c1f:  lgdt   0x7c62 <gdtdesc>
(gdb) si
0x00007c25 in ?? ()

# 2. 开启 cr0 的 PE 位
(gdb) x/3i $pc
=> 0x7c25:  mov    %cr0,%eax
   0x7c28:  or     $0x1,%eax
   0x7c2b:  mov    %eax,%cr0

# 3. 观察 cr0 变化
(gdb) i r cr0  # 执行前
cr0             0x10    [ ET ]
(gdb) si 3
0x00007c2e in ?? ()
(gdb) i r cr0  # 执行后
cr0             0x11    [ ET PE ]
```

**分析**：
- **关键观察**：执行 `lgdt` 后，GDB 仍然可以正常跟踪。执行 3 条指令后，`cr0` 寄存器的值从 `0x10` 变成了 `0x11`，GDB 将其解释为 `[ ET PE ]`。`PE` (Protected Enable) 位被成功置 1！这**验证**了我们已经**开启了保护模式**。

```
# 4. 执行 32 位长跳转
(gdb) x/i $pc
=> 0x7c2e:  ljmp   $0x8,$0x7c33

# 5. 执行长跳转
(gdb) si
0x00007c33 in ?? ()

# 6. 观察 CS 寄存器
(gdb) i r cs
cs             0x8      8
```
**分析**
- **关键观察**：`ljmp` 指令是切换模式的最后一步。它将 `PROT_MODE_CSEG`（值为 `0x8`）加载到 `cs` 寄存器中。执行 `si` 后，我们用 `i r cs` 检查，`cs` 寄存器的值果然**从 `0x0` 变成了 `0x8`**。
- `cs` 不再是段地址，而是 GDT 中的**选择子 (Selector)**，`0x8` 正是我们 `gdt` 表中的第二个表项（代码段）。这**验证**了 CPU 已经开始使用 GDT 并且进入了 32 位代码段。
#### 4. 32 位模式初始化与调用 C 代码
**目的**：在 32 位模式下，重新设置所有数据段寄存器（`ds`, `es` 等），使其指向 GDT 中的数据段。然后设置堆栈，并最终调用 `bootmain` 函数。
**GDB 跟踪与分析**：
```
# 1. 跟踪 32 位段寄存器设置
(gdb) x/6i $pc
=> 0x7c33:  mov    $0x10,%ax
   0x7c37:  mov    %ax,%ds
   0x7c39:  mov    %ax,%es
   0x7c3b:  mov    %ax,%fs
   0x7c3d:  mov    %ax,%gs
   0x7c3f:  mov    %ax,%ss
(gdb) si 6
0x00007c41 in ?? ()

# 2. 检查段寄存器
(gdb) i r ds es fs gs ss
ds             0x10     16
es             0x10     16
fs             0x10     16
gs             0x10     16
ss             0x10     16
```
**分析**
- **关键观察**：所有的数据段、附加段、堆栈段寄存器现在的值都是 `0x10`，即 `PROT_MODE_DSEG` 的值。这**验证**了在 32 位模式下，数据访问也已切换为使用 GDT 中的数据段描述符。

```
# 3. 跟踪堆栈设置和 call
(gdb) x/3i $pc
=> 0x7c41:  mov    $0x0,%ebp
   0x7c46:  mov    $0x7c00,%esp
   0x7c4b:  call   0x7e00 <bootmain>

# 4. 执行 mov ebp, mov esp
(gdb) si 2
0x00007c4b in ?? ()

# 5. 观察 ebp 和 esp 寄存器
(gdb) i r ebp esp
ebp            0x0      0x0
esp            0x7c00   0x7c00
```
**分析**：
- **关键观察**：`ebp` 被清零（C 语言中常用来标记调用栈的末尾），`esp` 被设置为 `0x7c00`（即 `start` 标签的地址）。这**验证**了我们为 `bootmain` C 函数准备了堆栈，堆栈空间位于 `0x7c00` 以下的内存区域。
- 下一条指令 `call 0x7e00 <bootmain>`，GDB 已经帮我们反解出了函数名 `bootmain`！这表明即将跳转到 C 代码。

**总结**： 通过 `si` 单步跟踪，我们不仅验证了 GDB 显示的汇编指令与 `bootasm.S` 源代码、`bootblock.asm` 反汇编文件完全一致，更重要的是，我们通过 `i r` 命令观察了关键寄存器（`eflags`, `ds`, `ss`, `cr0`, `cs`, `esp`）在每一步的变化，从而**实证**了 `bootloader` 从 16 位实模式启动、初始化段寄存器、开启 A20、加载 GDT、切换到 32 位保护模式、设置 32 位段和堆栈、最后成功调用 `bootmain` C 函数的**完整执行流程**。
## 练3
**分析bootloader进入保护模式的过程。**
BIOS将通过读取硬盘主引导扇区到内存，并转跳到对应内存中的位置执行bootloader。请分析bootloader是如何完成从实模式进入保护模式的。
提示：需要阅读小节“保护模式和分段机制”和lab1/boot/bootasm.S源码，了解如何从实模式切换到保护模式，需要了解：
· 为何开启A20，以及如何开启A20
· 如何初始化GDT表
· 如何使能和进入保护模式

- **为何开启 A20**:
    - 在早期的 8086 处理器（实模式）中，地址线只有 20 条 (A0-A19)，最大寻址能力是 1MB (2^20)。当地址计算结果超过 1MB 时（例如 FFFF:FFFF = 10FFEFh），会发生地址回绕 (wrap-around)，即第 21 个地址位 (A20) 被丢弃，实际访问的是低地址。
    - 为了兼容这种行为，后续的 CPU 在实模式下默认也禁用了 A20 地址线，即使它们物理上有更多的地址线。
    - 进入保护模式后，我们需要访问超过 1MB 的内存。如果 A20 仍然禁用，那么访问 1MB 以上的地址时，A20 位会被强制置 0，导致地址错误。因此，在进入保护模式之前，必须**开启 A20 Gate**，使得第 21 条地址线 (A20) 能正常工作。
- **如何开启 A20**:
    - 开启 A20 的方法有很多种，最常用的是通过控制键盘控制器 (8042 chip)。
    - 在 `bootasm.S` 中，相关的代码段是：
```c
# Enable A20:
#  For backwards compatibility with the earliest PCs, physical
#  address line 20 is tied low, so that addresses higher than
#  1MB wrap around to zero by default. This code undoes this.
        seta20.1:
            inb     $0x64, %al              # Wait for not busy(8042 input buffer empty).
            testb   $0x2, %al
            jnz     seta20.1
        
            movb    $0xd1, %al              # 0xd1 -> port 0x64
            outb    %al, $0x64              # 0xd1 means: write data to 8042's P2 port
        
        seta20.2:
            inb     $0x64, %al              # Wait for not busy(8042 input buffer empty).
            testb   $0x2, %al
            jnz     seta20.2
        
            movb    $0xdf, %al              # 0xdf -> port 0x60
            outb    %al, $0x60              # 0xdf = 11011111, means set P2's A20 bit(the 1 bit) to 1
```

**代码解释**:
- `inb $0x64, %al` / `testb $0x2, %al` / `jnz seta20.1`: 等待键盘控制器 (端口 0x64) 的状态寄存器的第 1 位（Input Buffer Full）变为 0，表示输入缓冲区为空，可以发送命令。
- `movb $0xd1, %al` / `outb %al, $0x64`: 向端口 0x64 发送命令 `0xd1`，表示下一个写入端口 0x60 的数据是写到键盘控制器的输出端口 (P2)。
- `inb $0x64, %al` / `testb $0x2, %al` / `jnz seta20.2`: 再次等待键盘控制器输入缓冲区为空。
- `movb $0xdf, %al` / `outb %al, $0x60`: 向端口 0x60 写入 `0xdf`。`0xdf` 的二进制是 `11011111`。键盘控制器输出端口的第 1 位（即 A20 Gate 位）被设置为 1，从而开启 A20 地址线。其他位保持不变或设置为特定值以确保正常功能。
**2. 如何初始化 GDT 表？**
- **为何需要 GDT**: 保护模式下的内存访问是基于段描述符的。GDT (Global Descriptor Table) 就是存储这些段描述符的表。CPU 通过 GDTR 寄存器找到 GDT 的位置，并通过段选择子 (Segment Selector) 索引 GDT 中的描述符，获取段的基址、限长、权限等信息。在切换到保护模式前，必须准备好一个 GDT，至少包含代码段和数据段的描述符。
- **如何初始化 GDT**:
    - `bootasm.S` 中定义了 GDT 的内容：
        代码段
        ```
        # Bootstrap GDT
        .p2align 2                                          # force 4 byte alignment
        gdt:
            SEG_NULLASM                                     # null seg
            SEG_ASM(STA_X|STA_R, 0x0, 0xffffffff)           # code seg for bootloader and kernel
            SEG_ASM(STA_W, 0x0, 0xffffffff)                 # data seg for bootloader and kernel
        
        gdtdesc:
            .word   0x17                                    # sizeof(gdt) - 1
            .long   gdt                                     # address gdt
        ```

    - **代码解释**:
        - `gdt:` 标签定义了 GDT 的起始位置。
        - `SEG_NULLASM`: 定义了一个全零的 NULL 描述符，这是 GDT 的第一个描述符必须是 NULL 的规定。`SEG_NULLASM` 是一个宏，定义在 `asm.h` 中，展开为 8 个 0 字节。
        - `SEG_ASM(STA_X|STA_R, 0x0, 0xffffffff)`: 定义了一个代码段描述符。`SEG_ASM` 也是 `asm.h` 中的宏，用于方便地创建段描述符。
            - `STA_X|STA_R`: 表示段属性为可执行 (Execute)、可读 (Read)。
            - `0x0`: 段基址 (Base Address) 为 0。
            - `0xffffffff`: 段限长 (Limit)。这里配合 G 位（Granularity，在宏定义内部设置）为 1，表示 Limit 的单位是 4KB，所以实际段大小是 4GB (0xfffff * 4KB + 3FFFh)。这创建了一个覆盖整个 4GB 物理地址空间的平坦模式 (flat model) 代码段。
        - `SEG_ASM(STA_W, 0x0, 0xffffffff)`: 类似地定义了一个数据段描述符。
            - `STA_W`: 表示段属性为可写 (Write)。基址同样为 0，限长也覆盖整个 4GB 地址空间。
        - `gdtdesc:` 定义了加载 GDT 到 GDTR 寄存器所需的数据结构：
            - `.word 0x17`: GDT 的界限 (Limit)，等于 GDT 大小减 1。这里有 3 个描述符，每个 8 字节，共 24 字节，所以 Limit 是 24 - 1 = 23 (0x17)。
            - `.long gdt`: GDT 的线性基地址。
    - **加载 GDT**: 使用 `lgdt` 指令将 `gdtdesc` 指向的 GDT 信息加载到 GDTR 寄存器中.
        ```
        lgdt    gdtdesc
        ```

**3. 如何使能和进入保护模式？**
- **使能保护模式**: 保护模式的开关位于 CR0 (Control Register 0) 控制寄存器的最低位 (PE - Protection Enable)。将 PE 位置 1 即可使能保护模式。
- **进入保护模式**:
    - 在 `bootasm.S` 中，使能保护模式并进行模式切换的代码是：

        ```
        # Switch from real mode to protected mode. Use a bootstrap GDT
        # based at 0x00000000.
        movl    %cr0, %eax
        orl     $CR0_PE_ON, %eax
        movl    %eax, %cr0
        ```
    - **代码解释**:
        - `movl %cr0, %eax`: 将 CR0 寄存器的内容读入 EAX。
        - `orl $CR0_PE_ON, %eax`: 将 EAX 中的 PE 位 (第 0 位) 置 1。`CR0_PE_ON` 是定义在 `mmu.h` (会被包含) 中的常量，值为 `0x1`。
        - `movl %eax, %cr0`: 将修改后的值写回 CR0 寄存器。**执行完这条指令后，CPU 就正式进入保护模式了**。
- **进入保护模式后的操作**:
    - 仅仅设置 CR0 的 PE 位是不够的。CPU 流水线中可能还有实模式下取的指令。为了清空流水线并确保后续指令在保护模式下正确解释，需要进行一个长跳转 (`ljmp`)。
    - 长跳转指令会同时加载代码段选择子 (CS) 和新的指令指针 (EIP)。加载 CS 会让 CPU 根据 GDT 重新加载代码段描述符缓存器，确保段基址、限长、属性按保护模式解释。
        ```
        # Jump to next instruction, but in 32-bit code segment.
        # Switches processor into 32-bit mode.
        ljmp    $PROT_MODE_CSEG, $protcseg
        ```
    - **代码解释**:
        - `ljmp $PROT_MODE_CSEG, $protcseg`: 执行长跳转。
            - `$PROT_MODE_CSEG`: 这是保护模式下代码段的选择子 (Selector)。根据 GDT 的定义（第 0 个是 NULL，第 1 个是 Code，第 2 个是 Data），代码段的索引是 1。选择子的格式是 `Index << 3 | TI | RPL`。这里 `TI=0` (GDT), `RPL=0` (最高权限)，所以选择子是 `1 << 3 | 0 | 0 = 8` (0x8)。`PROT_MODE_CSEG` 在 `asm.h` 中定义为 `0x8`。
            - `$protcseg`: 这是跳转的目标地址（偏移量），即 `protcseg` 标签所在的位置。
        - 这条跳转指令执行后，CS 寄存器加载了 `0x8`，CPU 开始执行 `protcseg` 处的 32 位代码，并且内存寻址方式也正式切换为保护模式下的方式。
    - **后续设置**: 在 `protcseg` 标签之后，代码会继续设置好数据段寄存器 (DS, ES, SS 等)，使用指向 GDT 中数据段描述符的选择子 (`PROT_MODE_DSEG`，值为 `0x10`，即索引 2)。
        ```
        .code32                                             # Assemble for 32-bit mode
        protcseg:
            # Set up the protected-mode data segment registers
            movw    $PROT_MODE_DSEG, %ax                    # Our data segment selector
            movw    %ax, %ds                                # -> DS: Data Segment
            movw    %ax, %es                                # -> ES: Extra Segment
            movw    %ax, %fs                                # -> FS
            movw    %ax, %gs                                # -> GS
            movw    %ax, %ss                                # -> SS: Stack Segment
        ```

**总结**: Bootloader 进入保护模式的过程可以概括为：
1. **准备工作**: 开启 A20 地址线，确保可以访问 1MB 以上内存。
2. **定义内存视图**: 创建 GDT，定义代码段和数据段（通常是覆盖 4GB 的平坦模式）。
3. **加载 GDT**: 使用 `lgdt` 指令告诉 CPU 新的 GDT 在哪里。
4. **切换模式**: 修改 CR0 寄存器的 PE 位，使能保护模式。
5. **刷新流水线与段寄存器**: 通过 `ljmp` 长跳转到 32 位代码段，清空 CPU 流水线，并加载新的 CS，使得 CPU 按保护模式解释后续指令和内存访问。
6. **设置数据段**: 加载 DS, ES, SS 等数据段寄存器，使用 GDT 中定义的数据段选择子。
7. **设置栈**: 设置保护模式下的栈指针 (ESP)。
完成这些步骤后，CPU 就完全运行在 32 位保护模式下了，可以为加载操作系统内核做准备。
## 练4
**分析bootloader加载ELF格式的OS过程**
通过阅读bootmain.c，了解bootloader如何加载ELF文件。通过分析源代码和通过qemu来运行并调试bootloader&OS，
· bootloader如何读取硬盘扇区的？
· bootloader是如何加载ELF格式的OS？
**1. bootloader 如何读取硬盘扇区的？**

`bootloader` 读取硬盘扇区是通过封装好的函数 `readsect` 和 `readseg` 来实现的。我们主要分析 `readseg` 函数，因为它负责将数据从硬盘读取到内存指定位置。
- **定位相关代码**: 打开 `labcodes/lab1/boot/bootmain.c`，找到 `readseg` 函数。
    ```c
    /* readseg - read @count bytes at @offset from kernel into virtual address @va,
     * might copy more than asked.
     * 加载kernel文件的前count个字节到虚拟地址va，kernel文件从offset位置开始读 */
    static void
    readseg(uintptr_t va, uint32_t count, uint32_t offset) {
        // 计算结束的虚拟地址
        uintptr_t end_va = va + count;
    
        // round down to sector boundary // va向下取整到扇区边界
        va -= offset % SECTSIZE;
    
        // translate from bytes to sectors; kernel starts at sector 1 // 字节偏移量转成扇区偏移量
        uint32_t sectno = (offset / SECTSIZE) + 1; // ELF文件（kernel）从磁盘的第1个扇区开始存储
    
        // If this is too slow, we could read lots of sectors at a time.
        // We'd write more to memory than asked, but it doesn't matter --
        // we load in increasing order. // va < end_va，说明还有数据要加载
        for (; va < end_va; va += SECTSIZE, sectno ++) {
            // 从sectno扇区读取数据到va地址
            readsect((void *)va, sectno);
        }
    }
    ```
    
- **分析**:
    - `readseg(uintptr_t va, uint32_t count, uint32_t offset)`: 这个函数的目的是从 ELF 文件（在硬盘上的偏移量为 `offset`）读取 `count` 个字节，加载到内存的虚拟地址 `va` 处。
    - `va -= offset % SECTSIZE;`: 为了方便按扇区读取，将起始加载地址 `va` 向下对齐到扇区边界。由于 ELF 文件中的段（segment）的偏移 `offset` 不一定是扇区大小 (512字节) 的整数倍，但硬盘读取必须按扇区进行，所以需要调整起始内存地址，使得第一次 `readsect` 读取的数据能够包含 `offset` 所在的位置。
    - `uint32_t sectno = (offset / SECTSIZE) + 1;`: 计算需要读取的第一个扇区的编号。`offset / SECTSIZE` 得到 `offset` 之前有多少个完整的扇区。因为 ucore 的内核镜像（ELF 文件）被放在硬盘的**第 1 个扇区之后**（第 0 个扇区是 bootloader 自己），所以需要加 1。
    - `for (; va < end_va; va += SECTSIZE, sectno ++)`: 这是一个循环，每次读取一个扇区的数据。
        - `va < end_va`: 判断是否已经读完了需要的 `count` 字节（或者稍微超过一点，因为是按扇区读）。
        - `readsect((void *)va, sectno);`: 调用 `readsect` 函数，将硬盘上编号为 `sectno` 的扇区内容读取到内存地址 `va` 处。
        - `va += SECTSIZE, sectno ++`: 更新下一次要读取的内存地址和硬盘扇区号。
- **`readsect` 函数**: `readseg` 依赖于 `readsect`。`readsect` 函数负责具体执行读取单个扇区的操作。
    ```c
    /* readsect - read one sector at @secno into @dst */
    static void
    readsect(void *dst, uint32_t secno) {
        // wait for disk ready // 等待硬盘就绪
        waitdisk();
        // issue command // 发送读取扇区的命令
        outb(0x1F2, 1);                         // count = 1 sector // 读取1个扇区
        outb(0x1F3, secno & 0xFF);              // 设置扇区号的低8位
        outb(0x1F4, (secno >> 8) & 0xFF);       // 设置扇区号的中8位
        outb(0x1F5, (secno >> 16) & 0xFF);      // 设置扇区号的高8位
        outb(0x1F6, ((secno >> 24) & 0xF) | 0xE0); // 使用LBA模式, 设置扇区号的最高4位和驱动器号（0xE0表示主盘）
        outb(0x1F7, 0x20);                      // CMD 0x20 means read sector // 0x20是读扇区命令
    
        // wait for disk ready // 等待硬盘就绪（完成读取操作）
        waitdisk();
    
        // read data // 从数据端口读取数据
        insl(0x1F0, dst, SECTSIZE / 4); // SECTSIZE=512, SECTSIZE/4=128, 读128个32位数据（共512字节）到dst
    }
    ```
    - **分析 `readsect`**:
        - 它通过向 IDE 控制器的 I/O 端口（0x1F0 - 0x1F7）发送命令来直接控制硬盘。
        - `waitdisk()`: 等待硬盘状态寄存器（端口 0x1F7）指示硬盘不忙碌且准备好接收命令或数据传输完成。
        - `outb(...)`: 向 IDE 控制器的命令/参数端口写入数据，设置要读取的扇区数量（这里是 1）、扇区号（LBA 模式）、驱动器号，并发送读命令（0x20）。
        - `insl(0x1F0, dst, SECTSIZE / 4)`: 等待读取完成后，从 IDE 控制器的数据端口（0x1F0）连续读取 128 个 4 字节（共 512 字节，即一个扇区）的数据到目标内存地址 `dst`。
**总结**: Bootloader 通过 `readseg` 函数计算需要读取的扇区范围，然后循环调用 `readsect` 函数。`readsect` 函数通过向 IDE 硬盘控制器发送特定命令序列并读取数据端口，来完成从硬盘读取一个扇区的操作。
**2. bootloader 是如何加载 ELF 格式的 OS？**
Bootloader 加载 ELF (Executable and Linkable Format) 格式的 OS 内核的过程主要在 `bootmain` 函数中完成。
- **定位相关代码**: 打开 `labcodes/lab1/boot/bootmain.c`，找到 `bootmain` 函数。
    ```c
    // bootmain - the entry of bootloader
    void
    bootmain(void) {
        // read the 1st page off disk // 把ELF header读进来
        // 读取kernel文件的第一个扇区（包含ELF Header）到内存0x10000处
        readseg((uintptr_t)ELFHDR, SECTSIZE * 8, 0);
    
        // is this a valid ELF? // 检查是否是有效的ELF文件
        // 通过比较magic number判断是否是ELF文件
        if (ELFHDR->e_magic != ELF_MAGIC) {
            goto bad;
        }
    
        struct proghdr *ph, *eph; // Program Header
    
        // load each program segment (ignores ph flags)
        // 加载每个program segment到内存
        // 计算program header table的起始地址 ph = ELFHDR + e_phoff
        ph = (struct proghdr *)((uintptr_t)ELFHDR + ELFHDR->e_phoff);
        // 计算program header table的结束地址 eph = ph + e_phnum
        eph = ph + ELFHDR->e_phnum;
        // 遍历所有program header
        for (; ph < eph; ph ++) {
            // 将每个段从磁盘加载到指定的物理地址(ph->p_pa)
            // 读取大小为ph->p_filesz字节，从文件偏移ph->p_offset开始
            readseg(ph->p_pa, ph->p_filesz, ph->p_offset);
        }
    
        // call the entry point from the ELF header
        // note: does not return // 跳转到ELF文件的入口点执行
        // ELFHDR->e_entry就是kernel的入口地址
        ((void (*)(void))(ELFHDR->e_entry))();
    
    bad:
        outw(0x8A00, 0x8A00);
        outw(0x8A00, 0x8E00);
    
        /* do nothing */
        while (1);
    }
    ```
- **分析**:
    1. **读取 ELF Header**:
        - `readseg((uintptr_t)ELFHDR, SECTSIZE * 8, 0);`
        - 首先，bootloader 调用 `readseg` 从硬盘的**偏移量 0** (相对于内核文件的起始位置，即硬盘的第 1 个扇区) 开始，读取 `SECTSIZE * 8` (通常是 4KB) 的数据到内存地址 `ELFHDR` (定义为 `0x10000`) 处。这足够包含 ELF Header 和 Program Header Table。
    2. **验证 ELF 文件**:
        - `if (ELFHDR->e_magic != ELF_MAGIC)`
        - 检查加载到内存的 ELF Header 的 `e_magic` 字段是否等于预定义的 ELF 魔数 (`ELF_MAGIC`)。如果不是，说明这不是一个有效的 ELF 文件，跳转到 `bad` 标签（通常是死循环）。
    3. **定位 Program Header Table**:
        - `ph = (struct proghdr *)((uintptr_t)ELFHDR + ELFHDR->e_phoff);`
        - `eph = ph + ELFHDR->e_phnum;`
        - ELF Header 中包含了 Program Header Table 在文件中的偏移量 (`e_phoff`) 和 Program Header 的数量 (`e_phnum`)。通过这些信息计算出 Program Header Table 在内存中的起始地址 `ph` 和结束地址 `eph`。（因为前面已经把包含 Program Header Table 的部分读到内存了）。
    4. **遍历 Program Headers 并加载 Segment**:
        - `for (; ph < eph; ph ++)`: 循环遍历每一个 Program Header。Program Header 描述了 ELF 文件中需要加载到内存的一个段（Segment）。
        - `readseg(ph->p_pa, ph->p_filesz, ph->p_offset);`: 对每个 Program Header (`ph`)：
            - `ph->p_offset`: 这是该段在 ELF 文件中的偏移量。
            - `ph->p_filesz`: 这是该段在文件中的实际大小。
            - `ph->p_pa`: 这是该段需要被加载到的**物理内存地址**。注意 `bootloader` 工作在刚进入保护模式后的阶段，还没有开启分页，所以这里的地址是物理地址。
            - 调用 `readseg` 函数，将文件中从 `p_offset` 开始的 `p_filesz` 字节数据，读取到物理内存的 `p_pa` 地址处。
            - **注意**: 这个加载过程忽略了 Program Header 中的 `p_memsz` (段在内存中的大小) 和标志位（`p_flags`）。对于 `.bss` 段（未初始化数据段），`p_filesz` 为 0，`p_memsz` 大于 0。这个简单的 bootloader 没有处理 `.bss` 段清零的操作，这通常由内核自己后续完成。
                
    5. **跳转到内核入口点**:
        - `((void (*)(void))(ELFHDR->e_entry))();`
        - ELF Header 中包含了程序的入口地址 (`e_entry`)。这是一个**虚拟地址** (在 ucore lab1 中，链接脚本 `tools/kernel.ld` 将内核链接到了高地址，如 `0xC0100000` 开始)。
        - 将 `e_entry` 强制转换为一个函数指针，并调用它。
        - **重要**: 在执行这条跳转指令之前，`bootasm.S` 已经设置好了 GDT，使得代码段和数据段的基址为 0，限长为 4GB，并且进入了保护模式。但是，**分页机制还没有开启**。这意味着 CPU 此时进行的地址转换是 `虚拟地址 = 物理地址` (因为段基址是 0)。然而，内核被链接到了高虚拟地址 `0xC0100000`，但它被 `readseg` 加载到了低物理地址 (通常是 `0x00100000`，即 1MB 处)。直接跳转到 `e_entry` (高虚拟地址) 会失败。
        - **隐藏的细节**: ucore 的 `bootasm.S` 在 `ljmp $PROT_MODE_CSEG, $protcseg` 跳转进入保护模式后，并没有立即跳转到 `bootmain` (它在物理地址 `0x7E00` 附近)。而是设置了段寄存器和栈之后，通过 `call bootmain` 来调用 C 函数。`bootmain` 加载完内核后，会跳转到 `ELFHDR->e_entry`。这个 `e_entry` 地址是内核的入口虚拟地址（例如 `0xC0100000`）。在 Lab1 中，这个跳转能成功，依赖于一个**技巧**或者说是一个**临时的映射**。在 `tools/kernel.ld` 链接脚本中，内核不仅被链接到了高地址 `KERNBASE` (`0xC0100000`)，同时也保留了其加载的低地址 `0x00100000` 附近的信息。`e_entry` 的值虽然是 `0xC010xxxx`，但在没有分页的情况下，CPU 会把它当作物理地址 `0xC010xxxx` 来寻址，这显然是错的。然而，ucore Lab1 的 makefile 在生成内核镜像时，巧妙地使得 `e_entry` 的**低 28 位** ( `0x0010xxxx` ) 正好是内核代码被加载到的物理地址。因此，即使 CPU 错误地尝试访问物理地址 `0xC010xxxx`，实际执行的代码却是在 `0x0010xxxx`。**在后续开启分页的实验 (Lab2) 中，会建立正确的虚拟地址到物理地址的映射，这个跳转才能真正按预期工作。** (在 Lab1 这个阶段，你可以理解为直接跳转到了内核被加载到的物理地址的入口点)。
**总结**: Bootloader 加载 ELF 内核的步骤是：读取并验证 ELF Header -> 找到 Program Header Table -> 遍历 Program Headers，调用 `readseg` 将每个段加载到对应的物理内存地址 -> 跳转到 ELF Header 中指定的内核入口地址 (`e_entry`) 开始执行内核。
## 练5
**实现函数调用堆栈跟踪函数**
![[{03013BC6-6B2A-4541-8570-D4B948769712}.png]]
#### 1. 核心原理：x86 栈帧 (Stack Frame)
要理解堆栈回溯，首先要理解 C 语言在 x86 架构上函数调用时栈（Stack）是如何工作的。
1. **函数调用**: 当一个函数 `caller` (调用者) 调用 `callee` (被调用者) 时：
    - `caller` 将函数参数**从右到左**依次压入（`push`）栈中。
    - `caller` 执行 `call callee` 指令。该指令会自动将**返回地址 (EIP)**（即 `call` 的下一条指令的地址）压入栈中。
2. **函数序言 (Prologue)**: `callee` (被调用者) 函数开始执行时，会先运行一段"序言"代码：
    - `pushl %ebp`: 将 `caller` (调用者) 的 `EBP` 寄存器值压入栈中保存。这非常关键，它像一个链表指针，将当前栈帧与上一个栈帧链接起来。
    - `movl %esp, %ebp`: 将 `ESP` 寄存器（当前栈顶）的值复制到 `EBP`。`EBP` 自此成为 `callee` 函数的**栈帧基址** (Base Pointer)，在 `callee` 函数执行期间，`EBP` 的值保持不变，用于方便地访问参数和局部变量。
        
3. **栈帧布局**: 完成上述步骤后，`callee` 函数（即当前函数）的栈帧布局如下：
    ```
       (高地址)
        ...
       | 参数N       |  <-- ebp + (4 + 4*N)
       | ...         |
       | 参数1       |  <-- ebp + 8
       | 返回地址(EIP)|  <-- ebp + 4   (指向 caller 函数中的下一条指令)
       | 旧的 EBP     |  <-- ebp       (指向 caller 的 EBP)  <== 当前 EBP 寄存器指向这里
       | 局部变量    |  <-- ebp - 4
        ...
       (低地址)      <== 当前 ESP 寄存器指向这里
    ```
    
#### 2. `print_stackframe` 函数代码分析
`print_stackframe` 的任务就是利用上述结构，从当前的 `EBP` 开始，顺着 `[ebp]` 中保存的"旧的 EBP" 链条不断回溯（走向高地址），并在每一层栈帧中提取所需的信息。
```c
// 你编辑器中的已实现代码
void
print_stackframe(void) {
    // (1) 调用 read_ebp() 获取当前 EBP
    uint32_t ebp = read_ebp();
    
    // (2) 调用 read_eip() 获取当前函数的返回地址，即 EIP
    uint32_t eip = read_eip();

    int i, j;
    // (3) 循环回溯栈帧，最多 STACKFRAME_DEPTH (20) 层，或者直到 ebp 为 0
    for (i = 0; i < STACKFRAME_DEPTH && ebp != 0; i++) {
        // (3.1) 打印 ebp 和 eip
        cprintf("ebp:0x%08x eip:0x%08x", ebp, eip);

        // (3.2) 获取参数。参数从 [ebp + 8] (即 (uint32_t *)ebp + 2) 开始
        uint32_t *args = (uint32_t *)ebp + 2;
        cprintf(" args:");
        for (j = 0; j < 4; j++) {
            cprintf(" 0x%08x", args[j]);
        }
        
        // (3.3) 换行
        cprintf("\n");

        // (3.4) 打印 EIP 所在的函数信息。
        print_debuginfo(eip - 1);

        // (3.5) 弹出栈帧，为下一次循环做准备
        //       获取调用者的 EIP (存储在 [ebp + 4])
        eip = ((uint32_t *)ebp)[1];
        //       获取调用者的 EBP (存储在 [ebp])
        ebp = ((uint32_t *)ebp)[0];
    }
}
```
## 练6
**完善中断初始化和处理（需要编程）**

请完成编码工作和回答如下问题：
1. 中断描述符表（也可简称为保护模式下的中断向量表）中一个表项占多少字节？其中哪几位代表中断处理代码的入口？
2. 请编程完善kern/trap/trap.c中对中断向量表进行初始化的函数idt_init。在idt_init函数中，依次对所有中断入口进行初始化。使用mmu.h中的SETGATE宏，填充idt数组内容。每个中断的入口由tools/vectors.c生成，使用trap.c中声明的vectors数组即可。
3. 请编程完善trap.c中的中断处理函数trap，在对时钟中断进行处理的部分填写trap函数中处理时钟中断的部分，使操作系统每遇到100次时钟中断后，调用print_ticks子程序，向屏幕上打印一行文字”100ticks”。
### 1. 问题 1：中断描述符表（IDT）
**大小：** 在 32 位保护模式下，IDT 中的一个表项（称为门描述符，Gate Descriptor）占用 **8 字节**（64 位）。
**入口地址：** 中断处理代码的入口地址（Offset）被分成了两个部分存储在这 8 字节中：
-  **低 16 位**：位于表项的第 0-15 位（`gd_off_15_0` 字段）。
- **高 16 位**：位于表项的第 48-63 位（`gd_off_31_16` 字段）。
    CPU 在响应中断时，会从 IDT 中找到对应的门描述符，并将这两个分离的地址部分重新组合成一个 32 位的 EIP 寄存器值，然后跳转到该地址执行。
### 2. 问题 2：编程完善 `idt_init` 函数

**任务：** 编程完善 `kern/trap/trap.c` 中对中断向量表进行初始化的函数 `idt_init`。
**代码分析 (位于 `labcodes/lab1/kern/trap/trap.c` 中)：**
```c
/* kern/trap/trap.c */

// ... 声明 __vectors 数组，该数组在 vectors.S 中定义
extern void __vectors[](void);

void
idt_init(void) {
    /* ... 注释 ... */

    // 1. 遍历所有 256 个中断向量
    int i;
    for (i = 0; i < 256; i ++) {
        // 2. 设置中断门
        SETGATE(idt[i], 0, GD_KTEXT, __vectors[i], DPL_KERNEL);
    }

    // 3. 特殊设置系统调用门 (用于 Challenge)
    SETGATE(idt[T_SYSCALL], 1, GD_KTEXT, __vectors[T_SYSCALL], DPL_USER);

    // 4. 加载 IDT
    lidt(&idt_pd);
}
```
**实现过程说明：**
1. **`extern void __vectors[](void);`**：首先，代码声明了 `__vectors` 数组。这个数组的地址由链接器提供，它指向在 `kern/trap/vectors.S` 中定义的 256 个中断处理入口点（如 `vector0`, `vector1`, ...）。`__vectors[i]` 对应的就是第 `i` 号中断的处理函数入口地址.
2. **`for (i = 0; i < 256; i ++)`**：循环遍历所有 256 个可能的中断向量（从 0 到 255）。
3. **`SETGATE(idt[i], 0, GD_KTEXT, __vectors[i], DPL_KERNEL);`**：这是初始化的核心。`SETGATE` 是一个在 `kern/mm/mmu.h` 中定义的宏，用于填充一个 8 字节的门描述符。
    - `idt[i]`: 要填充的 IDT 表项。
    - `0`: `istrap` 标志位。`0` 表示这是一个**中断门 (Interrupt Gate)**。当中断通过中断门触发时，CPU 会自动清除 EFLAGS 寄存器中的 `IF` 位，即自动**禁用**其他中断（执行 `cli`）。
    - `GD_KTEXT`: 段选择子（Segment Selector）。`GD_KTEXT` (值为 `0x8`) 指向 GDT 中的内核代码段。这告诉 CPU 在进入中断处理程序时，应切换到内核代码段 (CPL=0)。
    - `__vectors[i]`: 中断处理程序的入口地址（Offset），即 `vectors.S` 中对应的 `vectorX` 标签地址。
    - `DPL_KERNEL`: 描述符特权级 (DPL)。`DPL_KERNEL` (值为 `0`) 表示这个中断门是内核态的。这意味着在默认情况下，只有内核代码（CPL=0）能通过 `int $i` 指令来软件触发此中断。
4. **`SETGATE(idt[T_SYSCALL], 1, GD_KTEXT, __vectors[T_SYSCALL], DPL_USER);`**：
    - 这是一个**特殊设置**，用于系统调用（`T_SYSCALL` 中断号，通常是 `0x80` 或 `48`）。
    - `1`: `istrap` 标志位被设为 `1`，表示这是一个**陷阱门 (Trap Gate)**。陷阱门和中断门唯一的区别是：通过陷阱门进入中断处理时，CPU **不会**自动禁用中断（即不会清除 `IF` 位）。
    - `DPL_USER`: DPL 被设置为 `3`。这允许**用户态**代码（CPL=3）通过 `int $T_SYSCALL` 指令来触发这个中断，从而实现从用户态向内核态请求服务（即“系统调用”）。
5. **`lidt(&idt_pd);`**：最后，调用 `lidt` 指令（Load IDT Register）将 `idt_pd` 结构体（它包含了 IDT 数组的基地址和长度限制）加载到 CPU 的 `IDTR` 寄存器中。至此，CPU 就知道去哪里查找中断处理程序了。
### 3. 问题 3：编程完善 `trap` 函数中的时钟中断处理
**任务：** 在 `trap_dispatch` 函数中（`trap` 函数会调用它），处理时钟中断（`IRQ_OFFSET + IRQ_TIMER`），每 100 次中断打印一次 "100 ticks"。
**代码分析 (位于 `labcodes/lab1/kern/trap/trap.c` 中)：**

```c
/* kern/trap/trap.c */

// ... ticks 变量定义
static volatile int ticks;

// ...
static void
trap_dispatch(struct trapframe *tf) {
    char c;

    switch (tf->tf_trapno) {
    case IRQ_OFFSET + IRQ_TIMER:
        /* LAB1 EXERCISE6: YOUR CODE */
        
        // (1) 全局变量 ticks++
        ticks ++;
        
        // (2) 如果 ticks 是 100 的倍数, 打印 "100 ticks"
        if (ticks % 100 == 0) {
            print_ticks();
        }
        break; 
    // ...
    }
}
```
**实现过程说明：**
1. **`case IRQ_OFFSET + IRQ_TIMER:`**：
    - `tf->tf_trapno` 存储了触发的中断号。
    - `IRQ_OFFSET` 在 `trap.h` 中定义为 `32`。这是因为 x86 CPU 的 0-31 号中断/异常被保留用于 CPU 内部事件（如除零错误、页错误等）。
    - 外部硬件中断（IRQs）通过 8259A PIC 芯片被**重映射 (remap)** 到了 32-47 号中断。
    - `IRQ_TIMER` (在 `picirq.h` 中定义为 `0`) 是硬件中断请求的第 0 号线，即时钟中断。
    - 因此，`IRQ_OFFSET + IRQ_TIMER`（即 `32 + 0 = 32`）就是时钟中断的中断号。
2. **`ticks ++;`**：
    - `ticks` 是一个在 `trap.c` 文件顶部定义的静态全局变量 (`static volatile int ticks;`)。
    - 每当一次时钟中断发生，`trap_dispatch` 就会被调用，并执行这个 `case`，使 `ticks` 计数器加 1。
3. **`if (ticks % 100 == 0)`**：
    - 使用取模运算符 `%` 检查 `ticks` 计数器是否达到了 100 的倍数。
4. **`print_ticks();`**：
    - 如果达到了 100 次，就调用 `print_ticks()` 函数（也在 `trap.c` 中定义），该函数会向屏幕打印 "100 ticks\n"。
    - 由于 ucore 默认设置时钟中断频率为 100Hz（每秒 100 次），这个 `if` 语句大约每秒钟会执行一次，从而实现了“大约每 1 秒会输出一次”的实验现象。