#!/bin/bash
# cyclictest_three_scenarios.sh - 三种场景延迟对比

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/../results/cyclictest_scenarios_$(date +%Y%m%d_%H%M%S)"

mkdir -p "$OUTPUT_DIR"

DURATION=300  # 每个场景5分钟
INTERVAL=1000 # 1ms间隔

# 检查工具
if ! command -v cyclictest &> /dev/null; then
    echo "错误: cyclictest 未安装"
    echo "请运行: sudo ../install_rt_tests.sh"
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

CPU_COUNT=$(nproc)

# 基础cyclictest参数
BASE_PARAMS="-m -S -p 99 -i $INTERVAL -n -D $DURATION -q -h 10000"

echo "======================================"
echo "Cyclictest 三种场景延迟对比测试"
echo "======================================"
echo ""
echo "配置:"
echo "  持续时间: 每个场景 ${DURATION}秒"
echo "  测试间隔: ${INTERVAL}μs"
echo "  CPU 核心: $CPU_COUNT"
echo "  输出目录: $OUTPUT_DIR"
echo "======================================"
echo ""

# ========== 场景1: 空载（Idle）==========
echo "========================================="
echo "场景1: 系统空载"
echo "========================================="
echo ""
echo "描述: 无额外负载，理想情况下的基准延迟"
echo ""

# 清理后台进程
sudo pkill -f stress 2>/dev/null
sudo pkill -f stress-ng 2>/dev/null
sleep 5

echo "开始测试（${DURATION}秒）..."
sudo cyclictest $BASE_PARAMS \
    2>&1 | tee "$OUTPUT_DIR/scenario1_idle.log"

# 同时生成直方图数据
sudo cyclictest $BASE_PARAMS --histogram=10000 \
    > "$OUTPUT_DIR/scenario1_idle.hist" 2>&1 &
HIST_PID=$!
wait $HIST_PID 2>/dev/null

# 提取关键指标
IDLE_MIN=$(grep "Min Latencies:" "$OUTPUT_DIR/scenario1_idle.log" | awk '{print $3}' | head -1)
IDLE_AVG=$(grep "Avg Latencies:" "$OUTPUT_DIR/scenario1_idle.log" | awk '{print $3}' | head -1)
IDLE_MAX=$(grep "Max Latencies:" "$OUTPUT_DIR/scenario1_idle.log" | awk '{print $3}' | head -1)

echo ""
echo "✓ 空载测试完成"
echo "  结果: Min=${IDLE_MIN}μs, Avg=${IDLE_AVG}μs, Max=${IDLE_MAX}μs"
echo ""

sleep 10

# ========== 场景2: CPU满载 ==========
echo "========================================="
echo "场景2: CPU满载压力"
echo "========================================="
echo ""
echo "描述: 所有CPU核心100%负载，测试调度延迟"
echo ""

# 启动CPU压力（所有核心）
echo "启动 stress-ng --cpu $CPU_COUNT ..."
sudo stress-ng --cpu $CPU_COUNT --cpu-method all --timeout $((DURATION + 30))s &
STRESS_PID=$!
echo "  stress-ng PID: $STRESS_PID"
sleep 5  # 等待压力稳定

echo "开始测试（${DURATION}秒）..."
sudo cyclictest $BASE_PARAMS \
    2>&1 | tee "$OUTPUT_DIR/scenario2_cpu_load.log"

# 生成直方图
sudo cyclictest $BASE_PARAMS --histogram=10000 \
    > "$OUTPUT_DIR/scenario2_cpu_load.hist" 2>&1 &
HIST_PID=$!
wait $HIST_PID 2>/dev/null

# 停止压力
sudo kill $STRESS_PID 2>/dev/null
wait $STRESS_PID 2>/dev/null

CPU_MIN=$(grep "Min Latencies:" "$OUTPUT_DIR/scenario2_cpu_load.log" | awk '{print $3}' | head -1)
CPU_AVG=$(grep "Avg Latencies:" "$OUTPUT_DIR/scenario2_cpu_load.log" | awk '{print $3}' | head -1)
CPU_MAX=$(grep "Max Latencies:" "$OUTPUT_DIR/scenario2_cpu_load.log" | awk '{print $3}' | head -1)

echo ""
echo "✓ CPU满载测试完成"
echo "  结果: Min=${CPU_MIN}μs, Avg=${CPU_AVG}μs, Max=${CPU_MAX}μs"
echo ""

sleep 10

# ========== 场景3: I/O压力 ==========
echo "========================================="
echo "场景3: I/O压力"
echo "========================================="
echo ""
echo "描述: 磁盘I/O密集型负载，测试I/O干扰"
echo ""

# 启动I/O压力
echo "启动 stress-ng --io 8 --hdd 4 ..."
sudo stress-ng --io 8 --timeout $((DURATION + 30))s &
IO_PID1=$!
sudo stress-ng --hdd 4 --hdd-bytes 10G --temp-path /tmp --timeout $((DURATION + 30))s &
IO_PID2=$!
echo "  stress-ng PIDs: $IO_PID1, $IO_PID2"
sleep 5

echo "开始测试（${DURATION}秒）..."
sudo cyclictest $BASE_PARAMS \
    2>&1 | tee "$OUTPUT_DIR/scenario3_io_load.log"

# 生成直方图
sudo cyclictest $BASE_PARAMS --histogram=10000 \
    > "$OUTPUT_DIR/scenario3_io_load.hist" 2>&1 &
HIST_PID=$!
wait $HIST_PID 2>/dev/null

# 停止压力
sudo kill $IO_PID1 $IO_PID2 2>/dev/null
wait $IO_PID1 $IO_PID2 2>/dev/null

IO_MIN=$(grep "Min Latencies:" "$OUTPUT_DIR/scenario3_io_load.log" | awk '{print $3}' | head -1)
IO_AVG=$(grep "Avg Latencies:" "$OUTPUT_DIR/scenario3_io_load.log" | awk '{print $3}' | head -1)
IO_MAX=$(grep "Max Latencies:" "$OUTPUT_DIR/scenario3_io_load.log" | awk '{print $3}' | head -1)

echo ""
echo "✓ I/O压力测试完成"
echo "  结果: Min=${IO_MIN}μs, Avg=${IO_AVG}μs, Max=${IO_MAX}μs"
echo ""

sleep 10

# ========== 场景4: 组合压力（可选）==========
echo "========================================="
echo "场景4: CPU+I/O组合压力"
echo "========================================="
echo ""
echo "描述: 模拟真实混合负载场景"
echo ""

echo "启动 stress-ng --cpu $((CPU_COUNT/2)) --io 4 --hdd 2 ..."
sudo stress-ng --cpu $((CPU_COUNT/2)) --io 4 --hdd 2 --temp-path /tmp --timeout $((DURATION + 30))s &
COMBO_PID=$!
echo "  stress-ng PID: $COMBO_PID"
sleep 5

echo "开始测试（${DURATION}秒）..."
sudo cyclictest $BASE_PARAMS \
    2>&1 | tee "$OUTPUT_DIR/scenario4_combo.log"

# 生成直方图
sudo cyclictest $BASE_PARAMS --histogram=10000 \
    > "$OUTPUT_DIR/scenario4_combo.hist" 2>&1 &
HIST_PID=$!
wait $HIST_PID 2>/dev/null

sudo kill $COMBO_PID 2>/dev/null
wait $COMBO_PID 2>/dev/null

COMBO_MIN=$(grep "Min Latencies:" "$OUTPUT_DIR/scenario4_combo.log" | awk '{print $3}' | head -1)
COMBO_AVG=$(grep "Avg Latencies:" "$OUTPUT_DIR/scenario4_combo.log" | awk '{print $3}' | head -1)
COMBO_MAX=$(grep "Max Latencies:" "$OUTPUT_DIR/scenario4_combo.log" | awk '{print $3}' | head -1)

echo ""
echo "✓ 组合压力测试完成"
echo "  结果: Min=${COMBO_MIN}μs, Avg=${COMBO_AVG}μs, Max=${COMBO_MAX}μs"
echo ""

# ========== 生成对比报告 ==========
echo ""
echo "======================================"
echo "生成对比报告"
echo "======================================"
echo ""

# 计算恶化倍数
IDLE_MAX_FLOAT=$(echo "$IDLE_MAX" | bc)
if [ "$IDLE_MAX_FLOAT" = "0" ]; then
    IDLE_MAX_FLOAT=1
fi

CPU_DEGRADATION=$(echo "scale=2; $CPU_MAX / $IDLE_MAX_FLOAT" | bc)
IO_DEGRADATION=$(echo "scale=2; $IO_MAX / $IDLE_MAX_FLOAT" | bc)
COMBO_DEGRADATION=$(echo "scale=2; $COMBO_MAX / $IDLE_MAX_FLOAT" | bc)

cat > "$OUTPUT_DIR/comparison_report.txt" << EOF
Cyclictest 延迟对比报告
========================================

生成时间: $(date)
测试时长: ${DURATION}秒/场景
CPU 核心: $CPU_COUNT

场景对比
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
场景          最小延迟(μs)   平均延迟(μs)   最大延迟(μs)   恶化倍数
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
空载(基准)    ${IDLE_MIN}              ${IDLE_AVG}              ${IDLE_MAX}              1.00x
CPU满载       ${CPU_MIN}              ${CPU_AVG}              ${CPU_MAX}              ${CPU_DEGRADATION}x
I/O压力       ${IO_MIN}              ${IO_AVG}              ${IO_MAX}              ${IO_DEGRADATION}x
组合压力      ${COMBO_MIN}              ${COMBO_AVG}              ${COMBO_MAX}              ${COMBO_DEGRADATION}x
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

关键发现
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

最大延迟场景:
EOF

# 找出最差场景
WORST_MAX=$IDLE_MAX
WORST_SCENARIO="空载"

if [ $CPU_MAX -gt $WORST_MAX ]; then
    WORST_MAX=$CPU_MAX
    WORST_SCENARIO="CPU满载"
fi

if [ $IO_MAX -gt $WORST_MAX ]; then
    WORST_MAX=$IO_MAX
    WORST_SCENARIO="I/O压力"
fi

if [ $COMBO_MAX -gt $WORST_MAX ]; then
    WORST_MAX=$COMBO_MAX
    WORST_SCENARIO="组合压力"
fi

cat >> "$OUTPUT_DIR/comparison_report.txt" << EOF
  场景: $WORST_SCENARIO
  延迟: ${WORST_MAX}μs

平均延迟增长:
  CPU满载: +$((CPU_AVG - IDLE_AVG))μs ($(echo "scale=0; ($CPU_AVG - $IDLE_AVG) * 100 / $IDLE_AVG" | bc)%)
  I/O压力: +$((IO_AVG - IDLE_AVG))μs ($(echo "scale=0; ($IO_AVG - $IDLE_AVG) * 100 / $IDLE_AVG" | bc)%)
  组合压力: +$((COMBO_AVG - IDLE_AVG))μs ($(echo "scale=0; ($COMBO_AVG - $IDLE_AVG) * 100 / $IDLE_AVG" | bc)%)

性能分析
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

实时内核在CPU满载下应保持稳定延迟 (< 100μs)
I/O压力通常对实时性影响更大（DMA、中断风暴）
组合压力测试最坏情况下的系统行为

判定标准
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

# 性能评级
if [ $WORST_MAX -lt 50 ]; then
    cat >> "$OUTPUT_DIR/comparison_report.txt" << EOF
✓ 优秀: Max < 50μs (硬实时)
  - 系统具备优秀的实时性能
  - 适用于工业控制、高频交易、实时音视频
EOF
elif [ $WORST_MAX -lt 100 ]; then
    cat >> "$OUTPUT_DIR/comparison_report.txt" << EOF
○ 良好: Max < 100μs (软实时)
  - 系统具备良好的实时性能
  - 适用于网络设备、实时监控、游戏服务器
EOF
elif [ $WORST_MAX -lt 500 ]; then
    cat >> "$OUTPUT_DIR/comparison_report.txt" << EOF
△ 一般: Max < 500μs (准实时)
  - 系统实时性一般
  - 适用于流媒体、VoIP、一般嵌入式系统
  - 建议优化配置
EOF
else
    cat >> "$OUTPUT_DIR/comparison_report.txt" << EOF
✗ 差: Max > 1ms (非实时)
  - 系统实时性不足
  - 建议安装PREEMPT_RT内核
  - 配置CPU隔离和中断亲和性
EOF
fi

cat >> "$OUTPUT_DIR/comparison_report.txt" << EOF

优化建议
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

if [ $CPU_MAX -gt $((IDLE_MAX * 2)) ]; then
    cat >> "$OUTPUT_DIR/comparison_report.txt" << EOF

• CPU满载影响显著
  - 使用 isolcpus 内核参数隔离CPU核心
  - 将实时任务绑定到隔离的CPU
  - 示例: isolcpus=2,3 nohz_full=2,3 rcu_nocbs=2,3
EOF
fi

if [ $IO_MAX -gt $((IDLE_MAX * 2)) ]; then
    cat >> "$OUTPUT_DIR/comparison_report.txt" << EOF

• I/O压力影响显著
  - 使用独立磁盘用于实时任务
  - 配置I/O调度器（deadline或none）
  - 禁用不必要的磁盘I/O操作
EOF
fi

if ! uname -r | grep -qi "rt\|preempt"; then
    cat >> "$OUTPUT_DIR/comparison_report.txt" << EOF

• 安装PREEMPT_RT实时内核
  当前内核: $(uname -r)
  实时内核可显著改善延迟特性
EOF
fi

cat >> "$OUTPUT_DIR/comparison_report.txt" << EOF

• 系统调优建议
  - 禁用CPU频率调节: cpupower frequency-set -g performance
  - 禁用CPU空闲状态: idle=poll
  - 设置中断亲和性: echo <cpu_mask> > /proc/irq/*/smp_affinity
  - 增加实时任务优先级: chrt -f 99 <command>

详细数据
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

直方图文件:
  - scenario1_idle.hist
  - scenario2_cpu_load.hist
  - scenario3_io_load.hist
  - scenario4_combo.hist

日志文件:
  - scenario1_idle.log
  - scenario2_cpu_load.log
  - scenario3_io_load.log
  - scenario4_combo.log

可视化:
  使用 generate_histogram.sh 或 generate_comparison_plot.sh 生成图表
EOF

cat "$OUTPUT_DIR/comparison_report.txt"

# 生成gnuplot数据文件
cat > "$OUTPUT_DIR/plot_data.txt" << EOF
# Scenario Min Avg Max
Idle $IDLE_MIN $IDLE_AVG $IDLE_MAX
CPU_Load $CPU_MIN $CPU_AVG $CPU_MAX
IO_Load $IO_MIN $IO_AVG $IO_MAX
Combo $COMBO_MIN $COMBO_AVG $COMBO_MAX
EOF

echo ""
echo "======================================"
echo "测试完成！"
echo "======================================"
echo ""
echo "数据已保存至: $OUTPUT_DIR"
echo ""
echo "文件列表:"
ls -lh "$OUTPUT_DIR"
echo ""
echo "查看对比报告:"
echo "  cat $OUTPUT_DIR/comparison_report.txt"
echo ""
echo "生成可视化图表:"
echo "  ./generate_histogram.sh $OUTPUT_DIR/scenario1_idle.hist $OUTPUT_DIR/idle_hist.svg"
echo "  ./generate_comparison_plot.sh $OUTPUT_DIR"
echo "  ./generate_cdf_plot.sh $OUTPUT_DIR"
echo ""
