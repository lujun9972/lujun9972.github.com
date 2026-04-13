# GIF 流奇妙用途博文实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 写一篇原理+用途集合的趣味博文，讲解 GIF 流技术原理并展示多种奇怪用途

**Architecture:** 以 Haskell GIF 贪吃蛇游戏为引子，先讲 multipart/x-mixed-replace 原理，再展示 4 个递进式的有趣用途（Python 服务器→终端录制→系统监控→隐写术），最后总结

**Tech Stack:** Org-mode 博文格式，Python (Pillow + http.server)，ttyrec/ttygif，asciinema

**Design spec:** `docs/superpowers/specs/2026-04-13-gif-stream-creative-uses-design.md`

---

## 文件结构

- **Create:** `无主之地/GIF不仅仅是一种图片格式——用GIF流做些奇怪的事.org`

## 写作规范

- Org-mode 格式，不混用 Markdown
- 行内标记（=code=、*粗体*）前后必须有空格或英文标点，不与中文/中文标点相邻
- src block 区分用途：完整脚本加 `:tangle`，sudo 命令加 `:dir /sudo::`，纯展示不加头部
- 文件末尾保留换行符

---

### Task 1: 创建文件框架和引子

**Files:**
- Create: `无主之地/GIF不仅仅是一种图片格式——用GIF流做些奇怪的事.org`

- [ ] **Step 1: 创建文件并写入头部和引子**

```org
#+TITLE: GIF不仅仅是一种图片格式——用GIF流做些奇怪的事
#+AUTHOR: lujun9972
#+TAGS: 无主之地
#+DATE: [2026-04-13 日 00:00]
#+LANGUAGE:  zh-CN
#+OPTIONS:  H:6 num:nil toc:t \n:nil ::t |:t ^:nil -:nil f:t *:t <:nil

你有没有想过，有人用 GIF 动画在浏览器里玩游戏？

这不是玩笑。有人用 Haskell 写了一个贪吃蛇游戏，但它的画面输出不是通过窗口或 Canvas，而是通过 *GIF 动画流* ——服务器不断向浏览器推送新的 GIF 帧，浏览器自动显示，就这样实现了一个"实时"游戏。打开浏览器，访问一个 URL，就能看到不断变化的 GIF 画面，按 WASD 键还能控制蛇的移动方向。

这听起来很奇怪，但仔细想想又很巧妙：GIF 是一种几乎所有浏览器都支持的图片格式，不需要 JavaScript，不需要 WebSocket，甚至不需要现代浏览器——只要能显示 GIF 就行。

那么，这种"GIF 流"的技术原理是什么？除了玩游戏，它还能做哪些奇怪的事？让我们一起来探索。

参考资料: <https://hookrace.net/blog/haskell-game-programming-with-gif-streams/>
```

- [ ] **Step 2: Commit**

```bash
git add "无主之地/GIF不仅仅是一种图片格式——用GIF流做些奇怪的事.org"
git commit -m "blog: 添加 GIF 流博文框架和引子

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 2: 写 GIF 流原理部分

**Files:**
- Modify: `无主之地/GIF不仅仅是一种图片格式——用GIF流做些奇怪的事.org`

- [ ] **Step 1: 追加 GIF 流原理章节**

在引子后面追加以下内容：

```org

* GIF 流的原理

GIF 流的核心技术是 HTTP 的 =multipart/x-mixed-replace= Content-Type。这是一种 *服务器推送* （Server Push）技术，诞生于 Netscape 时代。

普通的 HTTP 响应是这样的：客户端发请求，服务器返回一个完整的响应（一个 HTML 页面、一张图片等），然后连接关闭。

而 =multipart/x-mixed-replace= 允许服务器在 *同一个 HTTP 连接* 上连续发送多个"部分"，每个部分都会 *替换* 前一个。浏览器收到新的部分后，会自动用新内容替换旧内容。

原始的 HTTP 响应看起来是这样的：

#+BEGIN_EXAMPLE
HTTP/1.1 200 OK
Content-Type: multipart/x-mixed-replace; boundary=frame

--frame
Content-Type: image/gif

<GIF 二进制数据：第 1 帧>
--frame
Content-Type: image/gif

<GIF 二进制数据：第 2 帧>
--frame
Content-Type: image/gif

<GIF 二进制数据：第 3 帧>
...
#+END_EXAMPLE

服务器 *永远不会关闭这个连接* ，而是持续不断地发送新的 GIF 帧。浏览器收到每一帧后立即显示，然后再等待下一帧。就这样，一个静态的 =<img>= 标签就变成了"实时视频"。

这项技术最常见于 *IP 摄像头的监控画面* （MJPEG 流），但用 GIF 来实现同样可行，而且 GIF 格式还有个优势：支持透明通道和简单的动画优化。

我们用 =curl= 来抓取一个 GIF 流，看看原始数据：

#+BEGIN_SRC shell
  curl -s http://example.com/stream | head -c 500 | xxd | head -20
#+END_SRC

你会看到 GIF 文件头（ =GIF89a= ）和二进制数据不断涌入，直到你按 Ctrl+C 终止连接。

理解了原理后，接下来我们来看看 GIF 流能做哪些有趣的事。
```

- [ ] **Step 2: Commit**

```bash
git add "无主之地/GIF不仅仅是一种图片格式——用GIF流做些奇怪的事.org"
git commit -m "blog: 添加 GIF 流原理部分

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 3: 写用途 1 — Python GIF 流服务器

**Files:**
- Modify: `无主之地/GIF不仅仅是一种图片格式——用GIF流做些奇怪的事.org`

- [ ] **Step 1: 追加 Python GIF 流服务器章节**

在原理部分后面追加以下内容：

```org

* 用途 1：用 Python 实现一个 GIF 流服务器

理解了原理，我们来动手实现一个最简 GIF 流服务器。用 Python 标准库 + Pillow 就够了。

** 安装依赖

#+BEGIN_SRC shell :dir /sudo::
  sudo pip install Pillow
#+END_SRC

** 完整代码

#+BEGIN_SRC python :tangle "/sudo::/tmp/gif_stream_server.py"
#!/usr/bin/env python3
"""最简 GIF 流服务器 - 在浏览器中显示实时变化的颜色"""
from http.server import HTTPServer, BaseHTTPRequestHandler
from io import BytesIO
import time, math
from PIL import Image, ImageDraw

class GifStreamHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'multipart/x-mixed-replace; boundary=frame')
        self.send_header('Cache-Control', 'no-cache')
        self.end_headers()

        t = 0
        while True:
            # 生成 200x200 的图像，颜色随时间变化
            r = int((math.sin(t * 0.05) + 1) * 127)
            g = int((math.sin(t * 0.05 + 2) + 1) * 127)
            b = int((math.sin(t * 0.05 + 4) + 1) * 127)

            img = Image.new('RGB', (200, 200), (r, g, b))
            draw = ImageDraw.Draw(img)
            # 在中间显示当前时间
            draw.text((50, 80), time.strftime('%H:%M:%S'), fill=(255, 255, 255))

            # 将图像编码为 GIF
            buf = BytesIO()
            img.save(buf, format='GIF')
            gif_data = buf.getvalue()

            # 按 multipart/x-mixed-replace 格式发送
            self.wfile.write(b'--frame\r\n')
            self.wfile.write(b'Content-Type: image/gif\r\n')
            self.wfile.write(f'Content-Length: {len(gif_data)}\r\n'.encode())
            self.wfile.write(b'\r\n')
            self.wfile.write(gif_data)
            self.wfile.write(b'\r\n')
            self.wfile.flush()

            t += 1
            time.sleep(0.1)  # 10 FPS

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 8080), GifStreamHandler)
    print('Listening on http://0.0.0.0:8080/')
    server.serve_forever()
#+END_SRC

** 运行效果

#+BEGIN_SRC shell
  python3 /tmp/gif_stream_server.py
#+END_SRC

然后在浏览器中打开 =http://localhost:8080/= ，你会看到一个不断变色的色块，中间显示着实时时钟。

整个过程：
- 服务器每 100ms 生成一帧 GIF 图像
- 通过 =multipart/x-mixed-replace= 协议推送给浏览器
- 浏览器自动替换显示，无需任何 JavaScript

你甚至可以用 =wget= 录制这个 GIF 流：

#+BEGIN_SRC shell
  # 录制 5 秒的 GIF 流（按 Ctrl+C 停止）
  timeout 5 wget -O recording.gif http://localhost:8080/
#+END_SRC

不过由于 =multipart/x-mixed-replace= 的原因，录制的文件不能直接当普通 GIF 使用，需要去掉 HTTP 头部和边界标记，只保留第一个完整的 GIF 数据块。
```

- [ ] **Step 2: Commit**

```bash
git add "无主之地/GIF不仅仅是一种图片格式——用GIF流做些奇怪的事.org"
git commit -m "blog: 添加 Python GIF 流服务器部分

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 4: 写用途 2 — 终端转 GIF

**Files:**
- Modify: `无主之地/GIF不仅仅是一种图片格式——用GIF流做些奇怪的事.org`

- [ ] **Step 1: 追加终端转 GIF 章节**

在 Python 服务器部分后面追加以下内容：

```org

* 用途 2：把终端操作录制成 GIF

GIF 的另一个有趣用途是 *录制终端操作* 。这在写教程、分享命令行技巧时特别好用。

** 方法一：ttyrec + ttygif

=ttyrec= 是一个经典的终端录制工具， =ttygif= 可以将录制结果转换为 GIF ：

#+BEGIN_SRC shell
  # 安装工具
  sudo pacman -S ttyrec ttygif imagemagick   # Arch Linux

  # 开始录制
  ttyrec mysession.tty

  # ... 在终端中执行一些命令 ...

  # 按 Ctrl+D 结束录制

  # 转换为 GIF
  ttygif mysession.tty -o output.gif
#+END_SRC

** 方法二：asciinema

=asciinema= 是更现代的选择，先录制为 JSON 格式（ =.cast= 文件），再转换为 GIF ：

#+BEGIN_SRC shell
  # 安装
  sudo pacman -S asciinema

  # 录制
  asciinema rec demo.cast

  # ... 执行命令 ...

  # 按 Ctrl+D 结束

  # 播放回放
  asciinema play demo.cast

  # 转换为 GIF（需要 agg 工具）
  agg demo.cast output.gif
#+END_SRC

=asciinema= 的优势在于录制文件是纯文本的 JSON，体积很小，还可以上传到 =asciinema.org= 在线分享。

** 方法三：直接生成 GIF

如果只是想把命令的输出快速转成 GIF ，可以用 =ImageMagick= 从文本直接生成：

#+BEGIN_SRC shell
  # 将命令输出转为 GIF 图片
  ls -la | convert -background black -fill green -font monospace -pointsize 14 text:- output.gif
#+END_SRC

这些工具的核心思路都是一样的：将终端的字符输出逐帧渲染成图片，然后打包成 GIF 动画。虽然不是"实时流"，但本质上跟 GIF 流服务器做的事情相同——都是把动态内容编码为 GIF 帧。
```

- [ ] **Step 2: Commit**

```bash
git add "无主之地/GIF不仅仅是一种图片格式——用GIF流做些奇怪的事.org"
git commit -m "blog: 添加终端转 GIF 部分

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 5: 写用途 3 — 实时系统监控

**Files:**
- Modify: `无主之地/GIF不仅仅是一种图片格式——用GIF流做些奇怪的事.org`

- [ ] **Step 1: 追加实时系统监控章节**

在终端转 GIF 部分后面追加以下内容：

```org

* 用途 3：零依赖的实时系统监控仪表盘

回到 GIF 流的话题。既然我们可以用 Python 生成 GIF 帧并通过 HTTP 推送，那就可以做一个 *不需要 WebSocket 、不需要 JavaScript 的实时监控仪表盘* 。

核心思路：每隔一段时间采集系统状态（CPU、内存），用 Python 画一个柱状图，编码为 GIF 帧，通过 =multipart/x-mixed-replace= 推送给浏览器。

#+BEGIN_SRC python :tangle "/sudo::/tmp/gif_monitor.py"
#!/usr/bin/env python3
"""GIF 流系统监控仪表盘 - 纯 GIF，无需 JavaScript"""
from http.server import HTTPServer, BaseHTTPRequestHandler
from io import BytesIO
import psutil
from PIL import Image, ImageDraw, ImageFont

WIDTH, HEIGHT = 400, 200

def get_stats():
    """获取系统状态"""
    return {
        'cpu': psutil.cpu_percent(interval=0),
        'mem': psutil.virtual_memory().percent,
        'disk': psutil.disk_usage('/').percent,
    }

def draw_chart(stats):
    """绘制柱状图"""
    img = Image.new('RGB', (WIDTH, HEIGHT), (20, 20, 20))
    draw = ImageDraw.Draw(img)

    labels = [('CPU', stats['cpu'], (0, 180, 0)),
              ('MEM', stats['mem'], (0, 0, 180)),
              ('DISK', stats['disk'], (180, 0, 0))]

    for i, (label, value, color) in enumerate(labels):
        x = 50 + i * 120
        bar_height = int(value / 100 * 150)
        # 画柱子
        draw.rectangle([x, HEIGHT - 30 - bar_height, x + 60, HEIGHT - 30], fill=color)
        # 画标签
        draw.text((x + 10, HEIGHT - 25), f'{label} {value}%', fill=(200, 200, 200))

    return img

class MonitorHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'multipart/x-mixed-replace; boundary=frame')
        self.send_header('Cache-Control', 'no-cache')
        self.end_headers()

        while True:
            stats = get_stats()
            img = draw_chart(stats)
            buf = BytesIO()
            img.save(buf, format='GIF')
            gif_data = buf.getvalue()

            self.wfile.write(b'--frame\r\n')
            self.wfile.write(b'Content-Type: image/gif\r\n')
            self.wfile.write(f'Content-Length: {len(gif_data)}\r\n'.encode())
            self.wfile.write(b'\r\n')
            self.wfile.write(gif_data)
            self.wfile.write(b'\r\n')
            self.wfile.flush()

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 8080), MonitorHandler)
    print('监控仪表盘: http://0.0.0.0:8080/')
    server.serve_forever()
#+END_SRC

运行后在浏览器中打开，你会看到一个实时更新的柱状图，显示 CPU、内存和磁盘使用率。

这个方案的特点：
- *不需要前端框架* ：没有 React、Vue，甚至没有 JavaScript
- *不需要 WebSocket* ：纯 HTTP 长连接
- *兼容性极强* ：任何能显示 GIF 的浏览器都支持，包括 =w3m= 这类文本浏览器配合图片渲染器
- *但带宽消耗大* ：每秒 10 帧 GIF 的数据量不小，不适合大规模部署
```

- [ ] **Step 2: Commit**

```bash
git add "无主之地/GIF不仅仅是一种图片格式——用GIF流做些奇怪的事.org"
git commit -m "blog: 添加实时系统监控部分

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 6: 写用途 4 + 小结 + 格式检查

**Files:**
- Modify: `无主之地/GIF不仅仅是一种图片格式——用GIF流做些奇怪的事.org`

- [ ] **Step 1: 追加 GIF 隐写术章节**

在系统监控部分后面追加以下内容：

```org

* 用途 4：在 GIF 帧延迟中藏数据

GIF 格式的每一帧都有一个 *延迟时间* （Delay Time），以 1/100 秒为单位。正常情况下这个值是 10（即 100ms），但我们可以用它来编码秘密信息。

比如，延迟 =20= 表示二进制 =1= ，延迟 =10= 表示二进制 =0= ：

#+BEGIN_SRC python :tangle "/sudo::/tmp/gif_stego.py"
#!/usr/bin/env python3
"""在 GIF 帧延迟中隐藏消息"""
from PIL import Image
import random

def encode_message(message, output_path, width=10, height=10):
    """将消息编码到 GIF 帧延迟中"""
    binary = ''.join(format(ord(c), '08b') for c in message)
    binary += '00000000'  # 结束标记

    frames = []
    for bit in binary:
        # 生成随机噪点帧
        pixels = [(random.randint(0, 255),) * 3 for _ in range(width * height)]
        img = Image.new('RGB', (width, height))
        img.putdata(pixels)
        frames.append(img)

    # 保存为 GIF，每帧延迟编码一个 bit
    # 20 = 二进制 1, 10 = 二进制 0（单位：1/100 秒）
    delays = [20 if b == '1' else 10 for b in binary]
    frames[0].save(
        output_path,
        save_all=True,
        append_images=frames[1:],
        duration=delays,
        loop=0,
    )
    print(f'已将 "{message}" 编码到 {output_path}（{len(binary)} 帧）')

def decode_message(gif_path):
    """从 GIF 帧延迟中解码消息"""
    img = Image.open(gif_path)
    binary = ''
    try:
        while True:
            delay = img.info.get('duration', 10)
            binary += '1' if delay >= 20 else '0'
            img.seek(img.tell() + 1)
    except EOFError:
        pass

    message = ''
    for i in range(0, len(binary), 8):
        byte = binary[i:i+8]
        if byte == '00000000':
            break
        message += chr(int(byte, 2))
    return message

if __name__ == '__main__':
    encode_message('Hello GIF!', 'secret.gif')
    decoded = decode_message('secret.gif')
    print(f'从 secret.gif 解码出: "{decoded}"')
#+END_SRC

运行后你会得到一个看起来像随机噪点的 GIF 动画，但帧延迟中隐藏了秘密消息。肉眼完全看不出区别。

当然，这种隐写术很容易被分析——只要检查 GIF 帧的时间间隔分布就能发现异常（正常动画的帧延迟应该是均匀的，而编码后的会出现双峰分布）。但作为一个 *GIF 的奇怪用途* ，它足够有趣了。
```

- [ ] **Step 2: 追加小结**

```org

* 小结

GIF 流是一项"复古"的技术，诞生于上世纪 90 年代。在今天 WebSocket 、WebRTC 、Server-Sent Events 大行其道的时代，它看起来已经过时了。但正是这种简洁性赋予了它独特的价值：

- *零前端依赖* ：不需要 JavaScript，一个 =<img>= 标签就够了
- *极简协议* ：基于 HTTP 长连接 + =multipart/x-mixed-replace= ，实现起来只需要几十行代码
- *广泛兼容* ：几乎所有浏览器都支持，甚至包括一些非主流的浏览方式

从贪吃蛇游戏、终端录制、系统监控到隐写术，GIF 证明了"老技术"也可以玩出新花样。下次当你看到一张 GIF 图片时，也许可以想想：它还能做什么更奇怪的事？

如果你也发现了 GIF 的其他有趣用途，欢迎在评论区分享。
```

- [ ] **Step 3: 格式检查**

检查以下格式问题：
- 所有 =code= 标记前后是否有空格或英文标点（不与中文相邻）
- 所有粗体是否使用单星号 *粗体* 而非 Markdown 的 **粗体**
- src block 头部是否正确：sudo 命令加 `:dir /sudo::`，Python 脚本文件加 `:tangle`，纯展示不加头部
- 文件末尾是否有换行符

- [ ] **Step 4: Final commit**

```bash
git add "无主之地/GIF不仅仅是一种图片格式——用GIF流做些奇怪的事.org"
git commit -m "blog: 完成 GIF 流奇妙用途博文

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```
