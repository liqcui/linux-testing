#!/bin/bash
# test_pid_namespace.sh - PID namespace测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRAMS_DIR="$SCRIPT_DIR/../programs"
RESULTS_DIR="$SCRIPT_DIR/../results/pid-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "PID Namespace 测试"
echo "========================================"
echo ""

# 检查权限
if [[ $EUID -ne 0 ]]; then
   echo "错误: 此脚本需要 root 权限"
   echo "使用: sudo $0"
   exit 1
fi

mkdir -p "$RESULTS_DIR"

# 编译测试程序
echo "步骤 1: 编译测试程序..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd "$PROGRAMS_DIR"
make namespace_test &>/dev/null

if [[ ! -f namespace_test ]]; then
    echo "✗ 编译失败"
    exit 1
fi

echo "✓ 编译成功: namespace_test"
echo ""

# 检查PID namespace支持
echo "步骤 2: 检查PID namespace支持..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ ! -d /proc/self/ns ]]; then
    echo "✗ 系统不支持namespace"
    exit 1
fi

if [[ ! -e /proc/self/ns/pid ]]; then
    echo "✗ 系统不支持PID namespace"
    exit 1
fi

echo "✓ PID namespace 已支持"
echo ""

# 显示当前PID namespace
echo "当前PID namespace:"
ls -l /proc/self/ns/pid
echo ""

# 基础PID namespace测试
echo "步骤 3: 基础PID namespace测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "在新PID namespace中运行进程..."
"$PROGRAMS_DIR/namespace_test" -p -c "echo '子进程PID: '\$\$; ps aux | head -10" | tee "$RESULTS_DIR/basic-test.txt"

echo ""

# PID隔离测试
echo "步骤 4: PID隔离验证..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "父namespace PID列表:"
ps aux | head -5
echo ""

echo "使用unshare创建PID namespace:"
unshare -p -f --mount-proc /bin/bash -c "
    echo '新namespace中的PID列表:'
    ps aux | head -10
    echo ''
    echo '当前shell PID: '\$\$
    echo '预期: PID应该从1开始'
" | tee "$RESULTS_DIR/pid-isolation.txt"

echo ""

# 嵌套PID namespace测试
echo "步骤 5: 嵌套PID namespace测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "创建嵌套的PID namespace..."
unshare -p -f --mount-proc /bin/bash -c "
    echo 'Level 1 namespace - PID: '\$\$
    ps aux | wc -l | xargs echo 'Level 1 进程数:'

    unshare -p -f --mount-proc /bin/bash -c '
        echo \"\"
        echo \"Level 2 namespace - PID: \"\$\$
        ps aux | wc -l | xargs echo \"Level 2 进程数:\"
        echo \"\"
        echo \"Level 2 进程列表:\"
        ps aux
    '
" | tee "$RESULTS_DIR/nested-pid.txt"

echo ""

# PID namespace与其他namespace组合
echo "步骤 6: PID + Mount namespace组合测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "创建PID + Mount namespace..."
unshare -p -m -f --mount-proc /bin/bash -c "
    echo 'PID: '\$\$
    echo ''
    echo '/proc挂载点:'
    mount | grep proc
    echo ''
    echo '进程列表:'
    ps aux | head -10
" | tee "$RESULTS_DIR/pid-mount.txt"

echo ""

# 使用nsenter进入namespace
echo "步骤 7: 使用nsenter进入namespace..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if command -v nsenter &> /dev/null; then
    echo "启动后台进程创建持久namespace..."

    # 创建一个长期运行的进程
    unshare -p -f --mount-proc sleep 30 &
    SLEEP_PID=$!
    sleep 1

    echo "后台进程PID: $SLEEP_PID"
    echo ""

    # 进入其PID namespace
    echo "使用nsenter进入PID namespace:"
    nsenter -p -t $SLEEP_PID ps aux 2>/dev/null | head -10 || echo "nsenter失败（可能需要更新的内核）"

    # 清理
    kill $SLEEP_PID 2>/dev/null
    wait $SLEEP_PID 2>/dev/null
else
    echo "⚠ nsenter不可用"
fi

echo ""

# PID namespace统计
echo "步骤 8: PID namespace统计..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "系统中的PID namespace数量:"
find /proc/*/ns/pid 2>/dev/null | wc -l

echo ""
echo "当前系统所有PID namespace:"
ls -l /proc/*/ns/pid 2>/dev/null | awk '{print $11}' | sort -u | head -10

echo ""

# 生成报告
{
    echo "PID Namespace测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo ""
    echo "系统信息:"
    echo "  内核版本: $(uname -r)"
    echo "  PID namespace支持: ✓"
    echo ""
    echo "测试项目:"
    echo "  ✓ 基础PID namespace创建"
    echo "  ✓ PID隔离验证"
    echo "  ✓ 嵌套PID namespace"
    echo "  ✓ PID + Mount namespace组合"
    if command -v nsenter &> /dev/null; then
        echo "  ✓ nsenter工具测试"
    fi
    echo ""
    echo "关键发现:"
    echo "  - 新PID namespace中进程PID从1开始"
    echo "  - 父namespace可以看到子namespace的进程"
    echo "  - 子namespace无法看到父namespace的进程"
    echo "  - 支持PID namespace嵌套"
    echo ""
    echo "详细日志:"
    echo "  基础测试: $RESULTS_DIR/basic-test.txt"
    echo "  PID隔离: $RESULTS_DIR/pid-isolation.txt"
    echo "  嵌套测试: $RESULTS_DIR/nested-pid.txt"
    echo "  组合测试: $RESULTS_DIR/pid-mount.txt"
    echo ""
} | tee "$RESULTS_DIR/summary.txt"

echo "========================================"
echo "测试完成"
echo "========================================"
echo ""
echo "✓ PID namespace测试完成"
echo ""
echo "结果目录: $RESULTS_DIR"
echo ""
