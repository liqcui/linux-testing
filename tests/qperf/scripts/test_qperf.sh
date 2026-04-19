#!/bin/bash
# test_qperf.sh - qperf网络性能综合测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results/qperf-$(date +%Y%m%d-%H%M%S)"

# 默认配置
SERVER_HOST="${1:-localhost}"
TEST_DURATION="${2:-10}"
QPERF_PORT=19765

echo "========================================"
echo "qperf 网络性能综合测试"
echo "========================================"
echo ""

mkdir -p "$RESULTS_DIR"

# 检查qperf
echo "步骤 1: 检查qperf安装..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ! command -v qperf &> /dev/null; then
    echo "qperf未安装，开始安装..."
    echo ""

    # 检测系统类型
    if [[ -f /etc/debian_version ]]; then
        echo "检测到Debian/Ubuntu系统"
        sudo apt-get update
        sudo apt-get install -y qperf
    elif [[ -f /etc/redhat-release ]]; then
        echo "检测到RHEL/CentOS/Fedora系统"
        sudo yum install -y qperf
    else
        echo "✗ 不支持的系统，请手动安装qperf"
        echo ""
        echo "源码安装:"
        echo "  git clone https://github.com/linux-rdma/qperf.git"
        echo "  cd qperf"
        echo "  ./autogen.sh"
        echo "  ./configure"
        echo "  make"
        echo "  sudo make install"
        exit 1
    fi

    if [[ $? -eq 0 ]]; then
        echo "✓ 安装成功"
    else
        echo "✗ 安装失败"
        exit 1
    fi
else
    echo "✓ qperf已安装"
fi

echo ""
qperf --version 2>&1 | head -1 || echo "qperf version unknown"
echo ""

# 检查并启动qperf服务器
echo "步骤 2: 检查qperf服务器..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if pgrep -x qperf > /dev/null; then
    echo "✓ qperf服务器已在运行"
else
    echo "启动qperf服务器..."
    qperf &
    sleep 2
    if pgrep -x qperf > /dev/null; then
        echo "✓ qperf服务器启动成功"
    else
        echo "⚠ qperf服务器启动失败，某些测试可能无法运行"
    fi
fi

echo ""

# 系统信息收集
echo "步骤 3: 收集系统信息..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "系统信息"
    echo "========================================"
    echo ""

    echo "操作系统:"
    echo "  $(uname -s) $(uname -r)"
    echo ""

    echo "网络接口:"
    if command -v ip &> /dev/null; then
        ip -br addr | grep -v "^lo"
    else
        ifconfig | grep -E "^[a-z]|inet "
    fi
    echo ""

    echo "RDMA设备:"
    if command -v ibstat &> /dev/null; then
        ibstat -l 2>/dev/null || echo "  未检测到InfiniBand设备"
    else
        echo "  ibstat未安装，无法检测RDMA设备"
    fi
    echo ""

    echo "测试配置:"
    echo "  服务器: $SERVER_HOST"
    echo "  测试时长: ${TEST_DURATION}秒"
    echo ""

} | tee "$RESULTS_DIR/sysinfo.txt"

# qperf测试原理
{
    echo "qperf测试原理"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  - TCP/UDP Socket性能测试"
    echo "  - RDMA性能测试（如果支持）"
    echo "  - 延迟和带宽测试"
    echo "  - CPU使用率分析"
    echo ""
    echo "核心功能:"
    echo ""
    echo "1. TCP Socket测试"
    echo "   - tcp_bw: TCP带宽测试"
    echo "   - tcp_lat: TCP延迟测试"
    echo "   - 关键指标: Bandwidth (MB/s), Latency (μs)"
    echo ""
    echo "2. UDP Socket测试"
    echo "   - udp_bw: UDP带宽测试"
    echo "   - udp_lat: UDP延迟测试"
    echo "   - 关键指标: Bandwidth (MB/s), Latency (μs)"
    echo ""
    echo "3. RDMA测试（需要RDMA硬件）"
    echo "   - rc_bw: RDMA RC (Reliable Connection) 带宽"
    echo "   - rc_lat: RDMA RC 延迟"
    echo "   - uc_bw: RDMA UC (Unreliable Connection) 带宽"
    echo "   - ud_bw: RDMA UD (Unreliable Datagram) 带宽"
    echo ""
    echo "4. CPU使用率测试"
    echo "   - 显示本地和远程CPU使用率"
    echo "   - 评估协议栈效率"
    echo ""
    echo "常用参数:"
    echo "  -t <time>: 测试时长（秒）"
    echo "  -m <size>: 消息大小"
    echo "  -v: 显示详细信息（包括CPU使用率）"
    echo "  -oo <opts>: 指定输出选项"
    echo ""
} | tee "$RESULTS_DIR/principles.txt"

echo ""

# 测试1: TCP带宽测试
echo "步骤 4: TCP带宽测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "TCP带宽测试"
    echo "========================================"
    echo ""
    echo "测试说明:"
    echo "  - 测量TCP协议最大吞吐量"
    echo "  - 评估网络带宽利用率"
    echo "  - 模拟场景: 大文件传输、数据备份"
    echo ""
} | tee "$RESULTS_DIR/tcp_bw.txt"

echo "运行TCP带宽测试..."

if qperf $SERVER_HOST -t $TEST_DURATION -v tcp_bw 2>&1 | \
    tee -a "$RESULTS_DIR/tcp_bw.txt"; then

    # 提取关键结果
    BW=$(grep "bw" "$RESULTS_DIR/tcp_bw.txt" | grep -v "send_bw\|recv_bw" | awk '{print $3}')

    if [[ -n "$BW" ]]; then
        {
            echo ""
            echo "测试结果分析:"
            BW_INT=${BW%.*}
            if [[ $BW_INT -ge 1000 ]]; then
                echo "  带宽: $BW MB/s"
                echo "  性能评级: ★★★★★ 卓越 (>= 1 GB/s)"
                echo "  网络类型: 10GbE或更高"
            elif [[ $BW_INT -ge 500 ]]; then
                echo "  带宽: $BW MB/s"
                echo "  性能评级: ★★★★☆ 优秀 (>= 500 MB/s)"
                echo "  网络类型: 10GbE部分带宽"
            elif [[ $BW_INT -ge 100 ]]; then
                echo "  带宽: $BW MB/s"
                echo "  性能评级: ★★★☆☆ 良好 (>= 100 MB/s)"
                echo "  网络类型: 1GbE线速"
            elif [[ $BW_INT -ge 50 ]]; then
                echo "  带宽: $BW MB/s"
                echo "  性能评级: ★★☆☆☆ 一般 (>= 50 MB/s)"
                echo "  网络类型: 1GbE部分带宽"
            else
                echo "  带宽: $BW MB/s"
                echo "  性能评级: ★☆☆☆☆ 较低 (< 50 MB/s)"
                echo "  网络类型: 受限或拥塞"
            fi
            echo ""
        } | tee -a "$RESULTS_DIR/tcp_bw.txt"
    fi
else
    echo "  ⚠ TCP带宽测试失败" | tee -a "$RESULTS_DIR/tcp_bw.txt"
fi

echo ""

# 测试2: TCP延迟测试
echo "步骤 5: TCP延迟测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "TCP延迟测试"
    echo "========================================"
    echo ""
    echo "测试说明:"
    echo "  - 测量TCP请求响应延迟"
    echo "  - 评估网络往返时延(RTT)"
    echo "  - 模拟场景: 数据库查询、API调用"
    echo ""
} | tee "$RESULTS_DIR/tcp_lat.txt"

echo "运行TCP延迟测试..."

if qperf $SERVER_HOST -t $TEST_DURATION -v tcp_lat 2>&1 | \
    tee -a "$RESULTS_DIR/tcp_lat.txt"; then

    # 提取延迟结果
    LAT=$(grep "latency" "$RESULTS_DIR/tcp_lat.txt" | awk '{print $3, $4}')

    if [[ -n "$LAT" ]]; then
        {
            echo ""
            echo "测试结果分析:"
            echo "  延迟: $LAT"

            # 提取数值（去掉单位）
            LAT_VAL=$(echo "$LAT" | awk '{print $1}')
            LAT_UNIT=$(echo "$LAT" | awk '{print $2}')

            # 转换为微秒进行比较
            if [[ "$LAT_UNIT" == "ms" ]]; then
                LAT_US=$(echo "$LAT_VAL * 1000" | bc)
            else
                LAT_US=$LAT_VAL
            fi

            LAT_US_INT=${LAT_US%.*}

            if [[ $LAT_US_INT -lt 10 ]]; then
                echo "  性能评级: ★★★★★ 卓越 (< 10 μs)"
                echo "  适用场景: 内存数据库、极低延迟交易"
            elif [[ $LAT_US_INT -lt 50 ]]; then
                echo "  性能评级: ★★★★☆ 优秀 (< 50 μs)"
                echo "  适用场景: 本地网络、Redis缓存"
            elif [[ $LAT_US_INT -lt 200 ]]; then
                echo "  性能评级: ★★★☆☆ 良好 (< 200 μs)"
                echo "  适用场景: 1GbE网络、MySQL查询"
            elif [[ $LAT_US_INT -lt 1000 ]]; then
                echo "  性能评级: ★★☆☆☆ 一般 (< 1 ms)"
                echo "  适用场景: 常规应用"
            else
                echo "  性能评级: ★☆☆☆☆ 较低 (>= 1 ms)"
                echo "  适用场景: 高延迟网络"
            fi
            echo ""
        } | tee -a "$RESULTS_DIR/tcp_lat.txt"
    fi
else
    echo "  ⚠ TCP延迟测试失败" | tee -a "$RESULTS_DIR/tcp_lat.txt"
fi

echo ""

# 测试3: UDP带宽测试
echo "步骤 6: UDP带宽测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "UDP带宽测试"
    echo "========================================"
    echo ""
    echo "测试说明:"
    echo "  - 测量UDP协议吞吐量"
    echo "  - 评估无连接传输性能"
    echo "  - 模拟场景: 视频直播、VoIP"
    echo ""
} | tee "$RESULTS_DIR/udp_bw.txt"

echo "运行UDP带宽测试..."

if qperf $SERVER_HOST -t $TEST_DURATION -v udp_bw 2>&1 | \
    tee -a "$RESULTS_DIR/udp_bw.txt"; then

    {
        echo ""
        echo "测试结果已保存"
        echo ""
    } | tee -a "$RESULTS_DIR/udp_bw.txt"
else
    echo "  ⚠ UDP带宽测试失败" | tee -a "$RESULTS_DIR/udp_bw.txt"
fi

echo ""

# 测试4: UDP延迟测试
echo "步骤 7: UDP延迟测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "UDP延迟测试"
    echo "========================================"
    echo ""
    echo "测试说明:"
    echo "  - 测量UDP请求响应延迟"
    echo "  - 评估无连接协议延迟"
    echo "  - 模拟场景: 实时游戏、DNS查询"
    echo ""
} | tee "$RESULTS_DIR/udp_lat.txt"

echo "运行UDP延迟测试..."

if qperf $SERVER_HOST -t $TEST_DURATION -v udp_lat 2>&1 | \
    tee -a "$RESULTS_DIR/udp_lat.txt"; then

    {
        echo ""
        echo "测试结果已保存"
        echo ""
    } | tee -a "$RESULTS_DIR/udp_lat.txt"
else
    echo "  ⚠ UDP延迟测试失败" | tee -a "$RESULTS_DIR/udp_lat.txt"
fi

echo ""

# 测试5: SCTP带宽测试
echo "步骤 8: SCTP带宽测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "SCTP带宽测试"
    echo "========================================"
    echo ""
    echo "测试说明:"
    echo "  - 测量SCTP协议吞吐量"
    echo "  - 评估消息流传输性能"
    echo "  - 模拟场景: 电信信令、多流传输"
    echo ""
} | tee "$RESULTS_DIR/sctp_bw.txt"

echo "运行SCTP带宽测试..."

if qperf $SERVER_HOST -t $TEST_DURATION -v sctp_bw 2>&1 | \
    tee -a "$RESULTS_DIR/sctp_bw.txt"; then

    {
        echo ""
        echo "测试结果已保存"
        echo ""
    } | tee -a "$RESULTS_DIR/sctp_bw.txt"
else
    echo "  ⚠ SCTP带宽测试失败（可能不支持SCTP）" | tee -a "$RESULTS_DIR/sctp_bw.txt"
fi

echo ""

# 测试6: 不同消息大小性能测试
echo "步骤 9: 不同消息大小性能测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "不同消息大小性能测试"
    echo "========================================"
    echo ""
    echo "测试说明:"
    echo "  - 测试不同消息大小下的性能"
    echo "  - 评估协议栈效率"
    echo "  - 找到最优消息大小"
    echo ""
    echo "消息大小  TCP带宽(MB/s)  TCP延迟(μs)"
    echo "--------  ------------  -----------"
} | tee "$RESULTS_DIR/msg_size.txt"

MSG_SIZES=(64 256 1024 4096 16384 65536)

for size in "${MSG_SIZES[@]}"; do
    echo "测试消息大小: $size bytes"

    # TCP带宽
    BW_OUTPUT=$(qperf $SERVER_HOST -m $size -t 5 tcp_bw 2>&1)
    BW=$(echo "$BW_OUTPUT" | grep "bw" | grep -v "send_bw\|recv_bw" | awk '{print $3}')

    # TCP延迟
    LAT_OUTPUT=$(qperf $SERVER_HOST -m $size -t 5 tcp_lat 2>&1)
    LAT=$(echo "$LAT_OUTPUT" | grep "latency" | awk '{print $3}')

    printf "%-8d  %-14s  %s\n" "$size" "${BW:-N/A}" "${LAT:-N/A}" | \
        tee -a "$RESULTS_DIR/msg_size.txt"
done

echo "" | tee -a "$RESULTS_DIR/msg_size.txt"
echo ""

# 测试7: RDMA性能测试（如果支持）
echo "步骤 10: RDMA性能测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "RDMA性能测试"
    echo "========================================"
    echo ""
    echo "测试说明:"
    echo "  - 测试RDMA RC/UC/UD性能"
    echo "  - 评估零拷贝传输性能"
    echo "  - 需要RDMA硬件支持"
    echo ""
} | tee "$RESULTS_DIR/rdma_test.txt"

# 检查是否有RDMA设备
if command -v ibstat &> /dev/null && ibstat -l &> /dev/null; then
    echo "检测到RDMA设备，运行RDMA测试..." | tee -a "$RESULTS_DIR/rdma_test.txt"

    # RDMA RC带宽测试
    echo "" | tee -a "$RESULTS_DIR/rdma_test.txt"
    echo "RDMA RC (Reliable Connection) 带宽测试:" | tee -a "$RESULTS_DIR/rdma_test.txt"
    if qperf $SERVER_HOST -t 5 -v rc_bw 2>&1 | tee -a "$RESULTS_DIR/rdma_test.txt"; then
        echo "✓ RDMA RC带宽测试完成" | tee -a "$RESULTS_DIR/rdma_test.txt"
    fi

    # RDMA RC延迟测试
    echo "" | tee -a "$RESULTS_DIR/rdma_test.txt"
    echo "RDMA RC 延迟测试:" | tee -a "$RESULTS_DIR/rdma_test.txt"
    if qperf $SERVER_HOST -t 5 -v rc_lat 2>&1 | tee -a "$RESULTS_DIR/rdma_test.txt"; then
        echo "✓ RDMA RC延迟测试完成" | tee -a "$RESULTS_DIR/rdma_test.txt"
    fi

    # RDMA UC带宽测试
    echo "" | tee -a "$RESULTS_DIR/rdma_test.txt"
    echo "RDMA UC (Unreliable Connection) 带宽测试:" | tee -a "$RESULTS_DIR/rdma_test.txt"
    if qperf $SERVER_HOST -t 5 -v uc_bw 2>&1 | tee -a "$RESULTS_DIR/rdma_test.txt"; then
        echo "✓ RDMA UC带宽测试完成" | tee -a "$RESULTS_DIR/rdma_test.txt"
    fi

    # RDMA UD带宽测试
    echo "" | tee -a "$RESULTS_DIR/rdma_test.txt"
    echo "RDMA UD (Unreliable Datagram) 带宽测试:" | tee -a "$RESULTS_DIR/rdma_test.txt"
    if qperf $SERVER_HOST -t 5 -v ud_bw 2>&1 | tee -a "$RESULTS_DIR/rdma_test.txt"; then
        echo "✓ RDMA UD带宽测试完成" | tee -a "$RESULTS_DIR/rdma_test.txt"
    fi
else
    echo "⚠ 未检测到RDMA设备，跳过RDMA测试" | tee -a "$RESULTS_DIR/rdma_test.txt"
    echo "  如需RDMA测试，请安装InfiniBand驱动和工具" | tee -a "$RESULTS_DIR/rdma_test.txt"
fi

echo "" | tee -a "$RESULTS_DIR/rdma_test.txt"
echo ""

# 生成测试报告
{
    echo "qperf 网络性能测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo "目标服务器: $SERVER_HOST"
    echo ""

    echo "测试结果汇总:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # TCP带宽
    if [[ -f "$RESULTS_DIR/tcp_bw.txt" ]]; then
        TCP_BW=$(grep "bw" "$RESULTS_DIR/tcp_bw.txt" | grep -v "send_bw\|recv_bw" | awk '{print $3, $4}' | head -1)
        if [[ -n "$TCP_BW" ]]; then
            echo "✓ TCP带宽: $TCP_BW"
        fi
    fi

    # TCP延迟
    if [[ -f "$RESULTS_DIR/tcp_lat.txt" ]]; then
        TCP_LAT=$(grep "latency" "$RESULTS_DIR/tcp_lat.txt" | awk '{print $3, $4}' | head -1)
        if [[ -n "$TCP_LAT" ]]; then
            echo "✓ TCP延迟: $TCP_LAT"
        fi
    fi

    # UDP带宽
    if [[ -f "$RESULTS_DIR/udp_bw.txt" ]]; then
        UDP_BW=$(grep "bw" "$RESULTS_DIR/udp_bw.txt" | grep -v "send_bw\|recv_bw" | awk '{print $3, $4}' | head -1)
        if [[ -n "$UDP_BW" ]]; then
            echo "✓ UDP带宽: $UDP_BW"
        fi
    fi

    # UDP延迟
    if [[ -f "$RESULTS_DIR/udp_lat.txt" ]]; then
        UDP_LAT=$(grep "latency" "$RESULTS_DIR/udp_lat.txt" | awk '{print $3, $4}' | head -1)
        if [[ -n "$UDP_LAT" ]]; then
            echo "✓ UDP延迟: $UDP_LAT"
        fi
    fi

    echo ""

    echo "详细结果文件:"
    echo "  系统信息: $RESULTS_DIR/sysinfo.txt"
    echo "  测试原理: $RESULTS_DIR/principles.txt"
    echo "  TCP带宽: $RESULTS_DIR/tcp_bw.txt"
    echo "  TCP延迟: $RESULTS_DIR/tcp_lat.txt"
    echo "  UDP带宽: $RESULTS_DIR/udp_bw.txt"
    echo "  UDP延迟: $RESULTS_DIR/udp_lat.txt"
    echo "  SCTP带宽: $RESULTS_DIR/sctp_bw.txt"
    echo "  消息大小: $RESULTS_DIR/msg_size.txt"
    echo "  RDMA测试: $RESULTS_DIR/rdma_test.txt"
    echo ""

    echo "高级测试:"
    echo "  如需进行更多高级测试，可使用:"
    echo "  $SCRIPT_DIR/qperf_advanced.sh"
    echo ""

} | tee "$RESULTS_DIR/report.txt"

echo ""
echo "========================================"
echo "测试完成"
echo "========================================"
echo ""
echo "查看报告: cat $RESULTS_DIR/report.txt"
echo "结果目录: $RESULTS_DIR"
echo ""
