#!/bin/bash
# adaptive_stress_rt_test.sh - 动态压力调节实时性测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/../results/adaptive_rt_$(date +%Y%m%d_%H%M%S)"

mkdir -p "$OUTPUT_DIR"

CPU_CORES=$(nproc)

# 前置检查
if [[ $EUID -ne 0 ]]; then
   echo "错误: 此脚本需要 root 权限"
   echo "使用: sudo $0"
   exit 1
fi

echo "=========================================="
echo "动态压力调节实时性测试"
echo "=========================================="
echo ""
echo "配置:"
echo "  CPU 核心: $CPU_CORES"
echo "  压力级别: 10%, 25%, 50%, 75%, 90%, 100%"
echo "  输出目录: $OUTPUT_DIR"
echo "=========================================="
echo ""

# 检查工具
if ! command -v stress-ng &> /dev/null; then
    echo "错误: stress-ng 未安装"
    echo "安装: sudo apt-get install stress-ng"
    exit 1
fi

if ! command -v cyclictest &> /dev/null; then
    echo "错误: cyclictest 未安装"
    echo "安装: sudo apt-get install rt-tests"
    exit 1
fi

# 动态调节函数
adjust_stress() {
    local target_latency=$1  # 目标延迟阈值(μs)
    local current_latency=$2

    if [ "$current_latency" -lt "$target_latency" ]; then
        # 增加压力
        echo "  分析: ${current_latency}μs < ${target_latency}μs，可继续增加压力"
        return 1
    else
        # 减少压力
        echo "  分析: ${current_latency}μs >= ${target_latency}μs，接近系统极限"
        return 0
    fi
}

# ========== 阶梯式压力测试 ==========
echo "=========================================="
echo "阶梯式CPU压力递增测试"
echo "=========================================="
echo ""

# 初始化数据文件
echo "# Load% MaxLat(μs) AvgLat(μs) MinLat(μs)" > "$OUTPUT_DIR/latency_curve.txt"

LOAD_LEVELS=(10 25 50 75 90 100)

for load in "${LOAD_LEVELS[@]}"; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "压力级别: ${load}%"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # 启动压力
    echo "启动 stress-ng --cpu $CPU_CORES --cpu-load $load ..."
    stress-ng --cpu $CPU_CORES --cpu-load $load \
        --timeout 70s \
        --metrics \
        --quiet \
        > "$OUTPUT_DIR/stress_load_${load}.log" 2>&1 &
    STRESS_PID=$!
    echo "  stress-ng PID: $STRESS_PID"

    sleep 5  # 压力稳定期

    # 运行cyclictest (60秒)
    echo "运行 cyclictest (60秒)..."
    cyclictest -m -S -p 99 -i 1000 -n -l 60000 \
        -q -h 10000 \
        --histfile "$OUTPUT_DIR/load_${load}.hist" \
        2>&1 | tee "$OUTPUT_DIR/load_${load}.log"

    # 提取关键指标
    max_lat=$(grep "Max Latencies:" "$OUTPUT_DIR/load_${load}.log" | awk '{print $3}' | head -1)
    avg_lat=$(grep "Avg Latencies:" "$OUTPUT_DIR/load_${load}.log" | awk '{print $3}' | head -1)
    min_lat=$(grep "Min Latencies:" "$OUTPUT_DIR/load_${load}.log" | awk '{print $3}' | head -1)

    echo ""
    echo "✓ 测试完成"
    echo "  Load ${load}%: Min=${min_lat}μs, Avg=${avg_lat}μs, Max=${max_lat}μs"

    # 保存数据点
    echo "$load $max_lat $avg_lat $min_lat" >> "$OUTPUT_DIR/latency_curve.txt"

    # 停止压力
    kill $STRESS_PID 2>/dev/null
    wait $STRESS_PID 2>/dev/null

    # 性能评估
    if [ -n "$max_lat" ]; then
        if [ "$max_lat" -lt 50 ]; then
            echo "  评级: ★★★★★ 优秀"
        elif [ "$max_lat" -lt 100 ]; then
            echo "  评级: ★★★★☆ 良好"
        elif [ "$max_lat" -lt 500 ]; then
            echo "  评级: ★★★☆☆ 一般"
        elif [ "$max_lat" -lt 1000 ]; then
            echo "  评级: ★★☆☆☆ 较差"
        else
            echo "  评级: ★☆☆☆☆ 很差"
        fi

        # 检查是否达到系统极限
        adjust_stress 1000 $max_lat
        if [ $? -eq 0 ]; then
            echo ""
            echo "⚠ 延迟超过1ms，系统接近实时性能极限"
            echo "  建议停止进一步增加压力"
            # 不中断，继续测试以获取完整曲线
        fi
    fi

    echo ""
    sleep 5
done

# ========== 不同CPU方法对比测试 ==========
echo "=========================================="
echo "不同CPU算法压力对比测试"
echo "=========================================="
echo ""

CPU_METHODS=("ackermann" "fft" "matrixprod" "correlate" "trig")

echo "# Method MaxLat(μs) AvgLat(μs)" > "$OUTPUT_DIR/method_comparison.txt"

for method in "${CPU_METHODS[@]}"; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "CPU方法: $method"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    echo "启动 stress-ng --cpu $CPU_CORES --cpu-method $method ..."
    stress-ng --cpu $CPU_CORES \
        --cpu-method $method \
        --timeout 70s \
        --metrics \
        --quiet \
        > "$OUTPUT_DIR/stress_method_${method}.log" 2>&1 &
    STRESS_PID=$!

    sleep 5

    echo "运行 cyclictest (60秒)..."
    cyclictest -m -S -p 99 -i 1000 -n -l 60000 \
        -q -h 10000 \
        --histfile "$OUTPUT_DIR/method_${method}.hist" \
        2>&1 | tee "$OUTPUT_DIR/method_${method}.log"

    max_lat=$(grep "Max Latencies:" "$OUTPUT_DIR/method_${method}.log" | awk '{print $3}' | head -1)
    avg_lat=$(grep "Avg Latencies:" "$OUTPUT_DIR/method_${method}.log" | awk '{print $3}' | head -1)

    echo ""
    echo "✓ $method 测试完成"
    echo "  结果: Avg=${avg_lat}μs, Max=${max_lat}μs"
    echo ""

    echo "$method $max_lat $avg_lat" >> "$OUTPUT_DIR/method_comparison.txt"

    kill $STRESS_PID 2>/dev/null
    wait $STRESS_PID 2>/dev/null

    sleep 5
done

# ========== 生成压力-延迟曲线分析 ==========
echo "=========================================="
echo "生成分析报告和可视化"
echo "=========================================="
echo ""

{
    echo "动态压力调节实时性测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo "系统: $(hostname) - $(uname -r)"
    echo "CPU 核心: $CPU_CORES"
    echo ""

    echo "一、阶梯式压力测试结果"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    printf "%-15s %15s %15s %15s   %s\n" "CPU负载" "最小延迟(μs)" "平均延迟(μs)" "最大延迟(μs)" "性能评级"
    echo "────────────────────────────────────────────────────────────────────"

    while read -r line; do
        # 跳过注释行
        if [[ "$line" =~ ^# ]]; then
            continue
        fi

        read -r load max avg min <<< "$line"

        # 评级
        if [ "$max" -lt 50 ]; then
            rating="★★★★★ 优秀"
        elif [ "$max" -lt 100 ]; then
            rating="★★★★☆ 良好"
        elif [ "$max" -lt 500 ]; then
            rating="★★★☆☆ 一般"
        elif [ "$max" -lt 1000 ]; then
            rating="★★☆☆☆ 较差"
        else
            rating="★☆☆☆☆ 很差"
        fi

        printf "%-15s %15s %15s %15s   %s\n" "${load}%" "$min" "$avg" "$max" "$rating"
    done < "$OUTPUT_DIR/latency_curve.txt"

    echo ""

    echo "二、CPU算法影响对比"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    printf "%-20s %15s %15s\n" "CPU方法" "平均延迟(μs)" "最大延迟(μs)"
    echo "────────────────────────────────────────────────────────────"

    while read -r line; do
        if [[ "$line" =~ ^# ]]; then
            continue
        fi

        read -r method max avg <<< "$line"
        printf "%-20s %15s %15s\n" "$method" "$avg" "$max"
    done < "$OUTPUT_DIR/method_comparison.txt"

    echo ""

    echo "三、关键发现"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # 分析压力-延迟关系
    LOAD_10=$(awk 'NR==2 {print $2}' "$OUTPUT_DIR/latency_curve.txt")
    LOAD_100=$(awk 'NR==7 {print $2}' "$OUTPUT_DIR/latency_curve.txt")

    if [ -n "$LOAD_10" ] && [ -n "$LOAD_100" ]; then
        INCREASE=$((LOAD_100 - LOAD_10))
        RATIO=$(echo "scale=2; $LOAD_100 / $LOAD_10" | bc)

        echo "• 压力-延迟线性度分析:"
        echo "  10%负载延迟: ${LOAD_10}μs"
        echo "  100%负载延迟: ${LOAD_100}μs"
        echo "  延迟增长: +${INCREASE}μs (${RATIO}倍)"
        echo ""

        if (( $(echo "$RATIO < 2" | bc -l) )); then
            echo "  结论: ★★★★★ 延迟增长缓慢，实时性能优秀"
            echo "  系统在高负载下仍能保持良好实时性"
        elif (( $(echo "$RATIO < 5" | bc -l) )); then
            echo "  结论: ★★★★☆ 延迟增长适中，实时性能良好"
            echo "  系统在中等负载下表现稳定"
        else
            echo "  结论: ★★☆☆☆ 延迟增长较快，需要优化"
            echo "  建议: 配置CPU隔离或使用PREEMPT_RT内核"
        fi
        echo ""
    fi

    # 找出最差和最优的CPU方法
    WORST_METHOD=""
    WORST_MAX=0
    BEST_METHOD=""
    BEST_MAX=999999

    while read -r line; do
        if [[ "$line" =~ ^# ]]; then
            continue
        fi

        read -r method max avg <<< "$line"

        if [ "$max" -gt "$WORST_MAX" ]; then
            WORST_MAX=$max
            WORST_METHOD=$method
        fi

        if [ "$max" -lt "$BEST_MAX" ]; then
            BEST_MAX=$max
            BEST_METHOD=$method
        fi
    done < "$OUTPUT_DIR/method_comparison.txt"

    if [ -n "$WORST_METHOD" ] && [ -n "$BEST_METHOD" ]; then
        echo "• CPU算法影响分析:"
        echo "  最优算法: $BEST_METHOD (${BEST_MAX}μs)"
        echo "  最差算法: $WORST_METHOD (${WORST_MAX}μs)"
        DIFF=$((WORST_MAX - BEST_MAX))
        echo "  差异: ${DIFF}μs"
        echo ""
        echo "  结论: 不同CPU密集型算法对实时性的影响存在差异"
        echo "       FFT、矩阵运算等密集型算法通常产生更高延迟"
        echo ""
    fi

    echo "四、优化建议"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [ -n "$LOAD_100" ] && [ "$LOAD_100" -gt 200 ]; then
        echo "• 系统整体实时性能需要改进:"
        echo "  1. 安装PREEMPT_RT实时内核"
        echo "  2. 配置CPU隔离:"
        echo "     编辑 /etc/default/grub"
        echo "     GRUB_CMDLINE_LINUX=\"isolcpus=2,3 nohz_full=2,3 rcu_nocbs=2,3\""
        echo "  3. 禁用CPU频率调节:"
        echo "     cpupower frequency-set -g performance"
        echo "  4. 设置中断亲和性，避免干扰实时核心"
        echo ""
    fi

    if (( $(echo "$RATIO > 3" | bc -l) )); then
        echo "• 高负载下延迟增长过快:"
        echo "  1. 考虑使用专用CPU核心运行实时任务"
        echo "  2. 减少非实时任务的CPU使用"
        echo "  3. 优化调度器参数"
        echo ""
    fi

    echo "• 负载均衡建议:"
    echo "  - 如果应用允许，保持CPU负载在50%以下"
    echo "  - 为实时任务预留专用CPU核心"
    echo "  - 使用cgroup限制非实时任务的CPU使用"
    echo ""

} | tee "$OUTPUT_DIR/adaptive_report.txt"

# ========== 生成可视化图表 ==========

if command -v gnuplot &> /dev/null; then
    echo "生成可视化图表..."

    # 压力-延迟曲线图
    gnuplot << EOF
set terminal svg enhanced size 1000,700 font "Arial,12"
set output '$OUTPUT_DIR/latency_curve.svg'

set title "CPU Load vs Latency" font ",16"
set xlabel "CPU Load (%)" font ",14"
set ylabel "Latency (μs)" font ",14"

set grid
set key top left

set xrange [0:105]
set yrange [0:*]

# 参考线
set arrow from 0,50 to 100,50 nohead dt 2 lc rgb "gray" lw 1
set arrow from 0,100 to 100,100 nohead dt 2 lc rgb "gray" lw 1
set label "50μs (硬实时)" at 5,55 font ",10"
set label "100μs (软实时)" at 5,105 font ",10"

plot '$OUTPUT_DIR/latency_curve.txt' using 1:2 with linespoints lw 2 pt 7 ps 1.5 lc rgb "#e74c3c" title "Max Latency", \
     '' using 1:3 with linespoints lw 2 pt 7 ps 1.5 lc rgb "#3498db" title "Avg Latency", \
     '' using 1:4 with linespoints lw 2 pt 7 ps 1.5 lc rgb "#2ecc71" title "Min Latency"
EOF

    echo "✓ 压力-延迟曲线图: $OUTPUT_DIR/latency_curve.svg"

    # CPU方法对比柱状图
    gnuplot << EOF
set terminal svg enhanced size 1000,700 font "Arial,12"
set output '$OUTPUT_DIR/method_comparison.svg'

set title "CPU Method Impact on Latency" font ",16"
set xlabel "CPU Method" font ",14"
set ylabel "Latency (μs)" font ",14"

set style data histogram
set style histogram cluster gap 1
set style fill solid 0.6 border -1
set boxwidth 0.9

set grid y

set xtics rotate by -45

plot '$OUTPUT_DIR/method_comparison.txt' using 3:xtic(1) title "Avg Latency" lc rgb "#3498db", \
     '' using 2 title "Max Latency" lc rgb "#e74c3c"
EOF

    echo "✓ CPU方法对比图: $OUTPUT_DIR/method_comparison.svg"
    echo ""
else
    echo "⚠ gnuplot 未安装，跳过图表生成"
    echo "  安装: sudo apt-get install gnuplot"
    echo ""
fi

echo "=========================================="
echo "测试完成！"
echo "=========================================="
echo ""
echo "结果保存至: $OUTPUT_DIR"
echo ""
echo "文件列表:"
ls -lh "$OUTPUT_DIR"/*.log "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.svg 2>/dev/null
echo ""
echo "查看报告:"
echo "  cat $OUTPUT_DIR/adaptive_report.txt"
echo ""
echo "查看图表:"
if [ -f "$OUTPUT_DIR/latency_curve.svg" ]; then
    echo "  open $OUTPUT_DIR/latency_curve.svg"
    echo "  open $OUTPUT_DIR/method_comparison.svg"
fi
echo ""
