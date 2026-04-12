# 博客设计：为什么 nohup 在 crontab 中不起作用

## 概述

写一篇 Org-mode 技术博客，分析为什么 nohup 的输出重定向在 crontab 中不生效。核心论点是 nohup 在 crontab 中"双重无用"：SIGHUP 保护无意义（cron 无终端会话），输出重定向不触发（cron 的 stdout 是管道而非终端）。

## 目标读者

通用技术文，不特别限定读者水平，重点把原理讲清楚。

## 与已有文章的关系

博客已有 `nohup,setsid与disown的不同之处.org`（2018年），讲解了 nohup/setsid/disown 的原理差异。新文章聚焦 nohup 与 crontab 的交互问题，第 2 节会简要回顾 nohup 机制但不重复已有内容。

## 文章结构

### 第 1 节：问题重现

给出一个典型的错误 crontab 条目：

```
* * * * * nohup some_command &
```

- 用户期望：输出写入 nohup.out
- 实际结果：nohup.out 没有被创建，输出被 cron 发送到系统邮件

配合简单实验验证：写一个输出文本的脚本，在 crontab 中用 nohup 运行，检查 nohup.out 是否存在、系统邮件中是否有输出。

### 第 2 节：nohup 到底做了什么

简要回顾 nohup 的两个核心行为：

1. `signal(SIGHUP, SIG_IGN)` — 忽略挂断信号
2. 输出重定向 — **关键点：只有当 stdout/stderr 是终端（isatty() 为真）时才重定向到 nohup.out**

展示 nohup 的核心判断逻辑（来自 coreutils 源码）：

```c
if (isatty(STDOUT_FILENO))
    redirect stdout to nohup.out
if (isatty(STDERR_FILENO))
    redirect stderr to nohup.out
```

重点说明：nohup 的重定向是条件触发的，不是无条件的。

### 第 3 节：crontab 的运行环境

分析 cron 如何执行命令：

- cron 通过 `/bin/sh -c "用户命令"` 执行
- stdout/stderr 被设为管道（pipe），cron 通过管道捕获输出
- isatty(stdout) 返回 false
- 没有 controlling terminal，不存在 SIGHUP 的来源
- 默认工作目录是用户 home 目录

### 第 4 节：为什么 nohup 的重定向不生效

核心分析链：

1. cron 的 stdout 是管道（pipe）
2. nohup 检查 isatty(stdout) → 返回 false
3. nohup 跳过重定向步骤
4. 输出走 cron 的管道
5. cron 将管道中的输出发送到系统邮件

同时说明 SIGHUP 保护也无意义：cron 没有终端会话，不存在挂断场景。

总结：nohup 在 crontab 中"双重无用"——既没有 SIGHUP 需要忽略，也没有输出需要重定向。

### 第 5 节：正确的做法

在 crontab 中直接用 shell 重定向：

```
* * * * * command >> /path/to/output.log 2>&1
```

- 不需要 nohup（无 SIGHUP 风险）
- 不需要 `&`（cron 本身就在后台执行）
- 自己控制输出位置

补充说明：如果确实需要让命令在 cron 触发后持续运行（如长时间任务），直接执行即可，cron 会等待命令完成，不会中途杀掉进程。

## 技术要点

- nohup 的 isatty() 检查是理解问题的关键
- cron 用管道连接子进程的 stdout/stderr，这是 nohup 重定向不触发的直接原因
- 需要准备实验验证，确保技术分析准确

## 文件位置

`linux和它的小伙伴/为什么nohup在crontab中不起作用.org`
