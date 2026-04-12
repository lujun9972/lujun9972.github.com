# yes | head 发生了什么 — 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 写一篇 Org-mode 博文，全面解释 `yes | head` 的执行全流程

**Architecture:** 按时间线组织，从 Shell 创建管道到进程退出，覆盖管道机制、缓冲区协调、SIGPIPE 信号。包含 strace 实验验证。

**Tech Stack:** Org-mode 博文，strace 实验

---

## 文件结构

| 文件 | 操作 | 职责 |
|------|------|------|
| `linux和它的小伙伴/yes管道head发生了什么.org` | 创建 | 博文主体 |

---

### Task 1: 创建文件头部和开场部分

**Files:**
- Create: `linux和它的小伙伴/yes管道head发生了什么.org`

- [ ] **Step 1: 创建文件，写入头部和第一、二节**

内容要点：

**头部：**
```
#+TITLE: yes 管道 head 发生了什么
#+AUTHOR: lujun9972
#+TAGS: linux和它的小伙伴
#+DATE: [2026-04-12 六 00:00]
#+LANGUAGE: zh-CN
#+OPTIONS: H:6 num:nil toc:t \n:nil ::t |:t ^:nil -:nil f:t *:t <:nil
```

**第一节：提出问题**
- 介绍 `yes | head` 命令，展示运行结果（10 行 y）
- `yes` 无限输出，`head` 只取 10 行
- 提出核心问题：为什么不会一直运行下去？

**第二节：Shell 做了什么**
- Shell 看到管道符号 `|` 后的操作序列：
  1. `pipe()` 创建管道，得到两个文件描述符（读端 fd[0]、写端 fd[1]）
  2. `fork()` 两次创建两个子进程
  3. yes 进程：关闭读端 fd[0]，`dup2(fd[1], 1)` 将 stdout 重定向到管道写端
  4. head 进程：关闭写端 fd[1]，`dup2(fd[0], 0)` 将 stdin 重定向到管道读端
- ASCII 图示：
```
  Shell (bash)
    │
    ├─ pipe() ──▶ [fd[0] 读端, fd[1] 写端]
    │
    ├─ fork() ──▶ yes 进程
    │               关闭 fd[0]
    │               dup2(fd[1], 1)  ← stdout → 管道写端
    │
    └─ fork() ──▶ head 进程
                    关闭 fd[1]
                    dup2(fd[0], 0)  ← 管道读端 → stdin

  最终效果：
  yes ──stdout──▶ [ 管道缓冲区 ] ──stdin──▶ head
```

- 引用 strace 输出中 Shell 创建管道的关键部分作为佐证（从实际实验数据中提取）：
```
pipe2([3, 4], 0)                  = 0        ← 创建管道，fd[0]=3(读), fd[1]=4(写)
clone(...)                        = 45210    ← fork 出 yes 进程
close(4)                          = 0        ← bash 关闭写端（自己不写）
clone(...)                        = 45211    ← fork 出 head 进程
close(3)                          = 0        ← bash 关闭读端（自己不读）

45210 close(3)                    = 0        ← yes 关闭读端
45210 dup2(4, 1)                  = 1        ← yes: fd[1] → stdout
45210 close(4)                    = 0        ← yes 关闭原来的 fd[1]
45210 execve("/usr/bin/yes" ...)  = 0        ← yes 开始执行

45211 dup2(3, 0)                  = 0        ← head: fd[0] → stdin
45211 close(3)                    = 0        ← head 关闭原来的 fd[0]
45211 execve("/usr/bin/head" ...) = 0        ← head 开始执行
```

- [ ] **Step 2: Commit**

```bash
git add "linux和它的小伙伴/yes管道head发生了什么.org"
git commit -m "blog: 新增《yes管道head发生了什么》前两节"
```

---

### Task 2: 写第三节（管道是什么）和第四节（运行中的协作）

**Files:**
- Modify: `linux和它的小伙伴/yes管道head发生了什么.org`

- [ ] **Step 1: 追加第三、四节内容**

**第三节：管道是什么**

要点：
- 管道的本质是内核维护的一个*固定大小的缓冲区*（Linux 默认 64KB，可通过 `fcntl(fd, F_GETPIPE_SZ)` 查询）
- 先进先出（FIFO）：先写入的数据先被读出
- 数据被读走后从缓冲区中移除，腾出空间给新数据
- 管道是*单向的*：数据只能从写端流向读端
- 管道没有名字（匿名管道），只能用于有亲缘关系的进程之间（父子进程）

**第四节：运行中的协作**

要点：
- 简要提及 blocking I/O 协调（因上一篇已详述，这里只概述结论）：
  - 缓冲区满了 → yes 的 =write()= 阻塞，yes 进入睡眠
  - 缓冲区空了 → head 的 =read()= 阻塞，head 进入睡眠
  - 两者通过内核自动协调速率
- 补充一句：在我们这个场景中，=yes= 输出速度远快于 =head= 消耗速度（head 只需要 10 行），所以实际上缓冲区几乎不会满

- [ ] **Step 2: Commit**

```bash
git add "linux和它的小伙伴/yes管道head发生了什么.org"
git commit -m "blog: 新增管道机制与运行协调部分"
```

---

### Task 3: 写第五节（head 完成后发生了什么）— 核心重点

**Files:**
- Modify: `linux和它的小伙伴/yes管道head发生了什么.org`

- [ ] **Step 1: 追加第五节内容**

这是全文最核心的部分，要讲清楚终止链条：

要点：
1. head 读够了 10 行（默认行为），任务完成
2. head 进程退出，内核自动关闭它所有的文件描述符，包括管道的*读端*
3. 此时管道只剩写端（yes），没有读端了
4. yes 还在继续调用 =write()= 往管道里写数据
5. 内核发现管道的读端已经没有进程在持有（所有引用都关闭了）
6. 内核向 yes 发送 =SIGPIPE= 信号（信号编号 13）
7. =SIGPIPE= 的默认处理方式是*终止进程*，所以 yes 也退出了

ASCII 图示展示连锁反应：
```
  ① head 读够 10 行，任务完成

  yes ──stdout──▶ [ 管道缓冲区 ] ──stdin──▶ head ✓ (完成)

  ② head 退出，内核关闭管道读端

  yes ──stdout──▶ [ 管道缓冲区 ] ──✕── (读端已关闭)

  ③ yes 继续写入，内核发现没有读端

  yes ──write()──▶ ???  ← 内核发送 SIGPIPE (信号13)

  ④ SIGPIPE 默认行为：终止 yes 进程

  yes ✕ (被 SIGPIPE 杀死)
```

从 strace 输出中提取关键证据：
```
45211 close(0)                          = 0        ← head 关闭 stdin（管道读端）
45210 write(1, "y\ny\n...", 8192)       = -1 EPIPE  ← yes 写入失败：EPIPE（断开的管道）
45210 --- SIGPIPE {si_signo=SIGPIPE} ---           ← yes 收到 SIGPIPE 信号
45210 +++ killed by SIGPIPE +++                    ← yes 被 SIGPIPE 杀死
45211 write(1, "y\ny\n...", 20)          = 20       ← head 输出结果到终端
45211 exit_group(0)                     = ?        ← head 正常退出
```

- [ ] **Step 2: Commit**

```bash
git add "linux和它的小伙伴/yes管道head发生了什么.org"
git commit -m "blog: 新增 SIGPIPE 终止机制部分"
```

---

### Task 4: 写第六节（实验验证）和第七节（总结）

**Files:**
- Modify: `linux和它的小伙伴/yes管道head发生了什么.org`

- [ ] **Step 1: 追加第六、七节**

**第六节：实验验证**

提供读者可复现的完整实验命令：

```shell
strace -f -e trace=write,read,pipe,pipe2,clone,close,dup2,execve,exit_group -o /tmp/yes_head.log bash -c 'yes | head'
```

然后展示关键输出并逐步解释（使用 Task 3 中实际获取的 strace 输出，但筛选出核心行）。

**第七节：总结**

要点：
- 一句话总结全文：管道不只是数据传输通道，还是进程间的"生死契约"——读端关闭，写端自动终止
- 整个过程涉及三个层面：
  1. Shell 层：解析管道符号，创建管道，连接进程
  2. 内核层：管理管道缓冲区，协调读写速率（blocking I/O）
  3. 信号层：读端关闭后通过 SIGPIPE 通知写端退出
- 最精妙的是：这一切对 =yes= 和 =head= 来说都是透明的——它们不需要知道彼此的存在，不需要写任何协调代码，只需要各做各的事，操作系统把剩下的事情都安排好了

文件末尾保留换行符。

- [ ] **Step 2: Commit**

```bash
git add "linux和它的小伙伴/yes管道head发生了什么.org"
git commit -m "blog: 完成《yes管道head发生了什么》"
```

---

## 自查结果

- **Spec 覆盖度**：设计文档中的 7 个章节分别由 Task 1（第一节、第二节）、Task 2（第三节、第四节）、Task 3（第五节）、Task 4（第六节、第七节）覆盖。无遗漏。
- **占位符扫描**：无 TBD/TODO/待定内容，所有步骤都包含具体内容。
- **一致性检查**：文件路径、strace 输出、ASCII 图示在各 Task 间保持一致。
