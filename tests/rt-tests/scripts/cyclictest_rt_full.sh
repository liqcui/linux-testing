#!/bin/bash
# cyclictest_rt_full.sh - 完整实时性测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/../results/cyclictest_rt_full_$(date +%Y%m%d_%H%M%S)"

# 前置检查
if [ "$(id -u)" != "0" ]; then
    echo "Error: 需要root权限运行实时测试"
    exit 1
fi

# 检查cyclictest
if ! command -v cyclictest &> /dev/null; then
    echo "错误: cyclictest 未安装"
    echo "请运行: sudo ../install_rt_tests.sh"
    exit 1
fi

# 检查内核实时性
echo "========================================="
echo "Cyclictest 完整实时性测试"
echo "========================================="
echo ""

if ! uname -r | grep -qi "rt\|preempt"; then
    echo "⚠ Warning: 当前内核可能不是实时内核"
    echo "当前内核: $(uname -r)"
    read -p "是否继续? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

mkdir -p "$OUTPUT_DIR"

CPU_COUNT=$(nproc)

# 系统信息记录
echo "=== 系统信息 ===" | tee "$OUTPUT_DIR/system_info.txt"
echo "Kernel: $(uname -r)" | tee -a "$OUTPUT_DIR/system_info.txt"
echo "CPU Count: $CPU_COUNT" | tee -a "$OUTPUT_DIR/system_info.txt"
echo "CPU Model: $(cat /proc/cpuinfo | grep 'model name' | head -1 | cut -d':' -f2 | xargs)" | tee -a "$OUTPUT_DIR/system_info.txt"
echo "" | tee -a "$OUTPUT_DIR/system_info.txt"

echo "Realtime config:" | tee -a "$OUTPUT_DIR/system_info.txt"
if [ -f /boot/config-$(uname -r) ]; then
    cat /boot/config-$(uname -r) | grep -E "PREEMPT|HZ=|CPU_FREQ" | tee -a "$OUTPUT_DIR/system_info.txt"
else
    echo "  内核配置文件未找到" | tee -a "$OUTPUT_DIR/system_info.txt"
fi
echo ""

# ========== 测试1: 单线程最高优先级 ==========
echo "========================================="
echo "测试1: 单线程 SCHED_FIFO 优先级99"
echo "========================================="
echo ""
echo "参数:"
echo "  -m        : 锁定内存"
echo "  -S        : SMP模式"
echo "  -p 99     : SCHED_FIFO 优先级99（最高）"
echo "  -i 1000   : 1000μs (1ms) 间隔"
echo "  -n        : 使用 clock_nanosleep"
echo "  -l 100000 : 100000次循环"
echo "  -q        : 静默模式"
echo "  -h 1000   : 直方图最大范围1000μs"
echo "  -D 300    : 运行300秒（5分钟）"
echo "  --smi     : 检测SMI干扰"
echo ""

sudo cyclictest -m -S -p 99 -i 1000 -n -l 100000 \
    -q -h 1000 \
    -D 300 \
    --smi \
    2>&1 | tee "$OUTPUT_DIR/test1_fifo99.log"

echo ""
echo "结果摘要:"
tail -10 "$OUTPUT_DIR/test1_fifo99.log"
echo ""

sleep 5

# ========== 测试2: 多线程不同优先级 ==========
echo "========================================="
echo "测试2: 多线程优先级分布"
echo "========================================="
echo ""
echo "配置: 4线程，优先级分别为 99, 80, 60, 40"
echo "测试线程间优先级调度的影响"
echo ""

# 4线程，优先级从99开始，每个线程递减
sudo cyclictest -m -S -p 99 -D 0 -i 1000 -n -l 50000 \
    --threads 4 \
    --distance 20 \
    -q -h 1000 \
    -D 150 \
    2>&1 | tee "$OUTPUT_DIR/test2_multi_prio.log"

echo ""
echo "结果摘要:"
tail -10 "$OUTPUT_DIR/test2_multi_prio.log"
echo ""

sleep 5

# ========== 测试3: CPU亲和性绑定 ==========
echo "========================================="
echo "测试3: CPU亲和性测试"
echo "========================================="
echo ""

# 检测可用CPU
if [ $CPU_COUNT -gt 2 ]; then
    # 绑定到最后一个CPU核心（通常较少被使用）
    TARGET_CPU=$((CPU_COUNT - 1))
    echo "绑定到 CPU $TARGET_CPU（总共 $CPU_COUNT 个核心）"
    echo "建议: 使用 isolcpus=$TARGET_CPU 内核参数隔离该CPU"
    echo ""

    sudo cyclictest -m -S -p 99 -i 1000 -n -l 100000 \
        -a $TARGET_CPU \
        -t 1 \
        -q -h 1000 \
        -D 180 \
        2>&1 | tee "$OUTPUT_DIR/test3_cpu${TARGET_CPU}_isolated.log"
else
    echo "CPU核心数量较少（$CPU_COUNT），跳过CPU亲和性测试"
    echo "建议至少3个CPU核心以进行隔离测试" | tee "$OUTPUT_DIR/test3_cpu${TARGET_CPU}_isolated.log"
fi

echo ""
echo "结果摘要:"
tail -10 "$OUTPUT_DIR/test3_cpu${TARGET_CPU}_isolated.log"
echo ""

sleep 5

# ========== 测试4: 不同调度策略对比 ==========
echo "========================================="
echo "测试4: 调度策略对比"
echo "========================================="
echo ""

# SCHED_FIFO（先进先出）
echo "4.1 SCHED_FIFO (先进先出，不可抢占)"
sudo cyclictest -m -S -p 99 -i 1000 -n -l 50000 \
    -q -h 1000 -D 120 \
    2>&1 | tee "$OUTPUT_DIR/test4_fifo.log"

echo "✓ SCHED_FIFO 测试完成"
echo ""
sleep 3

# SCHED_RR（时间片轮转）
echo "4.2 SCHED_RR (时间片轮转)"
sudo cyclictest -m -R -p 99 -i 1000 -n -l 50000 \
    -q -h 1000 -D 120 \
    2>&1 | tee "$OUTPUT_DIR/test4_rr.log"

echo "✓ SCHED_RR 测试完成"
echo ""
sleep 3

# SCHED_OTHER（普通分时，优先级无效）
echo "4.3 SCHED_OTHER (普通分时调度)"
sudo cyclictest -m -O -p 0 -i 1000 -n -l 50000 \
    -q -h 1000 -D 120 \
    2>&1 | tee "$OUTPUT_DIR/test4_other.log"

echo "✓ SCHED_OTHER 测试完成"
echo ""

# 对比结果
echo "========================================="
echo "调度策略对比结果:"
echo "========================================="
echo ""

FIFO_MAX=$(grep "Max Latencies:" "$OUTPUT_DIR/test4_fifo.log" | awk '{print $3}' | head -1)
FIFO_AVG=$(grep "Avg Latencies:" "$OUTPUT_DIR/test4_fifo.log" | awk '{print $3}' | head -1)

RR_MAX=$(grep "Max Latencies:" "$OUTPUT_DIR/test4_rr.log" | awk '{print $3}' | head -1)
RR_AVG=$(grep "Avg Latencies:" "$OUTPUT_DIR/test4_rr.log" | awk '{print $3}' | head -1)

OTHER_MAX=$(grep "Max Latencies:" "$OUTPUT_DIR/test4_other.log" | awk '{print $3}' | head -1)
OTHER_AVG=$(grep "Avg Latencies:" "$OUTPUT_DIR/test4_other.log" | awk '{print $3}' | head -1)

printf "%-20s %15s %15s\n" "调度策略" "平均延迟(μs)" "最大延迟(μs)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "%-20s %15s %15s\n" "SCHED_FIFO" "$FIFO_AVG" "$FIFO_MAX"
printf "%-20s %15s %15s\n" "SCHED_RR" "$RR_AVG" "$RR_MAX"
printf "%-20s %15s %15s\n" "SCHED_OTHER" "$OTHER_AVG" "$OTHER_MAX"
echo ""

# ========== 生成综合报告 ==========
echo "========================================="
echo "生成综合分析报告"
echo "========================================="
echo ""

{
    echo "Cyclictest 完整实时性测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo "系统: $(hostname) - $(uname -r)"
    echo "CPU 核心: $CPU_COUNT"
    echo ""

    echo "一、测试配置"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    cat "$OUTPUT_DIR/system_info.txt"
    echo ""

    echo "二、测试结果汇总"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # 测试1结果
    if [ -f "$OUTPUT_DIR/test1_fifo99.log" ]; then
        echo "测试1: 单线程 SCHED_FIFO 优先级99"
        T1_MIN=$(grep "Min Latencies:" "$OUTPUT_DIR/test1_fifo99.log" | awk '{print $3}' | head -1)
        T1_AVG=$(grep "Avg Latencies:" "$OUTPUT_DIR/test1_fifo99.log" | awk '{print $3}' | head -1)
        T1_MAX=$(grep "Max Latencies:" "$OUTPUT_DIR/test1_fifo99.log" | awk '{print $3}' | head -1)
        echo "  最小延迟: ${T1_MIN}μs"
        echo "  平均延迟: ${T1_AVG}μs"
        echo "  最大延迟: ${T1_MAX}μs"

        # SMI检测
        if grep -q "SMI count" "$OUTPUT_DIR/test1_fifo99.log"; then
            SMI_COUNT=$(grep "SMI count" "$OUTPUT_DIR/test1_fifo99.log" | awk '{print $3}')
            echo "  SMI 中断: $SMI_COUNT 次"
        fi
        echo ""
    fi

    # 测试2结果
    if [ -f "$OUTPUT_DIR/test2_multi_prio.log" ]; then
        echo "测试2: 多线程优先级分布"
        T2_MIN=$(grep "Min Latencies:" "$OUTPUT_DIR/test2_multi_prio.log" | awk '{print $3}' | head -1)
        T2_AVG=$(grep "Avg Latencies:" "$OUTPUT_DIR/test2_multi_prio.log" | awk '{print $3}' | head -1)
        T2_MAX=$(grep "Max Latencies:" "$OUTPUT_DIR/test2_multi_prio.log" | awk '{print $3}' | head -1)
        echo "  最小延迟: ${T2_MIN}μs"
        echo "  平均延迟: ${T2_AVG}μs"
        echo "  最大延迟: ${T2_MAX}μs"
        echo ""
    fi

    # 测试3结果
    if [ -f "$OUTPUT_DIR/test3_cpu${TARGET_CPU}_isolated.log" ]; then
        echo "测试3: CPU${TARGET_CPU} 亲和性绑定"
        if grep -q "Min Latencies:" "$OUTPUT_DIR/test3_cpu${TARGET_CPU}_isolated.log"; then
            T3_MIN=$(grep "Min Latencies:" "$OUTPUT_DIR/test3_cpu${TARGET_CPU}_isolated.log" | awk '{print $3}' | head -1)
            T3_AVG=$(grep "Avg Latencies:" "$OUTPUT_DIR/test3_cpu${TARGET_CPU}_isolated.log" | awk '{print $3}' | head -1)
            T3_MAX=$(grep "Max Latencies:" "$OUTPUT_DIR/test3_cpu${TARGET_CPU}_isolated.log" | awk '{print $3}' | head -1)
            echo "  最小延迟: ${T3_MIN}μs"
            echo "  平均延迟: ${T3_AVG}μs"
            echo "  最大延迟: ${T3_MAX}μs"
        else
            echo "  (跳过)"
        fi
        echo ""
    fi

    # 测试4结果
    echo "测试4: 调度策略对比"
    echo ""
    printf "  %-20s %15s %15s\n" "调度策略" "平均延迟(μs)" "最大延迟(μs)"
    echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "  %-20s %15s %15s\n" "SCHED_FIFO" "$FIFO_AVG" "$FIFO_MAX"
    printf "  %-20s %15s %15s\n" "SCHED_RR" "$RR_AVG" "$RR_MAX"
    printf "  %-20s %15s %15s\n" "SCHED_OTHER" "$OTHER_AVG" "$OTHER_MAX"
    echo ""

    echo "三、性能评估"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # 找出最优结果
    BEST_MAX=$T1_MAX
    BEST_TEST="测试1: 单线程FIFO"

    if [ -n "$T3_MAX" ] && [ $T3_MAX -lt $BEST_MAX ]; then
        BEST_MAX=$T3_MAX
        BEST_TEST="测试3: CPU亲和性"
    fi

    echo "最优配置: $BEST_TEST"
    echo "  最大延迟: ${BEST_MAX}μs"
    echo ""

    # 性能等级
    if [ $BEST_MAX -lt 50 ]; then
        echo "性能等级: ★★★★★ 优秀（硬实时）"
        echo "  适用于: 工业控制、实时音视频、高频交易"
    elif [ $BEST_MAX -lt 100 ]; then
        echo "性能等级: ★★★★☆ 良好（软实时）"
        echo "  适用于: 网络设备、实时监控、游戏服务器"
    elif [ $BEST_MAX -lt 500 ]; then
        echo "性能等级: ★★★☆☆ 一般（准实时）"
        echo "  适用于: 流媒体、VoIP、一般嵌入式系统"
    else
        echo "性能等级: ★★☆☆☆ 需要优化"
        echo "  建议: 升级到PREEMPT_RT内核，配置CPU隔离"
    fi
    echo ""

    echo "四、调度策略分析"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "SCHED_FIFO vs SCHED_RR:"
    if [ $FIFO_MAX -lt $RR_MAX ]; then
        DIFF=$((RR_MAX - FIFO_MAX))
        echo "  FIFO 性能更优，延迟降低 ${DIFF}μs"
        echo "  建议: 实时任务使用 SCHED_FIFO"
    else
        echo "  两者性能相当"
    fi
    echo ""

    echo "SCHED_FIFO vs SCHED_OTHER:"
    DIFF=$((OTHER_MAX - FIFO_MAX))
    RATIO=$(echo "scale=2; $OTHER_MAX / $FIFO_MAX" | bc)
    echo "  实时调度延迟降低 ${DIFF}μs (${RATIO}倍)"
    echo "  结论: 实时调度策略显著改善延迟特性"
    echo ""

    echo "五、优化建议"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if ! uname -r | grep -qi "rt"; then
        echo "• 安装 PREEMPT_RT 实时内核"
        echo "  当前内核: $(uname -r)"
        echo "  实时内核可显著降低延迟抖动"
        echo ""
    fi

    if [ $CPU_COUNT -gt 2 ]; then
        echo "• 配置 CPU 隔离"
        echo "  编辑 /etc/default/grub，添加:"
        echo "  GRUB_CMDLINE_LINUX=\"isolcpus=$((CPU_COUNT-1)) nohz_full=$((CPU_COUNT-1)) rcu_nocbs=$((CPU_COUNT-1))\""
        echo "  然后运行: sudo update-grub && sudo reboot"
        echo ""
    fi

    echo "• 禁用 CPU 频率调节"
    echo "  sudo cpupower frequency-set -g performance"
    echo ""

    echo "• 禁用 CPU 空闲状态"
    echo "  添加内核参数: idle=poll"
    echo ""

    if grep -q "SMI count" "$OUTPUT_DIR/test1_fifo99.log" 2>/dev/null; then
        SMI_COUNT=$(grep "SMI count" "$OUTPUT_DIR/test1_fifo99.log" | awk '{print $3}')
        if [ $SMI_COUNT -gt 0 ]; then
            echo "• 检测到 SMI 中断 ($SMI_COUNT 次)"
            echo "  在 BIOS 中禁用 SMM（System Management Mode）"
            echo ""
        fi
    fi

    echo "• 设置中断亲和性"
    echo "  将硬件中断绑定到非实时CPU核心"
    echo "  参考: /proc/irq/*/smp_affinity"
    echo ""

} | tee "$OUTPUT_DIR/summary_report.txt"

echo ""
echo "========================================="
echo "所有测试完成！"
echo "========================================="
echo ""
echo "结果保存到: $OUTPUT_DIR"
echo ""
echo "文件列表:"
ls -lh "$OUTPUT_DIR"
echo ""
echo "查看综合报告:"
echo "  cat $OUTPUT_DIR/summary_report.txt"
echo ""
