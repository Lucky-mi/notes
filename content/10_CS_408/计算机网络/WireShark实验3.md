## 实验目的
通过使用 `traceroute` (Windows 下为 `tracert`) 程序发送数据包，并使用 Wireshark 进行抓包分析，深入理解 IPv4 数据报（Datagram）的结构、头部字段含义（如 TTL、Protocol、Header Length 等）以及 IP 分片原理。
## 实验步骤与分析 (Part 1: Basic IPv4)
**操作描述：**
1. 启动 Wireshark 开始抓包。
2. 在 Windows 命令行中输入 `tracert gaia.cs.umass.edu`。
3. 待追踪完成后停止抓包。
4. 使用显示过滤器 `ip.dst == 128.119.245.12` 筛选出本机发往目标主机的第一个数据包（Packet #126）。
**数据包选择：** 本次分析选取的是追踪过程中本机发出的**第一个** IP 数据报（No. 126）。
![[{0235F8F7-8145-4BF3-BDD6-622DC7AC9400}.png]]
### Q1. What is the IP address of your computer?
**问题：** 你的计算机的 IP 地址是多少？
**答：** 根据 Wireshark 捕获的第 126 号数据包，查看 IPv4 头部信息的 **Source** 字段：
- **IP Address:** `172.23.176.163`
**分析：** 在 IP 数据报头部中，Source Address 字段占 32 位，标识了发送该数据报的源主机接口地址。
![[{2BC4ECAA-5F36-43CA-B0C4-E5D4894969A3}.png]]
### Q2. What is the value in the time-to-live (TTL) field in this IPv4 datagram’s header?
**问题：** 该 IPv4 数据报头部中的生存时间 (TTL) 字段的值是多少？
**答：** 查看 IPv4 头部的 **Time to live** 字段：
- **Value:** `1`
**分析：** `traceroute` 程序的工作原理是向目的地发送一系列数据包。为了探测路径上的第一个路由器，它将第一个数据包的 TTL 设置为 **1**。当该数据包到达第一跳路由器时，TTL 减 1 变为 0，路由器丢弃该包并返回 ICMP Time Exceeded 消息，从而让发送端获知第一跳路由器的 IP。
![[{0417746B-A072-4CCB-A4F0-6C97201032DB}.png]]
### Q3. What is the value in the upper layer protocol field in this IPv4 datagram’s header?
**问题：** 该 IPv4 数据报头部中的上层协议字段的值是多少？
**答：** 查看 IPv4 头部的 **Protocol** 字段：
- **Value:** `ICMP (1)`
**分析：** Protocol 字段指示了 IP 数据报的数据部分应该交给哪个上层协议处理。
- 由于本次实验是在 Windows 环境下使用 `tracert`，Windows 默认使用 ICMP Echo Request 报文进行探测，因此协议号为 **1 (ICMP)**。
- （注：若是 Linux/macOS 的 `traceroute`，默认使用 UDP，协议号则为 17）。
### Q4. How many bytes are in the IP header?
**问题：** IP 头部有多少字节？
**答：** 查看 IPv4 头部的 **Header Length** 字段：
- **Value:** `20 bytes`
**分析：** IPv4 头部的长度字段（IHL）占 4 位，单位是 32 位字（4 字节）。通常情况下，不包含选项（Options）的 IP 头部长度为 5，即 $5 \times 4 = 20$ 字节。这是 IPv4 头部的标准最小长度。
### Q5. How many bytes are in the payload of the IP datagram? Explain how you determined the number of payload bytes.
**问题：** IP 数据报的有效载荷（Payload）有多少字节？解释你是如何确定的。
**答：**
- **Payload Size:** `72 bytes`
**计算过程与解释：** IP 数据报的负载大小可以通过以下公式计算：
$$\text{Payload} = \text{Total Length} - \text{Header Length}$$
根据 Wireshark 抓包详情（Packet #126）：
1. **Total Length** (IP 数据报总长度): `92 bytes`
    - _(注：Wireshark 列表显示的 Length 106 包含 14 字节以太网头，故 IP Total Length = 106 - 14 = 92)_
2. **Header Length** (IP 头部长度): `20 bytes` (由 Q4 得知)
代入计算：
$$92 - 20 = 72 \text{ bytes}$$
因此，该 IP 数据报携带了 72 字节的上层数据（即 ICMP 报文）。
## 实验总结
通过本次实验 Part 1 部分，我成功抓取并分析了由 Windows `tracert` 生成的 IPv4 数据包。验证了：
1. IP 头部包含源 IP、TTL、协议号等关键控制信息。
2. `traceroute` 利用 TTL 字段的递减机制来探测网络路径。
3. IP 数据报的负载长度需通过总长度减去头部长度计算得出。