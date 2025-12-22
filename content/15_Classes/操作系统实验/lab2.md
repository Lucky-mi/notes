### 练习1：实现 first-fit 连续物理内存分配算法（需要编程）

在实现first fit 内存分配算法的回收函数时，要考虑地址连续的空闲块之间的合并操作。提示:在建立空闲页块链表时，需要按照空闲页块起始地址来排序，形成一个有序的链表。可能会修改default_pmm.c中的default_init，default_init_memmap，default_alloc_pages， default_free_pages等相关函数。请仔细查看和理解default_pmm.c中的注释。

请在实验报告中简要说明你的设计实现过程。请回答如下问题：
· 你的first fit算法是否有进一步的改进空间

#### 1. 设计实现过程
为了实现 First-Fit 连续物理内存分配算法，并响应实验指导书中“按照空闲页块起始地址来排序，形成一个有序的链表”的提示，本练习重写了 `kern/mm/default_pmm.c` 中的核心函数。
本实现的核心设计思想是：**`free_list` 始终维护一个按物理地址从小到大排序的空闲块链表**。
**a. 关键数据结构设计**
1. **`free_list` (空闲链表):** 这是一个双向循环链表（`list_entry_t`）。链表中的所有节点**严格按照**其对应的物理地址从小到大排序。
2. **`Page` 结构体的 `property` 字段:** 仅当一个 `Page` 是一个连续空闲块的**首页**时，`property` 字段才被使用，用于存储这个空闲块的总大小（即连续的空闲页数量）。
3. **`Page` 结构体的 `page_link` 字段:** **只有**空闲块的**首页**才会被通过 `page_link` 链接到 `free_list` 中。
    
**b. `default_init_memmap` (初始化内存映射)**
此函数负责将一块物理内存区域 `[base, base + n)` 作为一整个空闲块添加到 `free_list` 中，并且**保证插入后链表仍然有序**。
- **改动点:** 它不再是简单地将块添加到链表头，而是遍历 `free_list`（O(N)），找到第一个地址 `page` 大于 `base` 的节点 `le`。
- 然后调用 `list_add_before(le, &(base->page_link))`，将这个新块插入到正确的位置。
```c
// 关键代码: default_init_memmap (节选)
// ... (初始化 base 和 p) ...
base->property = n;
SetPageProperty(base);
nr_free += n;

// 遍历查找正确的插入位置
list_entry_t *le = list_next(&free_list);
while (le != &free_list) {
    struct Page *page = le2page(le, page_link);
    if (base < page) {
        break; // 找到了第一个地址大于 base 的块
    }
    le = list_next(le);
}
// 插入到 le 的前面，保持有序
list_add_before(le, &(base->page_link));
```

**c. `default_alloc_pages` (分配页)**
此函数实现了 First-Fit 搜索和**保持有序的块分裂**逻辑。
1. **搜索 (First-Fit)：** 从 `free_list` 头部（即最低地址）开始遍历，查找第一个 `p->property >= n` 的空闲块 `page`。
2. **移除：** 找到后，将 `page` 块从 `free_list` 中完整地移除（`list_del`）。
3. **分裂 (Split)：**
    - **改动点:** 如果 `found_page->property > n`，则说明块需要分裂。
    - 计算剩余块的首页 `remaining_block_page = page + n`。
    - 设置剩余块的大小 `remaining_block_page->property = page->property - n`。
    - **关键：** 必须将这个剩余的块 `remaining_block_page` 插回 `page` **原来的位置**（即 `le` 节点的前面），以保持链表的地址有序性。
```c
// 关键代码: default_alloc_pages (节选)
if (page != NULL) {
    list_del(&(page->page_link)); // 1. 移除
    if (page->property > n) {
        // 2. 分裂
        struct Page *remaining_block_page = page + n;
        remaining_block_page->property = page->property - n;
        SetPageProperty(remaining_block_page);
        // 3. 将剩余块插回原位，保持有序
        list_add_before(le, &(remaining_block_page->page_link));
    }
    nr_free -= n;
    ClearPageProperty(found_page);
}
```

**d. `default_free_pages` (释放页)**
这是体现“地址有序”**最大优势**的函数，它实现了高效的合并.
1. **准备：** 设置 `base->property = n` 和 `PG_property` 标记。
2. **查找插入点 (O(N))：** 遍历 `free_list`，找到第一个地址 `page` 大于 `base` 的节点 `insert_point`。
3. **插入 (O(1))：** 将 `base` 块插入到 `insert_point` 节点之前，确保链表依然有序。
4. **高效合并 (O(1) 检查)：**
    - **关键改动 (核心优势):** 因为链表是地址有序的，我们**不再需要遍历整个链表**来查找邻居。我们**只需要检查 `base` 块在链表中的前一个（`prev_node`）和后一个（`insert_point`）节点**即可。
    - **向前合并 (合并右侧)：** 检查 `insert_point` 节点（`base` 的后继）。如果 `base + n == next_page`，则说明物理地址连续。将 `next_page` 块合并到 `base` 块中，并从链表删除 `insert_point` 节点。
    - **向后合并 (合并左侧)：** 检查 `prev_node` 节点（`base` 的前驱）。如果 `prev_page + prev_page->property == base`，则说明物理地址连续。将 `base` 块合并到 `prev_page` 块中，并从链表删除 `base` 节点。
```c
// 关键代码: default_free_pages (节选)
// ... (1. 找到插入点 insert_point) ...
// ... (2. 插入 base: list_add_before(insert_point, &(base->page_link));) ...

// 3. 尝试向前合并 (O(1) 检查)
if (insert_point != &free_list) {
    struct Page *next_page = le2page(insert_point, page_link);
    if (base + n == next_page) {
        base->property += next_page->property;
        ClearPageProperty(next_page);
        list_del(insert_point);
    }
}

// 4. 尝试向后合并 (O(1) 检查)
list_entry_t * prev_node = list_prev(&(base->page_link));
if (prev_node != &free_list) {
    struct Page *prev_page = le2page(prev_node, page_link);
    if (prev_page + prev_page->property == base) {
        prev_page->property += base->property;
        ClearPageProperty(base);
        list_del(&(base->page_link));
    }
}
```
#### 2. first fit 算法是否有进一步的改进空间
是的，当前这个**地址有序的 First-Fit 算法**虽然极大提升了 `free_pages` 的合并效率（从 O(N) 遍历查找提升到 O(1) 检查），但 `alloc_pages` 函数仍有改进空间：
1. **分配效率仍为 O(N)：** `default_alloc_pages` 总是从 `free_list` 的头部（即物理内存的低地址）开始搜索（First-Fit）。
2. **头部碎片堆积：** 这种策略倾向于在链表的头部切割出许多小的、无法满足后续请求的内存碎片。这导致后续的 `alloc_pages` 调用可能需要跳过大量小碎片才能找到合适的块，使得**平均搜索时间变长**。
**进一步的改进方案（Next-Fit）：**
一个简单的改进是实现 **Next-Fit (下次适应)** 算法。
- **思路：** 我们可以额外维护一个全局指针 `last_le`，指向**上一次分配结束的位置**。
- **分配时：** `default_alloc_pages` 不再从 `free_list` 的表头开始搜索，而是从 `last_le` 开始搜索。如果搜索到链表末尾还没找到，再回到表头搜索到 `last_le`。
- **好处：** 这种方法可以更均匀地在整个空闲链表上切割内存，避免了碎片集中在头部，能有效提高 `alloc_pages` 的平均搜索效率。
### 练习2：实现寻找虚拟地址对应的页表项（需要编程）

通过设置页表和对应的页表项，可建立虚拟内存地址和物理内存地址的对应关系。其中的get_pte函数是设置页表项环节中的一个重要步骤。此函数找到一个虚地址对应的二级页表项的内核虚地址，如果此二级页表项不存在，则分配一个包含此项的二级页表。本练习需要补全get_pte函数 in kern/mm/pmm.c，实现其功能。请仔细查看和理解get_pte函数中的注释。get_pte函数的调用关系图如下所示：
![](file:///C:\Users\ADMINI~1\AppData\Local\Temp\ksohtml20048\wps1.jpg) 

图1 get_pte函数的调用关系图

请在实验报告中简要说明你的设计实现过程。请回答如下问题：
· 请描述页目录项（Page Directory Entry）和页表项（Page Table Entry）中每个组成部分的含义以及对ucore而言的潜在用处。
· 如果ucore执行过程中访问内存，出现了页访问异常，请问硬件要做哪些事情？



### 练习3：释放某虚地址所在的页并取消对应二级页表项的映射（需要编程）

当释放一个包含某虚地址的物理内存页时，需要让对应此物理内存页的管理数据结构Page做相关的清除处理，使得此物理内存页成为空闲；另外还需把表示虚地址与物理地址对应关系的二级页表项清除。请仔细查看和理解page_remove_pte函数中的注释。为此，需要补全在 kern/mm/pmm.c中的page_remove_pte函数。page_remove_pte函数的调用关系图如下所示：

![](file:///C:\Users\ADMINI~1\AppData\Local\Temp\ksohtml20048\wps2.jpg) 

图2 page_remove_pte函数的调用关系图

请在实验报告中简要说明你的设计实现过程。请回答如下问题：

· 数据结构Page的全局变量（其实是一个数组）的每一项与页表中的页目录项和页表项有无对应关系？如果有，其对应关系是啥？

· 如果希望虚拟地址与物理地址相等，则需要如何修改lab2，完成此事？ **鼓励通过编程来具体完成这个问题**
### 扩展练习Challenge：buddy system（伙伴系统）分配算法(需要编程)

Buddy System算法把系统中的可用存储空间划分为存储块(Block)来进行管理, 每个存储块的大小必须是2的n次幂(Pow(2, n)), 即1, 2, 4, 8, 16, 32, 64, 128...

· 参考[伙伴分配器的一个极简实现](http://coolshell.cn/articles/10427.html)， 在ucore中实现buddy system分配算法，要求有比较充分的测试用例说明实现的正确性，需要有设计文档。

### 扩展练习Challenge：任意大小的内存单元slub分配算法(需要编程)

slub算法，实现两层架构的高效内存单元分配，第一层是基于页大小的内存分配，第二层是在第一层基础上实现基于任意大小的内存分配。可简化实现，能够体现其主体思想即可。

· 参考[linux的slub分配算法/](http://www.ibm.com/developerworks/cn/linux/l-cn-slub/)，在ucore中实现slub分配算法。

要求有比较充分的测试用例说明实现的正确性，需要有设计文档。
![[Pasted image 20251111195110.png]]
