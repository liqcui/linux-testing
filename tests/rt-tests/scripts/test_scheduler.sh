#!/bin/bash
# test_scheduler.sh - 调度器测试套件

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOCK_DIR="$SCRIPT_DIR/../mock_programs"
RESULTS_DIR="$SCRIPT_DIR/../results/scheduler-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "Linux 调度器测试套件"
echo "========================================"
echo ""

# 检查权限
if [[ $EUID -ne 0 ]]; then
   echo "错误: 此脚本需要 root 权限"
   echo "使用: sudo $0"
   exit 1
fi

mkdir -p "$RESULTS_DIR"

# 编译模拟程序
echo "准备: 编译模拟程序..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd "$MOCK_DIR"
make cpu_intensive_workload realtime_task 2>&1 | grep -v "up to date"

if [[ ! -x cpu_intensive_workload ]] || [[ ! -x realtime_task ]]; then
    echo "✗ 编译失败"
    exit 1
fi

echo "✓ 模拟程序已准备"
echo ""

CPU_COUNT=$(nproc)

echo "系统信息:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  CPU 核心数: $CPU_COUNT"
echo "  内核版本:   $(uname -r)"
echo "  调度器:     $(cat /sys/kernel/debug/sched/features 2>/dev/null | head -1 || echo 'CFS')"
echo "  结果目录:   $RESULTS_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ========== 测试场景 1: CPU 公平性测试 ==========
echo "测试场景 1: CPU 调度公平性测试"
echo "==============================="
echo ""
echo "在单个 CPU 上运行 4 个密集型任务，观察 CPU 分配公平性"
echo ""

# 清理之前的进程
pkill -f cpu_intensive_workload 2>/dev/null

# 在 CPU 0 上启动 4 个任务
echo "启动 4 个 CPU 密集型任务（绑定到 CPU 0）..."

for i in {1..4}; do
    taskset -c 0 "$MOCK_DIR/cpu_intensive_workload" -d 30 -w mixed -i 5 &
    PIDS[$i]=$!
    echo "  Task $i: PID ${PIDS[$i]}"
done

echo ""
echo "监控 CPU 分配（30 秒）..."
echo ""

# 监控 5 次，每次间隔 6 秒
for iter in {1..5}; do
    sleep 6
    echo "=== 时间点 $iter ($(date +%H:%M:%S)) ==="
    ps -eo pid,comm,pcpu,psr --sort=-pcpu | grep workload | head -4
    echo ""
done

# 等待所有任务完成
for pid in "${PIDS[@]}"; do
    wait $pid 2>/dev/null
done

echo "✓ 公平性测试完成"
echo ""
echo "预期结果: 每个任务应获得大约 25% 的 CPU 时间"
echo ""

sleep 5

# ========== 测试场景 2: 实时调度器测试 ==========
echo "测试场景 2: 实时调度器测试 (SCHED_FIFO & SCHED_RR)"
echo "================================================="
echo ""

# 清理
pkill -f realtime_task 2>/dev/null
pkill -f cpu_intensive_workload 2>/dev/null

echo "场景 2.1: SCHED_FIFO 测试"
echo "-------------------------"
echo ""

# 启动普通优先级的后台负载
"$MOCK_DIR/cpu_intensive_workload" -d 40 -w mixed -i 8 > /dev/null 2>&1 &
NORMAL_PID=$!
echo "后台负载: PID $NORMAL_PID (SCHED_OTHER)"

sleep 2

# 启动高优先级 RT 任务
echo "启动 RT 任务: SCHED_FIFO, 优先级 99"
chrt -f 99 "$MOCK_DIR/realtime_task" -p 10000 -r 2000 -d 30 -s fifo -v \
    2>&1 | tee "$RESULTS_DIR/rt-fifo-test.log" &
RT_PID=$!

echo ""
echo "监控调度情况..."
sleep 5

ps -eo pid,comm,pri,policy,pcpu,psr | grep -E "PID|workload|realtime_task" | head -10

wait $RT_PID 2>/dev/null
kill $NORMAL_PID 2>/dev/null
wait $NORMAL_PID 2>/dev/null

echo ""
echo "✓ SCHED_FIFO 测试完成"
echo ""

sleep 3

echo "场景 2.2: SCHED_RR 测试"
echo "-----------------------"
echo ""

# 启动两个相同优先级的 RR 任务
echo "启动两个 SCHED_RR 任务（相同优先级 90）"

chrt -r 90 "$MOCK_DIR/realtime_task" -p 10000 -r 3000 -d 30 -s rr \
    2>&1 > "$RESULTS_DIR/rt-rr1.log" &
RR1_PID=$!
echo "  RR Task 1: PID $RR1_PID"

chrt -r 90 "$MOCK_DIR/realtime_task" -p 10000 -r 3000 -d 30 -s rr \
    2>&1 > "$RESULTS_DIR/rt-rr2.log" &
RR2_PID=$!
echo "  RR Task 2: PID $RR2_PID"

sleep 5
echo ""
echo "两个任务应该通过 Round-Robin 轮流执行"
ps -eo pid,comm,pri,policy,pcpu | grep -E "PID|realtime_task"

wait $RR1_PID 2>/dev/null
wait $RR2_PID 2>/dev/null

echo ""
echo "✓ SCHED_RR 测试完成"
echo ""

sleep 3

# ========== 测试场景 3: RT 带宽限制（RT Throttling）==========
echo "测试场景 3: RT 带宽限制测试（RT Throttling）"
echo "=========================================="
echo ""

# 检查 RT 带宽设置
RT_PERIOD=$(cat /proc/sys/kernel/sched_rt_period_us)
RT_RUNTIME=$(cat /proc/sys/kernel/sched_rt_runtime_us)

echo "当前 RT 带宽配置:"
echo "  Period:  $RT_PERIOD μs ($(echo "scale=2; $RT_PERIOD/1000" | bc) ms)"
echo "  Runtime: $RT_RUNTIME μs ($(echo "scale=2; $RT_RUNTIME/1000" | bc) ms)"
echo "  限制:    $(echo "scale=1; $RT_RUNTIME*100/$RT_PERIOD" | bc)% CPU for RT tasks"
echo ""

# 尝试启动高 CPU 利用率的 RT 任务
echo "启动高 CPU 利用率的 RT 任务（50% 利用率）..."
echo "如果超过 RT 带宽限制，任务将被 throttle"
echo ""

chrt -f 95 "$MOCK_DIR/realtime_task" -p 10000 -r 5000 -d 20 -v \
    2>&1 | tee "$RESULTS_DIR/rt-throttling-test.log" &
THROTTLE_PID=$!

sleep 15
ps -eo pid,comm,pri,pcpu | grep realtime_task

wait $THROTTLE_PID 2>/dev/null

echo ""
echo "✓ RT Throttling 测试完成"
echo ""
echo "分析 $RESULTS_DIR/rt-throttling-test.log 查看是否出现 deadline miss"
echo ""

sleep 3

# ========== 测试场景 4: 优先级继承测试 ==========
echo "测试场景 4: 优先级继承测试"
echo "========================="
echo ""

if command -v pi_stress &> /dev/null; then
    echo "运行 pi_stress 测试优先级继承..."
    pi_stress --duration=30 2>&1 | tee "$RESULTS_DIR/priority-inheritance.log"
    echo ""
else
    echo "pi_stress 未安装，跳过优先级继承测试"
    echo "安装: sudo ../install_from_source.sh"
fi

# ========== 测试场景 5: perf sched 分析 ==========
echo "测试场景 5: 调度延迟分析（perf sched）"
echo "====================================="
echo ""

if command -v perf &> /dev/null; then
    echo "使用 perf sched 分析调度延迟..."
    echo ""

    # 启动后台负载
    "$MOCK_DIR/cpu_intensive_workload" -d 15 -w mixed -i 7 > /dev/null 2>&1 &
    LOAD_PID=$!

    # 记录调度事件
    echo "记录调度事件（10 秒）..."
    perf sched record -o "$RESULTS_DIR/perf-sched.data" -- sleep 10 2>&1 | head -5

    kill $LOAD_PID 2>/dev/null
    wait $LOAD_PID 2>/dev/null

    # 分析延迟
    echo ""
    echo "分析调度延迟..."
    perf sched latency -i "$RESULTS_DIR/perf-sched.data" --sort max 2>&1 | head -30 | \
        tee "$RESULTS_DIR/perf-sched-latency.txt"

    echo ""
    echo "✓ perf sched 分析完成"
    echo "  详细数据: $RESULTS_DIR/perf-sched.data"
    echo "  延迟报告: $RESULTS_DIR/perf-sched-latency.txt"
else
    echo "perf 未安装，跳过 perf sched 分析"
    echo "安装: sudo yum install perf 或 sudo apt install linux-tools-generic"
fi

echo ""
echo ""

# ========== 生成测试报告 ==========
echo "========================================"
echo "测试完成 - 生成报告"
echo "========================================"
echo ""

{
    echo "Linux 调度器测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo "系统: $(hostname) - $(uname -r)"
    echo "CPU: $CPU_COUNT 核心"
    echo ""
    echo "测试结果:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "1. CPU 公平性测试"
    echo "   - 4 个任务在单个 CPU 上竞争"
    echo "   - 预期: 每个任务 ~25% CPU"
    echo ""
    echo "2. 实时调度器测试"
    echo "   - SCHED_FIFO: 最高优先级任务独占 CPU"
    echo "   - SCHED_RR: 相同优先级任务轮流执行"
    echo ""
    echo "3. RT 带宽限制"
    echo "   - Period: $RT_PERIOD μs"
    echo "   - Runtime: $RT_RUNTIME μs"
    echo "   - 限制: $(echo "scale=1; $RT_RUNTIME*100/$RT_PERIOD" | bc)%"
    echo ""
    echo "4. 测试文件:"
    ls -lh "$RESULTS_DIR"/*.log 2>/dev/null
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "分析建议:"
    echo ""
    echo "• 查看 RT 任务延迟:"
    echo "  grep 'Latency\\|Max latency' $RESULTS_DIR/rt-*.log"
    echo ""
    echo "• 检查 deadline miss:"
    echo "  grep 'Missed' $RESULTS_DIR/rt-*.log"
    echo ""
    echo "• perf sched 分析:"
    echo "  perf sched latency -i $RESULTS_DIR/perf-sched.data"
    echo "  perf sched map -i $RESULTS_DIR/perf-sched.data"
    echo ""
} | tee "$RESULTS_DIR/summary.txt"

echo ""
echo "详细结果保存在: $RESULTS_DIR"
echo ""
