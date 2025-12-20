## 一、 实验目的
1. 观察和分析 DHCP (Dynamic Host Configuration Protocol) 的协议交互过程。
2. 验证 DHCP 的四步握手机制（Discover, Offer, Request, ACK）。
3. 深入理解 DHCP 报文结构、UDP 封装以及关键字段（如 Transaction ID, Option 55）的含义。
## 二、 实验步骤
1. 在 Windows 命令行执行 `ipconfig /release` 释放当前 IP，使主机进入无 IP 状态。
2. 启动 Wireshark 开始抓包。
3. 执行 `ipconfig /renew` 请求新 IP，触发 DHCP 交互。
4. 在 Wireshark 中使用过滤条件 `dhcp` 筛选数据包。
5. **定位数据包：** 成功捕获到 **Packet #733 (DHCP Discover)**，这是主机寻找 DHCP 服务器的第一个广播包。
![[{5B9641BB-D17A-4F0B-8B2C-9E5D9C482C22}.png]]
## 三、 实验问答与分析 (Q1-Q5)
本次分析主要针对 **DHCP Discover** 报文（Packet #733）。
### Q1. Is this DHCP Discover message sent out using UDP or TCP as the underlying transport protocol?
**(这个 DHCP Discover 消息是使用 UDP 还是 TCP 作为底层传输协议？)**
- **答案：** **UDP**
- **分析：** 通过 Wireshark 的 Protocol 列可以看到显示为 DHCP，而 DHCP 是构建在 **UDP** 之上的应用层协议。
    - **原理：** DHCP 客户端在未获取 IP 地址之前，无法与服务器建立 TCP 连接（需要三次握手）。因此，必须使用无连接的 UDP 协议。 
    - 客户端使用端口 **68**，服务器使用端口 **67**。
### Q2. What is the source IP address used in the IP datagram containing the Discover message? Is there anything special about this address? Explain.
**(Discover 消息的源 IP 地址是多少？这个地址有什么特殊之处？请解释。)**
- **答案：** **0.0.0.0**
- **分析：**
    - 根据 Packet #733 的 Source 列显示，地址为 `0.0.0.0`。
    - **特殊之处与解释：** 这是一个特殊的 IPv4 地址，称为“未指定地址”。
    - 在 DHCP Discover 阶段，客户端（本机）尚未被分配有效的 IP 地址，处于初始化状态。因此，它使用 `0.0.0.0` 作为源地址，以此来代表“本机”，告诉网络“我现在还没有身份”。
### Q3. What is the destination IP address used in the datagram containing the Discover message? Is there anything special about this address? Explain.
**(Discover 消息的目的 IP 地址是多少？这个地址有什么特殊之处？请解释。)**
- **答案：** **255.255.255.255**
- **分析：**
    - 根据 Packet #733 的 Destination 列显示，地址为 `255.255.255.255`。
    - **特殊之处与解释：** 这是一个**受限广播地址 (Limited Broadcast Address)**。
    - 由于客户端不知道局域网内 DHCP 服务器的具体 IP 地址，也不确定有几台服务器，因此它必须向当前子网内的**所有设备**发送广播。只有运行了 DHCP 服务端的设备才会处理此报文并回复 Offer。
### Q4. What is the value in the transaction ID field of this DHCP Discover message?
**(这个 DHCP Discover 消息中的 Transaction ID 值是多少？)**
- **答案：** **0xbe5520d0**
- **分析：**
    - 在 Packet #733 的 Info 列（或展开 Bootstrap Protocol 详情）中可以看到：`Transaction ID 0xbe5520d0`。
    - **作用：** 这是一个由客户端生成的 32 位随机数。用于标识一次特定的 DHCP 会话。当服务器回复 DHCP Offer 时，会携带相同的 Transaction ID，客户端通过比对 ID 来确认“这个 Offer 是回给我的，而不是别人的”。
### Q5. Now inspect the options field in the DHCP Discover message. What are five pieces of information (beyond an IP address) that the client is suggesting or requesting to receive from the DHCP server?
**(检查 Options 字段。除了 IP 地址外，客户端还请求了哪 5 条信息？)**
![[{45EEDE77-7F1C-4768-AA12-FF8466F2DBAB}.png]]
![[{BB3882EC-9D4F-434A-98D4-AC8A1A973DDC}.png]]
- **答案：** 客户端通过 **Option (55) Parameter Request List** 字段请求以下参数（常见示例）：
    1. **Subnet Mask** (子网掩码, Option 1)
    2. **Router** (默认网关, Option 3)
    3. **Domain Name Server** (DNS 服务器, Option 6)
    4. **Domain Name** (域名, Option 15)
    5. **Broadcast Address** (广播地址, Option 28) _(注：实际抓包中可能还包含 NetBIOS Name Server, MTU 等，以上为最核心的 5 项网络配置)_
- **分析：** DHCP 不仅仅分配 IP 地址，还负责分发各种网络配置参数，实现了主机的“即插即用”。
## 四、 实验总结
通过本次实验，我成功抓取了完整的 DHCP 交互流程，验证了：
1. **UDP 传输：** DHCP 依赖 UDP 端口 67/68 工作。
2. **0.0.0.0 与 255.255.255.255：** 在主机无 IP 时，利用全零源地址和全 1 目的地址进行广播发现。
3. **Transaction ID：** 事务 ID 是确保请求与响应对应的关键。
本次抓包数据 (Packet 733-739) 清晰展示了 DORA (Discover-Offer-Request-ACK) 的全过程，与理论知识完全一致。