#!/bin/bash
# run_quick_test.sh - 运行 LTP 快速测试（约 30 分钟）

set -e

LTP_DIR="${LTP_DIR:-/opt/ltp}"
RESULTS_DIR="./ltp-quick-results-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "LTP 快速测试"
echo "========================================"
echo ""

# 检查 LTP 是否已安装
if [[ ! -x "$LTP_DIR/runltp" ]]; then
    echo "错误: LTP 未安装在 $LTP_DIR"
    echo ""
    echo "请先安装 LTP:"
    echo "  sudo ./install_ltp.sh"
    exit 1
fi

# 检查权限
if [[ $EUID -ne 0 ]]; then
   echo "此脚本需要 root 权限"
   echo "请使用: sudo $0"
   exit 1
fi

mkdir -p "$RESULTS_DIR"

echo "配置:"
echo "  LTP 路径:     $LTP_DIR"
echo "  结果目录:     $RESULTS_DIR"
echo "  开始时间:     $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

cd "$LTP_DIR"

# 创建快速测试场景
SCENARIO_FILE="$RESULTS_DIR/quick-scenario"

cat > "$SCENARIO_FILE" << 'EOF'
# 快速测试场景（约 30 分钟）
# 核心系统功能验证

# 系统调用基础测试
syscalls

# 内存管理
mm

# 进程调度
sched

# IPC
ipc
EOF

echo "测试场景:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat "$SCENARIO_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 运行测试
echo "开始运行测试..."
echo ""

./runltp \
    -f "$SCENARIO_FILE" \
    -l "$RESULTS_DIR/test.log" \
    -o "$RESULTS_DIR/output.log" \
    -p

# 分析结果
echo ""
echo "========================================"
echo "测试完成"
echo "========================================"
echo ""
echo "结束时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 统计结果
if [[ -f "$RESULTS_DIR/output.log" ]]; then
    TOTAL=$(grep -c "<<<test" "$RESULTS_DIR/output.log" || echo 0)
    PASS=$(grep -c "PASS" "$RESULTS_DIR/output.log" || echo 0)
    FAIL=$(grep -c "FAIL" "$RESULTS_DIR/output.log" || echo 0)
    CONF=$(grep -c "CONF" "$RESULTS_DIR/output.log" || echo 0)
    BROK=$(grep -c "BROK" "$RESULTS_DIR/output.log" || echo 0)

    echo "测试结果统计:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  总测试数:     $TOTAL"
    echo "  通过 (PASS):  $PASS"
    echo "  失败 (FAIL):  $FAIL"
    echo "  配置 (CONF):  $CONF"
    echo "  中断 (BROK):  $BROK"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [[ $FAIL -gt 0 ]]; then
        echo "失败的测试:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        grep "FAIL" "$RESULTS_DIR/output.log" | head -20
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "详细信息请查看: $RESULTS_DIR/output.log"
    fi
fi

echo "结果文件:"
echo "  主日志:   $RESULTS_DIR/test.log"
echo "  详细输出: $RESULTS_DIR/output.log"
echo ""

# 生成摘要
{
    echo "LTP 快速测试摘要"
    echo "========================================"
    echo ""
    echo "测试时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "系统信息:"
    echo "  主机名:   $(hostname)"
    echo "  内核:     $(uname -r)"
    echo "  架构:     $(uname -m)"
    echo "  CPU:      $(nproc) 核心"
    echo ""
    echo "测试统计:"
    echo "  总数:     $TOTAL"
    echo "  通过:     $PASS"
    echo "  失败:     $FAIL"
    echo "  配置:     $CONF"
    echo "  中断:     $BROK"
    echo ""
} > "$RESULTS_DIR/summary.txt"

cat "$RESULTS_DIR/summary.txt"

# 退出状态
if [[ $FAIL -gt 0 ]]; then
    exit 1
else
    exit 0
fi
