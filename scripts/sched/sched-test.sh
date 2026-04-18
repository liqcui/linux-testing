#!/bin/bash
# 进程调度性能测试脚本

set -e

OUTPUT_DIR="./results/sched"
mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DURATION=10
CPU_COUNT=$(nproc)

echo "========================================="
echo "进程调度性能测试"
echo "时间: $(date)"
echo "CPU 核心数: $CPU_COUNT"
echo "测试时长: ${DURATION}s"
echo "========================================="

# 1. 空闲系统调度延迟
echo ""
echo "[1/5] 测试空闲系统调度延迟..."
perf sched record -a -o "$OUTPUT_DIR/sched_idle_$TIMESTAMP.data" sleep $DURATION 2>&1
perf sched latency -i "$OUTPUT_DIR/sched_idle_$TIMESTAMP.data" > "$OUTPUT_DIR/sched_idle_latency_$TIMESTAMP.txt"
echo "✓ 结果保存到: $OUTPUT_DIR/sched_idle_latency_$TIMESTAMP.txt"

# 2. 高负载调度延迟
echo ""
echo "[2/5] 测试高负载调度延迟（启动 $CPU_COUNT 个 CPU 密集型任务）..."
if command -v stress-ng >/dev/null 2>&1; then
    perf sched record -a -o "$OUTPUT_DIR/sched_stress_$TIMESTAMP.data" \
        stress-ng --cpu $CPU_COUNT --timeout ${DURATION}s 2>&1
    perf sched latency -i "$OUTPUT_DIR/sched_stress_$TIMESTAMP.data" > "$OUTPUT_DIR/sched_stress_latency_$TIMESTAMP.txt"
    echo "✓ 结果保存到: $OUTPUT_DIR/sched_stress_latency_$TIMESTAMP.txt"
else
    echo "⚠ stress-ng 未安装，跳过高负载测试"
    echo "  安装命令: sudo yum install stress-ng 或 sudo apt install stress-ng"
fi

# 3. 调度时间线分析
echo ""
echo "[3/5] 生成调度时间线..."
if [ -f "$OUTPUT_DIR/sched_stress_$TIMESTAMP.data" ]; then
    perf sched timehist -i "$OUTPUT_DIR/sched_stress_$TIMESTAMP.data" > "$OUTPUT_DIR/sched_timehist_$TIMESTAMP.txt"
    echo "✓ 结果保存到: $OUTPUT_DIR/sched_timehist_$TIMESTAMP.txt"
else
    echo "⚠ 跳过（需要先运行高负载测试）"
fi

# 4. CPU 调度映射
echo ""
echo "[4/5] 生成 CPU 调度映射..."
if [ -f "$OUTPUT_DIR/sched_stress_$TIMESTAMP.data" ]; then
    perf sched map -i "$OUTPUT_DIR/sched_stress_$TIMESTAMP.data" > "$OUTPUT_DIR/sched_map_$TIMESTAMP.txt"
    echo "✓ 结果保存到: $OUTPUT_DIR/sched_map_$TIMESTAMP.txt"
else
    echo "⚠ 跳过（需要先运行高负载测试）"
fi

# 5. 生成报告
echo ""
echo "[5/5] 生成测试报告..."
{
    echo "进程调度性能测试报告"
    echo "===================="
    echo "测试时间: $(date)"
    echo "主机名: $(hostname)"
    echo "CPU 核心数: $CPU_COUNT"
    echo "测试时长: ${DURATION}s"
    echo ""

    echo "## 系统信息"
    echo ""
    lscpu | grep -E "Model name|CPU\(s\)|Thread|Core"
    echo ""

    echo "## 空闲系统调度延迟"
    echo ""
    if [ -f "$OUTPUT_DIR/sched_idle_latency_$TIMESTAMP.txt" ]; then
        head -20 "$OUTPUT_DIR/sched_idle_latency_$TIMESTAMP.txt" | tail -10
    fi
    echo ""

    echo "## 高负载调度延迟"
    echo ""
    if [ -f "$OUTPUT_DIR/sched_stress_latency_$TIMESTAMP.txt" ]; then
        head -20 "$OUTPUT_DIR/sched_stress_latency_$TIMESTAMP.txt" | tail -10
    fi
    echo ""

    echo "## 性能总结"
    echo ""
    if [ -f "$OUTPUT_DIR/sched_stress_latency_$TIMESTAMP.txt" ]; then
        echo "最大调度延迟:"
        grep -E "stress-ng|TOTAL" "$OUTPUT_DIR/sched_stress_latency_$TIMESTAMP.txt" | head -5
    fi

} > "$OUTPUT_DIR/report_$TIMESTAMP.txt"

echo "✓ 报告保存到: $OUTPUT_DIR/report_$TIMESTAMP.txt"
echo ""
echo "========================================="
echo "测试完成！"
echo "所有结果保存在: $OUTPUT_DIR"
echo "========================================="

# 清理 perf 数据文件（可选）
# rm -f "$OUTPUT_DIR"/*.data
