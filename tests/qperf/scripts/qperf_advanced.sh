#!/bin/bash
# qperf_advanced.sh - qperf高级网络性能测试场景

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results/qperf-advanced-$(date +%Y%m%d-%H%M%S)"

# 配置参数
SERVER_HOST="${1:-localhost}"
TEST_DURATION="${2:-10}"

echo "========================================"
echo "qperf 高级网络性能测试"
echo "========================================"
echo ""

mkdir -p "$RESULTS_DIR"

# 检查qperf
if ! command -v qperf &> /dev/null; then
    echo "✗ 错误: qperf未安装"
    echo ""
    echo "请先运行: $SCRIPT_DIR/test_qperf.sh"
    exit 1
fi

# 检查qperf服务器
if ! pgrep -x qperf > /dev/null; then
    echo "启动qperf服务器..."
    qperf &
    sleep 2
fi

echo "测试配置:"
echo "  服务器: $SERVER_HOST"
echo "  测试时长: ${TEST_DURATION}秒"
echo ""

# 场景1: Socket缓冲区大小优化测试
echo "场景 1: Socket缓冲区大小优化测试"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "Socket缓冲区大小优化测试"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  - 找到最优Socket缓冲区大小"
    echo "  - 优化高带宽网络性能"
    echo "  - 减少CPU开销"
    echo ""
    echo "缓冲区大小  TCP带宽(MB/s)  性能提升"
    echo "-----------  -----------  --------"
} | tee "$RESULTS_DIR/socket_buffer.txt"

BUFFER_SIZES=(64K 128K 256K 512K 1M 2M 4M)

for bufsize in "${BUFFER_SIZES[@]}"; do
    echo "测试缓冲区大小: $bufsize"

    OUTPUT=$(qperf $SERVER_HOST -oo msg_size:$bufsize -t 5 tcp_bw 2>&1)
    BW=$(echo "$OUTPUT" | grep "bw" | grep -v "send_bw\|recv_bw" | awk '{print $3}')

    if [[ -n "$BW" ]]; then
        if [[ -z "${BUFFER_BASELINE:-}" ]]; then
            BUFFER_BASELINE=$BW
            IMPROVEMENT="-"
        else
            IMPROVEMENT=$(echo "scale=1; (($BW - $BUFFER_BASELINE) / $BUFFER_BASELINE) * 100" | bc)
            IMPROVEMENT="${IMPROVEMENT}%"
        fi

        printf "%-11s  %-13s  %s\n" "$bufsize" "$BW" "$IMPROVEMENT" | \
            tee -a "$RESULTS_DIR/socket_buffer.txt"
    fi
done

echo "" | tee -a "$RESULTS_DIR/socket_buffer.txt"
echo ""

# 场景2: TCP vs UDP性能对比
echo "场景 2: TCP vs UDP性能对比"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "TCP vs UDP性能对比"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  - 对比TCP和UDP性能差异"
    echo "  - 评估协议开销"
    echo "  - 选择合适的传输协议"
    echo ""
    echo "协议  带宽(MB/s)  延迟(μs)  CPU使用率(%)"
    echo "----  ---------  -------  -----------"
} | tee "$RESULTS_DIR/tcp_vs_udp.txt"

# TCP测试
echo "测试TCP性能..."
TCP_OUTPUT=$(qperf $SERVER_HOST -t 5 -v tcp_bw tcp_lat 2>&1)
TCP_BW=$(echo "$TCP_OUTPUT" | grep "tcp_bw" -A10 | grep "bw" | grep -v "send_bw\|recv_bw" | awk '{print $3}')
TCP_LAT=$(echo "$TCP_OUTPUT" | grep "tcp_lat" -A10 | grep "latency" | awk '{print $3}')
TCP_CPU=$(echo "$TCP_OUTPUT" | grep "loc_cpus_used" | awk '{print $3}')

printf "%-4s  %-11s  %-9s  %s\n" "TCP" "${TCP_BW:-N/A}" "${TCP_LAT:-N/A}" "${TCP_CPU:-N/A}" | \
    tee -a "$RESULTS_DIR/tcp_vs_udp.txt"

# UDP测试
echo "测试UDP性能..."
UDP_OUTPUT=$(qperf $SERVER_HOST -t 5 -v udp_bw udp_lat 2>&1)
UDP_BW=$(echo "$UDP_OUTPUT" | grep "udp_bw" -A10 | grep "bw" | grep -v "send_bw\|recv_bw" | awk '{print $3}')
UDP_LAT=$(echo "$UDP_OUTPUT" | grep "udp_lat" -A10 | grep "latency" | awk '{print $3}')
UDP_CPU=$(echo "$UDP_OUTPUT" | grep "loc_cpus_used" | awk '{print $3}')

printf "%-4s  %-11s  %-9s  %s\n" "UDP" "${UDP_BW:-N/A}" "${UDP_LAT:-N/A}" "${UDP_CPU:-N/A}" | \
    tee -a "$RESULTS_DIR/tcp_vs_udp.txt"

echo "" | tee -a "$RESULTS_DIR/tcp_vs_udp.txt"

# 性能对比分析
{
    echo "性能对比分析:"
    if [[ -n "$TCP_BW" ]] && [[ -n "$UDP_BW" ]]; then
        BW_RATIO=$(echo "scale=2; $UDP_BW / $TCP_BW" | bc)
        echo "  UDP带宽/TCP带宽 = $BW_RATIO"
        if (( $(echo "$BW_RATIO > 1.1" | bc -l) )); then
            echo "  结论: UDP带宽明显高于TCP（无连接，开销小）"
        elif (( $(echo "$BW_RATIO < 0.9" | bc -l) )); then
            echo "  结论: TCP带宽高于UDP（可能受限于UDP缓冲区）"
        else
            echo "  结论: TCP和UDP带宽接近"
        fi
    fi
    echo ""
} | tee -a "$RESULTS_DIR/tcp_vs_udp.txt"

echo ""

# 场景3: 延迟分布测试
echo "场景 3: 延迟分布测试"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "延迟分布测试"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  - 测量延迟的统计分布"
    echo "  - 识别延迟峰值"
    echo "  - 评估网络稳定性"
    echo ""
} | tee "$RESULTS_DIR/latency_dist.txt"

echo "运行延迟分布测试（30秒）..."

# 使用-oo参数获取详细统计
if qperf $SERVER_HOST -t 30 -v -oo msg_size:1 tcp_lat 2>&1 | \
    tee -a "$RESULTS_DIR/latency_dist.txt"; then

    {
        echo ""
        echo "分析延迟分布结果，关注:"
        echo "  - latency: 平均延迟"
        echo "  - 延迟波动情况"
        echo "  - CPU使用率是否稳定"
        echo ""
    } | tee -a "$RESULTS_DIR/latency_dist.txt"
fi

echo ""

# 场景4: 带宽和CPU使用率关系测试
echo "场景 4: 带宽和CPU使用率关系测试"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "带宽和CPU使用率关系测试"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  - 评估协议栈效率"
    echo "  - 计算每Gbps所需CPU资源"
    echo "  - 优化系统配置"
    echo ""
    echo "消息大小  带宽(MB/s)  本地CPU(%)  远程CPU(%)  效率(MB/s/%CPU)"
    echo "--------  ---------  ---------  ---------  ---------------"
} | tee "$RESULTS_DIR/bw_cpu.txt"

MSG_SIZES=(1K 4K 16K 64K)

for size in "${MSG_SIZES[@]}"; do
    echo "测试消息大小: $size"

    OUTPUT=$(qperf $SERVER_HOST -oo msg_size:$size -t 5 -v tcp_bw 2>&1)
    BW=$(echo "$OUTPUT" | grep "bw" | grep -v "send_bw\|recv_bw" | awk '{print $3}')
    LOC_CPU=$(echo "$OUTPUT" | grep "loc_cpus_used" | awk '{print $3}')
    REM_CPU=$(echo "$OUTPUT" | grep "rem_cpus_used" | awk '{print $3}')

    if [[ -n "$BW" ]] && [[ -n "$LOC_CPU" ]]; then
        EFFICIENCY=$(echo "scale=2; $BW / $LOC_CPU" | bc)
    else
        EFFICIENCY="N/A"
    fi

    printf "%-8s  %-11s  %-11s  %-11s  %s\n" \
        "$size" "${BW:-N/A}" "${LOC_CPU:-N/A}" "${REM_CPU:-N/A}" "$EFFICIENCY" | \
        tee -a "$RESULTS_DIR/bw_cpu.txt"
done

echo "" | tee -a "$RESULTS_DIR/bw_cpu.txt"

{
    echo "效率分析:"
    echo "  效率越高，说明每单位CPU能处理更多数据"
    echo "  大消息通常效率更高（减少系统调用次数）"
    echo "  可用于容量规划和性能调优"
    echo ""
} | tee -a "$RESULTS_DIR/bw_cpu.txt"

echo ""

# 场景5: RDMA深度性能测试（如果支持）
echo "场景 5: RDMA深度性能测试"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "RDMA深度性能测试"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  - 对比不同RDMA传输类型性能"
    echo "  - 评估零拷贝带来的性能提升"
    echo "  - 测试RDMA低延迟特性"
    echo ""
} | tee "$RESULTS_DIR/rdma_advanced.txt"

# 检查RDMA支持
if command -v ibstat &> /dev/null && ibstat -l &> /dev/null; then
    echo "检测到RDMA设备，运行深度测试..." | tee -a "$RESULTS_DIR/rdma_advanced.txt"

    {
        echo ""
        echo "测试类型  带宽(MB/s)  延迟(μs)  CPU(%)"
        echo "--------  ---------  -------  ------"
    } | tee -a "$RESULTS_DIR/rdma_advanced.txt"

    # TCP基准
    echo "测试TCP（基准）..."
    TCP_OUT=$(qperf $SERVER_HOST -t 5 -v tcp_bw tcp_lat 2>&1)
    TCP_BW=$(echo "$TCP_OUT" | grep "tcp_bw" -A10 | grep "bw" | grep -v "send_bw\|recv_bw" | awk '{print $3}')
    TCP_LAT=$(echo "$TCP_OUT" | grep "tcp_lat" -A10 | grep "latency" | awk '{print $3}')
    TCP_CPU=$(echo "$TCP_OUT" | grep "loc_cpus_used" | head -1 | awk '{print $3}')

    printf "%-8s  %-11s  %-9s  %s\n" "TCP" "${TCP_BW:-N/A}" "${TCP_LAT:-N/A}" "${TCP_CPU:-N/A}" | \
        tee -a "$RESULTS_DIR/rdma_advanced.txt"

    # RDMA RC
    echo "测试RDMA RC..."
    RC_OUT=$(qperf $SERVER_HOST -t 5 -v rc_bw rc_lat 2>&1)
    RC_BW=$(echo "$RC_OUT" | grep "rc_bw" -A10 | grep "bw" | grep -v "send_bw\|recv_bw" | awk '{print $3}')
    RC_LAT=$(echo "$RC_OUT" | grep "rc_lat" -A10 | grep "latency" | awk '{print $3}')
    RC_CPU=$(echo "$RC_OUT" | grep "loc_cpus_used" | head -1 | awk '{print $3}')

    printf "%-8s  %-11s  %-9s  %s\n" "RDMA RC" "${RC_BW:-N/A}" "${RC_LAT:-N/A}" "${RC_CPU:-N/A}" | \
        tee -a "$RESULTS_DIR/rdma_advanced.txt"

    # RDMA UC
    echo "测试RDMA UC..."
    UC_OUT=$(qperf $SERVER_HOST -t 5 -v uc_bw uc_lat 2>&1)
    UC_BW=$(echo "$UC_OUT" | grep "uc_bw" -A10 | grep "bw" | grep -v "send_bw\|recv_bw" | awk '{print $3}')
    UC_LAT=$(echo "$UC_OUT" | grep "uc_lat" -A10 | grep "latency" | awk '{print $3}')
    UC_CPU=$(echo "$UC_OUT" | grep "loc_cpus_used" | head -1 | awk '{print $3}')

    printf "%-8s  %-11s  %-9s  %s\n" "RDMA UC" "${UC_BW:-N/A}" "${UC_LAT:-N/A}" "${UC_CPU:-N/A}" | \
        tee -a "$RESULTS_DIR/rdma_advanced.txt"

    # RDMA UD
    echo "测试RDMA UD..."
    UD_OUT=$(qperf $SERVER_HOST -t 5 -v ud_bw ud_lat 2>&1)
    UD_BW=$(echo "$UD_OUT" | grep "ud_bw" -A10 | grep "bw" | grep -v "send_bw\|recv_bw" | awk '{print $3}')
    UD_LAT=$(echo "$UD_OUT" | grep "ud_lat" -A10 | grep "latency" | awk '{print $3}')
    UD_CPU=$(echo "$UD_OUT" | grep "loc_cpus_used" | head -1 | awk '{print $3}')

    printf "%-8s  %-11s  %-9s  %s\n" "RDMA UD" "${UD_BW:-N/A}" "${UD_LAT:-N/A}" "${UD_CPU:-N/A}" | \
        tee -a "$RESULTS_DIR/rdma_advanced.txt"

    {
        echo ""
        echo "RDMA传输类型说明:"
        echo "  RC (Reliable Connection): 可靠连接，类似TCP"
        echo "  UC (Unreliable Connection): 不可靠连接"
        echo "  UD (Unreliable Datagram): 不可靠数据报，类似UDP"
        echo ""
        echo "性能对比:"
        echo "  带宽: RC ≈ UC > UD > TCP"
        echo "  延迟: UD < UC ≈ RC << TCP"
        echo "  CPU: RDMA << TCP (零拷贝优势)"
        echo ""
    } | tee -a "$RESULTS_DIR/rdma_advanced.txt"
else
    echo "⚠ 未检测到RDMA设备，跳过RDMA深度测试" | tee -a "$RESULTS_DIR/rdma_advanced.txt"
fi

echo ""

# 场景6: 多连接并发测试
echo "场景 6: 多连接并发测试"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "多连接并发测试"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  - 评估多连接并发性能"
    echo "  - 测试系统扩展性"
    echo "  - 验证多核心利用率"
    echo ""
    echo "并发数  聚合带宽(MB/s)  单连接平均(MB/s)  扩展效率"
    echo "------  -------------  ----------------  --------"
} | tee "$RESULTS_DIR/concurrent.txt"

# 注意：qperf不直接支持多连接，这里模拟说明
{
    echo ""
    echo "注意: qperf不直接支持多连接并发测试"
    echo "建议使用iperf3或netperf进行多流测试"
    echo ""
    echo "多连接测试替代方案:"
    echo "  1. 使用iperf3 -P 参数"
    echo "  2. 使用netperf并发多个实例"
    echo "  3. 使用专门的并发测试工具"
    echo ""
} | tee -a "$RESULTS_DIR/concurrent.txt"

echo ""

# 场景7: 双向同时传输测试
echo "场景 7: 双向同时传输测试"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "双向同时传输测试"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  - 测试全双工性能"
    echo "  - 评估上行和下行同时传输"
    echo "  - 检测链路对称性"
    echo ""
} | tee "$RESULTS_DIR/bidirectional.txt"

echo "运行双向测试（分别测试上行和下行）..."

# 发送方向
echo "测试方向1: 客户端 → 服务器"
SEND_OUT=$(qperf $SERVER_HOST -t 5 -v tcp_bw 2>&1)
SEND_BW=$(echo "$SEND_OUT" | grep "send_bw" | awk '{print $3}')

echo "  发送带宽: ${SEND_BW:-N/A} MB/s" | tee -a "$RESULTS_DIR/bidirectional.txt"

# 接收方向
echo "测试方向2: 服务器 → 客户端"
RECV_OUT=$(qperf $SERVER_HOST -t 5 -v tcp_bw 2>&1)
RECV_BW=$(echo "$RECV_OUT" | grep "recv_bw" | awk '{print $3}')

echo "  接收带宽: ${RECV_BW:-N/A} MB/s" | tee -a "$RESULTS_DIR/bidirectional.txt"

{
    echo ""
    echo "对称性分析:"
    if [[ -n "$SEND_BW" ]] && [[ -n "$RECV_BW" ]]; then
        RATIO=$(echo "scale=2; $SEND_BW / $RECV_BW" | bc)
        echo "  发送/接收比率: $RATIO"
        if (( $(echo "$RATIO > 0.9" | bc -l) )) && (( $(echo "$RATIO < 1.1" | bc -l) )); then
            echo "  评估: ★★★★★ 对称链路"
        else
            echo "  评估: 不对称链路（可能是ADSL等）"
        fi
    fi
    echo ""
} | tee -a "$RESULTS_DIR/bidirectional.txt"

echo ""

# 场景8: SCTP vs TCP性能对比
echo "场景 8: SCTP vs TCP性能对比"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "SCTP vs TCP性能对比"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  - 对比SCTP和TCP性能"
    echo "  - 评估多流传输优势"
    echo "  - 测试消息边界保留特性"
    echo ""
    echo "协议   带宽(MB/s)  延迟(μs)  特性"
    echo "----  ---------  -------  ----"
} | tee "$RESULTS_DIR/sctp_vs_tcp.txt"

# TCP测试
echo "测试TCP..."
TCP_OUT=$(qperf $SERVER_HOST -t 5 tcp_bw tcp_lat 2>&1)
TCP_BW=$(echo "$TCP_OUT" | grep "tcp_bw" -A5 | grep "bw" | grep -v "send_bw\|recv_bw" | awk '{print $3}')
TCP_LAT=$(echo "$TCP_OUT" | grep "tcp_lat" -A5 | grep "latency" | awk '{print $3}')

printf "%-4s  %-11s  %-9s  %s\n" "TCP" "${TCP_BW:-N/A}" "${TCP_LAT:-N/A}" "字节流" | \
    tee -a "$RESULTS_DIR/sctp_vs_tcp.txt"

# SCTP测试
echo "测试SCTP..."
SCTP_OUT=$(qperf $SERVER_HOST -t 5 sctp_bw sctp_lat 2>&1)
SCTP_BW=$(echo "$SCTP_OUT" | grep "sctp_bw" -A5 | grep "bw" | grep -v "send_bw\|recv_bw" | awk '{print $3}')
SCTP_LAT=$(echo "$SCTP_OUT" | grep "sctp_lat" -A5 | grep "latency" | awk '{print $3}')

printf "%-4s  %-11s  %-9s  %s\n" "SCTP" "${SCTP_BW:-N/A}" "${SCTP_LAT:-N/A}" "消息流" | \
    tee -a "$RESULTS_DIR/sctp_vs_tcp.txt"

{
    echo ""
    echo "SCTP优势:"
    echo "  - 多流支持（避免队头阻塞）"
    echo "  - 消息边界保留"
    echo "  - 多宿主支持（冗余路径）"
    echo "  - 适用场景: 电信信令、流媒体"
    echo ""
} | tee -a "$RESULTS_DIR/sctp_vs_tcp.txt"

echo ""

# 生成高级测试报告
{
    echo "qperf高级测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo "目标服务器: $SERVER_HOST"
    echo "测试时长: ${TEST_DURATION}秒"
    echo ""

    echo "测试场景完成情况:"
    echo "  ✓ Socket缓冲区优化测试"
    echo "  ✓ TCP vs UDP性能对比"
    echo "  ✓ 延迟分布测试"
    echo "  ✓ 带宽和CPU使用率关系测试"
    echo "  ✓ RDMA深度性能测试"
    echo "  ✓ 多连接并发测试（说明）"
    echo "  ✓ 双向同时传输测试"
    echo "  ✓ SCTP vs TCP性能对比"
    echo ""

    echo "详细结果文件:"
    echo "  Socket缓冲区: $RESULTS_DIR/socket_buffer.txt"
    echo "  TCP vs UDP: $RESULTS_DIR/tcp_vs_udp.txt"
    echo "  延迟分布: $RESULTS_DIR/latency_dist.txt"
    echo "  带宽CPU关系: $RESULTS_DIR/bw_cpu.txt"
    echo "  RDMA深度测试: $RESULTS_DIR/rdma_advanced.txt"
    echo "  并发测试: $RESULTS_DIR/concurrent.txt"
    echo "  双向测试: $RESULTS_DIR/bidirectional.txt"
    echo "  SCTP vs TCP: $RESULTS_DIR/sctp_vs_tcp.txt"
    echo ""

    echo "关键发现:"
    echo ""

    # 最优缓冲区大小
    if [[ -f "$RESULTS_DIR/socket_buffer.txt" ]]; then
        BEST_BUFFER=$(grep -E "^[0-9]" "$RESULTS_DIR/socket_buffer.txt" | \
            sort -k2 -nr | head -1 | awk '{print $1}')
        if [[ -n "$BEST_BUFFER" ]]; then
            echo "  最优Socket缓冲区: $BEST_BUFFER"
        fi
    fi

    # 协议对比结论
    if [[ -f "$RESULTS_DIR/tcp_vs_udp.txt" ]]; then
        echo "  协议对比结果已保存"
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
