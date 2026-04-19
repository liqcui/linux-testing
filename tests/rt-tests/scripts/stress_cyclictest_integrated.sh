#!/bin/bash
# stress_cyclictest_integrated.sh - 压力+实时性综合测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/../results/stress_rt_test_$(date +%Y%m%d_%H%M%S)"

mkdir -p "$OUTPUT_DIR"

DURATION=300  # 5分钟测试
CPU_CORES=$(nproc)

# 前置检查
if [[ $EUID -ne 0 ]]; then
   echo "错误: 此脚本需要 root 权限"
   echo "使用: sudo $0"
   exit 1
fi

echo "=========================================="
echo "Stress + Cyclictest 集成测试"
echo "=========================================="
echo ""
echo "配置:"
echo "  CPU 核心: $CPU_CORES"
echo "  测试时长: ${DURATION}秒/场景"
echo "  输出目录: $OUTPUT_DIR"
echo "=========================================="
echo ""

# 检查工具
MISSING_TOOLS=()

if ! command -v stress-ng &> /dev/null; then
    MISSING_TOOLS+=("stress-ng")
fi

if ! command -v cyclictest &> /dev/null; then
    MISSING_TOOLS+=("cyclictest")
fi

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo "错误: 缺少以下工具:"
    for tool in "${MISSING_TOOLS[@]}"; do
        echo "  • $tool"
    done
    echo ""
    echo "安装方法:"
    echo "  Ubuntu/Debian: sudo apt-get install stress-ng rt-tests"
    echo "  RHEL/CentOS: sudo yum install stress-ng rt-tests"
    exit 1
fi

echo "✓ 工具检查完成"
echo ""

# 系统信息
{
    echo "系统信息"
    echo "========================================"
    echo "测试时间: $(date)"
    echo "主机名: $(hostname)"
    echo "内核: $(uname -r)"
    echo "CPU 核心: $CPU_CORES"
    echo "CPU 型号: $(cat /proc/cpuinfo | grep 'model name' | head -1 | cut -d':' -f2 | xargs)"
    echo "总内存: $(free -h | grep Mem | awk '{print $2}')"
    echo ""
} | tee "$OUTPUT_DIR/system_info.txt"

# ========== 测试1: CPU压力 + 实时性 ==========
echo "=========================================="
echo "测试1: CPU压力 + 实时性"
echo "=========================================="
echo ""
echo "压力配置:"
echo "  • 方法: ackermann (递归计算)"
echo "  • 负载: 100% CPU"
echo "  • 核心: $CPU_CORES"
echo ""

# 启动CPU压力
echo "启动CPU压力..."
stress-ng --cpu $CPU_CORES \
    --cpu-method ackermann \
    --cpu-load 100 \
    --timeout $((DURATION + 10))s \
    --metrics \
    --quiet \
    > "$OUTPUT_DIR/stress_cpu_ackermann.log" 2>&1 &
STRESS_PID1=$!
echo "  stress-ng PID: $STRESS_PID1"

sleep 5  # 等待压力稳定

# 运行cyclictest
echo "运行cyclictest（${DURATION}秒）..."
cyclictest -m -S -p 99 -i 1000 -n -D $DURATION \
    -q -h 10000 \
    --histfile "$OUTPUT_DIR/test1_cpu_rt.hist" \
    2>&1 | tee "$OUTPUT_DIR/test1_cpu_rt.log"

# 停止压力
kill $STRESS_PID1 2>/dev/null
wait $STRESS_PID1 2>/dev/null

# 提取结果
T1_MIN=$(grep "Min Latencies:" "$OUTPUT_DIR/test1_cpu_rt.log" | awk '{print $3}' | head -1)
T1_AVG=$(grep "Avg Latencies:" "$OUTPUT_DIR/test1_cpu_rt.log" | awk '{print $3}' | head -1)
T1_MAX=$(grep "Max Latencies:" "$OUTPUT_DIR/test1_cpu_rt.log" | awk '{print $3}' | head -1)

echo ""
echo "✓ CPU压力测试完成"
echo "  结果: Min=${T1_MIN}μs, Avg=${T1_AVG}μs, Max=${T1_MAX}μs"
echo ""

sleep 10

# ========== 测试2: 内存压力 + 实时性 ==========
echo "=========================================="
echo "测试2: 内存压力 + 实时性"
echo "=========================================="
echo ""
echo "压力配置:"
echo "  • VM 线程: 4"
echo "  • 内存使用: 80%"
echo "  • 保持内存: 是"
echo ""

# 内存压力（80%内存使用）
echo "启动内存压力..."
stress-ng --vm 4 --vm-bytes 80% --vm-keep \
    --timeout $((DURATION + 10))s \
    --metrics \
    --quiet \
    > "$OUTPUT_DIR/stress_memory.log" 2>&1 &
STRESS_PID2=$!
echo "  stress-ng PID: $STRESS_PID2"

sleep 5

echo "运行cyclictest（${DURATION}秒）..."
cyclictest -m -S -p 99 -i 1000 -n -D $DURATION \
    -q -h 10000 \
    --histfile "$OUTPUT_DIR/test2_memory_rt.hist" \
    2>&1 | tee "$OUTPUT_DIR/test2_memory_rt.log"

kill $STRESS_PID2 2>/dev/null
wait $STRESS_PID2 2>/dev/null

T2_MIN=$(grep "Min Latencies:" "$OUTPUT_DIR/test2_memory_rt.log" | awk '{print $3}' | head -1)
T2_AVG=$(grep "Avg Latencies:" "$OUTPUT_DIR/test2_memory_rt.log" | awk '{print $3}' | head -1)
T2_MAX=$(grep "Max Latencies:" "$OUTPUT_DIR/test2_memory_rt.log" | awk '{print $3}' | head -1)

echo ""
echo "✓ 内存压力测试完成"
echo "  结果: Min=${T2_MIN}μs, Avg=${T2_AVG}μs, Max=${T2_MAX}μs"
echo ""

sleep 10

# ========== 测试3: I/O压力 + 实时性 ==========
echo "=========================================="
echo "测试3: I/O压力 + 实时性"
echo "=========================================="
echo ""
echo "压力配置:"
echo "  • I/O 线程: 8"
echo "  • HDD 线程: 4"
echo "  • HDD 数据: 10GB"
echo ""

# I/O压力（混合模式）
echo "启动I/O压力..."
stress-ng --io 8 --hdd 4 --hdd-bytes 10G \
    --temp-path /tmp \
    --timeout $((DURATION + 10))s \
    --metrics \
    --quiet \
    > "$OUTPUT_DIR/stress_io.log" 2>&1 &
STRESS_PID3=$!
echo "  stress-ng PID: $STRESS_PID3"

sleep 5

echo "运行cyclictest（${DURATION}秒）..."
cyclictest -m -S -p 99 -i 1000 -n -D $DURATION \
    -q -h 10000 \
    --histfile "$OUTPUT_DIR/test3_io_rt.hist" \
    2>&1 | tee "$OUTPUT_DIR/test3_io_rt.log"

kill $STRESS_PID3 2>/dev/null
wait $STRESS_PID3 2>/dev/null

T3_MIN=$(grep "Min Latencies:" "$OUTPUT_DIR/test3_io_rt.log" | awk '{print $3}' | head -1)
T3_AVG=$(grep "Avg Latencies:" "$OUTPUT_DIR/test3_io_rt.log" | awk '{print $3}' | head -1)
T3_MAX=$(grep "Max Latencies:" "$OUTPUT_DIR/test3_io_rt.log" | awk '{print $3}' | head -1)

echo ""
echo "✓ I/O压力测试完成"
echo "  结果: Min=${T3_MIN}μs, Avg=${T3_AVG}μs, Max=${T3_MAX}μs"
echo ""

sleep 10

# ========== 测试4: 组合压力 + 实时性 ==========
echo "=========================================="
echo "测试4: 组合压力 + 实时性"
echo "=========================================="
echo ""
echo "压力配置:"
echo "  • CPU: $((CPU_CORES/2)) 核心"
echo "  • I/O: 4 线程"
echo "  • VM: 2 线程 (50%内存)"
echo "  • HDD: 2 线程"
echo ""

# 全系统压力
echo "启动组合压力..."
stress-ng --cpu $((CPU_CORES/2)) \
    --io 4 \
    --vm 2 --vm-bytes 50% \
    --hdd 2 \
    --temp-path /tmp \
    --timeout $((DURATION + 10))s \
    --metrics \
    --quiet \
    > "$OUTPUT_DIR/stress_combo.log" 2>&1 &
STRESS_PID4=$!
echo "  stress-ng PID: $STRESS_PID4"

sleep 5

echo "运行cyclictest（${DURATION}秒）..."
cyclictest -m -S -p 99 -i 1000 -n -D $DURATION \
    -q -h 10000 \
    --smi \
    --histfile "$OUTPUT_DIR/test4_combo_rt.hist" \
    2>&1 | tee "$OUTPUT_DIR/test4_combo_rt.log"

kill $STRESS_PID4 2>/dev/null
wait $STRESS_PID4 2>/dev/null

T4_MIN=$(grep "Min Latencies:" "$OUTPUT_DIR/test4_combo_rt.log" | awk '{print $3}' | head -1)
T4_AVG=$(grep "Avg Latencies:" "$OUTPUT_DIR/test4_combo_rt.log" | awk '{print $3}' | head -1)
T4_MAX=$(grep "Max Latencies:" "$OUTPUT_DIR/test4_combo_rt.log" | awk '{print $3}' | head -1)

echo ""
echo "✓ 组合压力测试完成"
echo "  结果: Min=${T4_MIN}μs, Avg=${T4_AVG}μs, Max=${T4_MAX}μs"
echo ""

# 检查SMI中断
if grep -q "SMI count" "$OUTPUT_DIR/test4_combo_rt.log"; then
    SMI_COUNT=$(grep "SMI count" "$OUTPUT_DIR/test4_combo_rt.log" | awk '{print $3}')
    if [ "$SMI_COUNT" -gt 0 ]; then
        echo "  ⚠ 检测到 $SMI_COUNT 次 SMI 中断"
    fi
fi
echo ""

sleep 10

# ========== 测试5: FFT算法压力 + 实时性 ==========
echo "=========================================="
echo "测试5: FFT算法压力 + 实时性"
echo "=========================================="
echo ""
echo "压力配置:"
echo "  • 方法: fft (快速傅里叶变换)"
echo "  • 核心: $CPU_CORES"
echo "  • 场景: 科学计算模拟"
echo ""

# FFT压力（科学计算场景模拟）
echo "启动FFT算法压力..."
stress-ng --cpu $CPU_CORES \
    --cpu-method fft \
    --timeout $((DURATION + 10))s \
    --metrics \
    --quiet \
    > "$OUTPUT_DIR/stress_fft.log" 2>&1 &
STRESS_PID5=$!
echo "  stress-ng PID: $STRESS_PID5"

sleep 5

echo "运行cyclictest（${DURATION}秒）..."
cyclictest -m -S -p 99 -i 1000 -n -D $DURATION \
    -q -h 10000 \
    --histfile "$OUTPUT_DIR/test5_fft_rt.hist" \
    2>&1 | tee "$OUTPUT_DIR/test5_fft_rt.log"

kill $STRESS_PID5 2>/dev/null
wait $STRESS_PID5 2>/dev/null

T5_MIN=$(grep "Min Latencies:" "$OUTPUT_DIR/test5_fft_rt.log" | awk '{print $3}' | head -1)
T5_AVG=$(grep "Avg Latencies:" "$OUTPUT_DIR/test5_fft_rt.log" | awk '{print $3}' | head -1)
T5_MAX=$(grep "Max Latencies:" "$OUTPUT_DIR/test5_fft_rt.log" | awk '{print $3}' | head -1)

echo ""
echo "✓ FFT算法压力测试完成"
echo "  结果: Min=${T5_MIN}μs, Avg=${T5_AVG}μs, Max=${T5_MAX}μs"
echo ""

# ========== 测试6: 矩阵运算压力 + 实时性 ==========
echo "=========================================="
echo "测试6: 矩阵运算压力 + 实时性"
echo "=========================================="
echo ""
echo "压力配置:"
echo "  • 方法: matrixprod (矩阵乘法)"
echo "  • 核心: $CPU_CORES"
echo "  • 场景: 密集计算模拟"
echo ""

echo "启动矩阵运算压力..."
stress-ng --cpu $CPU_CORES \
    --cpu-method matrixprod \
    --timeout $((DURATION + 10))s \
    --metrics \
    --quiet \
    > "$OUTPUT_DIR/stress_matrix.log" 2>&1 &
STRESS_PID6=$!
echo "  stress-ng PID: $STRESS_PID6"

sleep 5

echo "运行cyclictest（${DURATION}秒）..."
cyclictest -m -S -p 99 -i 1000 -n -D $DURATION \
    -q -h 10000 \
    --histfile "$OUTPUT_DIR/test6_matrix_rt.hist" \
    2>&1 | tee "$OUTPUT_DIR/test6_matrix_rt.log"

kill $STRESS_PID6 2>/dev/null
wait $STRESS_PID6 2>/dev/null

T6_MIN=$(grep "Min Latencies:" "$OUTPUT_DIR/test6_matrix_rt.log" | awk '{print $3}' | head -1)
T6_AVG=$(grep "Avg Latencies:" "$OUTPUT_DIR/test6_matrix_rt.log" | awk '{print $3}' | head -1)
T6_MAX=$(grep "Max Latencies:" "$OUTPUT_DIR/test6_matrix_rt.log" | awk '{print $3}' | head -1)

echo ""
echo "✓ 矩阵运算压力测试完成"
echo "  结果: Min=${T6_MIN}μs, Avg=${T6_AVG}μs, Max=${T6_MAX}μs"
echo ""

# ========== 生成综合报告 ==========
echo "=========================================="
echo "生成综合测试报告"
echo "=========================================="
echo ""

{
    echo "Stress + Cyclictest 集成测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo "系统: $(hostname) - $(uname -r)"
    echo "CPU 核心: $CPU_CORES"
    echo "测试时长: ${DURATION}秒/场景"
    echo ""

    echo "测试场景汇总"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "%-20s %10s %10s %10s   %s\n" "场景" "最小(μs)" "平均(μs)" "最大(μs)" "性能评级"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # 评估函数
    get_rating() {
        local max=$1
        if [ -z "$max" ] || [ "$max" = "N/A" ]; then
            echo "N/A"
        elif [ "$max" -lt 50 ]; then
            echo "★★★★★ 优秀(硬实时)"
        elif [ "$max" -lt 100 ]; then
            echo "★★★★☆ 良好(软实时)"
        elif [ "$max" -lt 500 ]; then
            echo "★★★☆☆ 一般(准实时)"
        else
            echo "★★☆☆☆ 差(非实时)"
        fi
    }

    printf "%-20s %10s %10s %10s   %s\n" "CPU压力(ackermann)" "$T1_MIN" "$T1_AVG" "$T1_MAX" "$(get_rating $T1_MAX)"
    printf "%-20s %10s %10s %10s   %s\n" "内存压力(80%)" "$T2_MIN" "$T2_AVG" "$T2_MAX" "$(get_rating $T2_MAX)"
    printf "%-20s %10s %10s %10s   %s\n" "I/O压力(混合)" "$T3_MIN" "$T3_AVG" "$T3_MAX" "$(get_rating $T3_MAX)"
    printf "%-20s %10s %10s %10s   %s\n" "组合压力" "$T4_MIN" "$T4_AVG" "$T4_MAX" "$(get_rating $T4_MAX)"
    printf "%-20s %10s %10s %10s   %s\n" "FFT算法压力" "$T5_MIN" "$T5_AVG" "$T5_MAX" "$(get_rating $T5_MAX)"
    printf "%-20s %10s %10s %10s   %s\n" "矩阵运算压力" "$T6_MIN" "$T6_AVG" "$T6_MAX" "$(get_rating $T6_MAX)"

    echo ""

    # 找出最差场景
    WORST_MAX=$T1_MAX
    WORST_SCENARIO="CPU压力"

    for scenario in "内存压力:$T2_MAX" "I/O压力:$T3_MAX" "组合压力:$T4_MAX" "FFT压力:$T5_MAX" "矩阵压力:$T6_MAX"; do
        IFS=':' read -r name value <<< "$scenario"
        if [ -n "$value" ] && [ "$value" != "N/A" ] && [ $value -gt $WORST_MAX ]; then
            WORST_MAX=$value
            WORST_SCENARIO="$name"
        fi
    done

    echo "关键发现"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "• 最差延迟场景: $WORST_SCENARIO (${WORST_MAX}μs)"
    echo ""

    # 对比分析
    echo "• 压力类型影响分析:"
    echo "  - CPU密集型 (ackermann): ${T1_MAX}μs"
    echo "  - 内存密集型 (80%内存): ${T2_MAX}μs"
    echo "  - I/O密集型 (混合I/O): ${T3_MAX}μs"
    echo "  - 组合压力: ${T4_MAX}μs"
    echo ""

    # 算法对比
    echo "• CPU算法影响对比:"
    echo "  - Ackermann递归: ${T1_MAX}μs"
    echo "  - FFT变换: ${T5_MAX}μs"
    echo "  - 矩阵乘法: ${T6_MAX}μs"
    echo ""

    # SMI检测
    if grep -q "SMI count" "$OUTPUT_DIR/test4_combo_rt.log" 2>/dev/null; then
        SMI_COUNT=$(grep "SMI count" "$OUTPUT_DIR/test4_combo_rt.log" | awk '{print $3}')
        if [ "$SMI_COUNT" -gt 0 ]; then
            echo "• SMI中断检测: $SMI_COUNT 次"
            echo "  建议: 在BIOS中禁用SMM（System Management Mode）"
            echo ""
        fi
    fi

    echo "优化建议"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [ $WORST_MAX -gt 200 ]; then
        echo "• 系统整体实时性需要改进:"
        echo "  - 安装PREEMPT_RT实时内核"
        echo "  - 配置CPU隔离 (isolcpus参数)"
        echo "  - 设置中断亲和性"
        echo ""
    fi

    if [ $T1_MAX -gt $((T3_MAX * 2)) ]; then
        echo "• CPU密集型任务影响更大:"
        echo "  - 使用CPU隔离减少调度干扰"
        echo "  - 将实时任务绑定到专用核心"
        echo ""
    elif [ $T3_MAX -gt $((T1_MAX * 2)) ]; then
        echo "• I/O密集型任务影响更大:"
        echo "  - 使用独立磁盘进行I/O操作"
        echo "  - 优化I/O调度器配置"
        echo "  - 考虑使用SSD减少I/O延迟"
        echo ""
    fi

    echo "详细数据文件"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    ls -1 "$OUTPUT_DIR"/*.log "$OUTPUT_DIR"/*.hist 2>/dev/null | sed 's/^/  • /'
    echo ""

} | tee "$OUTPUT_DIR/integrated_report.txt"

cat "$OUTPUT_DIR/integrated_report.txt"

echo ""
echo "=========================================="
echo "测试完成！"
echo "=========================================="
echo ""
echo "结果保存至: $OUTPUT_DIR"
echo ""
echo "查看报告:"
echo "  cat $OUTPUT_DIR/integrated_report.txt"
echo ""
echo "生成可视化图表:"
echo "  ./generate_comparison_plot.sh $OUTPUT_DIR"
echo "  ./generate_cdf_plot.sh $OUTPUT_DIR"
echo ""
