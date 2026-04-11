# GitHub Action 博客自动构建 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 GitHub Action 中使用 EGO 自动构建博客 HTML 并推送到 master 分支。

**Architecture:** 在现有 `github-action.yml` 中新增 `Build-Blog` Job。修改 `auto_publish.el` 使路径可配置且 CSDN/头条发布容错。CI 环境中 checkout source 分支 + master 分支（作为 store-dir），执行 EGO 增量构建后推送 master。

**Tech Stack:** GitHub Actions, Emacs, EGO (Emacs static site generator), Git

---

### Task 1: 改造 auto_publish.el — 路径可配置化

**Files:**
- Modify: `auto_publish.el:1-30`

将 `auto_publish.el` 中的硬编码路径（EGO、csdn-publish、toutiao 的 load-path，以及 ego-project-config-alist 中的 repository-directory 和 store-dir）改为从环境变量读取，保留默认值确保本机使用不受影响。

- [ ] **Step 1: 修改 load-path 配置**

将 `auto_publish.el` 前 30 行中的硬编码路径替换为环境变量读取。把：

```emacs-lisp
(setq load-path (cons  "~/EGO/" load-path))
(setq load-path (cons  "~/csdn-publish/" load-path))
(setq load-path (cons  "~/toutiao/" load-path))
```

改为：

```emacs-lisp
(setq load-path (cons  (or (getenv "EGO_DIR") "~/EGO/") load-path))
(setq load-path (cons  (or (getenv "CSDN_DIR") "~/csdn-publish/") load-path))
(setq load-path (cons  (or (getenv "TOUTIAO_DIR") "~/toutiao/") load-path))
```

- [ ] **Step 2: 修改 ego-project-config-alist 中的路径**

将：

```emacs-lisp
`(("blog" :repository-directory "~/source" :site-domain "https://lujun9972.github.io/" ... :store-dir "~/web")))
```

改为：

```emacs-lisp
`(("blog" :repository-directory ,(or (getenv "REPO_DIR") "~/source") :site-domain "https://lujun9972.github.io/" ... :store-dir ,(or (getenv "STORE_DIR") "~/web")))
```

- [ ] **Step 3: 验证本机兼容性**

确认修改后的 `auto_publish.el` 在不设置任何环境变量时行为与原来一致（所有路径回退到原来的默认值）。

- [ ] **Step 4: Commit**

```bash
git add auto_publish.el
git commit -m "refactor: auto_publish.el 路径改为从环境变量读取，兼容 CI 环境"
```

---

### Task 2: 改造 auto_publish.el — CSDN/头条容错

**Files:**
- Modify: `auto_publish.el:79-108`

用 `condition-case` 包裹 CSDN 和头条的发布逻辑，使其失败时仅打印警告不中断整个脚本。

- [ ] **Step 1: 包裹 CSDN 发布代码**

将 `auto_publish.el` 中的 CSDN 发布部分（约第 86-92 行）：

```emacs-lisp
  (when publish-org-files
    (csdn-publish-articles publish-org-files)))
```

改为：

```emacs-lisp
  (when publish-org-files
    (condition-case err
        (csdn-publish-articles publish-org-files)
      (error (message "WARNING: CSDN 发布失败: %s" (error-message-string err))))))
```

- [ ] **Step 2: 包裹头条 hook 注册和发布**

将头条发布 hook（约第 93-105 行）：

```emacs-lisp
(defun post-to-toutiao (attr-plist)
  (let ((uri (concat "https://www.lujun9972.win" (plist-get attr-plist :uri)))
        (title (plist-get attr-plist :title))
        (category  "杂说乱炖")
        (toutiao-request-sync t))
    (when (string= (plist-get attr-plist :category) "Emacs之怒")
      (setq category "Emacs之怒"))
    (when (string= (plist-get attr-plist :category)  "英文必须死")
      (setq category "有趣即是正义"))
    (message "toutiao DEBUG[%s][%s][%s]" uri title category)
    (toutiao-post uri title category)))
(add-hook 'ego-post-publish-hooks #'post-to-toutiao)
```

改为：

```emacs-lisp
(defun post-to-toutiao (attr-plist)
  (condition-case err
      (let ((uri (concat "https://www.lujun9972.win" (plist-get attr-plist :uri)))
            (title (plist-get attr-plist :title))
            (category  "杂说乱炖")
            (toutiao-request-sync t))
        (when (string= (plist-get attr-plist :category) "Emacs之怒")
          (setq category "Emacs之怒"))
        (when (string= (plist-get attr-plist :category)  "英文必须死")
          (setq category "有趣即是正义"))
        (message "toutiao DEBUG[%s][%s][%s]" uri title category)
        (toutiao-post uri title category))
    (error (message "WARNING: 头条发布失败: %s" (error-message-string err)))))
(add-hook 'ego-post-publish-hooks #'post-to-toutiao)
```

- [ ] **Step 3: Commit**

```bash
git add auto_publish.el
git commit -m "refactor: CSDN 和头条发布添加容错，失败不中断构建"
```

---

### Task 3: 修改 GitHub Action workflow — 新增 Build-Blog Job

**Files:**
- Modify: `.github/workflows/github-action.yml`

在现有 workflow 文件中：更新触发条件、添加 permissions、新增 `Build-Blog` Job。

- [ ] **Step 1: 更新 workflow 名称和触发条件**

将文件头部：

```yaml
name: 提交 habitica 任务
on: [push]
```

改为：

```yaml
name: 提交 habitica 任务 + 构建博客
on:
  push:
    branches: [source]
```

- [ ] **Step 2: 添加顶层 permissions**

在 `on:` 和 `jobs:` 之间插入：

```yaml
permissions:
  contents: write
```

- [ ] **Step 3: 在 Finish-Habitica-Tasks Job 后新增 Build-Blog Job**

在文件末尾追加：

```yaml
  Build-Blog:
    runs-on: ubuntu-latest
    env:
      EGO_DIR: ${{ github.workspace }}/EGO
      REPO_DIR: ${{ github.workspace }}
      STORE_DIR: ${{ github.workspace }}/web
      REPO: https://github.com/lujun9972/${{ github.event.repository.name }}
    steps:
      - name: Checkout 博客源文件
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          ref: source

      - name: Checkout EGO
        uses: actions/checkout@v4
        with:
          repository: lujun9972/EGO
          path: EGO

      - name: Checkout master 分支到 store-dir
        run: |
          git clone --branch master --single-branch \
            https://x-access-token:${{ secrets.GITHUB_TOKEN }}@github.com/${{ github.repository }}.git \
            "$STORE_DIR"

      - name: 安装 Emacs 和系统依赖
        run: sudo apt-get update && sudo apt-get install -y emacs-nox

      - name: 执行 auto_publish.el 构建博客
        run: emacs --batch -l auto_publish.el

      - name: 推送 HTML 到 master 分支
        run: |
          cd "$STORE_DIR"
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add -A
          git diff --staged --quiet || git commit -m "auto publish: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
          git push origin master
```

关键设计决策：
- **Checkout master 到 store-dir**：EGO 增量构建需要读取上次发布的时间戳（存在 master 分支的 git log 中），所以必须先 clone master 到 `STORE_DIR`
- **`emacs-nox`**：无 GUI 的 Emacs，CI 环境够用且安装快
- **推送用 `GITHUB_TOKEN`**：Actions 内置 token，无需额外配置

- [ ] **Step 4: 验证 YAML 语法**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/github-action.yml'))"
```

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/github-action.yml
git commit -m "feat: 新增 Build-Blog Job，使用 EGO 自动构建博客并推送到 master"
```

---

### Task 4: 端到端测试

**Files:** 无新文件

Push 到 source 分支后验证 Action 是否正常运行。

- [ ] **Step 1: 推送所有更改并触发 Action**

```bash
git push origin source
```

- [ ] **Step 2: 检查 Action 运行结果**

```bash
gh run list --limit 1
gh run view
```

预期：
- `Finish-Habitica-Tasks` Job 成功（Habitica 打卡）
- `Build-Blog` Job 成功（EGO 构建 + master 分支更新）
- 如果 CSDN/头条 API 未配置，应看到 WARNING 日志但 Job 不失败

- [ ] **Step 3: 验证 master 分支内容**

```bash
git log origin/master --oneline -3
```

确认 master 分支有新的 commit 且包含更新后的 HTML 文件。
