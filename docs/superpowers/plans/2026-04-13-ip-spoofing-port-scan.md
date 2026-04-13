# IP 欺骗端口扫描博文实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 写一篇攻防并重的技术博文，讲解 nmap 伪装扫描（Idle Scan / Decoy Scan）的攻击原理与防御实战

**Architecture:** 以 hookrace.net 真实攻击案例为引子，前半部分讲解攻击技术原理和实操演示，后半部分讲解检测和防御方案

**Tech Stack:** Org-mode 博文格式，nmap、tcpdump、iptables 命令演示

**Design spec:** `docs/superpowers/specs/2026-04-13-ip-spoofing-port-scan-design.md`

---

## 文件结构

- **Create:** `linux和它的小伙伴/IP欺骗端口扫描：当别人冒充你去扫描别人.org`

## 写作规范

- Org-mode 格式，不混用 Markdown
- 行内标记（=code=、*粗体*）前后必须有空格或英文标点，不与中文/中文标点相邻
- src block 区分用途：完整脚本加 `:tangle`，sudo 命令加 `:dir /sudo::`，纯展示不加头部
- 文件末尾保留换行符
- 参考《使用nmap进行网络发现》和《安全的SSH设置》的写法风格

---

### Task 1: 创建文件框架和引子

**Files:**
- Create: `linux和它的小伙伴/IP欺骗端口扫描：当别人冒充你去扫描别人.org`

- [ ] **Step 1: 写文件头部和引子部分**

```org
#+TITLE: IP欺骗端口扫描：当别人冒充你去扫描别人
#+AUTHOR: lujun9972
#+TAGS: linux和它的小伙伴
#+DATE: [2026-04-13 日 00:00]
#+LANGUAGE:  zh-CN
#+OPTIONS:  H:6 num:nil toc:t \n:nil ::t |:t ^:nil -:nil f:t *:t <:nil

你有没有想过，有人可以用你的 IP 地址去扫描别人的服务器，而你可能毫不知情？

这并不是天方夜谭。2024 年，开源游戏项目 DDNet 的服务器就遭遇了这种攻击。攻击者利用 nmap 的 IP 伪装扫描功能，冒充 DDNet 的服务器 IP 对大学网络进行端口扫描。大学的安全系统自动检测到扫描行为后，向 DDNet 的主机商发送了 abuse 报告。主机商在无法验证数据包是否真的来自 DDNet 服务器的情况下，直接关停了他们的 VPS。更糟的是，即使 DDNet 配置了防火墙规则，攻击者仍然可以每天重复这种攻击，最终导致服务被终止。

这种攻击的核心技术就是 nmap 的 =Decoy Scan= 和 =Idle Scan= 。下面我们就来深入了解这两种伪装扫描技术是如何工作的，以及作为服务器管理员应该如何检测和防御。

参考资料: <https://hookrace.net/blog/port-scan-with-spoofed-ip-addresses/>
```

- [ ] **Step 2: Commit**

```bash
git add "linux和它的小伙伴/IP欺骗端口扫描：当别人冒充你去扫描别人.org"
git commit -m "blog: 添加 IP 欺骗端口扫描博文框架和引子"
```

---

### Task 2: 写 IP 欺骗扫描原理部分

**Files:**
- Modify: `linux和它的小伙伴/IP欺骗端口扫描：当别人冒充你去扫描别人.org`

- [ ] **Step 1: 追加"什么是 IP 欺骗"和原理说明**

在引子后面追加以下内容：

```org
* 什么是 IP 欺骗

IP 欺骗（IP Spoofing）是指发送数据包时伪造源 IP 地址。在 TCP 协议中，由于三次握手机制的存在，单纯的 IP 伪造很难建立完整的 TCP 连接，因为响应包会被发送到被伪造的 IP 地址而非攻击者。

但是，端口扫描不一定需要建立完整的 TCP 连接。nmap 的 SYN 扫描（半开扫描）只需要发送一个 SYN 包并观察响应即可判断端口状态，不需要完成三次握手。这就为 IP 欺骗扫描创造了条件。

nmap 提供了两种主要的伪装扫描方式：

1. =Decoy Scan= （诱饵扫描，=-D= 参数）：混入大量伪造源 IP 的探测包，让目标无法分辨真正的扫描者
2. =Idle Scan= （僵尸扫描，=-sI= 参数）：利用第三方僵尸主机的 IP ID 递增特性来间接判断端口状态，攻击者 IP 完全不出现在流量中

下面分别详细介绍这两种技术。
```

- [ ] **Step 2: Commit**

```bash
git add "linux和它的小伙伴/IP欺骗端口扫描：当别人冒充你去扫描别人.org"
git commit -m "blog: 添加 IP 欺骗扫描原理说明"
```

---

### Task 3: 写 Decoy Scan 原理和实操部分

**Files:**
- Modify: `linux和它的小伙伴/IP欺骗端口扫描：当别人冒充你去扫描别人.org`

- [ ] **Step 1: 追加 Decoy Scan 原理和演示**

在原理部分后面追加以下内容：

```org
* Decoy Scan（诱饵扫描）

** 原理

Decoy Scan 的思路很直接：在发送真实的 SYN 扫描包的同时，发送大量源 IP 伪造的 SYN 包。目标服务器会看到来自多个 IP 地址的扫描请求，无法确定哪个是真正的攻击者。

其数据包流程为：

1. nmap 向目标发送一批 SYN 包，其中一部分的源 IP 是真实的（攻击者的），其余的是伪造的诱饵 IP
2. 目标服务器对每个 SYN 包都回复 SYN/ACK（端口开放）或 RST（端口关闭）
3. 只有真实攻击者能收到目标的响应（因为诱饵 IP 是伪造的）
4. 攻击者根据收到的响应判断端口状态

从目标服务器的日志来看，扫描来自多个不同的 IP，就像遭到了分布式扫描一样。

** 命令格式

使用 =-D= 参数指定诱饵 IP 列表，用逗号分隔。=ME= 代表自己的真实 IP：

#+BEGIN_SRC shell
  # 使用指定 IP 作为诱饵
  nmap -D 192.168.1.100,192.168.1.101,ME 192.168.1.200

  # 使用随机生成的 IP 作为诱饵
  nmap -D RND:10 192.168.1.200

  # 将真实 IP 放在诱饵列表的后面（更隐蔽）
  nmap -D 192.168.1.100,192.168.1.101,192.168.1.102,192.168.1.103,ME 192.168.1.200
#+END_SRC

注意： =ME= 放在第 6 位或之后时，一些端口扫描检测工具（如 scanlogd）不会报告真实 IP。

** 实操演示

下面我们在本地环境中演示 Decoy Scan。假设有三台机器：

- 攻击者：192.168.1.10
- 目标：192.168.1.20
- 诱饵 IP（伪造）：192.168.1.100、192.168.1.101

在攻击者机器上执行：

#+BEGIN_SRC shell
  nmap -D 192.168.1.100,192.168.1.101,ME 192.168.1.20
#+END_SRC

同时在目标机器上用 =tcpdump= 抓包观察：

#+BEGIN_SRC shell :dir /sudo::
  sudo tcpdump -n -i any 'tcp[tcpflags] & (tcp-syn) != 0 and not tcp[tcpflags] & (tcp-ack) != 0' -c 30
#+END_SRC

目标服务器会看到类似这样的输出：

#+BEGIN_EXAMPLE
IP 192.168.1.100.12345 > 192.168.1.20.80: Flags [S], seq 123456
IP 192.168.1.101.12346 > 192.168.1.20.443: Flags [S], seq 234567
IP 192.168.1.10.12347 > 192.168.1.20.22: Flags [S], seq 345678
IP 192.168.1.100.12348 > 192.168.1.20.21: Flags [S], seq 456789
...
#+END_EXAMPLE

可以看到，目标服务器认为扫描来自 192.168.1.100、192.168.1.101 和 192.168.1.10 三个 IP。如果这些诱饵 IP 恰好属于某个真实的服务器，那台服务器的管理员就会收到 abuse 投诉，而不是攻击者。
```

- [ ] **Step 2: Commit**

```bash
git add "linux和它的小伙伴/IP欺骗端口扫描：当别人冒充你去扫描别人.org"
git commit -m "blog: 添加 Decoy Scan 原理和实操演示"
```

---

### Task 4: 写 Idle Scan 原理和实操部分

**Files:**
- Modify: `linux和它的小伙伴/IP欺骗端口扫描：当别人冒充你去扫描别人.org`

- [ ] **Step 1: 追加 Idle Scan 原理和演示**

在 Decoy Scan 部分后面追加以下内容：

```org
* Idle Scan（僵尸扫描）

** 原理

Idle Scan 是一种更加精巧的扫描技术。它利用了 TCP/IP 协议栈中 IP ID（IP 标识符）字段递增的特性，通过一个"僵尸主机"来间接探测目标服务器的端口状态，攻击者的 IP *完全不会* 出现在目标服务器的任何日志中。

其核心流程分为四步：

1. *探测僵尸的 IP ID*：攻击者向僵尸主机发送 SYN/ACK 包，僵尸主机会回复 RST 包，该包的 IP ID 值记为 N
2. *伪造 SYN 包发给目标*：攻击者伪造一个源 IP 为僵尸主机的 SYN 包，发送给目标服务器的待测端口
3. *目标与僵尸交互*：
   - 若目标端口*开放*：目标回复 SYN/ACK 给僵尸，僵尸觉得莫名其妙（没有发起过连接），回复 RST，此时僵尸的 IP ID 递增为 N+1
   - 若目标端口*关闭*：目标回复 RST 给僵尸，僵尸不需要回复，IP ID 不变
4. *再次探测僵尸的 IP ID*：攻击者再次发送 SYN/ACK 给僵尸，获取新的 IP ID 值 M：
   - M = N + 1 → 端口关闭或被过滤
   - M = N + 2 → 端口开放（中间那次递增就是目标与僵尸交互时产生的）

整个过程中，目标服务器只看到来自僵尸主机的扫描，*完全看不到攻击者的 IP* 。

** 僵尸主机的选择条件

并不是任何主机都能作为僵尸，需要满足：

- IP ID 序列是全局递增的（不是 per-connection 递增）
- 在扫描期间保持空闲（没有其他流量干扰 IP ID 递增）
- 能够响应 unsolicited SYN/ACK（即回复 RST）

实践中，网络打印机、老旧路由器、某些 IOT 设备常常满足这些条件。nmap 自带一个脚本可以帮你测试候选僵尸：

#+BEGIN_SRC shell :dir /sudo::
  sudo nmap --script ipidseq <candidate_ip>
#+END_SRC

如果输出显示 =IP ID Sequence: Incremental= ，则该主机可以作为僵尸。

** 命令格式

使用 =-sI= 参数指定僵尸主机：

#+BEGIN_SRC shell :dir /sudo::
  # 基本用法
  sudo nmap -sI <zombie_host> <target>

  # 指定端口范围
  sudo nmap -sI 192.168.1.50 -p 22,80,443 192.168.1.200

  # 扫描所有端口（需要较长时间）
  sudo nmap -Pn -p- -sI 192.168.1.50 192.168.1.200
#+END_SRC

注意：Idle Scan 需要 root 权限，因为要构造原始数据包。

** 实操演示

假设我们有：

- 攻击者：192.168.1.10
- 僵尸主机：192.168.1.50（一台网络打印机）
- 目标：192.168.1.20

先测试僵尸主机是否可用：

#+BEGIN_SRC shell :dir /sudo::
  sudo nmap --script ipidseq 192.168.1.50
#+END_SRC

确认 IP ID 是递增的后，执行扫描：

#+BEGIN_SRC shell :dir /sudo::
  sudo nmap -sI 192.168.1.50 -p 22,80,443 192.168.1.20
#+END_SRC

在目标服务器上用 =tcpdump= 抓包，你会发现*只有*僵尸主机的 IP 出现在日志中：

#+BEGIN_SRC shell :dir /sudo::
  sudo tcpdump -n host 192.168.1.20 and tcp
#+END_SRC

#+BEGIN_EXAMPLE
IP 192.168.1.50.12345 > 192.168.1.20.22: Flags [S], seq ...
IP 192.168.1.20.22 > 192.168.1.50.12345: Flags [S.], seq ...
IP 192.168.1.50.12345 > 192.168.1.20.22: Flags [R], seq ...
#+END_EXAMPLE

整个过程攻击者 192.168.1.10 *完全没有出现* 。如果大学的安全系统检测到这个扫描，他们会认为扫描来自 192.168.1.50 这台打印机。
```

- [ ] **Step 2: Commit**

```bash
git add "linux和它的小伙伴/IP欺骗端口扫描：当别人冒充你去扫描别人.org"
git commit -m "blog: 添加 Idle Scan 原理和实操演示"
```

---

### Task 5: 写防御方案部分

**Files:**
- Modify: `linux和它的小伙伴/IP欺骗端口扫描：当别人冒充你去扫描别人.org`

- [ ] **Step 1: 追加防御方案内容**

在 Idle Scan 部分后面追加以下内容：

```org
* 防御方案

了解了攻击原理后，我们来看看作为服务器管理员可以采取哪些防御措施。

** 检测异常流量

使用 =tcpdump= 监控异常的 SYN 包模式：

#+BEGIN_SRC shell :dir /sudo::
  # 监控所有入站 SYN 包
  sudo tcpdump -n -i any 'tcp[tcpflags] & (tcp-syn) != 0 and not tcp[tcpflags] & (tcp-ack) != 0'
#+END_SRC

如果短时间内看到来自大量不同 IP 的 SYN 包，很可能就是 Decoy Scan。

也可以用 =ss= 命令查看处于 SYN_RECV 状态的连接：

#+BEGIN_SRC shell
  ss -tunap | grep SYN_RECV
#+END_SRC

大量 SYN_RECV 状态的连接说明有人在扫描或进行 SYN Flood 攻击。

** 限制出站 TCP 连接

DDNet 在遭遇攻击后采取的防御措施之一就是限制出站 TCP 新连接，只保留必要端口。这样即使有人想冒充你去扫描，你的服务器也不会发出这些包（不过这只能证明你的服务器没有主动发出扫描，无法阻止别人伪造你的 IP）：

#+BEGIN_SRC shell :dir /sudo::
  # 阻止所有出站 TCP 新连接，除了指定端口
  sudo iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
  sudo iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
  sudo iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
  sudo iptables -A OUTPUT -p tcp -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  sudo iptables -A OUTPUT -p tcp -m conntrack --ctstate NEW -j DROP
#+END_SRC

你也可以直接拒绝特定 IP 段的流量（比如频繁发 abuse 报告的大学）：

#+BEGIN_SRC shell :dir /sudo::
  sudo iptables -A INPUT -s 147.251.0.0/16 -j DROP
  sudo iptables -A OUTPUT -d 147.251.0.0/16 -j DROP
#+END_SRC

** BCP38 与 uRPF：根本解决方案

上面这些措施只是治标。IP 欺骗攻击的根本原因是：很多 ISP 没有过滤伪造源 IP 的数据包。

BCP38（原名 RFC 2827）是 IETF 发布的最佳实践文档，要求 ISP 在网络边界实施 *入站过滤* ，阻止源 IP 不属于该网络的数据包离开网络。其具体实现机制叫做 uRPF（Unicast Reverse Path Forwarding，单播反向路径转发）。

在 Linux 上，uRPF 可以通过内核参数启用：

#+BEGIN_SRC shell :dir /sudo::
  # 查看当前 uRPF 设置（0=关闭, 1=严格模式, 2=松散模式）
  cat /proc/sys/net/ipv4/conf/all/rp_filter

  # 启用严格模式
  sudo sysctl -w net.ipv4.conf.all.rp_filter=1
#+END_SRC

严格模式会检查数据包的源 IP 是否可以通过接收该包的接口到达。如果不匹配，就丢弃该包。这样可以有效阻止伪造源 IP 的数据包从你的网络发出。

*但是* ，uRPF 需要在 ISP 的路由器上配置，普通 VPS 用户无能为力。这也是为什么 IP 欺骗攻击至今仍然有效——它需要整个互联网生态的配合才能根治。

** 收到 abuse 报告时的应对

如果你的服务器被别人冒充进行 IP 欺骗扫描，收到了主机商转发的 abuse 报告，可以采取以下步骤：

1. *检查服务器日志*：确认在报告所述时间段内，服务器没有发出相关流量
#+BEGIN_SRC shell
  # 检查 iptables 日志（如果配置了 LOG 规则）
  grep "reported_time_range" /var/log/kern.log | grep "DPT="
#+END_SRC

2. *提供 tcpdump 证据*：在服务器上持续抓包记录，作为没有发出扫描流量的证据
#+BEGIN_SRC shell :dir /sudo::
  # 持续记录 TCP 新连接（后台运行，写入带时间戳的文件）
  sudo tcpdump -i any -G 3600 -w '/var/log/traffic_%Y%m%d_%H.pcap' 'tcp[tcpflags] & (tcp-syn) != 0 and not tcp[tcpflags] & (tcp-ack) != 0'
#+END_SRC

3. *向主机商解释*：说明 IP 欺骗扫描的原理，指出攻击者可以从任何位置伪造你的 IP 进行扫描，你的服务器不需要发出任何数据包。可以引用原文 <https://hookrace.net/blog/port-scan-with-spoofed-ip-addresses/> 作为参考

4. *请求 ISP 提供 netflow 数据*：只有上游路由器的 netflow 数据才能证明数据包是否真的从你的 VPS 发出
```

- [ ] **Step 2: Commit**

```bash
git add "linux和它的小伙伴/IP欺骗端口扫描：当别人冒充你去扫描别人.org"
git commit -m "blog: 添加防御方案部分"
```

---

### Task 6: 写小结和格式检查

**Files:**
- Modify: `linux和它的小伙伴/IP欺骗端口扫描：当别人冒充你去扫描别人.org`

- [ ] **Step 1: 追加小结**

在防御方案后面追加以下内容：

```org
* 小结

IP 欺骗端口扫描利用的是互联网信任链中的漏洞：大学信任 IP 地址 → 主机商信任 abuse 报告 → 但 IP 地址可以被伪造。本质上是一种"借刀杀人"。

对于个人服务器管理员来说，能做的防御有限：
- 限制出站连接可以证明自己的清白，但无法阻止别人伪造你的 IP
- 保留网络流量日志可以在收到 abuse 报告时提供证据
- 向主机商解释 IP 欺骗的原理，争取理解

根本解决方案需要 ISP 实施 BCP38 源地址验证，阻止伪造源 IP 的数据包离开网络。但在整个互联网都实施之前，这种攻击手法仍将存在。

如果你也遭遇了类似的攻击，欢迎在评论区分享你的经历和应对方法。
```

- [ ] **Step 2: 格式检查**

检查以下格式问题：
- 所有 =code= 标记前后是否有空格或英文标点（不与中文相邻）
- 所有粗体是否使用单星号 *粗体* 而非 Markdown 的 **粗体**
- src block 头部是否正确：sudo 命令加 `:dir /sudo::`，纯展示不加头部
- 文件末尾是否有换行符

- [ ] **Step 3: Final commit**

```bash
git add "linux和它的小伙伴/IP欺骗端口扫描：当别人冒充你去扫描别人.org"
git commit -m "blog: 完成 IP 欺骗端口扫描博文"
```
