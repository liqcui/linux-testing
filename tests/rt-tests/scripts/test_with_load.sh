#!/bin/bash
# test_with_load.sh - 带系统负载的实时性测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results/with-load-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "带负载的实时性测试"
echo "========================================"
echo ""

# 检查工具
if ! command -v cyclictest &> /dev/null; then
    echo "错误: cyclictest 未安装"
    exit 1
fi

if ! command -v stress-ng &> /dev/null; then
    echo "错误: stress-ng 未安装"
    echo "安装: sudo apt-get install stress-ng"
    exit 1
fi

# 检查权限
if [[ $EUID -ne 0 ]]; then
   echo "错误: 此脚本需要 root 权限"
   echo "使用: sudo $0"
   exit 1
fi

mkdir -p "$RESULTS_DIR"

CPU_COUNT=$(nproc)

echo "测试配置:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  CPU 核心:   $CPU_COUNT"
echo "  测试时长:   300 秒（每阶段）"
echo "  结果目录:   $RESULTS_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 阶段 1: 无负载基准测试
echo "阶段 1: 无负载基准测试（300秒）"
echo "================================"
echo ""
echo "建立性能基准..."
echo ""

cyclictest -m -a -p 99 -t $CPU_COUNT -i 1000 -n -q -D 300s \
    > "$RESULTS_DIR/baseline-no-load.log" 2>&1

echo "✓ 无负载测试完成"
echo ""

# 提取基准数据
BASELINE_MAX=$(grep "Max:" "$RESULTS_DIR/baseline-no-load.log" | awk '{print $9}' | sort -n | tail -1)
BASELINE_AVG=$(grep "Avg:" "$RESULTS_DIR/baseline-no-load.log" | awk '{sum+=$7; count++} END {print int(sum/count)}')

echo "基准结果:"
echo "  平均延迟: ${BASELINE_AVG}μs"
echo "  最大延迟: ${BASELINE_MAX}μs"
echo ""

sleep 10

# 阶段 2: CPU 负载测试
echo "阶段 2: CPU 密集负载测试（300秒）"
echo "================================="
echo ""
echo "启动 CPU 负载: stress-ng --cpu $CPU_COUNT"
echo ""

stress-ng --cpu $CPU_COUNT --timeout 310s &
STRESS_PID=$!

sleep 5

cyclictest -m -a -p 99 -t $CPU_COUNT -i 1000 -n -q -D 300s \
    > "$RESULTS_DIR/with-cpu-load.log" 2>&1

wait $STRESS_PID 2>/dev/null

echo "✓ CPU 负载测试完成"
echo ""

CPU_MAX=$(grep "Max:" "$RESULTS_DIR/with-cpu-load.log" | awk '{print $9}' | sort -n | tail -1)
CPU_AVG=$(grep "Avg:" "$RESULTS_DIR/with-cpu-load.log" | awk '{sum+=$7; count++} END {print int(sum/count)}')

echo "CPU 负载结果:"
echo "  平均延迟: ${CPU_AVG}μs (基准: ${BASELINE_AVG}μs)"
echo "  最大延迟: ${CPU_MAX}μs (基准: ${BASELINE_MAX}μs)"
echo ""

sleep 10

# 阶段 3: I/O 负载测试
echo "阶段 3: I/O 密集负载测试（300秒）"
echo "================================="
echo ""
echo "启动 I/O 负载: stress-ng --io 4 --hdd 2"
echo ""

stress-ng --io 4 --hdd 2 --temp-path /tmp --timeout 310s &
STRESS_PID=$!

sleep 5

cyclictest -m -a -p 99 -t $CPU_COUNT -i 1000 -n -q -D 300s \
    > "$RESULTS_DIR/with-io-load.log" 2>&1

wait $STRESS_PID 2>/dev/null

echo "✓ I/O 负载测试完成"
echo ""

IO_MAX=$(grep "Max:" "$RESULTS_DIR/with-io-load.log" | awk '{print $9}' | sort -n | tail -1)
IO_AVG=$(grep "Avg:" "$RESULTS_DIR/with-io-load.log" | awk '{sum+=$7; count++} END {print int(sum/count)}')

echo "I/O 负载结果:"
echo "  平均延迟: ${IO_AVG}μs (基准: ${BASELINE_AVG}μs)"
echo "  最大延迟: ${IO_MAX}μs (基准: ${BASELINE_MAX}μs)"
echo ""

sleep 10

# 阶段 4: 内存负载测试
echo "阶段 4: 内存密集负载测试（300秒）"
echo "================================="
echo ""
echo "启动内存负载: stress-ng --vm 2 --vm-bytes 512M"
echo ""

stress-ng --vm 2 --vm-bytes 512M --timeout 310s &
STRESS_PID=$!

sleep 5

cyclictest -m -a -p 99 -t $CPU_COUNT -i 1000 -n -q -D 300s \
    > "$RESULTS_DIR/with-memory-load.log" 2>&1

wait $STRESS_PID 2>/dev/null

echo "✓ 内存负载测试完成"
echo ""

MEM_MAX=$(grep "Max:" "$RESULTS_DIR/with-memory-load.log" | awk '{print $9}' | sort -n | tail -1)
MEM_AVG=$(grep "Avg:" "$RESULTS_DIR/with-memory-load.log" | awk '{sum+=$7; count++} END {print int(sum/count)}')

echo "内存负载结果:"
echo "  平均延迟: ${MEM_AVG}μs (基准: ${BASELINE_AVG}μs)"
echo "  最大延迟: ${MEM_MAX}μs (基准: ${BASELINE_MAX}μs)"
echo ""

sleep 10

# 阶段 5: 综合负载测试
echo "阶段 5: 综合负载测试（300秒）"
echo "============================="
echo ""
echo "启动综合负载: CPU + I/O + 内存"
echo ""

stress-ng --cpu $CPU_COUNT --io 2 --vm 2 --vm-bytes 256M --timeout 310s &
STRESS_PID=$!

sleep 5

cyclictest -m -a -p 99 -t $CPU_COUNT -i 1000 -n -q -D 300s \
    > "$RESULTS_DIR/with-combined-load.log" 2>&1

wait $STRESS_PID 2>/dev/null

echo "✓ 综合负载测试完成"
echo ""

COMB_MAX=$(grep "Max:" "$RESULTS_DIR/with-combined-load.log" | awk '{print $9}' | sort -n | tail -1)
COMB_AVG=$(grep "Avg:" "$RESULTS_DIR/with-combined-load.log" | awk '{sum+=$7; count++} END {print int(sum/count)}')

echo "综合负载结果:"
echo "  平均延迟: ${COMB_AVG}μs (基准: ${BASELINE_AVG}μs)"
echo "  最大延迟: ${COMB_MAX}μs (基准: ${BASELINE_MAX}μs)"
echo ""

# 生成对比报告
echo "========================================"
echo "测试完成 - 结果对比"
echo "========================================"
echo ""

{
    echo "带负载的实时性测试报告"
    echo "========================================"
    echo ""
    echo "测试日期: $(date)"
    echo "系统: $(hostname) - $(uname -r)"
    echo "CPU 核心: $CPU_COUNT"
    echo ""
    echo "测试结果对比（最大延迟）:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "%-20s %12s %12s %12s\n" "测试场景" "平均(μs)" "最大(μs)" "相对增加"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    printf "%-20s %12s %12s %12s\n" "无负载（基准）" "$BASELINE_AVG" "$BASELINE_MAX" "-"

    if [[ -n "$CPU_MAX" ]]; then
        increase=$((CPU_MAX - BASELINE_MAX))
        printf "%-20s %12s %12s %12s\n" "CPU 负载" "$CPU_AVG" "$CPU_MAX" "+${increase}μs"
    fi

    if [[ -n "$IO_MAX" ]]; then
        increase=$((IO_MAX - BASELINE_MAX))
        printf "%-20s %12s %12s %12s\n" "I/O 负载" "$IO_AVG" "$IO_MAX" "+${increase}μs"
    fi

    if [[ -n "$MEM_MAX" ]]; then
        increase=$((MEM_MAX - BASELINE_MAX))
        printf "%-20s %12s %12s %12s\n" "内存负载" "$MEM_AVG" "$MEM_MAX" "+${increase}μs"
    fi

    if [[ -n "$COMB_MAX" ]]; then
        increase=$((COMB_MAX - BASELINE_MAX))
        printf "%-20s %12s %12s %12s\n" "综合负载" "$COMB_AVG" "$COMB_MAX" "+${increase}μs"
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "分析:"
    echo ""

    # 最差情况
    worst_max=$BASELINE_MAX
    worst_scenario="无负载"

    for scenario in "CPU:$CPU_MAX" "I/O:$IO_MAX" "内存:$MEM_MAX" "综合:$COMB_MAX"; do
        IFS=':' read -r name value <<< "$scenario"
        if [[ -n "$value" ]] && [[ $value -gt $worst_max ]]; then
            worst_max=$value
            worst_scenario="$name 负载"
        fi
    done

    echo "• 最差延迟场景: $worst_scenario (${worst_max}μs)"

    # 评估稳定性
    increase_percent=$(( (worst_max - BASELINE_MAX) * 100 / BASELINE_MAX ))

    if [[ $increase_percent -lt 50 ]]; then
        echo "• 实时性能: ★★★ 优秀（负载增加 < 50%）"
        echo "  系统在高负载下仍保持良好实时性"
    elif [[ $increase_percent -lt 100 ]]; then
        echo "• 实时性能: ★★☆ 良好（负载增加 < 100%）"
        echo "  系统实时性受负载影响适中"
    else
        echo "• 实时性能: ★☆☆ 需优化（负载增加 >= 100%）"
        echo "  系统实时性受负载影响较大"
    fi

    echo ""
    echo "建议:"

    if [[ $CPU_MAX -gt $((BASELINE_MAX * 2)) ]]; then
        echo "  • CPU 负载影响显著，考虑 CPU 隔离"
    fi

    if [[ $IO_MAX -gt $((BASELINE_MAX * 2)) ]]; then
        echo "  • I/O 负载影响显著，考虑使用独立磁盘"
    fi

    if [[ $MEM_MAX -gt $((BASELINE_MAX * 2)) ]]; then
        echo "  • 内存负载影响显著，确保内存充足"
    fi

    if [[ $worst_max -gt 200 ]]; then
        echo "  • 最大延迟超过 200μs，建议优化系统配置"
        echo "  • 考虑使用 PREEMPT_RT 内核"
        echo "  • 设置 CPU 隔离和中断亲和性"
    fi

} | tee "$RESULTS_DIR/comparison-report.txt"

echo ""
echo "详细日志保存在: $RESULTS_DIR"
echo ""
echo "文件列表:"
ls -lh "$RESULTS_DIR"/*.log
echo ""
