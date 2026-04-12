# yes | head 发生了什么 — 博文设计

## 概述

一篇解释 `yes | head` 命令执行全流程的博文，按时间线组织，从 Shell 创建管道到进程退出，全面覆盖管道机制、缓冲区协调和 SIGPIPE 信号。

## 文件

- 路径：`linux和它的小伙伴/yes|head发生了什么.org`
- 格式：Org-mode，与现有博文一致
- 头信息：TITLE / AUTHOR / TAGS: linux和它的小伙伴 / DATE / LANGUAGE: zh-CN

## 风格

- 通俗讲解，与《blocking I/O 的作用》风格一致
- ASCII 图示辅助说明
- strace 实验验证
- 行内标记遵循 Org-mode 规范（标记前后加空格、粗体用单星号）

## 文章结构

### 第一节：开场 — 提出问题

- 介绍 `yes | head` 命令
- 核心问题：yes 无限输出，head 只要 10 行，为什么不会一直跑？

### 第二节：Shell 做了什么

- Shell 解析 `|` 时的操作：`pipe()` → `fork()` × 2 → 重定向文件描述符
- 左进程（yes）：关闭读端，stdout → 管道写端
- 右进程（head）：关闭写端，stdin ← 管道读端
- ASCII 图示

### 第三节：管道是什么

- 管道本质：内核维护的固定大小缓冲区（Linux 默认 64KB）
- 先进先出（FIFO）
- 数据一旦被读走就从缓冲区移除

### 第四节：运行中的协作

- 简短提及 blocking I/O 协调（不重复上一篇细节）
- 缓冲区满 → write() 阻塞
- 缓冲区空 → read() 阻塞

### 第五节：head 完成后发生了什么（重点）

- head 读够 10 行，执行完毕，进程退出
- 内核关闭 head 的所有 fd，包括管道读端
- 管道只剩写端（yes），无读端
- yes 继续调用 write()
- 内核向 yes 发送 SIGPIPE 信号
- SIGPIPE 默认行为：终止进程
- ASCII 图示展示连锁反应

### 第六节：实验验证

- strace 追踪两个进程
- 观察 write() / read() 调用
- 观察 yes 收到 SIGPIPE

### 第七节：总结

- 管道不只是数据传输通道，还是进程间的"生死契约"
- 读端关闭，写端自动终止
