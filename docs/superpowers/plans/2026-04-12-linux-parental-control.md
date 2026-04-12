# 在 Linux 上限制儿童使用电脑 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 撰写一篇 Org-mode 格式博文，介绍如何用纯 Linux 原生方案限制儿童使用电脑（登录时段、使用时长、网站过滤、程序限制）。

**Architecture:** 按场景分节的博文结构，每节先给快速配置步骤，再讲底层原理。使用 Org-mode 格式，遵循行内标记规范。

**Tech Stack:** Org-mode, PAM (`pam_time`, `pam_exec`), cron, iptables/nftables, bash, Linux 文件权限, AppArmor

---

### Task 1: 创建博文文件并写入头部和引言

**Files:**
- Create: `linux和它的小伙伴/在Linux上限制儿童使用电脑.org`

- [ ] **Step 1: 创建文件并写入头部 + 引言**

创建 `linux和它的小伙伴/在Linux上限制儿童使用电脑.org`，写入以下内容：

```org
#+TITLE: 在Linux上限制儿童使用电脑
#+AUTHOR: lujun9972
#+TAGS: linux和它的小伙伴
#+DATE: [2026-04-12 六 21:00]
#+LANGUAGE:  zh-CN
#+OPTIONS:  H:6 num:nil toc:t \n:nil ::t |:t ^:nil -:nil f:t *:t <:nil

作为家长，你可能希望控制孩子使用电脑的时间——比如只能在晚上 6 点到 8 点登录，每天最多用 2 小时，超时后自动踢出。Windows 有专门的家长控制面板，而 Linux 虽然没有这样的集成工具，但它提供的原生机制完全可以实现同样的效果，而且更加灵活。

本文将介绍如何用纯 Linux 原生方案（PAM、cron、iptables 等）实现以下功能：

+ 限制允许登录的时间段
+ 限制每日累计使用时长
+ 超时警告并自动踢出
+ 限制可访问的网站
+ 限制可运行的程序

本文假设系统中已创建一个名为 =geo= 的受限用户。所有配置需要 root 权限。
```

- [ ] **Step 2: 提交**

```bash
git add linux和它的小伙伴/在Linux上限制儿童使用电脑.org
git commit -m "blog: 新增《在Linux上限制儿童使用电脑》引言"
```

---

### Task 2: 编写第一节——限制允许登录的时间段

**Files:**
- Modify: `linux和它的小伙伴/在Linux上限制儿童使用电脑.org`

在引言后追加以下内容。

- [ ] **Step 1: 追加第一节内容**

追加内容要点：
- 节标题：`* 限制允许登录的时间段`
- 开头引出场景：想限制 geo 只能在特定时间段登录
- **快速配置部分**：
  - 说明需要在 PAM 服务文件中启用 `pam_time.so`
  - 展示如何在 `/etc/pam.d/login` 中添加 `account required pam_time.so`
  - 展示 `/etc/security/time.conf` 的规则格式：`services;ttys;users;times`
  - 给出具体示例：`*;*;geo;!Wd1800-2000` 表示 geo 用户只能在工作日 18:00-20:00 登录（注意用 `!` 表示"除此时段外禁止"，或用 `Wk1800-2000` 表示允许）
  - 补充说明：还需要在 `/etc/pam.d/lightdm` 或 `/etc/pam.d/gdm` 等图形登录服务的 PAM 文件中也添加同样的配置
  - 给出验证方法：在非允许时段尝试用 geo 登录，应被拒绝
- **原理部分**：
  - 解释 PAM（Pluggable Authentication Modules）是 Linux 的可插拔认证框架
  - 四种模块类型：auth（认证）、account（账户管理）、password（密码管理）、session（会话管理）
  - `pam_time` 属于 account 类型，在认证通过后检查时间条件
  - `time.conf` 语法说明：`!` 取反、`Wd` 工作日、`Wk` 每周每天、`Al` 所有天、时间段用 `HHMM-HHMM` 格式
- 代码块示例：

```org
* 限制允许登录的时间段

Linux 中控制用户登录时间的机制是 PAM（Pluggable Authentication Modules，可插拔认证模块）中的 =pam_time= 模块。

** 快速配置

首先，在 PAM 配置文件中启用 =pam_time.so= 。需要修改的文件取决于你使用的登录方式：

+ 控制台登录： =/etc/pam.d/login=
+ 图形界面登录： =/etc/pam.d/lightdm= 或 =/etc/pam.d/gdm=
+ SSH 登录： =/etc/pam.d/sshd=

在上述文件的 =account= 部分添加一行：

#+BEGIN_SRC shell
  account required pam_time.so
#+END_SRC

然后在 =/etc/security/time.conf= 中添加规则。该文件的格式为：

#+BEGIN_EXAMPLE
  services;ttys;users;times
#+END_EXAMPLE

各字段含义：

+ =services= :: 服务名，=*= 表示所有服务
+ =ttys= :: 终端类型，=*= 表示所有终端
+ =users= :: 用户名
+ =times= :: 时间规则

时间规则的语法比较特别：

+ =Wd= 表示工作日（周一到周五），=Wk= 表示每天，=Al= 也表示每天
+ 时间格式为 =HHMM-HHMM=
+ 前面加 =!= 表示取反（"除此时段外禁止"）

例如，限制 =geo= 用户只能在工作日 18:00 到 20:00 登录：

#+BEGIN_SRC shell
  *;*;geo;Wk1800-2000
#+END_SRC

这行规则的意思是：对所有服务、所有终端、geo 用户，允许每天 18:00-20:00 登录。注意，=pam_time= 的逻辑是：匹配到的允许登录，未匹配到则拒绝。

验证配置：在非允许时段尝试用 =geo= 账户登录，应该会看到类似 "Permission denied" 的提示。

** 原理说明

PAM 是 Linux 的可插拔认证框架，它将认证逻辑从应用程序中解耦出来。PAM 定义了四种模块类型：

+ *auth* :: 验证用户身份（如检查密码）
+ *account* :: 检查账户是否允许访问（如检查账户是否过期、是否在允许的时间段内）
+ *password* :: 管理密码更新
+ *session* :: 管理会话的创建和销毁

=pam_time= 属于 *account* 类型。它的工作时机是在用户通过了 *auth* 阶段的密码验证之后、系统创建会话之前。此时 =pam_time= 会检查当前时间是否匹配 =time.conf= 中的规则，如果不匹配则拒绝登录。
```

- [ ] **Step 2: 提交**

```bash
git add linux和它的小伙伴/在Linux上限制儿童使用电脑.org
git commit -m "blog: 完成《在Linux上限制儿童使用电脑》第一节"
```

---

### Task 3: 编写第二节——限制每日累计使用时长

**Files:**
- Modify: `linux和它的小伙伴/在Linux上限制儿童使用电脑.org`

- [ ] **Step 1: 追加第二节内容**

追加内容要点：
- 节标题：`* 限制每日累计使用时长`
- 开头引出问题：`pam_time` 只能控制"什么时候能登录"，但无法控制"登录后能用多久"。需要一个记录和计算累计时长的方案。
- **方案设计**：用 `pam_exec` 在登录/登出时记录时间戳，用 cron 定时检查累计时长
- **快速配置部分**：
  - 登录记录脚本 `/usr/local/bin/session-logger.sh`，利用 `pam_exec` 传入的 `PAM_TYPE` 环境变量区分 open/close
  - `session-logger.sh` 的核心逻辑：
    - 当 `PAM_TYPE=open` 时，追加一行 `LOGIN YYYY-MM-DD HH:MM:SS username` 到 `/var/log/user-sessions.log`
    - 当 `PAM_TYPE=close` 时，追加一行 `LOGOUT YYYY-MM-DD HH:MM:SS username`
  - PAM 配置：在 `/etc/pam.d/login` 等文件中添加 `session optional pam_exec.so /usr/local/bin/session-logger.sh`
  - 时长检查脚本 `/usr/local/bin/check-usage.sh`：解析当天日志，计算累计在线时长，超限时执行踢出（踢出逻辑在第三节中完善）
  - cron 配置：`* * * * * /usr/local/bin/check-usage.sh`
- **原理部分**：
  - 解释 PAM session 类型的调用时机：用户登录成功后调用 open，登出时调用 close
  - `pam_exec` 会设置 `PAM_TYPE`、`PAM_USER`、`PAM_RHOST` 等环境变量
  - cron 的 `* * * * *` 表示每分钟执行一次

代码块中的 `session-logger.sh` 脚本：

```bash
#!/bin/bash
# /usr/local/bin/session-logger.sh
# 由 pam_exec 调用，记录用户登录/登出时间

LOGFILE="/var/log/user-sessions.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
USERNAME="$PAM_USER"
TYPE="$PAM_TYPE"

if [ -z "$USERNAME" ]; then
    exit 0
fi

case "$TYPE" in
    open)
        echo "LOGIN $TIMESTAMP $USERNAME" >> "$LOGFILE"
        ;;
    close)
        echo "LOGOUT $TIMESTAMP $USERNAME" >> "$LOGFILE"
        ;;
esac

exit 0
```

`check-usage.sh` 脚本（初步版本，警告和踢出在第三节补充）：

```bash
#!/bin/bash
# /usr/local/bin/check-usage.sh
# 检查用户当日累计使用时长，超限时发出警告并踢出

LOGFILE="/var/log/user-sessions.log"
TODAY=$(date '+%Y-%m-%d')
MAX_MINUTES=120  # 每天最多使用 120 分钟（2 小时）
WARN_BEFORE=5   # 超时前 5 分钟发出警告
TARGET_USER="geo"

# 计算今日累计在线分钟数
calculate_usage() {
    local user=$1
    local total_seconds=0
    local login_time=""

    while IFS= read -r line; do
        local action=$(echo "$line" | awk '{print $1}')
        local timestamp=$(echo "$line" | awk '{print $2, $3}')
        local username=$(echo "$line" | awk '{print $4}')

        [ "$username" != "$user" ] && continue

        case "$action" in
            LOGIN)
                login_time="$timestamp"
                ;;
            LOGOUT)
                if [ -n "$login_time" ]; then
                    local login_ts=$(date -d "$login_time" '+%s')
                    local logout_ts=$(date -d "$timestamp" '+%s')
                    total_seconds=$((total_seconds + logout_ts - login_ts))
                    login_time=""
                fi
                ;;
        esac
    done < <(grep "^LOGIN\|^LOGOUT" "$LOGFILE" | grep "$TODAY")

    # 如果用户当前在线（有未配对的 LOGIN），累加到现在
    if [ -n "$login_time" ]; then
        local login_ts=$(date -d "$login_time" '+%s')
        local now_ts=$(date '+%s')
        total_seconds=$((total_seconds + now_ts - login_ts))
    fi

    echo $((total_seconds / 60))
}

usage=$(calculate_usage "$TARGET_USER")
remaining=$((MAX_MINUTES - usage))

if [ "$remaining" -le 0 ]; then
    # 超时，踢出用户（第三节完善）
    wall "⚠ 使用时间已到，系统将在 2 分钟后将 $TARGET_USER 踢出！" 2>/dev/null
    sleep 120
    pkill -u "$TARGET_USER"
elif [ "$remaining" -le "$WARN_BEFORE" ]; then
    # 即将超时，发出警告
    wall "⚠ $TARGET_USER 还有 $remaining 分钟的使用时间" 2>/dev/null
fi
```

追加的 Org-mode 内容（包含原理说明）：

```org
* 限制每日累计使用时长

=pam_time= 只能控制"什么时候能登录"，但无法控制"登录后能用多久"。要实现每日使用时长的累计限制，需要自己动手：记录每次登录和登出的时间，然后定期检查是否超限。

** 快速配置

整个方案由两部分组成：一个记录登录/登出时间的脚本，和一个定期检查累计时长的脚本。

*** 第一步：记录登录/登出时间

创建 =/usr/local/bin/session-logger.sh= ：

#+BEGIN_SRC shell
  #!/bin/bash
  # /usr/local/bin/session-logger.sh
  # 由 pam_exec 调用，记录用户登录/登出时间

  LOGFILE="/var/log/user-sessions.log"
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  USERNAME="$PAM_USER"
  TYPE="$PAM_TYPE"

  if [ -z "$USERNAME" ]; then
      exit 0
  fi

  case "$TYPE" in
      open)
          echo "LOGIN $TIMESTAMP $USERNAME" >> "$LOGFILE"
          ;;
      close)
          echo "LOGOUT $TIMESTAMP $USERNAME" >> "$LOGFILE"
          ;;
  esac

  exit 0
#+END_SRC

然后赋予执行权限：

#+BEGIN_SRC shell
  sudo chmod +x /usr/local/bin/session-logger.sh
  sudo touch /var/log/user-sessions.log
  sudo chmod 622 /var/log/user-sessions.log
#+END_SRC

在 PAM 配置文件（如 =/etc/pam.d/login= 、 =/etc/pam.d/lightdm= ）的 *session* 部分添加：

#+BEGIN_SRC shell
  session optional pam_exec.so /usr/local/bin/session-logger.sh
#+END_SRC

*** 第二步：检查累计时长

创建 =/usr/local/bin/check-usage.sh= ：

#+BEGIN_SRC shell
  #!/bin/bash
  # /usr/local/bin/check-usage.sh
  # 检查用户当日累计使用时长

  LOGFILE="/var/log/user-sessions.log"
  TODAY=$(date '+%Y-%m-%d')
  MAX_MINUTES=120  # 每天最多使用 120 分钟（2 小时）
  TARGET_USER="geo"

  # 计算今日累计在线分钟数
  calculate_usage() {
      local user=$1
      local total_seconds=0
      local login_time=""

      while IFS= read -r line; do
          local action=$(echo "$line" | awk '{print $1}')
          local timestamp=$(echo "$line" | awk '{print $2, $3}')
          local username=$(echo "$line" | awk '{print $4}')

          [ "$username" != "$user" ] && continue

          case "$action" in
              LOGIN)
                  login_time="$timestamp"
                  ;;
              LOGOUT)
                  if [ -n "$login_time" ]; then
                      local login_ts=$(date -d "$login_time" '+%s')
                      local logout_ts=$(date -d "$timestamp" '+%s')
                      total_seconds=$((total_seconds + logout_ts - login_ts))
                      login_time=""
                  fi
                  ;;
          esac
      done < <(grep "$TODAY" "$LOGFILE" | grep -E "^(LOGIN|LOGOUT)")

      # 如果用户当前在线（有未配对的 LOGIN），累加到现在
      if [ -n "$login_time" ]; then
          local login_ts=$(date -d "$login_time" '+%s')
          local now_ts=$(date '+%s')
          total_seconds=$((total_seconds + now_ts - login_ts))
      fi

      echo $((total_seconds / 60))
  }

  usage=$(calculate_usage "$TARGET_USER")
  remaining=$((MAX_MINUTES - usage))

  if [ "$remaining" -le 0 ]; then
      wall "使用时间已到，系统将在 2 分钟后将 $TARGET_USER 踢出！" 2>/dev/null
      sleep 120
      pkill -u "$TARGET_USER"
  elif [ "$remaining" -le 5 ]; then
      wall "$TARGET_USER 还有 $remaining 分钟的使用时间" 2>/dev/null
  fi
#+END_SRC

赋予执行权限，并配置 cron 每分钟运行一次：

#+BEGIN_SRC shell
  sudo chmod +x /usr/local/bin/check-usage.sh
  # 添加到 root 的 crontab
  echo '* * * * * /usr/local/bin/check-usage.sh' | sudo tee /etc/cron.d/check-usage
  sudo chmod 644 /etc/cron.d/check-usage
#+END_SRC

** 原理说明

这里用到了两个机制：

+ *PAM session 管理* :: 当用户登录成功后，PAM 会依次调用 session 类型的模块的 =open= 钩子；当用户登出时，调用 =close= 钩子。=pam_exec.so= 会将钩子类型通过环境变量 =PAM_TYPE= （值为 =open= 或 =close= ）传递给外部脚本，同时通过 =PAM_USER= 传递用户名。

+ *cron 定时任务* :: =* * * * * = 表示每分钟执行一次。这个频率足够及时地检测到超时，同时不会给系统带来明显负担。
```

- [ ] **Step 2: 提交**

```bash
git add linux和它的小伙伴/在Linux上限制儿童使用电脑.org
git commit -m "blog: 完成《在Linux上限制儿童使用电脑》第二节"
```

---

### Task 4: 编写第三节——超时警告并踢出

**Files:**
- Modify: `linux和它的小伙伴/在Linux上限制儿童使用电脑.org`

- [ ] **Step 1: 追加第三节内容**

追加内容要点：
- 节标题：`* 超时警告并踢出`
- 说明在第二节中已经实现了基本的警告和踢出，这一节补充更多细节
- 展示多级警告的完整逻辑：
  - 剩余 5 分钟：`wall` 广播温和提醒
  - 剩余 2 分钟：`wall` 广播最后警告
  - 超时：先 `wall` 通知，等待 2 分钟后 `pkill -u geo` 踢出
  - 进阶选项：`loginctl terminate-session` 按会话踢出（比 pkill 更精确）
  - 更彻底的选项：`shutdown -h +2`（但会影响所有用户，适合单人电脑）
- **原理部分**：
  - `wall` 的工作原理：向 `/dev/pts/*` 和 `/dev/tty*` 写入消息
  - `pkill -u` 发送 SIGTERM 给用户所有进程，如果进程不退出可加 `-9` 强制
  - `loginctl` 与 systemd-logind 的关系：logind 跟踪每个登录会话，`terminate-session` 会优雅地结束指定会话

追加的 Org-mode 内容：

```org
* 超时警告并踢出

上一节的脚本已经包含了基本的警告和踢出逻辑。这里再详细说明一下各个踢出手段的区别。

** 多级警告策略

实际使用中，建议采用多级警告，给孩子一个心理准备的过程：

#+BEGIN_SRC shell
  # 在 check-usage.sh 中替换警告逻辑
  usage=$(calculate_usage "$TARGET_USER")
  remaining=$((MAX_MINUTES - usage))

  if [ "$remaining" -le 0 ]; then
      # 已超时，通知并踢出
      wall "$TARGET_USER，今日使用时间已到！" 2>/dev/null
      sleep 120
      pkill -u "$TARGET_USER"
  elif [ "$remaining" -le 2 ]; then
      # 最后 2 分钟警告
      wall "$TARGET_USER，还有 $remaining 分钟，请保存工作！" 2>/dev/null
  elif [ "$remaining" -le 5 ]; then
      # 5 分钟提醒
      wall "$TARGET_USER，还有 $remaining 分钟的使用时间" 2>/dev/null
  fi
#+END_SRC

** 踢出用户的不同方式

+ *=pkill -u geo=* :: 向 geo 用户的所有进程发送 SIGTERM 信号。这是最简单的方式，但如果有进程忽略了 SIGTERM，可能无法完全清理。可以追加 =pkill -9 -u geo= 来强制结束。

+ *=loginctl terminate-session SESSION_ID=* :: 通过 systemd-logind 来终止指定的登录会话。这比 pkill 更精确，因为它能正确地清理会话资源。查看当前会话列表可以用 =loginctl list-sessions= 。

+ *=shutdown -h +2=* :: 2 分钟后关闭整个系统。这是最彻底的方式，但会影响所有用户。如果电脑是孩子独占使用的，这也是个不错的选择。

** 原理说明

=wall= 命令的工作原理是向系统中所有终端设备（ =/dev/pts/*= 和 =/dev/tty*= ）写入消息。只有拥有终端的登录用户才能看到消息。

=pkill= 通过匹配进程的 UID 来选择目标进程，先发送 SIGTERM（信号 15），允许进程优雅退出。如果进程不响应，可以发送 SIGKILL（信号 9）强制终止。

=loginctl= 是 systemd-logind 的命令行接口。logind 作为 systemd 的用户登录管理器，跟踪系统中所有的登录会话（包括图形和终端会话）。 =terminate-session= 会向会话中的所有进程发送终止信号，并清理会话资源。
```

- [ ] **Step 2: 提交**

```bash
git add linux和它的小伙伴/在Linux上限制儿童使用电脑.org
git commit -m "blog: 完成《在Linux上限制儿童使用电脑》第三节"
```

---

### Task 5: 编写第四节——限制可访问网站

**Files:**
- Modify: `linux和它的小伙伴/在Linux上限制儿童使用电脑.org`

- [ ] **Step 1: 追加第四节内容**

追加内容要点：
- 节标题：`* 限制可访问网站`
- 开头说明限制网站访问的难度：HTTPS 时代无法做内容过滤，只能做 IP/域名级别
- **方法一：DNS 级过滤（dnsmasq）**：
  - 配置 `dnsmasq` 作为本地 DNS 服务器
  - 维护一个黑名单文件 `/etc/blocked-hosts`
  - 将黑名单中的域名解析到 `127.0.0.1`
  - 优点：配置简单，对所有协议生效
  - 缺点：孩子可以手动改 DNS 绕过
- **方法二：iptables 按用户限制网络访问**：
  - 用 `owner` 模块匹配特定 UID 的流量
  - 结合 `time` 模块按时间段限制
  - 展示具体 iptables 规则
  - 优点：无法通过改 DNS 绕过
  - 缺点：只能按 IP/端口限制，不能精确到域名
- **原理部分**：
  - Netfilter 的五个钩子点
  - iptables 规则匹配流程：从上到下匹配，匹配到就执行动作
  - `owner` 模块和 `time` 模块的工作方式

追加的 Org-mode 内容：

```org
* 限制可访问网站

在 HTTPS 普及的今天，我们无法在不安装额外证书的情况下检查 HTTP 请求的内容。因此 Linux 原生方案只能在 IP 和域名级别进行过滤。下面介绍两种方法。

** 方法一：DNS 级过滤

通过配置本地 DNS 服务器 =dnsmasq= ，将不希望访问的域名解析到无效地址。

首先安装 =dnsmasq= ：

#+BEGIN_SRC shell
  sudo pacman -S dnsmasq  # Arch Linux
#+END_SRC

创建黑名单文件 =/etc/blocked-hosts= ：

#+BEGIN_EXAMPLE
  # /etc/blocked-hosts
  # 每行一个要屏蔽的域名
  example-bad-site.com
  another-bad-site.com
#+END_EXAMPLE

在 =/etc/dnsmasq.conf= 中添加配置：

#+BEGIN_SRC shell
  # 将黑名单中的域名解析到 127.0.0.1
  conf-file=/etc/blocked-hosts
  addn-hosts=/etc/blocked-hosts
#+END_EXAMPLE

然后启动 dnsmasq 并将系统 DNS 指向本地：

#+BEGIN_SRC shell
  sudo systemctl enable --now dnsmasq
  # 修改 /etc/resolv.conf
  echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf
#+END_SRC

这种方法的缺点是：只要孩子知道如何修改 DNS 设置，就能轻松绕过。

** 方法二：iptables 按用户限制

=iptables= 的 =owner= 模块可以根据进程的 UID 来匹配网络流量， =time= 模块可以按时间段匹配。两者结合，可以限制特定用户在特定时间段内的网络访问。

#+BEGIN_SRC shell
  # 允许 geo 用户在 18:00-20:00 访问网络
  sudo iptables -A OUTPUT -m owner --uid-owner geo -m time --timestart 18:00 --timestop 20:00 -j ACCEPT

  # 禁止 geo 用户在其他时间访问网络
  sudo iptables -A OUTPUT -m owner --uid-owner geo -j DROP
#+END_EXAMPLE

要持久化这些规则，可以将它们写入一个脚本，然后让 =systemd= 在启动时自动执行：

#+BEGIN_SRC shell
  # /etc/iptables/parental-control.rules
  *filter
  :OUTPUT ACCEPT [0:0]
  -A OUTPUT -m owner --uid-owner geo -m time --timestart 18:00 --timestop 20:00 -j ACCEPT
  -A OUTPUT -m owner --uid-owner geo -j DROP
  COMMIT
#+END_SRC

#+BEGIN_SRC shell
  # 恢复规则
  sudo iptables-restore < /etc/iptables/parental-control.rules
#+END_SRC

** 原理说明

Linux 的网络过滤由 Netfilter 框架实现。Netfilter 在网络协议栈中设置了五个钩子点：

+ *PREROUTING* :: 数据包进入路由之前
+ *INPUT* :: 数据包发往本机进程之前
+ *FORWARD* :: 数据包转发到其他接口之前
+ *OUTPUT* :: 本机进程发出的数据包
+ *POSTROUTING* :: 数据包发出之前

我们使用的是 *OUTPUT* 链，它处理本机进程发出的所有数据包。 =owner= 模块通过检查数据包对应的 socket 的 UID 来匹配， =time= 模块通过系统时间来匹配。规则从上到下依次匹配，匹配到后就执行指定的动作（ =ACCEPT= 或 =DROP= ）。
```

**注意：** 上面 iptables 代码块中有一个 `#+END_EXAMPLE` 应该是 `#+END_SRC`，在实际写入时需修正。

- [ ] **Step 2: 提交**

```bash
git add linux和它的小伙伴/在Linux上限制儿童使用电脑.org
git commit -m "blog: 完成《在Linux上限制儿童使用电脑》第四节"
```

---

### Task 6: 编写第五节——限制可运行程序

**Files:**
- Modify: `linux和它的小伙伴/在Linux上限制儿童使用电脑.org`

- [ ] **Step 1: 追加第五节内容**

追加内容要点：
- 节标题：`* 限制可运行程序`
- **方法一：文件权限（DAC）**：
  - 创建受限组 `restricted`
  - 将要限制的程序设为 `root:restricted 750`
  - geo 用户不在 restricted 组中就无法执行
  - 优点：简单直观
  - 缺点：需要逐个程序设置，更新后可能重置权限
- **方法二：AppArmor（MAC）**：
  - 简要介绍 AppArmor 的 profile 概念
  - 给出一个简单的 profile 示例
  - 说明 Arch Linux 上 AppArmor 的安装和启用
- **原理部分**：
  - DAC（自主访问控制）：基于文件权限位（rwx）和所有者/组/其他
  - MAC（强制访问控制）：AppArmor 基于路径的强制策略

追加的 Org-mode 内容：

```org
* 限制可运行程序

不想让孩子玩某些游戏或使用某些软件？最直接的方法是通过 Linux 的权限系统来限制。

** 方法一：文件权限控制

Linux 的每个文件都有三组权限：所有者（owner）、所属组（group）、其他人（others）。我们可以利用这个机制来限制特定用户执行特定程序。

假设要禁止 =geo= 用户运行 =steam= ：

#+BEGIN_SRC shell
  # 创建受限组
  sudo groupadd restricted

  # 将 steam 的组改为 restricted，权限设为 750
  sudo chgrp restricted /usr/bin/steam
  sudo chmod 750 /usr/bin/steam

  # 确保 geo 不在 restricted 组中
  sudo gpasswd -d geo restricted 2>/dev/null || true
#+END_SRC

这样，只有 root 用户和 restricted 组的成员可以运行 =steam= ，而 =geo= 用户会得到 "Permission denied" 的错误。

对于需要限制的每个程序，重复上述步骤即可。也可以写一个脚本来批量处理：

#+BEGIN_SRC shell
  #!/bin/bash
  # /usr/local/bin/restrict-programs.sh
  # 限制指定程序只能由 restricted 组执行

  PROGRAMS="/usr/bin/steam /usr/bin/wine /usr/bin/discord"

  for prog in $PROGRAMS; do
      if [ -f "$prog" ]; then
          sudo chgrp restricted "$prog"
          sudo chmod 750 "$prog"
          echo "Restricted: $prog"
      fi
  done
#+END_SRC

需要注意：当软件包更新时，权限可能会被重置。可以将这个脚本放在 systemd 的 timer 或 pacman 的 hook 中定期执行。

** 方法二：AppArmor

AppArmor 提供了更强大的强制访问控制（MAC）。与文件权限不同，AppArmor 的策略无法被用户（包括文件所有者）修改。

在 Arch Linux 上安装并启用 AppArmor：

#+BEGIN_SRC shell
  sudo pacman -S apparmor
  sudo systemctl enable --now apparmor
#+END_SRC

AppArmor 通过 profile 来定义程序的访问权限。下面是一个简单的 profile 示例，禁止 =geo= 用户执行 =steam= ：

#+BEGIN_EXAMPLE
  # /etc/apparmor.d/restrict-geo-steam
  abi <abi/4.0>,
  include <tunables/global>

  /usr/bin/steam {
      include <abstractions/base>

      # 拒绝 geo 用户执行
      audit deny /usr/bin/steam rwx,
      owner /usr/bin/steam rwx,
  }
#+END_EXAMPLE

加载 profile：

#+BEGIN_SRC shell
  sudo apparmor_parser -r /etc/apparmor.d/restrict-geo-steam
#+END_SRC

** 原理说明

+ *DAC（自主访问控制）* :: Linux 默认的权限模型。每个文件有三组权限位（读 r、写 w、执行 x），分别对应所有者、所属组、其他人。文件的所有者可以自主修改文件的权限。"自主"的含义就在于此——权限由所有者决定。

+ *MAC（强制访问控制）* :: AppArmor 实现的权限模型。策略由系统管理员定义，普通用户无法绕过或修改。AppArmor 使用基于路径的匹配（而非 SELinux 的基于标签的匹配），配置相对简单。
```

- [ ] **Step 2: 提交**

```bash
git add linux和它的小伙伴/在Linux上限制儿童使用电脑.org
git commit -m "blog: 完成《在Linux上限制儿童使用电脑》第五节"
```

---

### Task 7: 编写总结

**Files:**
- Modify: `linux和它的小伙伴/在Linux上限制儿童使用电脑.org`

- [ ] **Step 1: 追加总结**

追加总结内容：

```org
* 总结

本文介绍了五种用纯 Linux 原生机制限制儿童使用电脑的方法：

+ *限制登录时段* :: 使用 PAM 的 =pam_time= 模块，通过 =/etc/security/time.conf= 配置
+ *限制使用时长* :: 使用 =pam_exec= 记录登录/登出时间，配合 cron 定时检查
+ *超时踢出* :: 使用 =wall= 发送警告， =pkill= 或 =loginctl= 踢出用户
+ *限制网站访问* :: 使用 =dnsmasq= 做 DNS 过滤，或 =iptables= 按用户和时间限制网络访问
+ *限制可运行程序* :: 使用文件权限或 AppArmor 控制程序执行

这些方案组合使用，可以构建一个相当完整的家长控制系统。但需要注意以下几点：

+ 这些方案需要 *root 权限* 来配置。如果你的孩子拥有 sudo 权限，ta 理论上可以绕过所有限制。
+ =pam_time= 只能控制新登录，无法踢出已经在线的用户。需要配合时长检查脚本来处理。
+ iptables 的 =owner= 模块只能匹配本机进程发出的流量，对于通过代理或 VPN 的流量可能无效。

最后，技术手段只是辅助。与孩子建立良好的沟通和信任，比任何软件限制都更有效。
```

- [ ] **Step 2: 提交**

```bash
git add linux和它的小伙伴/在Linux上限制儿童使用电脑.org
git commit -m "blog: 完成《在Linux上限制儿童使用电脑》总结"
```

---

### Task 8: 格式审查和最终修正

**Files:**
- Modify: `linux和它的小伙伴/在Linux上限制儿童使用电脑.org`

- [ ] **Step 1: 检查 Org-mode 行内标记规范**

逐项检查：
1. 所有 `=code=` 标记前后是否有空格或英文标点（不能紧邻中文或中文标点）
2. 所有粗体使用 `*粗体*`（单星号），不是 `**粗体**`
3. 代码块 `#+BEGIN_SRC` 和 `#+END_SRC` 配对正确
4. 示例块 `#+BEGIN_EXAMPLE` 和 `#+END_EXAMPLE` 配对正确
5. 文件末尾保留换行符
6. 修正第四节中 `#+END_EXAMPLE` 应为 `#+END_SRC` 的错误

- [ ] **Step 2: 最终提交**

```bash
git add linux和它的小伙伴/在Linux上限制儿童使用电脑.org
git commit -m "blog: 修正《在Linux上限制儿童使用电脑》格式"
```

---

## Self-Review

**1. Spec coverage:**
- 引言 ✓ (Task 1)
- 限制登录时段 ✓ (Task 2)
- 限制使用时长 ✓ (Task 3)
- 超时警告踢出 ✓ (Task 4)
- 限制网站访问 ✓ (Task 5)
- 限制可运行程序 ✓ (Task 6)
- 总结 ✓ (Task 7)
- 格式审查 ✓ (Task 8)

**2. Placeholder scan:** 无 TBD/TODO/待定内容。

**3. Type consistency:** 受限用户名统一为 `geo`，脚本路径统一为 `/usr/local/bin/`，日志文件统一为 `/var/log/user-sessions.log`。
