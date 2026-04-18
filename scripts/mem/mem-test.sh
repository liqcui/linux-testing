#!/bin/bash
# 内存访问性能测试脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_DIR="$PROJECT_ROOT/tests/mem"
OUTPUT_DIR="$PROJECT_ROOT/results/mem"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$OUTPUT_DIR"

echo "========================================="
echo "内存访问性能测试"
echo "时间: $(date)"
echo "========================================="

# 检查并编译测试程序
cd "$TEST_DIR"

if [ ! -f mem_test ]; then
    echo ""
    echo "[编译] 编译内存测试程序..."
    make
    echo "✓ 编译完成"
fi

echo ""
echo "[1/4] 运行基本内存测试..."
./mem_test > "$OUTPUT_DIR/mem_basic_$TIMESTAMP.txt" 2>&1
echo "✓ 结果保存: $OUTPUT_DIR/mem_basic_$TIMESTAMP.txt"

echo ""
echo "[2/4] 使用 perf mem record 记录内存访问..."
if command -v perf >/dev/null 2>&1; then
    # 检查是否支持 mem 事件
    if perf mem record --help >/dev/null 2>&1; then
        echo "使用 perf mem record 分析..."
        perf mem record -o "$OUTPUT_DIR/perf_$TIMESTAMP.data" \
            ./mem_test > "$OUTPUT_DIR/mem_perf_output_$TIMESTAMP.txt" 2>&1 || true
        echo "✓ 结果保存: $OUTPUT_DIR/perf_$TIMESTAMP.data"

        echo ""
        echo "[3/4] 生成 perf mem report..."
        if [ -f "$OUTPUT_DIR/perf_$TIMESTAMP.data" ]; then
            perf mem report -i "$OUTPUT_DIR/perf_$TIMESTAMP.data" \
                > "$OUTPUT_DIR/mem_report_$TIMESTAMP.txt" 2>&1 || true
            echo "✓ 结果保存: $OUTPUT_DIR/mem_report_$TIMESTAMP.txt"
        fi
    else
        echo "⚠ perf mem 不支持，使用 perf stat 替代..."
        if perf list | grep -q "cache-references"; then
            perf stat -e cache-references,cache-misses,LLC-loads,LLC-load-misses \
                -o "$OUTPUT_DIR/mem_cache_$TIMESTAMP.txt" \
                ./mem_test 2>&1 | tee -a "$OUTPUT_DIR/mem_cache_$TIMESTAMP.txt"
        else
            perf stat -e cpu-clock,task-clock,page-faults \
                -o "$OUTPUT_DIR/mem_cache_$TIMESTAMP.txt" \
                ./mem_test 2>&1 | tee -a "$OUTPUT_DIR/mem_cache_$TIMESTAMP.txt"
        fi
        echo "✓ 结果保存: $OUTPUT_DIR/mem_cache_$TIMESTAMP.txt"
    fi
else
    echo "⚠ perf 未安装，跳过"
fi

echo ""
echo "[4/4] 生成测试报告..."
{
    echo "内存访问性能测试报告"
    echo "===================="
    echo "测试时间: $(date)"
    echo "主机名: $(hostname)"
    echo "内核版本: $(uname -r)"
    echo ""

    echo "## 系统信息"
    echo ""
    echo "### CPU"
    lscpu | grep -E "Model name|CPU\(s\)|Thread|Core|Cache" || true
    echo ""

    echo "### 内存"
    free -h || true
    echo ""

    echo "## 基本测试结果"
    echo ""
    if [ -f "$OUTPUT_DIR/mem_basic_$TIMESTAMP.txt" ]; then
        cat "$OUTPUT_DIR/mem_basic_$TIMESTAMP.txt"
    fi
    echo ""

    echo "## Perf Mem Report"
    echo ""
    if [ -f "$OUTPUT_DIR/mem_report_$TIMESTAMP.txt" ]; then
        cat "$OUTPUT_DIR/mem_report_$TIMESTAMP.txt"
    elif [ -f "$OUTPUT_DIR/mem_cache_$TIMESTAMP.txt" ]; then
        echo "使用缓存统计数据:"
        cat "$OUTPUT_DIR/mem_cache_$TIMESTAMP.txt"
    else
        echo "perf mem 分析不可用"
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
