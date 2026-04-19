#!/bin/bash
# iperf3_advanced.sh - iperf3高级网络性能测试场景

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results/iperf3-advanced-$(date +%Y%m%d-%H%M%S)"

# 配置参数
SERVER_HOST="${1:-localhost}"
TEST_DURATION="${2:-10}"
IPERF3_PORT=5201

echo "========================================"
echo "iperf3 高级网络性能测试"
echo "========================================"
echo ""

mkdir -p "$RESULTS_DIR"

# 检查iperf3
if ! command -v iperf3 &> /dev/null; then
    echo "✗ 错误: iperf3未安装"
    echo ""
    echo "请先运行: $SCRIPT_DIR/test_iperf3.sh"
    exit 1
fi

# 检查iperf3服务器
if ! pgrep -x iperf3 > /dev/null; then
    echo "启动iperf3服务器..."
    iperf3 -s -D -p $IPERF3_PORT 2>/dev/null
    sleep 2
fi

echo "测试配置:"
echo "  服务器: $SERVER_HOST"
echo "  测试时长: ${TEST_DURATION}秒"
echo "  端口: $IPERF3_PORT"
echo ""

# 场景1: 不同TCP窗口大小测试
echo "场景 1: TCP窗口大小优化测试"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "TCP窗口大小优化测试"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  - 找到最优TCP窗口大小"
    echo "  - 优化高延迟网络性能"
    echo "  - 评估BDP影响"
    echo ""
    echo "窗口大小    带宽(Mbps)  性能提升"
    echo "----------  ---------  --------"
} | tee "$RESULTS_DIR/window_size.txt"

WINDOW_SIZES=(64K 128K 256K 512K 1M 2M 4M)

for window in "${WINDOW_SIZES[@]}"; do
    echo "测试窗口大小: $window"

    OUTPUT=$(iperf3 -c $SERVER_HOST -p $IPERF3_PORT -w $window \
        -t 5 -J 2>&1)

    BANDWIDTH=$(echo "$OUTPUT" | grep -o '"bits_per_second":[^,]*' | \
        grep -A1 '"sum_sent"' | tail -1 | cut -d: -f2)

    if [[ -n "$BANDWIDTH" ]]; then
        BANDWIDTH_MBPS=$(echo "scale=2; $BANDWIDTH / 1000000" | bc)

        if [[ -z "${WINDOW_BASELINE:-}" ]]; then
            WINDOW_BASELINE=$BANDWIDTH_MBPS
            IMPROVEMENT="-"
        else
            IMPROVEMENT=$(echo "scale=1; (($BANDWIDTH_MBPS - $WINDOW_BASELINE) / $WINDOW_BASELINE) * 100" | bc)
            IMPROVEMENT="${IMPROVEMENT}%"
        fi

        printf "%-10s  %-11s  %s\n" "$window" "$BANDWIDTH_MBPS" "$IMPROVEMENT" | \
            tee -a "$RESULTS_DIR/window_size.txt"
    fi
done

echo "" | tee -a "$RESULTS_DIR/window_size.txt"
echo ""

# 场景2: 不同MSS大小测试
echo "场景 2: MSS (Maximum Segment Size) 测试"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "MSS大小测试"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  - 评估不同MSS对性能的影响"
    echo "  - 优化MTU设置"
    echo "  - 减少分片"
    echo ""
    echo "MSS大小   带宽(Mbps)  性能比"
    echo "--------  ---------  ------"
} | tee "$RESULTS_DIR/mss_test.txt"

MSS_SIZES=(536 1024 1460 8960)

for mss in "${MSS_SIZES[@]}"; do
    echo "测试MSS: $mss bytes"

    OUTPUT=$(iperf3 -c $SERVER_HOST -p $IPERF3_PORT -M $mss \
        -t 5 -J 2>&1)

    BANDWIDTH=$(echo "$OUTPUT" | grep -o '"bits_per_second":[^,]*' | \
        grep -A1 '"sum_sent"' | tail -1 | cut -d: -f2)

    if [[ -n "$BANDWIDTH" ]]; then
        BANDWIDTH_MBPS=$(echo "scale=2; $BANDWIDTH / 1000000" | bc)

        if [[ -z "${MSS_BASELINE:-}" ]]; then
            MSS_BASELINE=$BANDWIDTH_MBPS
            RATIO="1.00"
        else
            RATIO=$(echo "scale=2; $BANDWIDTH_MBPS / $MSS_BASELINE" | bc)
        fi

        printf "%-8d  %-11s  %s\n" "$mss" "$BANDWIDTH_MBPS" "$RATIO" | \
            tee -a "$RESULTS_DIR/mss_test.txt"
    fi
done

echo "" | tee -a "$RESULTS_DIR/mss_test.txt"
echo ""

# 场景3: 不同拥塞控制算法对比
echo "场景 3: TCP拥塞控制算法对比"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "TCP拥塞控制算法对比"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  - 对比不同拥塞控制算法性能"
    echo "  - 找到最适合当前网络的算法"
    echo ""
    echo "算法        带宽(Mbps)  重传次数"
    echo "----------  ---------  --------"
} | tee "$RESULTS_DIR/congestion.txt"

# 获取可用的拥塞控制算法
if [[ -f /proc/sys/net/ipv4/tcp_available_congestion_control ]]; then
    AVAILABLE_CC=$(cat /proc/sys/net/ipv4/tcp_available_congestion_control)
    echo "可用的拥塞控制算法: $AVAILABLE_CC" | tee -a "$RESULTS_DIR/congestion.txt"
    echo "" | tee -a "$RESULTS_DIR/congestion.txt"

    for cc in cubic reno bbr; do
        if echo "$AVAILABLE_CC" | grep -q "$cc"; then
            echo "测试拥塞控制算法: $cc"

            OUTPUT=$(iperf3 -c $SERVER_HOST -p $IPERF3_PORT -C $cc \
                -t 5 -J 2>&1)

            BANDWIDTH=$(echo "$OUTPUT" | grep -o '"bits_per_second":[^,]*' | \
                grep -A1 '"sum_sent"' | tail -1 | cut -d: -f2)
            RETRANSMITS=$(echo "$OUTPUT" | grep -o '"retransmits":[^,]*' | \
                tail -1 | cut -d: -f2)

            if [[ -n "$BANDWIDTH" ]]; then
                BANDWIDTH_MBPS=$(echo "scale=2; $BANDWIDTH / 1000000" | bc)
                printf "%-10s  %-11s  %s\n" "$cc" "$BANDWIDTH_MBPS" "${RETRANSMITS:-0}" | \
                    tee -a "$RESULTS_DIR/congestion.txt"
            fi
        fi
    done
else
    echo "⚠ 无法获取可用的拥塞控制算法" | tee -a "$RESULTS_DIR/congestion.txt"
fi

echo "" | tee -a "$RESULTS_DIR/congestion.txt"
echo ""

# 场景4: UDP不同带宽目标测试
echo "场景 4: UDP不同带宽目标测试"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "UDP不同带宽目标测试"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  - 测试不同目标带宽下的丢包率"
    echo "  - 找到网络容量上限"
    echo "  - 评估QoS效果"
    echo ""
    echo "目标带宽   实际带宽   丢包率   抖动(ms)"
    echo "--------  --------  ------  --------"
} | tee "$RESULTS_DIR/udp_bandwidth.txt"

UDP_TARGETS=(10M 50M 100M 500M 1G)

for target in "${UDP_TARGETS[@]}"; do
    echo "测试目标带宽: $target"

    OUTPUT=$(iperf3 -c $SERVER_HOST -p $IPERF3_PORT -u -b $target \
        -t 5 -J 2>&1)

    BANDWIDTH=$(echo "$OUTPUT" | grep -o '"bits_per_second":[^,]*' | tail -1 | cut -d: -f2)
    JITTER=$(echo "$OUTPUT" | grep -o '"jitter_ms":[^,]*' | tail -1 | cut -d: -f2)
    LOST=$(echo "$OUTPUT" | grep -o '"lost_packets":[^,]*' | tail -1 | cut -d: -f2)
    TOTAL=$(echo "$OUTPUT" | grep -o '"packets":[^,]*' | tail -1 | cut -d: -f2)

    if [[ -n "$BANDWIDTH" ]]; then
        BANDWIDTH_MBPS=$(echo "scale=1; $BANDWIDTH / 1000000" | bc)
        LOSS_PERCENT=$(echo "scale=2; ($LOST / $TOTAL) * 100" | bc 2>/dev/null || echo "0")

        printf "%-8s  %7s M  %5s%%  %8s\n" \
            "$target" "$BANDWIDTH_MBPS" "$LOSS_PERCENT" "$JITTER" | \
            tee -a "$RESULTS_DIR/udp_bandwidth.txt"
    fi
done

echo "" | tee -a "$RESULTS_DIR/udp_bandwidth.txt"
echo ""

# 场景5: 长时间稳定性测试
echo "场景 5: 长时间稳定性测试（5分钟）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "长时间稳定性测试"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  - 评估长时间运行稳定性"
    echo "  - 检测性能波动"
    echo "  - 验证持续工作能力"
    echo ""
} | tee "$RESULTS_DIR/stability.txt"

echo "运行5分钟稳定性测试..."

if iperf3 -c $SERVER_HOST -p $IPERF3_PORT -t 300 -i 30 2>&1 | \
    tee -a "$RESULTS_DIR/stability.txt"; then

    {
        echo ""
        echo "分析:"
        echo "  检查带宽是否稳定"
        echo "  检查是否有重传增加"
        echo "  评估长期性能"
        echo ""
    } | tee -a "$RESULTS_DIR/stability.txt"
fi

echo ""

# 场景6: IPv6性能测试（如果支持）
echo "场景 6: IPv6性能测试"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "IPv6性能测试"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  - 对比IPv4和IPv6性能"
    echo "  - 评估IPv6部署影响"
    echo ""
} | tee "$RESULTS_DIR/ipv6_test.txt"

# 检查是否支持IPv6
if ping6 -c 1 ::1 &> /dev/null; then
    echo "IPv6支持检测: ✓" | tee -a "$RESULTS_DIR/ipv6_test.txt"

    # 尝试IPv6测试（需要服务器支持）
    echo "测试IPv6连接..."
    if iperf3 -c $SERVER_HOST -6 -p $IPERF3_PORT -t 5 2>&1 | \
        tee -a "$RESULTS_DIR/ipv6_test.txt"; then
        echo "✓ IPv6测试完成" | tee -a "$RESULTS_DIR/ipv6_test.txt"
    else
        echo "⚠ IPv6测试失败（服务器可能不支持IPv6）" | tee -a "$RESULTS_DIR/ipv6_test.txt"
    fi
else
    echo "⚠ 系统不支持IPv6" | tee -a "$RESULTS_DIR/ipv6_test.txt"
fi

echo "" | tee -a "$RESULTS_DIR/ipv6_test.txt"
echo ""

# 场景7: 零拷贝(Zero-Copy)测试
echo "场景 7: 零拷贝性能测试"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "零拷贝性能测试"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  - 评估零拷贝(sendfile)性能提升"
    echo "  - 对比标准传输和零拷贝"
    echo ""
} | tee "$RESULTS_DIR/zerocopy.txt"

echo "标准传输测试..."
OUTPUT_NORMAL=$(iperf3 -c $SERVER_HOST -p $IPERF3_PORT -t 5 -J 2>&1)
BW_NORMAL=$(echo "$OUTPUT_NORMAL" | grep -o '"bits_per_second":[^,]*' | \
    grep -A1 '"sum_sent"' | tail -1 | cut -d: -f2)
BW_NORMAL_MBPS=$(echo "scale=2; $BW_NORMAL / 1000000" | bc)

echo "  带宽: ${BW_NORMAL_MBPS} Mbps" | tee -a "$RESULTS_DIR/zerocopy.txt"

echo "零拷贝传输测试..."
OUTPUT_ZEROCOPY=$(iperf3 -c $SERVER_HOST -p $IPERF3_PORT -Z -t 5 -J 2>&1)
BW_ZEROCOPY=$(echo "$OUTPUT_ZEROCOPY" | grep -o '"bits_per_second":[^,]*' | \
    grep -A1 '"sum_sent"' | tail -1 | cut -d: -f2)
BW_ZEROCOPY_MBPS=$(echo "scale=2; $BW_ZEROCOPY / 1000000" | bc)

echo "  带宽: ${BW_ZEROCOPY_MBPS} Mbps" | tee -a "$RESULTS_DIR/zerocopy.txt"

if [[ -n "$BW_NORMAL" ]] && [[ -n "$BW_ZEROCOPY" ]]; then
    IMPROVEMENT=$(echo "scale=1; (($BW_ZEROCOPY - $BW_NORMAL) / $BW_NORMAL) * 100" | bc)
    {
        echo ""
        echo "性能提升: ${IMPROVEMENT}%"
        echo ""
    } | tee -a "$RESULTS_DIR/zerocopy.txt"
fi

echo ""

# 场景8: 逐秒统计测试
echo "场景 8: 逐秒带宽统计测试"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "逐秒带宽统计测试"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  - 观察带宽波动情况"
    echo "  - 检测性能抖动"
    echo "  - 分析网络稳定性"
    echo ""
} | tee "$RESULTS_DIR/interval_stats.txt"

echo "运行30秒测试，每秒输出统计..."
iperf3 -c $SERVER_HOST -p $IPERF3_PORT -t 30 -i 1 2>&1 | \
    tee -a "$RESULTS_DIR/interval_stats.txt"

echo ""

# 生成高级测试报告
{
    echo "iperf3高级测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo "目标服务器: $SERVER_HOST"
    echo "测试时长: ${TEST_DURATION}秒"
    echo ""

    echo "测试场景完成情况:"
    echo "  ✓ TCP窗口大小优化测试"
    echo "  ✓ MSS大小测试"
    echo "  ✓ 拥塞控制算法对比"
    echo "  ✓ UDP不同带宽目标测试"
    echo "  ✓ 长时间稳定性测试"
    echo "  ✓ IPv6性能测试"
    echo "  ✓ 零拷贝性能测试"
    echo "  ✓ 逐秒统计测试"
    echo ""

    echo "详细结果文件:"
    echo "  TCP窗口测试: $RESULTS_DIR/window_size.txt"
    echo "  MSS测试: $RESULTS_DIR/mss_test.txt"
    echo "  拥塞控制: $RESULTS_DIR/congestion.txt"
    echo "  UDP带宽: $RESULTS_DIR/udp_bandwidth.txt"
    echo "  稳定性测试: $RESULTS_DIR/stability.txt"
    echo "  IPv6测试: $RESULTS_DIR/ipv6_test.txt"
    echo "  零拷贝测试: $RESULTS_DIR/zerocopy.txt"
    echo "  逐秒统计: $RESULTS_DIR/interval_stats.txt"
    echo ""

    echo "关键发现:"
    echo ""

    # 最优窗口大小
    if [[ -f "$RESULTS_DIR/window_size.txt" ]]; then
        BEST_WINDOW=$(grep -E "^[0-9]" "$RESULTS_DIR/window_size.txt" | \
            sort -k2 -nr | head -1 | awk '{print $1}')
        if [[ -n "$BEST_WINDOW" ]]; then
            echo "  最优TCP窗口: $BEST_WINDOW"
        fi
    fi

    # 最优拥塞控制
    if [[ -f "$RESULTS_DIR/congestion.txt" ]]; then
        BEST_CC=$(grep -E "^[a-z]" "$RESULTS_DIR/congestion.txt" | \
            sort -k2 -nr | head -1 | awk '{print $1}')
        if [[ -n "$BEST_CC" ]]; then
            echo "  推荐拥塞控制: $BEST_CC"
        fi
    fi

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
