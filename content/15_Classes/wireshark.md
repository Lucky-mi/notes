## 1. 实验概述

本次实验旨在通过 Wireshark 抓取并分析 TCP 协议在建立连接（三次握手）及数据传输阶段的行为。实验对象为客户端上传 `alice.txt` 文件至 `gaia.cs.umass.edu` 服务器的过程。

为了获取准确的 TCP 序列号，本次分析已在 Wireshark 首选项中**关闭了“相对序列号” (Relative Sequence Numbers)** 功能。

---

## 2. 实验结果分析 (Q1 - Q5)

### Q1. 客户端连接信息

**问题：** 将 `alice.txt` 文件传输到 `gaia.cs.umass.edu` 的客户端计算机（源）使用的 IP 地址和 TCP 端口号是什么？

- **客户端 IP 地址:** `172.22.238.107`
    
- **客户端 TCP 端口号:** `61849`
    

**【分析过程】** 在 Wireshark 过滤出的 TCP 流中，选取**第一个数据包（No. 782）**。该数据包是三次握手的起始包（SYN）。

- **IP 地址：** 查看 IP 首部中的 **Source** 字段，确认为 `172.22.238.107`。
    
- **端口号：** 查看 TCP 首部中的 **Source Port** 字段，确认为 `61849`。这是一个由操作系统动态分配的临时端口（Ephemeral Port）。
    
![[wireshark.png]]

---

### Q2. 服务器连接信息

**问题：** `gaia.cs.umass.edu` 的 IP 地址是什么？它在哪个端口号上发送和接收该连接的 TCP 数据段？

- **服务器 IP 地址:** `128.119.245.12`
    
- **服务器 TCP 端口号:** `80`
    

**【分析过程】** 同样观察 **No. 782** 数据包（或者 No. 877 服务器回复的包）：

- **IP 地址：** 数据包的 **Destination** 字段显示为 `128.119.245.12`，经 DNS 解析确认这就是 `gaia.cs.umass.edu`。
    
- **端口号：** 数据包的 **Destination Port** 为 `80`。这是 HTTP 协议的标准熟知端口（Well-known Port）。

---

### Q3. SYN 数据段序列号

**问题：** 用于在客户端计算机和 `gaia.cs.umass.edu` 之间发起 TCP 连接的 TCP SYN 数据段的序列号是什么？

- **SYN 数据段序列号 (Sequence Number):** `3022533196`
    

**【分析过程】** 定位到 TCP 三次握手的第一步（No. 782）：

1. 该数据包 Info 列标记为 `[SYN]`，表示这是一个同步报文段。
    
2. 在 Wireshark 设置中取消勾选 "Relative sequence numbers" 后，查看到的 **Sequence Number (raw)** 值为 `3022533196`。
    
3. 该数值是由客户端随机生成的初始序列号（ISN, Initial Sequence Number）。
    
---

### Q4. SYN 段的标识

**问题：** 在这个数据段中，是什么标识了它是一个 SYN 数据段？

- **标识字段：** TCP 首部 **Flags (控制位)** 字段中的 **Syn** 位被置为 1。
    

**【分析过程】** 在 Wireshark 的 Packet Details（详情面板）中展开 Transmission Control Protocol 协议头，查看 Flags 字段：

- 可以看到 `Syn: Set (1)`。
    
- 其他标志位（如 Ack, Psh, Fin）均为 0。
    
- 这表明该报文段用于请求建立连接。
    


![[{7CED30BA-7682-4D44-8D2C-FFD4EA66E669}.png]]

---

### Q5. SYNACK 数据段序列号

**问题：** `gaia.cs.umass.edu` 作为对 SYN 的回复，发送给客户端计算机的 SYNACK 数据段的序列号是什么？

- **SYNACK 数据段序列号 (Sequence Number):** `3307193554`
    

**【分析过程】** 定位到 TCP 三次握手的第二步（No. 877）：

1. 该数据包由服务器发往客户端，Info 列标记为 `[SYN, ACK]`。
    
2. 此时服务器生成了自己的初始序列号。在关闭相对序列号显示的情况下，读取到 `Seq=3307193554`。
    
3. **补充验证（408 考点）：** 该包同时携带确认号 `Ack=3022533197`，该值等于 Q3 中的客户端序列号 + 1，证明了 SYN 包消耗一个序列号。
    