#!/bin/bash
# test_network_stress.sh - 网络压力测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "================================"
echo "stress-ng 网络压力测试"
echo "================================"
echo ""

# 检查 stress-ng
if ! command -v stress-ng &> /dev/null; then
    echo "错误: stress-ng 未安装"
    exit 1
fi

CPU_COUNT=$(nproc)

echo "系统信息:"
echo "  CPU 核心数: $CPU_COUNT"
echo "  本地回环: 127.0.0.1 (lo)"
echo ""

echo "测试场景 1: Socket 配对压力测试"
echo "==============================="
echo ""
echo "运行参数:"
echo "  --sock 4                  # 4个socket工作进程"
echo "  --sock-opts send          # 发送模式"
echo "  --timeout 30s             # 运行30秒"
echo "  --metrics-brief           # 简要指标"
echo ""

stress-ng --sock 4 --sock-opts send --timeout 30s --metrics-brief

echo ""
echo ""
echo "测试场景 2: UDP 压力测试"
echo "======================="
echo ""

echo "测试 2.1: UDP 基本压力"
echo "---------------------"
stress-ng --udp 4 --udp-domain ipv4 --timeout 30s --metrics-brief

echo ""
echo ""
echo "测试 2.2: UDP 洪泛测试"
echo "---------------------"
stress-ng --udp-flood 4 --udp-flood-domain ipv4 --timeout 20s --metrics-brief

echo ""
echo ""
echo "测试 2.3: UDP IPv6"
echo "-----------------"
stress-ng --udp 2 --udp-domain ipv6 --timeout 20s --metrics-brief

echo ""
echo ""
echo "测试场景 3: TCP 压力测试"
echo "======================="
echo ""

echo "测试 3.1: TCP 基本压力"
echo "---------------------"
stress-ng --sock 4 --sock-type stream --sock-opts send --timeout 30s --metrics-brief

echo ""
echo ""
echo "测试 3.2: TCP 连接建立/关闭压力"
echo "------------------------------"
(
    echo "启动 TCP 服务端（后台）..."
    stress-ng --sockfd 1 --sockfd-port 9000 --timeout 45s &
    SERVER_PID=$!

    sleep 3

    echo "启动 TCP 客户端压力..."
    stress-ng --sockmany 4 --sockmany-port 9000 --timeout 30s --metrics-brief

    wait $SERVER_PID 2>/dev/null
)

echo ""
echo ""
echo "测试 3.3: TCP 大数据传输"
echo "-----------------------"
stress-ng --sock 2 --sock-type stream --sock-opts send --sock-msgs 10000 --timeout 30s --metrics-brief

echo ""
echo ""
echo "测试场景 4: Unix Domain Socket 压力"
echo "==================================="
echo ""

echo "测试: 本地socket通信"
echo "-------------------"
stress-ng --sockpair 4 --timeout 30s --metrics-brief

echo ""
echo ""
echo "测试场景 5: 网络协议栈压力"
echo "========================="
echo ""

echo "测试 5.1: ICMP Echo (Ping) 压力"
echo "-------------------------------"
stress-ng --icmp-flood 2 --timeout 15s --metrics-brief

echo ""
echo ""
echo "测试 5.2: Raw Socket 压力"
echo "------------------------"
if [[ $EUID -eq 0 ]]; then
    stress-ng --rawsock 2 --timeout 15s --metrics-brief
else
    echo "跳过: raw socket 需要 root 权限"
fi

echo ""
echo ""
echo "测试场景 6: 多协议并发测试"
echo "========================="
echo ""

echo "测试: 同时运行 TCP/UDP/ICMP"
echo "--------------------------"
stress-ng --sock 2 --udp 2 --icmp-flood 1 --timeout 30s --metrics-brief

echo ""
echo ""
echo "测试场景 7: 网络缓冲区压力"
echo "========================="
echo ""

echo "测试: Socket 缓冲区压力"
echo "----------------------"
stress-ng --sockfd 4 --sockfd-reuse --timeout 20s --metrics-brief

echo ""
echo ""
echo "测试场景 8: 连接数压力测试"
echo "========================="
echo ""

echo "测试: 大量并发连接"
echo "-----------------"
stress-ng --sock 8 --sock-type stream --timeout 25s --metrics-brief

echo ""
echo ""
echo "================================"
echo "测试完成！"
echo "================================"
echo ""
echo "结果指标说明:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. 网络测试类型:"
echo "   • sock         - Socket配对通信"
echo "   • sockfd       - Socket文件描述符"
echo "   • sockpair     - Unix domain socket配对"
echo "   • sockmany     - 大量TCP连接"
echo "   • udp          - UDP数据报"
echo "   • udp-flood    - UDP洪泛"
echo "   • icmp-flood   - ICMP Echo洪泛"
echo "   • rawsock      - Raw socket"
echo ""
echo "2. Socket 选项:"
echo "   • send         - 发送数据"
echo "   • sendmsg      - 使用sendmsg()"
echo "   • sendmmsg     - 批量发送"
echo "   • nodelay      - TCP_NODELAY（禁用Nagle）"
echo "   • zerocopy     - 零拷贝发送"
echo ""
echo "3. 域类型:"
echo "   • ipv4         - IPv4协议"
echo "   • ipv6         - IPv6协议"
echo "   • unix         - Unix domain"
echo ""
echo "4. 性能指标:"
echo "   • bogo ops/s   - 每秒操作数（数据包/连接）"
echo "   • MB/s         - 吞吐量（如果显示）"
echo "   • 延迟         - 网络延迟（如果测量）"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "典型输出示例:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "stress-ng: info:  [12345] dispatching hogs: 4 udp"
echo "stress-ng: info:  [12345] successful run completed in 30.00s"
echo "stress-ng: info:  [12345] stressor       bogo ops real time  usr time  sys time   bogo ops/s"
echo "stress-ng: info:  [12345] udp             856420     30.00     12.50     65.30     28547.33"
echo ""
echo "解读:"
echo "  - 4个UDP工作进程"
echo "  - 30秒完成856420次操作（数据包）"
echo "  - 系统态65秒（网络密集）"
echo "  - 每秒28547次操作"
echo "  - 高系统态时间表示网络协议栈开销"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "网络协议对比:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "• TCP (Transmission Control Protocol):"
echo "  - 面向连接，可靠传输"
echo "  - 三次握手建立连接"
echo "  - 流量控制、拥塞控制"
echo "  - 适合: 文件传输、HTTP、数据库"
echo "  - 开销: 较高（连接维护、重传）"
echo ""
echo "• UDP (User Datagram Protocol):"
echo "  - 无连接，不可靠传输"
echo "  - 无握手，直接发送"
echo "  - 无流量控制"
echo "  - 适合: 视频流、DNS、游戏"
echo "  - 开销: 较低（无连接维护）"
echo ""
echo "• ICMP (Internet Control Message Protocol):"
echo "  - 网络层协议，用于诊断"
echo "  - Ping使用ICMP Echo"
echo "  - 错误报告、网络诊断"
echo ""
echo "• Unix Domain Socket:"
echo "  - 本地IPC，不经过网络协议栈"
echo "  - 最高性能的进程间通信"
echo "  - 适合: 本地服务通信"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "性能分析:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "• 高 bogo ops/s 意味着:"
echo "  - 网络协议栈处理能力强"
echo "  - CPU性能好（协议处理需要CPU）"
echo "  - 网络接口性能好"
echo ""
echo "• 高系统态时间 (sys time) 表示:"
echo "  - 大量时间在内核态处理网络"
echo "  - 协议栈开销大"
echo "  - 上下文切换频繁"
echo ""
echo "• TCP vs UDP 性能差异:"
echo "  - UDP通常有更高的 ops/s（无连接开销）"
echo "  - TCP有更多系统态时间（连接管理）"
echo "  - Localhost测试两者差异较小"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "监控命令:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "• netstat -s           # 网络统计"
echo "• ss -s                # Socket统计"
echo "• iftop                # 网络流量监控"
echo "• nethogs              # 按进程网络使用"
echo "• tcpdump -i lo        # 抓包分析"
echo "• nstat                # 网络统计快照"
echo ""
echo "实时监控 TCP 连接:"
echo "  watch -n1 'ss -tan | grep ESTAB | wc -l'"
echo ""
echo "实时监控 UDP 数据包:"
echo "  watch -n1 'netstat -su'"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
