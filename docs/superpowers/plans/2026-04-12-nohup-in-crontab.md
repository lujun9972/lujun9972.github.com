# 为什么 nohup 在 crontab 中不起作用 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 写一篇 Org-mode 博客，分析为什么 nohup 的输出重定向在 crontab 中不生效。

**Architecture:** 问题驱动式结构，从实际 crontab 配置问题出发，通过分析 nohup 的 isatty() 条件检查和 cron 的管道执行环境，解释输出重定向不触发的根本原因。

**Tech Stack:** Org-mode 博客，配合 shell 实验验证。

---

### Task 1: 验证 nohup 的 isatty 检查逻辑

**目的：** 确认 nohup 源码中输出重定向的条件判断，确保技术分析准确。

- [ ] **Step 1: 读取 coreutils nohup.c 源码**

用 curl 获取 nohup 源码：

```bash
curl -sL https://raw.githubusercontent.com/coreutils/coreutils/master/src/nohup.c | head -200
```

关注 `isatty(STDOUT_FILENO)` 和 `isatty(STDERR_FILENO)` 的判断逻辑，确认重定向确实是条件触发的。

- [ ] **Step 2: 记录关键源码片段**

从源码中提取输出重定向的核心逻辑，保存备用。关键点：
- stdout 是终端 → 重定向到 nohup.out
- stdout 不是终端 → 不做重定向
- stderr 类似处理

---

### Task 2: 编写博文第 1 节（问题重现）和头部

**Files:**
- Create: `linux和它的小伙伴/为什么nohup在crontab中不起作用.org`

- [ ] **Step 1: 创建博文文件，写入头部和第 1 节**

```org
#+TITLE: 为什么 nohup 在 crontab 中不起作用
#+AUTHOR: lujun9972
#+TAGS: linux和它的小伙伴
#+DATE: [2026-04-12 六 00:00]
#+LANGUAGE:  zh-CN
#+OPTIONS:  H:6 num:nil toc:t \n:nil ::t |:t ^:nil -:nil f:t *:t <:nil

很多初学者在 crontab 中运行长时间任务时，习惯性地加上 =nohup= ，像这样：

#+BEGIN_SRC shell
  * * * * * nohup /path/to/long-running-command &
#+END_SRC

他们期望命令的输出会被重定向到 =nohup.out= 文件中。但实际结果是： =nohup.out= 根本没有被创建，命令的输出却出现在了系统邮件中（可以用 =mail= 命令查看）。

为什么会这样？要理解这个问题，我们需要先搞清楚两件事： =nohup= 到底做了什么，以及 =crontab= 是怎么执行命令的。

* nohup 到底做了什么

在之前的文章 [[file:nohup,setsid与disown的不同之处.org][nohup,setsid与disown的不同之处]] 中，我详细分析了 nohup 的原理。这里简要回顾一下。

=nohup= 做两件事：

1. 忽略 =SIGHUP= 信号（即 =signal(SIGHUP, SIG_IGN)= ），防止进程在终端关闭时被杀死
2. 将输出重定向到 =nohup.out= 文件

但关键是第二点并不是无条件的。让我们看看 coreutils 中 =nohup= 的源码逻辑：

#+BEGIN_SRC C
  if (isatty (STDIN_FILENO))
    /* 将 stdin 重定向到 /dev/null */

  if (isatty (STDOUT_FILENO))
    /* 将 stdout 重定向到 nohup.out */

  if (isatty (STDERR_FILENO))
    /* 将 stderr 重定向到与 stdout 相同的地方 */
#+END_SRC

注意到了吗？ =nohup= 只在 stdout/stderr *是终端* 的时候才会进行重定向。也就是说，如果你的 stdout 已经被重定向到了文件或管道， =nohup= 会认为"输出已经有地方去了"，就不会再创建 =nohup.out= 了。

这是理解问题的关键。
```

注意 Org-mode 格式规范：
- 行内标记 `=code=` 前后与中文相邻时加空格
- 粗体用单星号 `*粗体*`
- 不要混用 Markdown 语法

- [ ] **Step 2: 检查格式规范**

检查要点：
- 所有 `=...=` 行内标记前后是否与中文/中文标点相邻？如果是则补空格
- 没有使用 Markdown 的 `**` 粗体
- 文件末尾保留换行符

---

### Task 3: 编写博文第 2 节（crontab 的运行环境）

**Files:**
- Modify: `linux和它的小伙伴/为什么nohup在crontab中不起作用.org`

- [ ] **Step 1: 在第 1 节后面追加第 2 节内容**

在文件末尾追加：

```org
* crontab 的运行环境

要理解为什么 =nohup= 在 crontab 中不生效，我们需要看看 cron 是怎么执行用户命令的。

当你编辑 =crontab= 添加一条任务后， =cron= 守护进程会在指定时间执行你的命令。关键在于 cron 是*怎么*执行这些命令的：

1. cron 会 fork 出一个子进程
2. 这个子进程会调用 =exec("/bin/sh", "-c", "你的命令")= 来执行任务
3. 在执行之前，cron 会将子进程的 stdout 和 stderr 连接到*管道*（pipe），而不是终端

这意味着什么？意味着在你的命令看来：

- stdin 是 =/dev/null= （不是终端）
- stdout 是一个管道（不是终端）
- stderr 是一个管道（不是终端）
- 没有控制终端（controlling terminal）
- 工作目录默认是 =HOME=

你可以用一个简单的方法验证：在 crontab 中执行 =tty= 命令，它会告诉你当前的终端设备：

#+BEGIN_SRC shell
  * * * * * tty
#+END_SRC

你会收到一封系统邮件，内容类似 =not a tty= 或者 =/dev/null= ，这就证明了 crontab 的执行环境中没有终端。
```

- [ ] **Step 2: 检查行内标记格式**

确保所有 `=...=` 标记与中文之间有空格。

---

### Task 4: 编写博文第 3 节（为什么 nohup 的重定向不生效）

**Files:**
- Modify: `linux和它的小伙伴/为什么nohup在crontab中不起作用.org`

- [ ] **Step 1: 在第 2 节后面追加第 3 节内容**

在文件末尾追加：

```org
* 为什么 nohup 的重定向不生效

现在把前面的线索串起来：

1. crontab 执行命令时，stdout 和 stderr 是*管道*，不是终端
2. =nohup= 检查 =isatty(STDOUT_FILENO)= → 返回 =false= （因为 stdout 是管道）
3. =nohup= 认为"输出已经有地方去了"，*跳过* 重定向步骤
4. 命令的输出顺着管道传给了 cron
5. cron 将收到的输出发送到系统邮件

所以 =nohup.out= 根本就不会被创建！输出去了哪里？去了 cron 的邮件队列。

同时， =nohup= 的另一个功能——忽略 =SIGHUP= 信号——在 crontab 中也毫无意义。因为 cron 的执行环境根本没有终端会话，不存在"终端挂断"的场景，自然也不会有 =SIGHUP= 信号。

总结一下： =nohup= 在 crontab 中是 *双重无用* 的：

| 功能 | 在 crontab 中 | 原因 |
|------+---------------+------|
| 忽略 SIGHUP | 不需要 | cron 无终端会话，无 SIGHUP |
| 输出重定向到 nohup.out | 不触发 | stdout 不是终端，isatty 返回 false |
```

- [ ] **Step 2: 检查格式**

确认 Org-mode 表格格式正确（用 `|` 和 `+-` 分隔），行内标记规范。

---

### Task 5: 编写博文第 4 节（正确的做法）

**Files:**
- Modify: `linux和它的小伙伴/为什么nohup在crontab中不起作用.org`

- [ ] **Step 1: 在第 3 节后面追加第 4 节内容**

在文件末尾追加：

```org
* 正确的做法

既然 =nohup= 在 crontab 中没用，那输出应该怎么处理？答案很简单：自己重定向。

#+BEGIN_SRC shell
  * * * * * /path/to/command >> /path/to/output.log 2>&1
#+END_SRC

这样写就足够了，原因：

- *不需要 nohup* ：cron 没有终端会话，不存在 SIGHUP 的问题
- *不需要 &* ：cron 本身就在后台执行命令，不需要手动放到后台
- *自己控制输出位置* ：用 shell 的重定向语法精确指定输出文件

如果你想让命令在 cron 触发后持续运行（比如一个需要跑好几个小时的任务），直接执行就行。cron 会等待命令完成，不会中途杀掉进程。但要注意：如果命令运行时间超过了 crontab 的调度间隔，可能会出现重复执行的问题。这时候可以考虑在命令中加入锁机制（比如 =flock= ），或者使用 =systemd timer= 替代 crontab。

如果你想丢弃输出，也不想收到邮件：

#+BEGIN_SRC shell
  * * * * * /path/to/command > /dev/null 2>&1
#+END_SRC

这比 =nohup command > /dev/null 2>&1 &= 简洁得多，而且效果完全一样。
```

- [ ] **Step 2: 全文格式审查**

检查全文：
1. 所有行内标记 `=...=` 前后与中文/中文标点相邻处是否加了空格
2. 粗体使用单星号 `*...*`，没有用 Markdown 的 `**`
3. src block 格式正确
4. 文件末尾有换行符

---

### Task 6: 最终审查与提交

- [ ] **Step 1: 通读全文，检查逻辑连贯性**

确认：
- 问题重现 → nohup 原理 → cron 环境 → 分析原因 → 正确做法，逻辑链完整
- 技术细节准确（isatty 检查、管道、cron 执行方式）
- 与已有文章 `nohup,setsid与disown的不同之处.org` 的引用关系正确

- [ ] **Step 2: 提交博文**

```bash
git add "linux和它的小伙伴/为什么nohup在crontab中不起作用.org"
git commit -m "blog: 为什么 nohup 在 crontab 中不起作用"
```
