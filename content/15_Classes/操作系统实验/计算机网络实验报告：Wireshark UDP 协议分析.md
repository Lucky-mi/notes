
实验环境： Wireshark v4.x

分析对象： UDP 数据段 (Packet No. 30)

操作命令： nslookup www.bnu.edu.cn

---

## Q1. UDP 数据包编号

问题描述：

选中轨迹文件中的第一个 UDP 段。该段在轨迹文件中的数据包编号 (Packet Number) 是多少？

实验解答：

该 UDP 段在轨迹文件中的数据包编号为 30。

**操作步骤与分析**：

1. 在 Wireshark 的过滤栏输入 `udp` 进行过滤。
    
2. 定位到由 `nslookup` 命令产生的 DNS 查询请求包。
    
3. 观察 **Packet List Pane**（顶部列表栏）的最左侧 `No.` 列。
    
4. 可以看到选中的数据包编号为 30。
    

![[计算机网络实验报告：Wireshark UDP 协议分析.png]]

---

## Q2. 应用层协议类型

问题描述：

这个 UDP 段中携带的应用层负载或协议消息的类型是什么？

实验解答：

该 UDP 段携带的应用层协议是 DNS (Domain Name System，域名系统)。

**操作步骤与分析**：

1. 观察 **Packet List Pane** 的 `Protocol` 列，显示为 DNS。
    
2. 观察 **Packet Details Pane**（中间详情栏），在 `User Datagram Protocol` 层级之下，显示有 `Domain Name System (query)`。
    
3. **理论分析**：`nslookup` 是用于查询域名解析的工具，DNS 协议在传输层通常使用 UDP 协议（当数据包长度超过 512 字节或区域传输时才使用 TCP）。
    

---

## Q3. UDP 首部字段数量与名称

问题描述：

查看 Wireshark 中该数据包的详细信息。UDP 头部一共有多少个字段？这些字段的名称分别是什么？

实验解答：

UDP 头部一共有 4 个字段。

它们的名称分别是：

1. **Source Port** (源端口号)
    
2. **Destination Port** (目的端口号)
    
3. **Length** (长度)
    
4. **Checksum** (校验和)
    

**操作步骤与分析**：

1. 在 **Packet Details Pane** 中找到 `User Datagram Protocol` 行。
    
2. 点击左侧箭头展开，观察其直接子项。
    
3. **408 考点注记**：UDP 是无连接、不可靠的传输层协议，其首部开销非常小，固定为 **8 字节**。这也解释了为什么它只有这 4 个必要的字段。
    

![[计算机网络实验报告：Wireshark UDP 协议分析-1.png]]

---

## Q4. UDP 首部字段长度

问题描述：

根据 Wireshark 中显示的数据包内容，每个 UDP 头部字段的长度（以字节为单位）是多少？

实验解答：

每个字段的长度均为 2 字节。

**操作步骤与分析**：

1. **观察验证**：在 Wireshark 中点击任意一个字段（如 Source Port），观察底部 **Packet Bytes Pane** 高亮的十六进制数。
    
    - 例如 `Source Port: 51669` 对应十六进制 `c9 d5`（假设值），这是 2 个字节。
        
    - `Checksum` 显示为 `0x1c33`，也是 4 个十六进制位，即 2 个字节。
        
2. **理论计算**：
    
    - 源端口 (2 Bytes) + 目的端口 (2 Bytes) + 长度 (2 Bytes) + 校验和 (2 Bytes) = **8 Bytes** (UDP 首部总长度)。
        


---

## Q5. Length 字段的含义与验证

问题描述：

“Length”（长度）字段中的值代表什么的长度？请用你捕获的 UDP 数据包验证你的结论。

实验解答：

结论：Length 字段的值代表 UDP 头部长度加上 UDP 数据载荷（Payload）的总长度。即 $Length = Header + Data$。

数据验证：

根据捕获的第 30 号数据包（Packet 30）：

1. **观察值**：
    
    - Wireshark 显示 `Length: 40`。
        
    - Wireshark 显示 `UDP payload: 32 bytes`。
        
    - 已知 UDP 头部长度固定为 `8 bytes`。
        
2. 计算验证：
    
    $$UDP Header (8) + UDP Payload (32) = 40$$
    
    计算结果 40 与 Length 字段显示的数值 40 完全一致，结论得证。

### 实验总结

通过本次实验，利用 Wireshark 抓取并分析 DNS 查询报文，直观地验证了 UDP 协议的简洁特性。观察到了 UDP 首部仅包含 4 个字段（源端口、目的端口、长度、校验和），每个字段占 2 字节，总首部开销为 8 字节，符合计算机网络理论模型。