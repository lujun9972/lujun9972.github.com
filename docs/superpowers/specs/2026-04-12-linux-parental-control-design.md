# 博文设计：在 Linux 上限制儿童使用电脑

## 元信息

- **文件名**: `linux和它的小伙伴/在Linux上限制儿童使用电脑.org`
- **格式**: Org-mode（遵循行内标记规范：标记前后加空格、粗体用单星号）
- **目标读者**: 兼顾普通家长（先给配置步骤）和 Linux 爱好者（再讲原理）
- **方案范围**: 纯 Linux 原生方案，不依赖第三方软件
- **组织方式**: 按场景分节，每节独立可读

## 参考来源

百度知道问题："如何在 linux 系统中限制用户登录时间段和时间长度？"（限制登录时段 + 限制使用时长 + 超时警告踢出）

## 博文结构

### 引言

简述场景：家长希望限制孩子使用电脑的时间和内容，Linux 虽然没有 Windows 那样的家长控制面板，但原生机制完全够用。本文将用纯 Linux 原生工具实现多项管控功能。

假设系统中已创建一个名为 `child` 的受限用户。

### 第一节：限制允许登录的时间段

**技术方案**: PAM `pam_time.so` + `/etc/security/time.conf`

**快速配置**:
1. 在 `/etc/pam.d/login`（以及 `/etc/pam.d/lightdm`、`/etc/pam.d/sshd` 等需要的 PAM 服务文件）中添加 `account required pam_time.so`
2. 在 `/etc/security/time.conf` 中添加规则，格式为 `services;ttys;users;times`
3. 示例：`*;*;child;Wd1800-2000` 限制 child 用户只能在工作日 18:00-20:00 登录

**深入原理**: 解释 PAM 的四种模块类型（auth/account/password/session），`pam_time` 属于 account 类型，在认证通过后检查是否允许访问。说明 time.conf 中的通配符和时间段语法。

### 第二节：限制每日累计使用时长

**技术方案**: PAM `pam_exec.so`（记录登录/登出时间）+ cron 定时检查脚本

**快速配置**:
1. 编写登录记录脚本 `/usr/local/bin/session-logger.sh`，在 session open 时记录登录时间戳，在 session close 时记录登出时间戳，写入 `/var/log/user-sessions.log`
2. 在 `/etc/pam.d/login` 等文件中添加 `session optional pam_exec.so /usr/local/bin/session-logger.sh`
3. 编写时长检查脚本 `/usr/local/bin/check-usage.sh`，计算当日累计时长，判断是否超限
4. 配置 cron 每分钟运行一次检查脚本

**深入原理**: 解释 PAM session 管理的调用时机（open/close），`pam_exec` 传入的 `PAM_TYPE` 环境变量区分 open/close，以及 cron 的定时调度机制。

### 第三节：超时警告并踢出

**技术方案**: 整合到第二节的检查脚本中

**快速配置**:
1. 多级警告逻辑：
   - 剩余 5 分钟：`wall` 广播 "还有 5 分钟"
   - 剩余 2 分钟：`wall` 广播 "最后 2 分钟"
   - 超时：`loginctl terminate-session` 或 `pkill -u child` 踢出
2. 如果需要更彻底，可用 `shutdown -h +2`（但影响所有用户）

**深入原理**: 解释 `wall` 的广播机制（写入所有终端的 `/dev/pts/*`），`loginctl` 与 systemd-logind 的关系，session 管理的信号处理。

### 第四节：限制可访问网站

**技术方案**: iptables/nftables + owner 模块 + time 模块

**快速配置**:
1. 方法一（DNS 级过滤）：配置 `dnsmasq`，维护 `/etc/blocked-hosts` 黑名单，将指定域名解析到 127.0.0.1
2. 方法二（IP/端口级限制）：用 iptables 的 `owner` 模块匹配特定用户 UID，结合 `time` 模块按时间段限制
   ```
   iptables -A OUTPUT -m owner --uid-owner child -m time --timestart 18:00 --timestop 20:00 -j ACCEPT
   iptables -A OUTPUT -m owner --uid-owner child -j DROP
   ```
3. 注意纯 iptables 无法做 HTTPS 内容过滤，只能做 IP/域名级别

**深入原理**: 解释 Netfilter 框架的五个钩子点（PREROUTING/INPUT/FORWARD/OUTPUT/POSTROUTING），iptables 规则匹配流程，以及 owner 模块和 time 模块的匹配机制。

### 第五节：限制可运行程序

**技术方案**: Linux 文件权限（DAC）+ AppArmor（MAC）

**快速配置**:
1. 主要方法（文件权限）：
   - 创建一个 `restricted` 组
   - 将要限制的程序（如 `/usr/bin/steam`）设为 `root:restricted 750`
   - 把 `child` 用户排除在 `restricted` 组之外
   - 对于需要允许的程序，保持 everyone 可执行（`chmod 755`）
2. 进阶方法（AppArmor）：
   - 为特定程序编写 AppArmor profile
   - 限制只有特定用户可以执行

**深入原理**: 解释 Linux 的 DAC（自主访问控制）模型：文件权限位（rwx）+ 所有者/组/其他三层。简述 AppArmor 的 MAC（强制访问控制）机制：基于路径的 profile 绑定。

### 总结

回顾五节内容，强调每个方案都是 Linux 原生机制，组合起来可以实现较完整的家长控制。提醒读者这些方案需要 root 权限配置，且孩子如果是 sudoers 则可能绕过。

## 技术要点

- 所有代码示例使用 bash 脚本
- 配置文件路径使用 Arch Linux 标准（如 `/etc/pam.d/`）
- 代码块使用 `#+BEGIN_SRC shell` 和 `#+BEGIN_EXAMPLE` 格式
- 篇幅控制在 3000-5000 字
