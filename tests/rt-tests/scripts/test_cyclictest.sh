#!/bin/bash
# test_cyclictest.sh - cyclictest 完整测试套件

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results/cyclictest-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "cyclictest 实时延迟测试"
echo "========================================"
echo ""

# 检查 cyclictest
if ! command -v cyclictest &> /dev/null; then
    echo "错误: cyclictest 未安装"
    echo "请运行: sudo ../install_rt_tests.sh"
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

echo "系统信息:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  CPU 核心数: $CPU_COUNT"
echo "  内核版本:   $(uname -r)"
if uname -a | grep -qi "PREEMPT"; then
    echo "  内核类型:   PREEMPT (实时)"
else
    echo "  内核类型:   标准 (非实时)"
fi
echo "  结果目录:   $RESULTS_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 保存系统信息
{
    echo "测试系统信息"
    echo "========================================"
    echo "日期: $(date)"
    echo "主机: $(hostname)"
    echo "内核: $(uname -a)"
    echo "CPU 信息:"
    lscpu
    echo ""
    echo "内存信息:"
    free -h
} > "$RESULTS_DIR/system-info.txt"

echo "测试场景 1: 基础延迟测试（60秒）"
echo "================================"
echo ""
echo "参数:"
echo "  -m        : 锁定内存"
echo "  -a        : CPU 亲和性"
echo "  -p 99     : 最高实时优先级"
echo "  -t $CPU_COUNT      : $CPU_COUNT 个线程"
echo "  -i 1000   : 1ms 间隔"
echo "  -n        : 使用 clock_nanosleep"
echo "  -D 60s    : 运行 60 秒"
echo ""

cyclictest -m -a -p 99 -t $CPU_COUNT -i 1000 -n -D 60s \
    2>&1 | tee "$RESULTS_DIR/basic-test.log"

echo ""
echo ""
echo "测试场景 2: 短间隔高精度测试（30秒）"
echo "====================================="
echo ""
echo "测试 100μs 间隔的延迟"
echo ""

cyclictest -m -a -p 99 -t $CPU_COUNT -i 100 -n -D 30s \
    2>&1 | tee "$RESULTS_DIR/high-precision-test.log"

echo ""
echo ""
echo "测试场景 3: 长时间稳定性测试（300秒）"
echo "====================================="
echo ""
echo "测试长时间运行的稳定性"
echo ""

cyclictest -m -a -p 99 -t $CPU_COUNT -i 1000 -n -S -D 300s \
    2>&1 | tee "$RESULTS_DIR/long-run-test.log"

echo ""
echo ""
echo "测试场景 4: 生成直方图数据（120秒）"
echo "==================================="
echo ""
echo "生成延迟分布直方图..."
echo ""

cyclictest -m -a -p 99 -t $CPU_COUNT -i 1000 -n \
    --histogram=1000 -D 120s \
    > "$RESULTS_DIR/histogram.dat" 2>&1

echo "✓ 直方图数据已保存: $RESULTS_DIR/histogram.dat"

# 如果有 gnuplot，生成图表
if command -v gnuplot &> /dev/null; then
    echo "生成延迟分布图表..."

    gnuplot << EOF
set terminal png size 1200,800
set output '$RESULTS_DIR/latency-histogram.png'
set title "Cyclictest Latency Histogram"
set xlabel "Latency (microseconds)"
set ylabel "Number of Samples"
set grid
set style data lines

plot for [i=2:$(($CPU_COUNT+1))] '$RESULTS_DIR/histogram.dat' using 1:i with lines title sprintf("CPU %d", i-2)
EOF

    echo "✓ 图表已生成: $RESULTS_DIR/latency-histogram.png"
fi

echo ""
echo ""
echo "测试场景 5: 单线程高优先级测试"
echo "=============================="
echo ""
echo "测试单个 CPU 的最佳延迟"
echo ""

cyclictest -m -p 99 -t 1 -i 1000 -n -D 60s \
    2>&1 | tee "$RESULTS_DIR/single-thread-test.log"

echo ""
echo ""
echo "========================================"
echo "测试完成！"
echo "========================================"
echo ""

# 分析结果
echo "结果分析:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 提取各个测试的最大延迟
echo "各测试场景最大延迟:"
echo ""

for log in "$RESULTS_DIR"/*.log; do
    if [[ -f "$log" ]]; then
        test_name=$(basename "$log" .log)
        max_latency=$(grep "Max:" "$log" 2>/dev/null | awk '{print $9}' | sort -n | tail -1)

        if [[ -n "$max_latency" ]]; then
            echo "  $test_name: ${max_latency}μs"

            # 评估
            if [[ $max_latency -lt 50 ]]; then
                echo "    评级: ★★★ 优秀"
            elif [[ $max_latency -lt 100 ]]; then
                echo "    评级: ★★☆ 良好"
            elif [[ $max_latency -lt 200 ]]; then
                echo "    评级: ★☆☆ 可接受"
            else
                echo "    评级: ☆☆☆ 需要优化"
            fi
        fi
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 生成摘要报告
{
    echo "Cyclictest 测试摘要"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo "系统: $(hostname) - $(uname -r)"
    echo "CPU 核心: $CPU_COUNT"
    echo ""
    echo "测试结果:"
    echo ""

    for log in "$RESULTS_DIR"/*.log; do
        if [[ -f "$log" ]]; then
            test_name=$(basename "$log" .log)
            echo "$test_name:"

            max=$(grep "Max:" "$log" 2>/dev/null | awk '{print $9}' | sort -n | tail -1)
            avg=$(grep "Avg:" "$log" 2>/dev/null | awk '{sum+=$7; count++} END {if(count>0) print int(sum/count); else print "N/A"}')
            min=$(grep "Min:" "$log" 2>/dev/null | awk '{print $5}' | sort -n | head -1)

            echo "  最小延迟: ${min:-N/A}μs"
            echo "  平均延迟: ${avg:-N/A}μs"
            echo "  最大延迟: ${max:-N/A}μs"
            echo ""
        fi
    done

    echo "评估标准:"
    echo "  优秀:     Max < 50μs"
    echo "  良好:     Max < 100μs"
    echo "  可接受:   Max < 200μs"
    echo "  需优化:   Max >= 200μs"

} > "$RESULTS_DIR/summary.txt"

cat "$RESULTS_DIR/summary.txt"

echo ""
echo "详细结果保存在: $RESULTS_DIR"
echo ""
echo "文件列表:"
ls -lh "$RESULTS_DIR"
echo ""

# 优化建议
echo "优化建议:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if ! uname -a | grep -qi "PREEMPT RT"; then
    echo "  • 安装 PREEMPT_RT 实时内核以获得更好性能"
fi

if command -v cpupower &>/dev/null; then
    governor=$(cpupower frequency-info 2>/dev/null | grep "current policy" | awk '{print $NF}')
    if [[ "$governor" != "performance" ]]; then
        echo "  • 设置 CPU 频率为 performance 模式:"
        echo "    sudo cpupower frequency-set -g performance"
    fi
fi

echo "  • 隔离 CPU 核心用于实时任务:"
echo "    编辑 /etc/default/grub，添加 isolcpus=2,3"
echo "  • 禁用 CPU 节能特性"
echo "  • 运行带负载的测试: sudo ./test_with_load.sh"
echo ""
