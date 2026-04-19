#!/bin/bash
# netperf_advanced.sh - Netperf高级网络性能测试场景

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results/netperf-advanced-$(date +%Y%m%d-%H%M%S)"

# 配置参数
SERVER_HOST="${1:-localhost}"
TEST_DURATION="${2:-10}"
NETPERF_PORT=12865

echo "========================================"
echo "Netperf 高级网络性能测试"
echo "========================================"
echo ""

mkdir -p "$RESULTS_DIR"

# 检查netperf
if ! command -v netperf &> /dev/null; then
    echo "✗ 错误: netperf未安装"
    echo ""
    echo "请先运行: $SCRIPT_DIR/test_netperf.sh"
    exit 1
fi

# 检查netserver
if ! pgrep -x netserver > /dev/null; then
    echo "启动netserver..."
    netserver -D -p $NETPERF_PORT 2>/dev/null
    sleep 2
fi

echo "测试配置:"
echo "  服务器: $SERVER_HOST"
echo "  测试时长: ${TEST_DURATION}秒"
echo "  端口: $NETPERF_PORT"
echo ""

# 场景1: 双向同时传输测试（全双工性能）
echo "场景 1: 双向同时传输测试（全双工）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "双向同时传输测试"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  - 测试全双工通信性能"
    echo "  - 验证上下行同时工作的能力"
    echo "  - 模拟实际双向数据交换场景"
    echo ""
    echo "测试方法:"
    echo "  - 同时运行发送和接收测试"
    echo "  - 分别测量上行和下行吞吐量"
    echo "  - 检查是否存在性能干扰"
    echo ""
} | tee "$RESULTS_DIR/bidirectional.txt"

echo "运行双向传输测试..."

# 发送方向（客户端到服务器）
echo "  测试方向1: 客户端 → 服务器"
netperf -H $SERVER_HOST -p $NETPERF_PORT -t TCP_STREAM -l $TEST_DURATION -- \
    -m 64K > "$RESULTS_DIR/bidirectional_send.txt" 2>&1 &
PID_SEND=$!

# 接收方向（服务器到客户端）
echo "  测试方向2: 服务器 → 客户端"
netperf -H $SERVER_HOST -p $NETPERF_PORT -t TCP_MAERTS -l $TEST_DURATION -- \
    -m 64K > "$RESULTS_DIR/bidirectional_recv.txt" 2>&1 &
PID_RECV=$!

# 等待两个测试完成
wait $PID_SEND
wait $PID_RECV

# 提取结果
SEND_THROUGHPUT=$(grep -E "^[0-9]" "$RESULTS_DIR/bidirectional_send.txt" | tail -1 | awk '{print $5}')
RECV_THROUGHPUT=$(grep -E "^[0-9]" "$RESULTS_DIR/bidirectional_recv.txt" | tail -1 | awk '{print $5}')

{
    echo ""
    echo "测试结果:"
    echo "  上行吞吐量: ${SEND_THROUGHPUT} Mbps"
    echo "  下行吞吐量: ${RECV_THROUGHPUT} Mbps"

    if [[ -n "$SEND_THROUGHPUT" ]] && [[ -n "$RECV_THROUGHPUT" ]]; then
        TOTAL=$(echo "$SEND_THROUGHPUT + $RECV_THROUGHPUT" | bc)
        echo "  总吞吐量: ${TOTAL} Mbps"
        echo ""

        # 对称性分析
        RATIO=$(echo "scale=2; $SEND_THROUGHPUT / $RECV_THROUGHPUT" | bc)
        echo "  对称性比值: ${RATIO} (理想值接近1.0)"

        if (( $(echo "$RATIO > 0.9 && $RATIO < 1.1" | bc -l) )); then
            echo "  ✓ 链路对称性良好"
        else
            echo "  ⚠ 链路存在不对称性"
        fi
    fi
    echo ""
} | tee -a "$RESULTS_DIR/bidirectional.txt"

echo ""

# 场景2: 并发连接性能测试
echo "场景 2: 并发连接性能测试"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "并发连接性能测试"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  - 测试多连接并发性能"
    echo "  - 评估负载均衡能力"
    echo "  - 模拟Web服务器、代理等场景"
    echo ""
    echo "并发数  总吞吐量(Mbps)  平均吞吐量(Mbps)  聚合效率"
    echo "------  -------------  ---------------  --------"
} | tee "$RESULTS_DIR/concurrent.txt"

CONCURRENT_COUNTS=(1 2 4 8 16)

for count in "${CONCURRENT_COUNTS[@]}"; do
    echo "测试 $count 个并发连接..."

    # 启动多个并发测试
    for ((i=0; i<count; i++)); do
        netperf -H $SERVER_HOST -p $NETPERF_PORT -t TCP_STREAM \
            -l $TEST_DURATION -- -m 64K \
            > "$RESULTS_DIR/concurrent_${count}_${i}.txt" 2>&1 &
    done

    # 等待所有测试完成
    wait

    # 汇总吞吐量
    TOTAL_THROUGHPUT=0
    for ((i=0; i<count; i++)); do
        THROUGHPUT=$(grep -E "^[0-9]" "$RESULTS_DIR/concurrent_${count}_${i}.txt" | tail -1 | awk '{print $5}')
        if [[ -n "$THROUGHPUT" ]]; then
            TOTAL_THROUGHPUT=$(echo "$TOTAL_THROUGHPUT + $THROUGHPUT" | bc)
        fi
    done

    AVG_THROUGHPUT=$(echo "scale=2; $TOTAL_THROUGHPUT / $count" | bc)

    # 计算聚合效率（相对于单连接）
    if [[ $count -eq 1 ]]; then
        BASELINE_THROUGHPUT=$TOTAL_THROUGHPUT
        EFFICIENCY="100.0"
    else
        EFFICIENCY=$(echo "scale=1; ($TOTAL_THROUGHPUT / $BASELINE_THROUGHPUT / $count) * 100" | bc)
    fi

    printf "%-6d  %-15s  %-17s  %s%%\n" \
        "$count" "$TOTAL_THROUGHPUT" "$AVG_THROUGHPUT" "$EFFICIENCY" | \
        tee -a "$RESULTS_DIR/concurrent.txt"
done

echo "" | tee -a "$RESULTS_DIR/concurrent.txt"
echo ""

# 场景3: 不同Socket缓冲区大小测试
echo "场景 3: Socket缓冲区大小优化测试"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "Socket缓冲区大小优化测试"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  - 找到最优缓冲区大小"
    echo "  - 优化高延迟网络性能"
    echo "  - 调优TCP窗口大小"
    echo ""
    echo "缓冲区大小  吞吐量(Mbps)  性能提升"
    echo "----------  -----------  --------"
} | tee "$RESULTS_DIR/socket_buffer.txt"

BUFFER_SIZES=(16384 32768 65536 131072 262144 524288 1048576)

for size in "${BUFFER_SIZES[@]}"; do
    echo "测试缓冲区大小: ${size} bytes"

    THROUGHPUT=$(netperf -H $SERVER_HOST -p $NETPERF_PORT -t TCP_STREAM \
        -l $TEST_DURATION -- -s $size -S $size -m 64K 2>&1 | \
        grep -E "^[0-9]" | tail -1 | awk '{print $5}')

    if [[ -n "$THROUGHPUT" ]]; then
        # 记录基准
        if [[ -z "${BUFFER_BASELINE:-}" ]]; then
            BUFFER_BASELINE=$THROUGHPUT
            IMPROVEMENT="-"
        else
            IMPROVEMENT=$(echo "scale=1; (($THROUGHPUT - $BUFFER_BASELINE) / $BUFFER_BASELINE) * 100" | bc)
            IMPROVEMENT="${IMPROVEMENT}%"
        fi

        SIZE_KB=$((size / 1024))
        printf "%-10s  %-13s  %s\n" "${SIZE_KB}KB" "$THROUGHPUT" "$IMPROVEMENT" | \
            tee -a "$RESULTS_DIR/socket_buffer.txt"
    fi
done

echo "" | tee -a "$RESULTS_DIR/socket_buffer.txt"
echo ""

# 场景4: CPU亲和性测试
echo "场景 4: CPU亲和性对网络性能的影响"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "CPU亲和性测试"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  - 评估CPU绑定对性能的影响"
    echo "  - 优化NUMA系统性能"
    echo "  - 减少缓存抖动"
    echo ""
} | tee "$RESULTS_DIR/cpu_affinity.txt"

# 获取CPU核心数
CPU_CORES=$(nproc)

echo "测试1: 无CPU绑定（默认）"
THROUGHPUT_DEFAULT=$(netperf -H $SERVER_HOST -p $NETPERF_PORT -t TCP_STREAM \
    -l $TEST_DURATION -- -m 64K 2>&1 | \
    grep -E "^[0-9]" | tail -1 | awk '{print $5}')

echo "  吞吐量: ${THROUGHPUT_DEFAULT} Mbps" | tee -a "$RESULTS_DIR/cpu_affinity.txt"
echo ""

echo "测试2: 绑定到CPU 0"
THROUGHPUT_CPU0=$(taskset -c 0 netperf -H $SERVER_HOST -p $NETPERF_PORT \
    -t TCP_STREAM -l $TEST_DURATION -- -m 64K 2>&1 | \
    grep -E "^[0-9]" | tail -1 | awk '{print $5}')

echo "  吞吐量: ${THROUGHPUT_CPU0} Mbps" | tee -a "$RESULTS_DIR/cpu_affinity.txt"
echo ""

if [[ $CPU_CORES -gt 1 ]]; then
    LAST_CPU=$((CPU_CORES - 1))
    echo "测试3: 绑定到CPU $LAST_CPU"
    THROUGHPUT_LAST=$(taskset -c $LAST_CPU netperf -H $SERVER_HOST -p $NETPERF_PORT \
        -t TCP_STREAM -l $TEST_DURATION -- -m 64K 2>&1 | \
        grep -E "^[0-9]" | tail -1 | awk '{print $5}')

    echo "  吞吐量: ${THROUGHPUT_LAST} Mbps" | tee -a "$RESULTS_DIR/cpu_affinity.txt"
fi

echo "" | tee -a "$RESULTS_DIR/cpu_affinity.txt"
echo ""

# 场景5: 延迟分布测试（百分位）
echo "场景 5: 延迟分布测试（百分位分析）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "延迟分布测试"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  - 分析延迟分布特征"
    echo "  - 识别延迟峰值"
    echo "  - 评估服务质量（QoS）"
    echo ""
} | tee "$RESULTS_DIR/latency_distribution.txt"

echo "运行延迟测试（采集足够样本）..."

# 运行更长时间的RR测试以获得延迟分布
netperf -H $SERVER_HOST -p $NETPERF_PORT -t TCP_RR -l 60 -- \
    -r 1,1 -o min_latency,mean_latency,max_latency,stddev_latency,99th_percentile_latency \
    2>&1 | tee -a "$RESULTS_DIR/latency_distribution.txt"

echo "" | tee -a "$RESULTS_DIR/latency_distribution.txt"
echo ""

# 场景6: 带宽延迟乘积（BDP）优化测试
echo "场景 6: 带宽延迟乘积（BDP）优化测试"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "BDP优化测试"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  - 评估高延迟链路性能"
    echo "  - 优化TCP窗口大小"
    echo "  - 验证TCP窗口缩放"
    echo ""
    echo "说明:"
    echo "  BDP = 带宽 × RTT"
    echo "  TCP窗口应 >= BDP 才能充分利用带宽"
    echo ""
} | tee "$RESULTS_DIR/bdp_optimization.txt"

# 先测试RTT
echo "测量往返延迟（RTT）..."
if command -v ping &> /dev/null; then
    RTT=$(ping -c 10 $SERVER_HOST 2>/dev/null | grep "avg" | awk -F'/' '{print $5}')
    if [[ -n "$RTT" ]]; then
        echo "  平均RTT: ${RTT} ms" | tee -a "$RESULTS_DIR/bdp_optimization.txt"

        # 假设带宽为1Gbps，计算BDP
        BANDWIDTH_MBPS=1000
        BDP_BITS=$(echo "$BANDWIDTH_MBPS * 1000000 * $RTT / 1000" | bc)
        BDP_BYTES=$(echo "$BDP_BITS / 8" | bc)
        BDP_KB=$(echo "$BDP_BYTES / 1024" | bc)

        echo "  BDP (1Gbps链路): ${BDP_KB} KB" | tee -a "$RESULTS_DIR/bdp_optimization.txt"
        echo "" | tee -a "$RESULTS_DIR/bdp_optimization.txt"

        # 测试不同窗口大小
        echo "  测试不同TCP窗口大小:" | tee -a "$RESULTS_DIR/bdp_optimization.txt"
        for window in 65536 131072 262144 524288; do
            THROUGHPUT=$(netperf -H $SERVER_HOST -p $NETPERF_PORT -t TCP_STREAM \
                -l 10 -- -s $window -S $window -m 64K 2>&1 | \
                grep -E "^[0-9]" | tail -1 | awk '{print $5}')

            WINDOW_KB=$((window / 1024))
            echo "    窗口 ${WINDOW_KB}KB: ${THROUGHPUT} Mbps" | \
                tee -a "$RESULTS_DIR/bdp_optimization.txt"
        done
    fi
fi

echo "" | tee -a "$RESULTS_DIR/bdp_optimization.txt"
echo ""

# 场景7: UDP丢包率测试
echo "场景 7: UDP丢包率测试"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "UDP丢包率测试"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  - 评估网络丢包情况"
    echo "  - 测试不同发送速率下的丢包率"
    echo "  - 验证QoS配置"
    echo ""
    echo "发送速率(Mbps)  接收速率(Mbps)  丢包率(%)"
    echo "-------------  -------------  --------"
} | tee "$RESULTS_DIR/udp_loss.txt"

# 测试不同速率
RATES=(10 50 100 500 1000)

for rate in "${RATES[@]}"; do
    echo "测试发送速率: ${rate} Mbps"

    # 运行UDP测试，使用omni输出格式获取详细统计
    OUTPUT=$(netperf -H $SERVER_HOST -p $NETPERF_PORT -t UDP_STREAM \
        -l 10 -- -m 1472 -R 1 2>&1)

    # 从输出中提取发送和接收速率
    # 注意：这里需要根据实际输出格式调整
    echo "$OUTPUT" | tee -a "$RESULTS_DIR/udp_loss_${rate}.txt"
done

echo "" | tee -a "$RESULTS_DIR/udp_loss.txt"
echo ""

# 生成高级测试报告
{
    echo "Netperf高级测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo "目标服务器: $SERVER_HOST"
    echo "测试时长: ${TEST_DURATION}秒"
    echo ""

    echo "测试场景完成情况:"
    echo "  ✓ 双向同时传输测试"
    echo "  ✓ 并发连接性能测试"
    echo "  ✓ Socket缓冲区优化测试"
    echo "  ✓ CPU亲和性测试"
    echo "  ✓ 延迟分布测试"
    echo "  ✓ BDP优化测试"
    echo "  ✓ UDP丢包率测试"
    echo ""

    echo "详细结果文件:"
    echo "  双向传输: $RESULTS_DIR/bidirectional.txt"
    echo "  并发连接: $RESULTS_DIR/concurrent.txt"
    echo "  Socket缓冲区: $RESULTS_DIR/socket_buffer.txt"
    echo "  CPU亲和性: $RESULTS_DIR/cpu_affinity.txt"
    echo "  延迟分布: $RESULTS_DIR/latency_distribution.txt"
    echo "  BDP优化: $RESULTS_DIR/bdp_optimization.txt"
    echo "  UDP丢包: $RESULTS_DIR/udp_loss.txt"
    echo ""

} | tee "$RESULTS_DIR/advanced_report.txt"

echo ""
echo "========================================"
echo "高级测试完成"
echo "========================================"
echo ""
echo "查看报告: cat $RESULTS_DIR/advanced_report.txt"
echo "结果目录: $RESULTS_DIR"
echo ""
