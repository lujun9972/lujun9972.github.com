#!/bin/bash
# SonarQube 静态代码分析验证脚本
# 用途：在本地用 Docker 启动 SonarQube，扫描真实 Java 项目，展示结果
# 依赖：docker, curl, unzip
# 用法：./sonarqube-verify.sh [项目路径]

set -e

# ── 全局变量 ──
SQ_CONTAINER=sonarqube-verify
SQ_IMAGE=sonarqube:lts-community
SQ_PORT=9000
SQ_URL="http://localhost:${SQ_PORT}"
SQ_ADMIN_PASSWORD=sonar2026
SCANNER_VERSION=6.2.1.4610
SCANNER_DIR=/tmp/sonar-scanner-${SCANNER_VERSION}-linux-x64
TOKEN=""

# 扫描目标（可通过命令行参数覆盖）
PROJECT_DIR="${1:-$HOME/github/mobileorg-android}"
PROJECT_KEY=mobileorg-android
PROJECT_NAME="MobileOrg Android"
SRC_DIR="${PROJECT_DIR}/MobileOrg/src/main/java"

# 空目录——SonarQube 不编译也能扫描
EMPTY_BINARIES=/tmp/empty-binaries

# ── 颜色 ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ── 清理函数 ──
cleanup() {
    info "清理资源..."
    docker stop  ${SQ_CONTAINER} 2>/dev/null || true
    docker rm -f ${SQ_CONTAINER} 2>/dev/null || true
    rm -rf "${EMPTY_BINARIES}"
    info "清理完成"
}
trap cleanup EXIT

# ════════════════════════════════════════════════════════════
# Step 1: 检查前置条件
# ════════════════════════════════════════════════════════════
info "Step 1/6: 检查前置条件"

if [ ! -d "${PROJECT_DIR}" ]; then
    error "项目目录不存在: ${PROJECT_DIR}"
    exit 1
fi

if [ ! -d "${SRC_DIR}" ]; then
    error "源码目录不存在: ${SRC_DIR} (请确认项目结构)"
    exit 1
fi

JAVA_FILE_COUNT=$(find "${SRC_DIR}" -name '*.java' | wc -l)
JAVA_LINE_COUNT=$(find "${SRC_DIR}" -name '*.java' -exec cat {} + | wc -l)
info "扫描目标: ${PROJECT_DIR}"
info "Java 文件: ${JAVA_FILE_COUNT} 个，共 ${JAVA_LINE_COUNT} 行"

# 准备空 binaries 目录（不编译，SonarQube 仍然能扫描文本规则）
mkdir -p "${EMPTY_BINARIES}"
info "binaries 目录: ${EMPTY_BINARIES} (空——不编译，只跑文本级规则)"

# ════════════════════════════════════════════════════════════
# Step 2: 启动 SonarQube Server
# ════════════════════════════════════════════════════════════
info "Step 2/6: 启动 SonarQube Server (Docker)"

if ! docker images "${SQ_IMAGE}" --format '{{.Repository}}:{{.Tag}}' | grep -q .; then
    info "拉取 SonarQube 镜像..."
    docker pull "${SQ_IMAGE}"
fi

docker rm -f ${SQ_CONTAINER} 2>/dev/null || true

docker run -d --name ${SQ_CONTAINER} -p ${SQ_PORT}:${SQ_PORT} "${SQ_IMAGE}"
info "容器已启动，等待服务就绪..."

for i in $(seq 1 60); do
    status=$(curl -s -u admin:admin "${SQ_URL}/api/system/status" 2>/dev/null \
        | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null || true)
    if [ "$status" = "UP" ]; then
        info "SonarQube 就绪 (耗时约 $((i*5)) 秒)"
        break
    fi
    if [ $i -eq 60 ]; then
        error "SonarQube 启动超时"
        exit 1
    fi
    sleep 5
done

# ════════════════════════════════════════════════════════════
# Step 3: 准备 sonar-scanner
# ════════════════════════════════════════════════════════════
info "Step 3/6: 准备 sonar-scanner"

if [ ! -f "${SCANNER_DIR}/bin/sonar-scanner" ]; then
    info "下载 sonar-scanner..."
    curl -sL "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SCANNER_VERSION}-linux-x64.zip" \
        -o /tmp/sonar-scanner.zip
    unzip -qo /tmp/sonar-scanner.zip -d /tmp/
fi
info "sonar-scanner 就绪: ${SCANNER_DIR}/bin/sonar-scanner"

# ════════════════════════════════════════════════════════════
# Step 4: 生成访问 Token
# ════════════════════════════════════════════════════════════
info "Step 4/6: 生成 SonarQube 访问 Token"

TOKEN=$(curl -s -u admin:admin -X POST \
    "${SQ_URL}/api/user_tokens/generate" \
    -d "name=verify-$(date +%s)" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])" 2>/dev/null)

if [ -z "$TOKEN" ]; then
    error "Token 生成失败"
    exit 1
fi
info "Token: ${TOKEN:0:12}..."

# ════════════════════════════════════════════════════════════
# Step 5: 运行扫描（不编译）
# ════════════════════════════════════════════════════════════
info "Step 5/6: 运行 SonarQube 扫描"

cd "${PROJECT_DIR}"

# 关键：sonar.java.binaries 指向空目录，Scanner 跳过类型解析
# 但仍会跑所有文本级规则（包括 java:S2068 等安全规则）
"${SCANNER_DIR}/bin/sonar-scanner" \
    -Dsonar.projectKey="${PROJECT_KEY}" \
    -D"sonar.projectName=${PROJECT_NAME}" \
    -Dsonar.sources="${SRC_DIR}" \
    -Dsonar.java.binaries="${EMPTY_BINARIES}" \
    -Dsonar.host.url="${SQ_URL}" \
    -Dsonar.login="${TOKEN}"

info "扫描完成"

# ════════════════════════════════════════════════════════════
# Step 6: 展示结果
# ════════════════════════════════════════════════════════════
info "Step 6/6: 拉取并展示扫描结果"

sleep 8

echo ""
echo "╔════════════════════════════════════╗"
echo "║       Dashboard 指标摘要           ║"
echo "╚════════════════════════════════════╝"
curl -s -u admin:admin \
    "${SQ_URL}/api/measures/component?component=${PROJECT_KEY}&metricKeys=bugs,vulnerabilities,code_smells,security_hotspots,ncloc,files" \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
measures = data.get('component', {}).get('measures', [])
labels = {
    'bugs':'Bug', 'vulnerabilities':'漏洞', 'code_smells':'Code Smell',
    'security_hotspots':'安全热点', 'ncloc':'代码行数', 'files':'文件数'
}
for m in measures:
    name = labels.get(m['metric'], m['metric'])
    print(f'  {name}: {m[\"value\"]}')"

echo ""
echo "╔════════════════════════════════════╗"
echo "║       检测到的具体问题              ║"
echo "╚════════════════════════════════════╝"
curl -s -u admin:admin \
    "${SQ_URL}/api/issues/search?componentKeys=${PROJECT_KEY}&ps=10" \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(f'  总问题数: {data[\"total\"]}')
print()
for issue in data.get('issues', []):
    t = {'BUG':'Bug','VULNERABILITY':'漏洞',
         'CODE_SMELL':'Code Smell','SECURITY_HOTSPOT':'安全热点'}.get(issue['type'], issue['type'])
    s = {'BLOCKER':'阻塞','CRITICAL':'严重','MAJOR':'主要','MINOR':'次要','INFO':'信息'}.get(issue['severity'], issue['severity'])
    print(f'  [{t}] [{s}] {issue.get(\"rule\", \"?\")}')
    print(f'    文件: {issue[\"component\"].split(\":\")[-1]}')
    print(f'    消息: {issue.get(\"message\", \"?\")[:120]}')
    print()"

echo ""
echo "╔════════════════════════════════════╗"
echo "║       安全热点 (待人工审核)          ║"
echo "╚════════════════════════════════════╝"
curl -s -u admin:admin \
    "${SQ_URL}/api/hotspots/search?projectKey=${PROJECT_KEY}&ps=10" \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
hotspots = data.get('hotspots', [])
if not hotspots:
    print('  (无)')
else:
    for h in hotspots:
        print(f'  规则: {h.get(\"ruleKey\", \"?\")}')
        print(f'  消息: {h.get(\"message\", \"?\")[:120]}')
        print(f'  文件: {h.get(\"component\", \"?\").split(\":\")[-1]}')
        print(f'  状态: {h.get(\"status\", \"?\")} → 需人工判定')
        print()

echo ''
info "验证完成！Dashboard 地址: ${SQ_URL}/dashboard?id=${PROJECT_KEY}"
info "按 Enter 清理资源并退出..."
read -r
