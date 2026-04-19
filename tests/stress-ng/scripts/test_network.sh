#!/bin/bash
# test_network.sh - stress-ng 网络子系统专项测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/../results/network_test_$(date +%Y%m%d_%H%M%S)"

mkdir -p "$OUTPUT_DIR"

DURATION=60  # 每个测试60秒
CPU_CORES=$(nproc)

# 前置检查
if [[ $EUID -ne 0 ]]; then
   echo "错误: 此脚本需要 root 权限"
   echo "使用: sudo $0"
   exit 1
fi

echo "=========================================="
echo "stress-ng 网络子系统专项测试"
echo "=========================================="
echo ""
echo "配置:"
echo "  CPU 核心: $CPU_CORES"
echo "  测试时长: ${DURATION}秒/测试"
echo "  输出目录: $OUTPUT_DIR"
echo "=========================================="
echo ""

# 检查工具
if ! command -v stress-ng &> /dev/null; then
    echo "错误: stress-ng 未安装"
    echo "安装: sudo apt-get install stress-ng"
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
    echo ""

    # 网络接口信息
    echo "网络接口:"
    ip -brief addr show
    echo ""

    # TCP参数
    echo "关键TCP参数:"
    sysctl net.core.somaxconn net.core.netdev_max_backlog \
           net.ipv4.tcp_fin_timeout net.ipv4.tcp_tw_reuse 2>/dev/null
    echo ""

    # 当前连接统计
    echo "当前连接统计:"
    ss -s
    echo ""
} | tee "$OUTPUT_DIR/system_info.txt"

# ========== 测试1: TCP Socket 压力测试 ==========
echo "=========================================="
echo "测试1: TCP Socket 压力测试"
echo "=========================================="
echo ""
echo "测试配置:"
echo "  • Worker数: 4"
echo "  • 协议: TCP (loopback)"
echo "  • 测试重点: TCP协议栈性能"
echo ""

stress-ng --sock 4 \
    --sock-domain ipv4 \
    --sock-type stream \
    --timeout ${DURATION}s \
    --metrics-brief \
    --times \
    2>&1 | tee "$OUTPUT_DIR/test1_tcp_socket.log"

echo ""
echo "✓ TCP Socket测试完成"
echo ""
sleep 5

# ========== 测试2: UDP Socket 压力测试 ==========
echo "=========================================="
echo "测试2: UDP Socket 压力测试"
echo "=========================================="
echo ""
echo "测试配置:"
echo "  • Worker数: 4"
echo "  • 协议: UDP (loopback)"
echo "  • 测试重点: UDP协议栈性能"
echo ""

stress-ng --udp 4 \
    --udp-domain ipv4 \
    --timeout ${DURATION}s \
    --metrics-brief \
    --times \
    2>&1 | tee "$OUTPUT_DIR/test2_udp_socket.log"

echo ""
echo "✓ UDP Socket测试完成"
echo ""
sleep 5

# ========== 测试3: Unix Domain Socket 测试 ==========
echo "=========================================="
echo "测试3: Unix Domain Socket 测试"
echo "=========================================="
echo ""
echo "测试配置:"
echo "  • Worker数: 4"
echo "  • 类型: Unix Domain Socket"
echo "  • 测试重点: 本地IPC性能"
echo ""

stress-ng --sockfd 4 \
    --timeout ${DURATION}s \
    --metrics-brief \
    --times \
    2>&1 | tee "$OUTPUT_DIR/test3_unix_socket.log"

echo ""
echo "✓ Unix Domain Socket测试完成"
echo ""
sleep 5

# ========== 测试4: sockpair 套接字对测试 ==========
echo "=========================================="
echo "测试4: socketpair 套接字对测试"
echo "=========================================="
echo ""
echo "测试配置:"
echo "  • Worker数: $CPU_CORES"
echo "  • 测试重点: socketpair IPC性能"
echo ""

stress-ng --sockpair $CPU_CORES \
    --timeout ${DURATION}s \
    --metrics-brief \
    --times \
    2>&1 | tee "$OUTPUT_DIR/test4_sockpair.log"

echo ""
echo "✓ socketpair测试完成"
echo ""
sleep 5

# ========== 测试5: netdev 网络设备压力测试 ==========
echo "=========================================="
echo "测试5: netdev 网络设备压力测试"
echo "=========================================="
echo ""
echo "测试配置:"
echo "  • Worker数: 2"
echo "  • 测试重点: 网络设备吞吐量"
echo ""

stress-ng --netdev 2 \
    --timeout ${DURATION}s \
    --metrics-brief \
    --times \
    2>&1 | tee "$OUTPUT_DIR/test5_netdev.log"

echo ""
echo "✓ netdev测试完成"
echo ""
sleep 5

# ========== 测试6: TCP Flood 压力测试 ==========
echo "=========================================="
echo "测试6: TCP连接洪水测试"
echo "=========================================="
echo ""
echo "测试配置:"
echo "  • Worker数: 4"
echo "  • 测试重点: 快速建立/销毁TCP连接"
echo ""

stress-ng --sockfd 4 \
    --sockfd-port 9000 \
    --timeout ${DURATION}s \
    --metrics-brief \
    --times \
    2>&1 | tee "$OUTPUT_DIR/test6_tcp_flood.log"

echo ""
echo "✓ TCP连接洪水测试完成"
echo ""
sleep 5

# ========== 测试7: UDP Flood 压力测试 ==========
echo "=========================================="
echo "测试7: UDP数据包洪水测试"
echo "=========================================="
echo ""
echo "测试配置:"
echo "  • Worker数: 4"
echo "  • 数据包大小: 1024 bytes"
echo "  • 测试重点: UDP数据包处理能力"
echo ""

stress-ng --udp-flood 4 \
    --udp-flood-domain ipv4 \
    --timeout ${DURATION}s \
    --metrics-brief \
    --times \
    2>&1 | tee "$OUTPUT_DIR/test7_udp_flood.log"

echo ""
echo "✓ UDP洪水测试完成"
echo ""
sleep 5

# ========== 测试8: ICMP Echo (ping) 压力测试 ==========
echo "=========================================="
echo "测试8: ICMP Echo 压力测试"
echo "=========================================="
echo ""
echo "测试配置:"
echo "  • Worker数: 2"
echo "  • 测试重点: ICMP协议处理"
echo ""

stress-ng --icmp-flood 2 \
    --timeout ${DURATION}s \
    --metrics-brief \
    --times \
    2>&1 | tee "$OUTPUT_DIR/test8_icmp_flood.log"

echo ""
echo "✓ ICMP压力测试完成"
echo ""
sleep 5

# ========== 测试9: sendfile 零拷贝传输测试 ==========
echo "=========================================="
echo "测试9: sendfile 零拷贝传输测试"
echo "=========================================="
echo ""
echo "测试配置:"
echo "  • Worker数: 4"
echo "  • 文件大小: 16MB"
echo "  • 测试重点: 零拷贝网络传输"
echo ""

stress-ng --sendfile 4 \
    --sendfile-size 16M \
    --timeout ${DURATION}s \
    --metrics-brief \
    --times \
    2>&1 | tee "$OUTPUT_DIR/test9_sendfile.log"

echo ""
echo "✓ sendfile测试完成"
echo ""

# ========== 生成综合报告 ==========
echo "=========================================="
echo "生成综合测试报告"
echo "=========================================="
echo ""

{
    echo "stress-ng 网络子系统测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo "系统: $(hostname) - $(uname -r)"
    echo "CPU 核心: $CPU_CORES"
    echo ""

    echo "测试结果汇总"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # 提取各测试的bogo ops/s
    extract_metric() {
        local logfile=$1
        local stressor=$2

        if [ -f "$logfile" ]; then
            # 提取bogo ops/s (real time)
            bogo_real=$(grep "^stress-ng: info:" "$logfile" | grep "$stressor" | awk '{print $(NF-1)}')

            if [ -n "$bogo_real" ]; then
                echo "$bogo_real"
            else
                echo "N/A"
            fi
        else
            echo "N/A"
        fi
    }

    printf "%-30s %20s %s\n" "测试项" "bogo ops/s (real)" "性能评级"
    echo "────────────────────────────────────────────────────────────────────────"

    # 评级函数
    get_network_rating() {
        local test_type=$1
        local bogo_ops=$2

        if [ "$bogo_ops" = "N/A" ]; then
            echo "N/A"
            return
        fi

        case $test_type in
            tcp)
                if (( $(echo "$bogo_ops > 100000" | bc -l) )); then
                    echo "★★★★★ 优秀"
                elif (( $(echo "$bogo_ops > 50000" | bc -l) )); then
                    echo "★★★★☆ 良好"
                elif (( $(echo "$bogo_ops > 10000" | bc -l) )); then
                    echo "★★★☆☆ 一般"
                else
                    echo "★★☆☆☆ 较差"
                fi
                ;;
            udp)
                if (( $(echo "$bogo_ops > 150000" | bc -l) )); then
                    echo "★★★★★ 优秀"
                elif (( $(echo "$bogo_ops > 80000" | bc -l) )); then
                    echo "★★★★☆ 良好"
                elif (( $(echo "$bogo_ops > 30000" | bc -l) )); then
                    echo "★★★☆☆ 一般"
                else
                    echo "★★☆☆☆ 较差"
                fi
                ;;
            unix)
                if (( $(echo "$bogo_ops > 200000" | bc -l) )); then
                    echo "★★★★★ 优秀"
                elif (( $(echo "$bogo_ops > 100000" | bc -l) )); then
                    echo "★★★★☆ 良好"
                elif (( $(echo "$bogo_ops > 50000" | bc -l) )); then
                    echo "★★★☆☆ 一般"
                else
                    echo "★★☆☆☆ 较差"
                fi
                ;;
            *)
                echo "参考INTERPRETATION_GUIDE.md"
                ;;
        esac
    }

    # TCP Socket测试
    tcp_ops=$(extract_metric "$OUTPUT_DIR/test1_tcp_socket.log" "sock")
    printf "%-30s %20s %s\n" "TCP Socket" "$tcp_ops" "$(get_network_rating tcp $tcp_ops)"

    # UDP Socket测试
    udp_ops=$(extract_metric "$OUTPUT_DIR/test2_udp_socket.log" "udp")
    printf "%-30s %20s %s\n" "UDP Socket" "$udp_ops" "$(get_network_rating udp $udp_ops)"

    # Unix Domain Socket测试
    unix_ops=$(extract_metric "$OUTPUT_DIR/test3_unix_socket.log" "sockfd")
    printf "%-30s %20s %s\n" "Unix Domain Socket" "$unix_ops" "$(get_network_rating unix $unix_ops)"

    # socketpair测试
    sockpair_ops=$(extract_metric "$OUTPUT_DIR/test4_sockpair.log" "sockpair")
    printf "%-30s %20s %s\n" "socketpair" "$sockpair_ops" "参考INTERPRETATION_GUIDE.md"

    # netdev测试
    netdev_ops=$(extract_metric "$OUTPUT_DIR/test5_netdev.log" "netdev")
    printf "%-30s %20s %s\n" "netdev网络设备" "$netdev_ops" "参考INTERPRETATION_GUIDE.md"

    # TCP Flood测试
    tcpflood_ops=$(extract_metric "$OUTPUT_DIR/test6_tcp_flood.log" "sockfd")
    printf "%-30s %20s %s\n" "TCP连接洪水" "$tcpflood_ops" "参考INTERPRETATION_GUIDE.md"

    # UDP Flood测试
    udpflood_ops=$(extract_metric "$OUTPUT_DIR/test7_udp_flood.log" "udp-flood")
    printf "%-30s %20s %s\n" "UDP数据包洪水" "$udpflood_ops" "参考INTERPRETATION_GUIDE.md"

    # ICMP Flood测试
    icmp_ops=$(extract_metric "$OUTPUT_DIR/test8_icmp_flood.log" "icmp-flood")
    printf "%-30s %20s %s\n" "ICMP Echo洪水" "$icmp_ops" "参考INTERPRETATION_GUIDE.md"

    # sendfile测试
    sendfile_ops=$(extract_metric "$OUTPUT_DIR/test9_sendfile.log" "sendfile")
    printf "%-30s %20s %s\n" "sendfile零拷贝" "$sendfile_ops" "参考INTERPRETATION_GUIDE.md"

    echo ""

    echo "关键发现"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # 分析网络吞吐量
    if [ -f "$OUTPUT_DIR/test5_netdev.log" ]; then
        throughput=$(grep "Gbps\\|Mbps" "$OUTPUT_DIR/test5_netdev.log" | awk '{print $2, $3}' | head -1)
        if [ -n "$throughput" ]; then
            echo "• 网络吞吐量: $throughput"
            echo ""
        fi
    fi

    # 协议性能对比
    echo "• 协议性能对比:"
    echo "  - TCP Socket: $tcp_ops ops/s"
    echo "  - UDP Socket: $udp_ops ops/s"
    echo "  - Unix Domain Socket: $unix_ops ops/s"
    echo ""

    if [ "$unix_ops" != "N/A" ] && [ "$tcp_ops" != "N/A" ]; then
        if (( $(echo "$unix_ops > $tcp_ops" | bc -l) )); then
            ratio=$(echo "scale=2; $unix_ops / $tcp_ops" | bc)
            echo "  分析: Unix Socket比TCP快 ${ratio}x，适合本地IPC"
        fi
    fi
    echo ""

    # 检查网络错误
    echo "• 网络错误统计:"
    netstat -s 2>/dev/null | grep -i "error\|drop\|fail" | head -10
    echo ""

    # UDP丢包检测
    echo "• UDP统计:"
    netstat -su 2>/dev/null | grep -i "packet receive errors\|RcvbufErrors" || echo "  无法获取UDP统计"
    echo ""

    echo "优化建议"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "详细的性能解读和优化建议请参考:"
    echo "  • INTERPRETATION_GUIDE.md - 网络测试结果解读章节"
    echo ""
    echo "常见优化方向:"
    echo ""
    echo "  1. TCP参数优化:"
    echo "     sysctl -w net.core.somaxconn=65535"
    echo "     sysctl -w net.core.netdev_max_backlog=16384"
    echo "     sysctl -w net.ipv4.tcp_fin_timeout=30"
    echo "     sysctl -w net.ipv4.tcp_tw_reuse=1"
    echo ""
    echo "  2. Socket缓冲区优化:"
    echo "     sysctl -w net.core.rmem_max=134217728"
    echo "     sysctl -w net.core.wmem_max=134217728"
    echo "     sysctl -w net.ipv4.tcp_rmem='4096 87380 67108864'"
    echo "     sysctl -w net.ipv4.tcp_wmem='4096 65536 67108864'"
    echo ""
    echo "  3. UDP缓冲区优化:"
    echo "     sysctl -w net.core.rmem_default=16777216"
    echo "     sysctl -w net.core.wmem_default=16777216"
    echo ""
    echo "  4. 网卡队列和中断优化:"
    echo "     ethtool -l eth0                    # 查看队列数"
    echo "     ethtool -k eth0                    # 查看offload特性"
    echo "     cat /proc/interrupts | grep eth0   # 查看中断分布"
    echo ""
    echo "  5. 使用Unix Domain Socket:"
    echo "     - 对于本地IPC，优先使用Unix Socket"
    echo "     - 性能通常是TCP的2-3倍"
    echo ""

    echo "详细日志文件"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    ls -1 "$OUTPUT_DIR"/*.log 2>/dev/null | sed 's/^/  • /'
    echo ""

} | tee "$OUTPUT_DIR/network_test_report.txt"

cat "$OUTPUT_DIR/network_test_report.txt"

echo ""
echo "=========================================="
echo "测试完成！"
echo "=========================================="
echo ""
echo "结果保存至: $OUTPUT_DIR"
echo ""
echo "查看报告:"
echo "  cat $OUTPUT_DIR/network_test_report.txt"
echo ""
echo "查看详细解读:"
echo "  cat ../INTERPRETATION_GUIDE.md"
echo ""
