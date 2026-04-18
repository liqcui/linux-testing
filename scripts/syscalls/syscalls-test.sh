#!/bin/bash
# 系统调用性能测试脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_DIR="$PROJECT_ROOT/tests/syscalls"
OUTPUT_DIR="$PROJECT_ROOT/results/syscalls"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$OUTPUT_DIR"

echo "========================================="
echo "系统调用性能测试"
echo "时间: $(date)"
echo "========================================="

# 检查并编译测试程序
cd "$TEST_DIR"

if [ ! -f syscalls_test ]; then
    echo ""
    echo "[编译] 编译系统调用测试程序..."
    make
    echo "✓ 编译完成"
fi

echo ""
echo "[1/4] 运行基本系统调用测试..."
./syscalls_test > "$OUTPUT_DIR/syscalls_basic_$TIMESTAMP.txt" 2>&1
echo "✓ 结果保存: $OUTPUT_DIR/syscalls_basic_$TIMESTAMP.txt"

echo ""
echo "[2/4] 使用 perf stat 分析性能..."
if command -v perf >/dev/null 2>&1; then
    perf stat -e cycles -e instructions -e cache-misses -e context-switches \
        -o "$OUTPUT_DIR/syscalls_perf_$TIMESTAMP.txt" \
        ./syscalls_test 2>&1 | tee -a "$OUTPUT_DIR/syscalls_perf_$TIMESTAMP.txt"
    echo "✓ 结果保存: $OUTPUT_DIR/syscalls_perf_$TIMESTAMP.txt"
else
    echo "⚠ perf 未安装，跳过"
fi

echo ""
echo "[3/4] 使用 strace 统计系统调用..."
if command -v strace >/dev/null 2>&1; then
    strace -c -o "$OUTPUT_DIR/syscalls_strace_$TIMESTAMP.txt" ./syscalls_test 2>&1
    echo "✓ 结果保存: $OUTPUT_DIR/syscalls_strace_$TIMESTAMP.txt"
else
    echo "⚠ strace 未安装，跳过"
fi

echo ""
echo "[4/4] 生成测试报告..."
{
    echo "系统调用性能测试报告"
    echo "===================="
    echo "测试时间: $(date)"
    echo "主机名: $(hostname)"
    echo "内核版本: $(uname -r)"
    echo ""

    echo "## 系统信息"
    echo ""
    echo "### CPU"
    lscpu | grep -E "Model name|CPU\(s\)|Thread|Core" || true
    echo ""

    echo "## 基本测试结果"
    echo ""
    if [ -f "$OUTPUT_DIR/syscalls_basic_$TIMESTAMP.txt" ]; then
        cat "$OUTPUT_DIR/syscalls_basic_$TIMESTAMP.txt"
    fi
    echo ""

    echo "## Perf 统计"
    echo ""
    if [ -f "$OUTPUT_DIR/syscalls_perf_$TIMESTAMP.txt" ]; then
        grep -A 20 "Performance counter stats" "$OUTPUT_DIR/syscalls_perf_$TIMESTAMP.txt" || true
    fi
    echo ""

    echo "## Strace 统计"
    echo ""
    if [ -f "$OUTPUT_DIR/syscalls_strace_$TIMESTAMP.txt" ]; then
        cat "$OUTPUT_DIR/syscalls_strace_$TIMESTAMP.txt"
    fi

} > "$OUTPUT_DIR/report_$TIMESTAMP.txt"

echo "✓ 报告保存: $OUTPUT_DIR/report_$TIMESTAMP.txt"

echo ""
echo "========================================="
echo "测试完成！"
echo "========================================="
echo "结果位置: $OUTPUT_DIR"
echo ""
echo "查看报告:"
echo "  cat $OUTPUT_DIR/report_$TIMESTAMP.txt"
echo ""
