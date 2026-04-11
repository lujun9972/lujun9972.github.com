# GitHub Action 博客自动构建设计

## 目标

在现有 GitHub Action workflow 中增加博客自动构建功能，使用 EGO（Emacs + Git + Org-mode）将 .org 源文件转换为静态 HTML 并推送到 master 分支。保留 CSDN/头条同步功能，但其失败不影响 Action 整体状态。

## 现状

- **source 分支**：存放 .org 博客源文件
- **master 分支**：存放 EGO 生成的静态 HTML
- **auto_publish.el**：本机执行的 Emacs 脚本，包含 EGO 构建 + CSDN/头条同步
- **现有 GitHub Action**：仅有 Habitica 打卡功能
- **EGO 仓库**：`https://github.com/lujun9972/EGO`，master 分支

## 设计

### Workflow 结构

在现有 `github-action.yml` 中新增 `Build-Blog` Job，与 `Finish-Habitica-Tasks` 并行运行。触发条件改为仅监听 source 分支的 push。

```yaml
name: 提交 habitica 任务 + 构建博客
on:
  push:
    branches: [source]
jobs:
  Finish-Habitica-Tasks:
    # 现有内容不变
  Build-Blog:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout 博客源文件
      - name: Checkout EGO
      - name: 安装 Emacs 和系统依赖
      - name: 执行 auto_publish.el
      - name: 推送 HTML 到 master 分支
```

### Step 详细说明

#### 1. Checkout 博客源文件
- `actions/checkout@v4`，checkout 本仓库 source 分支
- `fetch-depth: 0`（全量历史，EGO 增量构建需要 git log）

#### 2. Checkout EGO
- `actions/checkout@v4`，checkout `lujun9972/EGO` 仓库
- path: `EGO`（放在子目录中）

#### 3. 安装 Emacs 和系统依赖
- 安装 `emacs` 包（ubuntu-latest 默认可用）
- Emacs 包（mustache, htmlize, yaml-mode 等）由 `auto_publish.el` 中的 `package-install` 自动处理

#### 4. 执行 auto_publish.el
- 调用方式：`emacs --batch -l auto_publish.el`
- 需要设置环境变量让 `auto_publish.el` 中的路径适配 CI 环境

**auto_publish.el 需要的改动：**

将硬编码路径改为环境变量，并提供默认值保持本机兼容：

```emacs-lisp
;; 路径配置：优先读环境变量，未设置则用默认值
(setq ego-load-path (or (getenv "EGO_DIR") "~/EGO/"))
(setq csdn-load-path (or (getenv "CSDN_DIR") "~/csdn-publish/"))
(setq toutiao-load-path (or (getenv "TOUTIAO_DIR") "~/toutiao/"))
(setq repo-dir (or (getenv "REPO_DIR") "~/source"))
(setq store-dir (or (getenv "STORE_DIR") "~/web"))
```

**CSDN/头条容错处理：**

在 CSDN 和头条发布代码外包裹 `condition-case`，失败时仅打印警告不中断：

```emacs-lisp
(condition-case err
    (csdn-publish-articles publish-org-files)
  (error (message "CSDN 发布失败: %s" (error-message-string err))))
```

#### 5. 推送 HTML 到 master 分支
- 进入 store-dir 目录
- `git init` → `git add -A` → `git commit` → `git push` 到 origin master 分支
- 使用 `${{ secrets.GITHUB_TOKEN }}` 认证

### 环境变量

在 Job 级别设置以下环境变量：

| 变量 | CI 值 | 说明 |
|------|-------|------|
| `EGO_DIR` | `${{ github.workspace }}/EGO` | EGO 仓库路径 |
| `REPO_DIR` | `${{ github.workspace }}` | 博客源文件路径 |
| `STORE_DIR` | `${{ github.workspace }}/web` | HTML 输出路径 |
| `REPO` | 博客仓库 URL | 用于 source-browse-url 配置 |
| `GITHUB_TOKEN` | `${{ secrets.GITHUB_TOKEN }}` | 推送 master 分支用 |

### 权限

```yaml
permissions:
  contents: write  # 需要推送 master 分支
```

### 错误处理策略

| 步骤 | 失败影响 |
|------|----------|
| EGO 构建 | Action 失败 |
| CSDN 发布 | 仅警告，Action 继续 |
| 头条发布 | 仅警告，Action 继续 |
| 推送 master | Action 失败 |
| Habitica 打卡 | 不影响 Build-Blog（并行 Job） |

### 不在范围内

- 不修改现有的博客主题或 EGO 配置
- 不新增 CSDN/头条的 API 密钥管理（密钥需用户自行配置到 GitHub Secrets）
- 不修改 `generate_index.sh`（README 生成仍由现有逻辑处理）
