#!/bin/bash
# 锁性能测试脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_DIR="$PROJECT_ROOT/tests/lock"
OUTPUT_DIR="$PROJECT_ROOT/results/lock"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$OUTPUT_DIR"

echo "========================================="
echo "锁性能和竞争测试"
echo "时间: $(date)"
echo "========================================="

# 检查并编译测试程序
cd "$TEST_DIR"

if [ ! -f lock_test ]; then
    echo ""
    echo "[编译] 编译锁测试程序..."
    make
    echo "✓ 编译完成"
fi

echo ""
echo "[1/4] 运行基本锁测试..."
./lock_test > "$OUTPUT_DIR/lock_basic_$TIMESTAMP.txt" 2>&1
echo "✓ 结果保存: $OUTPUT_DIR/lock_basic_$TIMESTAMP.txt"

echo ""
echo "[2/4] 使用 perf lock record 记录锁事件..."
if command -v perf >/dev/null 2>&1; then
    # 检查是否支持 lock 事件
    if perf list | grep -q "lock:"; then
        echo "使用 perf lock record 分析..."
        perf lock record -o "$OUTPUT_DIR/perf_$TIMESTAMP.data" \
            ./lock_test > "$OUTPUT_DIR/lock_perf_output_$TIMESTAMP.txt" 2>&1 || true
        echo "✓ 结果保存: $OUTPUT_DIR/perf_$TIMESTAMP.data"

        echo ""
        echo "[3/4] 生成 perf lock report..."
        if [ -f "$OUTPUT_DIR/perf_$TIMESTAMP.data" ]; then
            perf lock report -i "$OUTPUT_DIR/perf_$TIMESTAMP.data" \
                > "$OUTPUT_DIR/lock_report_$TIMESTAMP.txt" 2>&1 || true
            echo "✓ 结果保存: $OUTPUT_DIR/lock_report_$TIMESTAMP.txt"
        fi
    else
        echo "⚠ 内核不支持 lock 事件跟踪，跳过"
        echo "  提示: 内核需要 CONFIG_LOCK_STAT=y 支持"
    fi
else
    echo "⚠ perf 未安装，跳过"
fi

echo ""
echo "[4/4] 生成测试报告..."
{
    echo "锁性能测试报告"
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
    if [ -f "$OUTPUT_DIR/lock_basic_$TIMESTAMP.txt" ]; then
        cat "$OUTPUT_DIR/lock_basic_$TIMESTAMP.txt"
    fi
    echo ""

    echo "## Perf Lock Report"
    echo ""
    if [ -f "$OUTPUT_DIR/lock_report_$TIMESTAMP.txt" ]; then
        cat "$OUTPUT_DIR/lock_report_$TIMESTAMP.txt"
    else
        echo "perf lock 分析不可用"
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
