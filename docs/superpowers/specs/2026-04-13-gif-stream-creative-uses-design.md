# GIF 流奇妙用途博文设计

## 灵感来源
https://hookrace.net/blog/haskell-game-programming-with-gif-streams/ — 用 Haskell + GIF 流实现贪吃蛇游戏

## 目标
写一篇原理+用途集合的趣味博文，讲解 GIF 流的技术原理并展示多种奇怪用途

## 目标读者
对 Linux 命令行和编程技巧感兴趣的读者

## 暂定标题
- GIF 不仅仅是一种图片格式——用 GIF 流做些奇怪的事

## 分类
linux和它的小伙伴 或 无主之地

## 文章结构

### 1. 引子（~200 字）
从 hookrace.net 的 Haskell 贪吃蛇游戏说起——有人用 GIF 动画流在浏览器里玩游戏。引出问题：GIF 流到底是什么原理？还能用来做哪些奇怪的事？

### 2. GIF 流原理（~400 字）
- HTTP 的 multipart/x-mixed-replace Content-Type——服务器推送技术
- MJPEG（Motion JPEG）就是这个原理，摄像头监控常用
- 为什么用 GIF 而不是 JPEG？GIF 支持多帧动画，可以一次连接推送无限帧
- 用 curl 抓一个 GIF 流看看原始数据长什么样

### 3. 用途 1：用 Python 实现 GIF 流服务器（~400 字）
- 用 Python 写一个最简 GIF 流 HTTP 服务器
- 生成实时变化的画面（如时钟、随机色块）
- 浏览器打开就能看到"活的"图像

### 4. 用途 2：把终端变成 GIF 流（~300 字）
- 用 ttyrec / asciinema 录制终端会话，转成 GIF 动画
- 或者直接把终端输出通过 GIF 流推送到浏览器——手机远程看终端

### 5. 用途 3：实时系统监控仪表盘（~300 字）
- 用 Python 生成系统状态图（CPU、内存使用率），通过 GIF 流推送到浏览器
- 不需要 WebSocket、不需要 JavaScript，纯 GIF 就能实现"实时更新"

### 6. 用途 4：在 GIF 里藏数据/玩彩蛋（~200 字）
- 每一帧 GIF 可以携带隐藏信息（类似隐写术）
- 或者用 GIF 帧的延迟时间编码二进制数据

### 7. 小结（~150 字）
GIF 流是一个被遗忘的技术，在今天 WebSocket 和 WebRTC 的时代显得很"复古"，但它的简洁性（纯 HTTP、无需 JS）在某些场景下仍有独特价值。

## 写作风格
- Org-mode 格式
- 使用实际命令和代码演示
- 参考《无主之地》分类的趣味文章风格
- 参考《linux和它的小伙伴》的技术实操风格
