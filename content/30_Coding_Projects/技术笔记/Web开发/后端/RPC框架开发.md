## 简介
**项目目标：** 从零开始，使用 Netty、Zookeeper 和 Protobuf（或 Kryo）实现一个高性能的轻量级 RPC 框架。目标是让“服务消费者”能像调用本地方法一样，调用“服务提供者”上的方法。

**核心技术栈：**
- **网络通信：** Netty (提供高性能的异步NIO)
- **服务注册与发现：** Zookeeper (充当注册中心)
- **序列化：** Protobuf / Kryo (比JSON高效得多的编解码方案)
- **动态代理：** Java JDK Dynamic Proxy (实现“透明”调用的关键)

**整体架构与功能模块：**

**1. `yujia-rpc-api` (公共 API 模块)**
- **功能：** 这是最基础的模块，被“提供者”和“消费者”共同依赖。
- **实现：**
    - 定义服务接口（例如 `interface UserService { User getUserById(int id); }`）。
    - 定义 POJO 实体（例如 `User` 类）。

**2. `yujia-rpc-registry` (注册中心模块)**
- **功能：** 负责服务地址的“注册”与“发现”。
- **实现：**
    - 使用 Zookeeper 客户端。
    - **服务提供者 (Provider)** 启动时，将其服务名称（如 `UserService`）和地址（如 `127.0.0.1:8080`）注册为 Zookeeper 上的一个“临时节点”。
    - **服务消费者 (Consumer)** 启动时，订阅 Zookeeper 上的服务节点，获取可用的服务地址列表，并监听变化。

**3. `yujia-rpc-protocol` (通信协议模块)**
- **功能：** 定义服务间通信的“语言”。一个好的协议是RPC性能的关键。
- **实现：**
    - **序列化器 (Serializer)：** 封装 Protobuf 或 Kryo，提供 `serialize(Object)` 和 `deserialize(byte[], Class)` 接口。
    - **自定义消息帧 (Message Frame)：** 定义网络上传输的字节流结构，例如：
        - `MagicNumber (4 字节)`: 验证数据包是否合法。
        - `MessageType (1 字节)`: 标记是“请求”还是“响应”。
        - `RequestID (8 字节)`: 唯一ID，用于匹配异步的请求和响应。
        - `DataLength (4 字节)`: 消息体的长度。
        - `DataBody (N 字节)`: 序列化后的请求/响应对象。

**4. `yujia-rpc-transport` (网络传输模块)**
- **功能：** 真正负责收发数据。
- **实现：**
    - **服务端 (Provider)：**
        - 使用 **Netty** 启动一个 `ServerBootstrap`。
        - 定义 `ChannelPipeline`：包含自定义的“解码器”（按 `Message Frame` 拆包）、“编码器”和“业务处理器”。
        - **业务处理器 (Handler)：** 收到请求后，反序列化 `DataBody`，找到对应的服务实现（如 `UserServiceImpl`），用“反射”调用方法，将结果序列化并编码，最后写回 (writeAndFlush)。
    - **客户端 (Consumer)：**
        - 使用 **Netty** 启动 `Bootstrap` 来管理连接。
        - **连接池：** 维护与服务端的长连接。
        - **业务处理器 (Handler)：** 发送请求（编码），并异步接收响应。使用一个 `Map<RequestID, CompletableFuture>` 来存放“正在路上”的请求，当响应回来时，根据 `RequestID` 找到对应的 `CompletableFuture` 并填入结果。

**5. `yujia-rpc-proxy` (动态代理模块)**

- **功能：** 这是实现“透明调用”的魔术所在。
- **实现：**
    - 为消费者提供一个 `getProxy(Class<?> serviceClass)` 方法。
    - 内部使用 `Proxy.newProxyInstance` 创建一个 JDK 动态代理。
    - 当消费者调用 `userService.getUserById(1)` 时，实际会进入代理的 `invoke` 方法。
    - **`invoke` 方法的逻辑：**
        1. 从 `yujia-rpc-registry` 获取服务地址。
        2. 构建请求对象（包含服务名、方法名、参数）。
        3. 使用 `yujia-rpc-protocol` 序列化请求。
        4. 使用 `yujia-rpc-transport` 发送请求，并异步等待 `CompletableFuture` 返回结果。
        5. 反序列化结果并返回给调用方。

## 学习笔记
lombok改善POJO:
@data\@NoArgsConstructor\@AllArgsConstructor
反射：程序可以访问、检测和修改它本身状态或行为的一种能力，
transport:
编码、解码（按照编码反向解）
