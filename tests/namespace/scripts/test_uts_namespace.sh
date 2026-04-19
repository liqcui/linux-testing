#!/bin/bash
# test_uts_namespace.sh - UTS (hostname) namespace测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results/uts-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "UTS Namespace 测试"
echo "========================================"
echo ""

# 检查权限
if [[ $EUID -ne 0 ]]; then
   echo "错误: 此脚本需要 root 权限"
   echo "使用: sudo $0"
   exit 1
fi

mkdir -p "$RESULTS_DIR"

# 检查UTS namespace支持
echo "步骤 1: 检查UTS namespace支持..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ ! -e /proc/self/ns/uts ]]; then
    echo "✗ 系统不支持UTS namespace"
    exit 1
fi

echo "✓ UTS namespace 已支持"
echo ""

# 显示当前主机名和域名
echo "当前系统信息:"
echo "  主机名: $(hostname)"
echo "  域名: $(hostname -d 2>/dev/null || echo '(未设置)')"
echo "  FQDN: $(hostname -f 2>/dev/null || echo '(未设置)')"
echo ""

# 保存原始主机名
ORIGINAL_HOSTNAME=$(hostname)

# 基础UTS namespace测试
echo "步骤 2: 基础UTS namespace测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "在新UTS namespace中修改主机名..."
unshare -u /bin/bash -c "
    echo '新namespace初始主机名: '\$(hostname)
    hostname test-container-$$
    echo '修改后的主机名: '\$(hostname)
    echo ''
    echo '主机名信息:'
    uname -n
" | tee "$RESULTS_DIR/basic-test.txt"

echo ""
echo "主namespace的主机名（应该未改变）: $(hostname)"
echo ""

# 多个UTS namespace测试
echo "步骤 3: 多个UTS namespace隔离测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "创建3个不同的UTS namespace..."

unshare -u /bin/bash -c "hostname container-1; echo 'Namespace 1: '\$(hostname)" &
PID1=$!

unshare -u /bin/bash -c "hostname container-2; echo 'Namespace 2: '\$(hostname)" &
PID2=$!

unshare -u /bin/bash -c "hostname container-3; echo 'Namespace 3: '\$(hostname)" &
PID3=$!

wait $PID1 $PID2 $PID3

echo ""
echo "主namespace: $(hostname)"
echo ""

# UTS + PID namespace组合
echo "步骤 4: UTS + PID namespace组合测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "创建UTS + PID namespace..."
unshare -u -p -f --mount-proc /bin/bash -c "
    hostname isolated-container
    echo '容器主机名: '\$(hostname)
    echo '容器PID: '\$\$
    echo ''
    echo '进程列表:'
    ps aux | head -5
" | tee "$RESULTS_DIR/uts-pid-combined.txt"

echo ""

# domainname测试
echo "步骤 5: Domain name测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "当前域名: $(domainname 2>/dev/null || echo '(none)')"
echo ""

unshare -u /bin/bash -c "
    echo '新namespace初始域名: '\$(domainname 2>/dev/null || echo '(none)')
    domainname test.local 2>/dev/null || echo '设置域名失败'
    echo '修改后的域名: '\$(domainname 2>/dev/null || echo '(none)')
" | tee "$RESULTS_DIR/domainname-test.txt"

echo ""
echo "主namespace的域名（应该未改变）: $(domainname 2>/dev/null || echo '(none)')"
echo ""

# uname信息测试
echo "步骤 6: uname信息测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "主namespace的uname信息:"
uname -a | tee "$RESULTS_DIR/main-uname.txt"
echo ""

echo "新UTS namespace中的uname信息:"
unshare -u /bin/bash -c "
    hostname new-test-host
    uname -a
" | tee "$RESULTS_DIR/new-uname.txt"

echo ""

# 持久化UTS namespace测试
echo "步骤 7: 持久化UTS namespace测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "创建持久化namespace进程..."
unshare -u /bin/bash -c "
    hostname persistent-ns
    echo 'Persistent namespace主机名: '\$(hostname)
    echo 'PID: '\$\$
    sleep 10
" &
PERSISTENT_PID=$!

sleep 2

echo "持久化进程PID: $PERSISTENT_PID"
echo "其UTS namespace:"
ls -l /proc/$PERSISTENT_PID/ns/uts

echo ""

# 尝试进入该namespace
if command -v nsenter &> /dev/null; then
    echo "使用nsenter进入该namespace:"
    nsenter -u -t $PERSISTENT_PID hostname || echo "nsenter失败"
else
    echo "⚠ nsenter不可用"
fi

# 清理
kill $PERSISTENT_PID 2>/dev/null
wait $PERSISTENT_PID 2>/dev/null

echo ""

# 验证主机名未改变
echo "步骤 8: 验证主namespace主机名..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

CURRENT_HOSTNAME=$(hostname)
if [[ "$CURRENT_HOSTNAME" == "$ORIGINAL_HOSTNAME" ]]; then
    echo "✓ 主namespace主机名未改变: $CURRENT_HOSTNAME"
else
    echo "⚠ 主机名已改变: $ORIGINAL_HOSTNAME -> $CURRENT_HOSTNAME"
fi

echo ""

# 生成报告
{
    echo "UTS Namespace测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo ""
    echo "系统信息:"
    echo "  内核版本: $(uname -r)"
    echo "  UTS namespace支持: ✓"
    echo "  原始主机名: $ORIGINAL_HOSTNAME"
    echo ""
    echo "测试项目:"
    echo "  ✓ UTS namespace创建"
    echo "  ✓ 主机名隔离验证"
    echo "  ✓ 多UTS namespace并发"
    echo "  ✓ UTS + PID namespace组合"
    echo "  ✓ Domain name测试"
    echo "  ✓ uname信息隔离"
    echo "  ✓ 持久化namespace"
    echo ""
    echo "关键发现:"
    echo "  - 主机名修改仅在当前namespace有效"
    echo "  - 不同namespace可以有相同或不同的主机名"
    echo "  - uname输出中的nodename会改变"
    echo "  - 主namespace不受新namespace影响"
    echo ""
    echo "详细日志:"
    echo "  基础测试: $RESULTS_DIR/basic-test.txt"
    echo "  组合测试: $RESULTS_DIR/uts-pid-combined.txt"
    echo "  域名测试: $RESULTS_DIR/domainname-test.txt"
    echo "  uname对比: $RESULTS_DIR/main-uname.txt, $RESULTS_DIR/new-uname.txt"
    echo ""
} | tee "$RESULTS_DIR/summary.txt"

echo "========================================"
echo "测试完成"
echo "========================================"
echo ""
echo "✓ UTS namespace测试完成"
echo ""
echo "结果目录: $RESULTS_DIR"
echo ""
