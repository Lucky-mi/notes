unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY
### 一、 战况复盘：我们遇到了什么？

| **遭遇的问题**    | **表现现象**                                      | **根本原因**                                              | **最终解法**                                            |
| ------------ | --------------------------------------------- | ----------------------------------------------------- | --------------------------------------------------- |
| **DNS 解析失败** | `apt update` 报错 `Temporary failure resolving` | WSL 默认 DNS 被污染或超时，无法将域名转为 IP。                         | 强制修改 `/etc/resolv.conf` 为 `8.8.8.8`。                |
| **二进制不兼容**   | `exec: node: not found`                       | WSL 调用了 Windows 的 npm，试图在 Linux 运行 Windows 的 EXE 逻辑。  | 在 WSL 内部安装原生 Linux 版 Node.js。                       |
| **网络隔离**     | 浏览器登录后白屏，无法回调                                 | WSL 2 默认是 NAT 模式，Windows 的浏览器无法访问 WSL 的 localhost 端口。 | **逃课法**：手动搬运 `auth.json` 凭证文件。                      |
| **代理死循环**    | `curl` 报 `Proxy CONNECT aborted`              | WSL 设置了指向 localhost 的代理变量，但那是 Windows 的端口，WSL 访问不到。   | **镜像网络**：`.wslconfig` 让 WSL 共享 Windows 网卡 + 清除代理变量。 |
| **配置“诈尸”**   | 重启 WSL 后故障重现                                  | 错误的环境变量写在了 `.bashrc` 启动脚本里，每次登录自动加载。                  | 修改 `.bashrc`，彻底删除 `export proxy` 语句。                |

---

### 二、 硬核知识点解析（关联考研 408）

这一部分我们把刚才的操作映射到计算机科学的理论中。

#### 1. 网络地址转换 (NAT) vs. 镜像网络 (Mirrored)

这是本次最核心的痛点。

- **默认模式 (NAT)**：
    
    - **原理**：WSL 就像是你电脑（宿主机）里的一台“虚拟机”。它有自己独立的虚拟网卡和 IP 段（例如 `172.x.x.x`）。
        
    - **问题**：
        
        - **出不去**：WSL 想访问 Windows 的 VPN（监听在 `127.0.0.1:7890`），但对 WSL 来说，`127.0.0.1` 是它自己！它自己的 7890 端口没人监听，所以拒绝连接。
            
        - **进不来**：Windows 浏览器验证完 Claude 登录，想回调 `localhost:8080`。但这个 8080 开在 WSL 的虚拟局域网里，Windows 找不到路。
            
    - **类比**：你住在一个有门禁的小区（WSL），外卖员（浏览器回调）进不来；你想去隔壁小区（Windows）买东西，但小区大门关了。
        
- **镜像网络模式 (Mirrored Mode)**：
    
    - **原理**：这是 Windows 11 的新特性。它打破了虚拟化的边界，让 WSL **共享** Windows 的物理网卡 IP 和网络命名空间。
        
    - **效果**：Windows 连了 VPN，WSL 自动就有了；Windows 的 `localhost` 和 WSL 的 `localhost` 变成了同一个。
        
    - **考点关联**：**网络层（IP 地址与路由）**、**虚拟化技术（网络命名空间）**。
        

#### 2. 环境变量与 Shell 生命周期

为什么 `unset` 后重启又坏了？

- **进程空间**：`unset` 命令只修改了**当前 Shell 进程**（及子进程）的内存数据。一旦关闭终端，进程销毁，内存释放，修改就没了。
    
- **启动脚本 (`.bashrc`)**：
    
    - 每次打开新终端（启动 `/bin/bash`），系统都会读取 `~/.bashrc` 文件。
        
    - **持久化**：这就好比电脑的“开机自启”。如果你把 `export proxy=...` 写在里面，每次开机它都会重新给变量赋值。
        
    - **考点关联**：**操作系统（进程管理、父子进程环境继承）**。
        

#### 3. 系统调用与 ABI (Application Binary Interface)

为什么 Windows 的 npm 在 WSL 里不能用？

- **原理**：
    
    - **Windows 程序 (.exe)** 调用的是 Windows API（如 `CreateProcess`）。
        
    - **Linux 程序 (ELF)** 调用的是 Linux System Calls（如 `fork`, `exec`）。
        
- **WSL 的魔法**：虽然 WSL 可以通过 `binfmt_misc` 机制运行 Windows 的 `.exe`，但那个 npm 脚本试图去找一个叫 `node` 的可执行文件。它找到了 Windows 的 `node.exe` 还是 Linux 的 `/usr/bin/node`？路径混杂导致了混乱。
    
- **最佳实践**：**上帝的归上帝，凯撒的归凯撒**。Linux 环境就应该用 Linux 编译的二进制文件。
    
- **考点关联**：**操作系统（系统调用接口、链接与加载）**。
    

#### 4. Authentication (认证机制)

我们用的“手动搬运凭证法”利用了什么原理？

- **OAuth 2.0 变种**：Claude 的登录通常基于 OAuth 流程。
    
    - 正常流程：CLI 发起 -> 浏览器认证 -> 重定向回 CLI (带 Token) -> CLI 保存 Token。
        
    - 我们做的：直接把最后一步保存的 **Token (Session Key)** 从 Windows 复制到了 WSL。
        
- **Token 的本质**：它就是一个字符串（JSON 文件），代表了“我已经登录”的状态。只要服务器认可这个字符串，它在 Windows 上生成还是在 WSL 上生成并不重要。
    
- **考点关联**：**应用层（HTTP 协议、Cookie/Session/Token 认证）**。