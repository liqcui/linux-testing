#!/bin/bash
# test_netperf.sh - Netperf网络性能综合测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results/netperf-$(date +%Y%m%d-%H%M%S)"

# 默认配置
SERVER_HOST="${1:-localhost}"
TEST_DURATION=10
NETPERF_PORT=12865

echo "========================================"
echo "Netperf 网络性能综合测试"
echo "========================================"
echo ""

mkdir -p "$RESULTS_DIR"

# 检查netperf
echo "步骤 1: 检查Netperf安装..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ! command -v netperf &> /dev/null; then
    echo "Netperf未安装，开始安装..."
    echo ""

    # 检测系统类型
    if [[ -f /etc/debian_version ]]; then
        echo "检测到Debian/Ubuntu系统"
        sudo apt-get update
        sudo apt-get install -y netperf
    elif [[ -f /etc/redhat-release ]]; then
        echo "检测到RHEL/CentOS/Fedora系统"
        sudo yum install -y netperf
    elif [[ "$(uname -s)" == "Darwin" ]]; then
        echo "检测到macOS系统"
        if command -v brew &> /dev/null; then
            brew install netperf
        else
            echo "请先安装Homebrew: https://brew.sh/"
            exit 1
        fi
    else
        echo "✗ 不支持的系统，请手动安装netperf"
        echo ""
        echo "源码安装:"
        echo "  wget https://github.com/HewlettPackard/netperf/archive/netperf-2.7.0.tar.gz"
        echo "  tar xzf netperf-2.7.0.tar.gz"
        echo "  cd netperf-netperf-2.7.0"
        echo "  ./configure && make && sudo make install"
        exit 1
    fi

    if [[ $? -eq 0 ]]; then
        echo "✓ 安装成功"
    else
        echo "✗ 安装失败"
        exit 1
    fi
else
    echo "✓ Netperf已安装"
fi

echo ""
netperf -V 2>&1 | head -1 || echo "Netperf version check"
echo ""

# 启动netserver
echo "步骤 2: 启动netserver..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 检查netserver是否已运行
if pgrep -x netserver > /dev/null; then
    echo "✓ netserver已在运行"
else
    echo "启动netserver..."
    if command -v netserver &> /dev/null; then
        netserver -D -p $NETPERF_PORT 2>/dev/null
        sleep 2
        if pgrep -x netserver > /dev/null; then
            echo "✓ netserver启动成功"
        else
            echo "⚠ netserver启动失败，某些测试可能无法运行"
        fi
    else
        echo "⚠ netserver未找到"
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

    echo "网络配置:"
    if [[ -f /proc/sys/net/ipv4/tcp_rmem ]]; then
        echo "  TCP接收缓冲区: $(cat /proc/sys/net/ipv4/tcp_rmem)"
        echo "  TCP发送缓冲区: $(cat /proc/sys/net/ipv4/tcp_wmem)"
        echo "  TCP拥塞控制: $(cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || echo "N/A")"
    fi
    echo ""

    echo "测试配置:"
    echo "  服务器: $SERVER_HOST"
    echo "  端口: $NETPERF_PORT"
    echo "  测试时长: ${TEST_DURATION}秒"
    echo ""

} | tee "$RESULTS_DIR/sysinfo.txt"

# Netperf测试原理
{
    echo "Netperf测试原理"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  - 网络吞吐量测试（带宽）"
    echo "  - 网络延迟测试（RTT）"
    echo "  - 并发连接性能测试"
    echo "  - 不同协议性能对比（TCP/UDP）"
    echo "  - 不同消息大小的性能特征"
    echo ""
    echo "核心测试类型:"
    echo ""
    echo "1. TCP_STREAM - TCP批量传输测试"
    echo "   - 测量TCP单向传输吞吐量"
    echo "   - 模拟大文件传输、视频流等场景"
    echo "   - 关键指标: Throughput (Mbps)"
    echo ""
    echo "2. TCP_RR - TCP请求响应测试"
    echo "   - 测量TCP往返延迟和事务率"
    echo "   - 模拟数据库查询、API调用等场景"
    echo "   - 关键指标: Transactions/sec, Latency (ms)"
    echo ""
    echo "3. TCP_CRR - TCP连接请求响应测试"
    echo "   - 每次测试建立新连接"
    echo "   - 模拟HTTP短连接等场景"
    echo "   - 关键指标: Connections/sec"
    echo ""
    echo "4. UDP_STREAM - UDP批量传输测试"
    echo "   - 测量UDP单向传输吞吐量"
    echo "   - 模拟视频直播、VoIP等场景"
    echo "   - 关键指标: Throughput (Mbps), Packet Loss"
    echo ""
    echo "5. TCP_SENDFILE - 零拷贝传输测试"
    echo "   - 使用sendfile()系统调用"
    echo "   - 模拟高性能文件服务器"
    echo "   - 关键指标: Throughput (Mbps), CPU Usage"
    echo ""
    echo "关键参数:"
    echo "  -H: 目标服务器地址"
    echo "  -p: 服务器端口"
    echo "  -t: 测试类型"
    echo "  -l: 测试时长（秒）"
    echo "  -m: 消息大小"
    echo "  -s: 本地socket缓冲区大小"
    echo "  -S: 远程socket缓冲区大小"
    echo ""
} | tee "$RESULTS_DIR/principles.txt"

echo ""

# 测试1: TCP吞吐量测试
echo "步骤 4: TCP吞吐量测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "TCP吞吐量测试（TCP_STREAM）"
    echo "========================================"
    echo ""
    echo "测试说明:"
    echo "  - 单向TCP批量数据传输"
    echo "  - 测量最大吞吐量"
    echo "  - 模拟场景: 大文件下载、视频流"
    echo ""
} | tee "$RESULTS_DIR/tcp_stream.txt"

echo "运行TCP吞吐量测试..."

if netperf -H $SERVER_HOST -p $NETPERF_PORT -t TCP_STREAM -l $TEST_DURATION -- \
    -m 64K 2>&1 | tee -a "$RESULTS_DIR/tcp_stream.txt"; then

    # 提取结果
    THROUGHPUT=$(grep -E "^[0-9]" "$RESULTS_DIR/tcp_stream.txt" | tail -1 | awk '{print $5}')

    {
        echo ""
        echo "测试结果:"
        if [[ -n "$THROUGHPUT" ]]; then
            echo "  吞吐量: ${THROUGHPUT} Mbps"
            echo ""

            # 性能评级
            THROUGHPUT_INT=${THROUGHPUT%.*}
            if [[ $THROUGHPUT_INT -ge 9000 ]]; then
                echo "  性能评级: ★★★★★ 卓越 (>= 9 Gbps)"
                echo "  网络类型: 10GbE或更高"
            elif [[ $THROUGHPUT_INT -ge 900 ]]; then
                echo "  性能评级: ★★★★☆ 优秀 (>= 900 Mbps)"
                echo "  网络类型: 1GbE (接近线速)"
            elif [[ $THROUGHPUT_INT -ge 500 ]]; then
                echo "  性能评级: ★★★☆☆ 良好 (>= 500 Mbps)"
                echo "  网络类型: 1GbE (部分带宽)"
            elif [[ $THROUGHPUT_INT -ge 90 ]]; then
                echo "  性能评级: ★★☆☆☆ 一般 (>= 90 Mbps)"
                echo "  网络类型: 100Mbps或1GbE受限"
            else
                echo "  性能评级: ★☆☆☆☆ 较低 (< 90 Mbps)"
                echo "  网络类型: <100Mbps或严重拥塞"
            fi
        else
            echo "  ✗ 无法提取吞吐量数据"
        fi
        echo ""
    } | tee -a "$RESULTS_DIR/tcp_stream.txt"
else
    echo "  ⚠ TCP吞吐量测试失败（可能服务器不可达）" | tee -a "$RESULTS_DIR/tcp_stream.txt"
fi

echo ""

# 测试2: TCP延迟测试（请求响应）
echo "步骤 5: TCP延迟测试（请求响应）..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "TCP延迟测试（TCP_RR）"
    echo "========================================"
    echo ""
    echo "测试说明:"
    echo "  - TCP请求响应模式"
    echo "  - 测量事务率和延迟"
    echo "  - 模拟场景: 数据库查询、API调用、缓存访问"
    echo ""
} | tee "$RESULTS_DIR/tcp_rr.txt"

echo "运行TCP请求响应测试..."

if netperf -H $SERVER_HOST -p $NETPERF_PORT -t TCP_RR -l $TEST_DURATION -- \
    -r 1,1 2>&1 | tee -a "$RESULTS_DIR/tcp_rr.txt"; then

    # 提取结果
    TPS=$(grep -E "^[0-9]" "$RESULTS_DIR/tcp_rr.txt" | tail -1 | awk '{print $6}')

    {
        echo ""
        echo "测试结果:"
        if [[ -n "$TPS" ]]; then
            echo "  事务率: ${TPS} Trans/sec"

            # 计算平均延迟（毫秒）
            LATENCY=$(echo "scale=3; 1000 / $TPS" | bc)
            echo "  平均延迟: ${LATENCY} ms"
            echo ""

            # 性能评级（基于事务率）
            TPS_INT=${TPS%.*}
            if [[ $TPS_INT -ge 100000 ]]; then
                echo "  性能评级: ★★★★★ 卓越 (>= 100K TPS)"
                echo "  延迟级别: < 0.01 ms"
            elif [[ $TPS_INT -ge 50000 ]]; then
                echo "  性能评级: ★★★★☆ 优秀 (>= 50K TPS)"
                echo "  延迟级别: 0.01-0.02 ms"
            elif [[ $TPS_INT -ge 20000 ]]; then
                echo "  性能评级: ★★★☆☆ 良好 (>= 20K TPS)"
                echo "  延迟级别: 0.02-0.05 ms"
            elif [[ $TPS_INT -ge 5000 ]]; then
                echo "  性能评级: ★★☆☆☆ 一般 (>= 5K TPS)"
                echo "  延迟级别: 0.05-0.2 ms"
            else
                echo "  性能评级: ★☆☆☆☆ 较低 (< 5K TPS)"
                echo "  延迟级别: > 0.2 ms"
            fi
        else
            echo "  ✗ 无法提取事务率数据"
        fi
        echo ""
    } | tee -a "$RESULTS_DIR/tcp_rr.txt"
else
    echo "  ⚠ TCP延迟测试失败" | tee -a "$RESULTS_DIR/tcp_rr.txt"
fi

echo ""

# 测试3: TCP连接请求响应测试
echo "步骤 6: TCP连接性能测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "TCP连接性能测试（TCP_CRR）"
    echo "========================================"
    echo ""
    echo "测试说明:"
    echo "  - 每次请求建立新TCP连接"
    echo "  - 测量连接建立速率"
    echo "  - 模拟场景: HTTP/1.0短连接、频繁建立连接的应用"
    echo ""
} | tee "$RESULTS_DIR/tcp_crr.txt"

echo "运行TCP连接测试..."

if netperf -H $SERVER_HOST -p $NETPERF_PORT -t TCP_CRR -l $TEST_DURATION -- \
    -r 1,1 2>&1 | tee -a "$RESULTS_DIR/tcp_crr.txt"; then

    # 提取结果
    CONN_RATE=$(grep -E "^[0-9]" "$RESULTS_DIR/tcp_crr.txt" | tail -1 | awk '{print $6}')

    {
        echo ""
        echo "测试结果:"
        if [[ -n "$CONN_RATE" ]]; then
            echo "  连接率: ${CONN_RATE} Conn/sec"

            # 计算平均连接时间（毫秒）
            CONN_TIME=$(echo "scale=3; 1000 / $CONN_RATE" | bc)
            echo "  连接时间: ${CONN_TIME} ms/conn"
            echo ""

            # 性能评级
            CONN_INT=${CONN_RATE%.*}
            if [[ $CONN_INT -ge 50000 ]]; then
                echo "  性能评级: ★★★★★ 卓越 (>= 50K Conn/s)"
            elif [[ $CONN_INT -ge 20000 ]]; then
                echo "  性能评级: ★★★★☆ 优秀 (>= 20K Conn/s)"
            elif [[ $CONN_INT -ge 10000 ]]; then
                echo "  性能评级: ★★★☆☆ 良好 (>= 10K Conn/s)"
            elif [[ $CONN_INT -ge 5000 ]]; then
                echo "  性能评级: ★★☆☆☆ 一般 (>= 5K Conn/s)"
            else
                echo "  性能评级: ★☆☆☆☆ 较低 (< 5K Conn/s)"
            fi
        else
            echo "  ✗ 无法提取连接率数据"
        fi
        echo ""
    } | tee -a "$RESULTS_DIR/tcp_crr.txt"
else
    echo "  ⚠ TCP连接测试失败" | tee -a "$RESULTS_DIR/tcp_crr.txt"
fi

echo ""

# 测试4: UDP吞吐量测试
echo "步骤 7: UDP吞吐量测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "UDP吞吐量测试（UDP_STREAM）"
    echo "========================================"
    echo ""
    echo "测试说明:"
    echo "  - UDP单向数据传输"
    echo "  - 测量吞吐量和丢包率"
    echo "  - 模拟场景: 视频直播、VoIP、游戏"
    echo ""
} | tee "$RESULTS_DIR/udp_stream.txt"

echo "运行UDP吞吐量测试..."

if netperf -H $SERVER_HOST -p $NETPERF_PORT -t UDP_STREAM -l $TEST_DURATION -- \
    -m 1472 2>&1 | tee -a "$RESULTS_DIR/udp_stream.txt"; then

    # 提取结果
    UDP_THROUGHPUT=$(grep -E "^[0-9]" "$RESULTS_DIR/udp_stream.txt" | tail -1 | awk '{print $4}')

    {
        echo ""
        echo "测试结果:"
        if [[ -n "$UDP_THROUGHPUT" ]]; then
            echo "  UDP吞吐量: ${UDP_THROUGHPUT} Mbps"
            echo ""
            echo "  注意: UDP测试需要检查接收端是否有丢包"
            echo "  建议: 使用 -R 1 参数查看接收端统计"
        else
            echo "  ✗ 无法提取UDP吞吐量数据"
        fi
        echo ""
    } | tee -a "$RESULTS_DIR/udp_stream.txt"
else
    echo "  ⚠ UDP吞吐量测试失败" | tee -a "$RESULTS_DIR/udp_stream.txt"
fi

echo ""

# 测试5: 不同消息大小的TCP性能
echo "步骤 8: 不同消息大小性能测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "不同消息大小性能测试"
    echo "========================================"
    echo ""
    echo "测试说明:"
    echo "  - 测试不同消息大小的吞吐量"
    echo "  - 找到最优消息大小"
    echo "  - 分析消息大小对性能的影响"
    echo ""
    echo "消息大小  吞吐量(Mbps)  性能比"
    echo "--------  -----------  ------"
} | tee "$RESULTS_DIR/message_size.txt"

MESSAGE_SIZES=(1 64 256 1024 4096 8192 16384 32768 65536)

for size in "${MESSAGE_SIZES[@]}"; do
    echo "测试消息大小: ${size} bytes"

    if OUTPUT=$(netperf -H $SERVER_HOST -p $NETPERF_PORT -t TCP_STREAM \
        -l 5 -- -m $size 2>&1); then

        THROUGHPUT=$(echo "$OUTPUT" | grep -E "^[0-9]" | tail -1 | awk '{print $5}')

        if [[ -n "$THROUGHPUT" ]]; then
            # 如果是第一个，记录为基准
            if [[ -z "${BASELINE_THROUGHPUT:-}" ]]; then
                BASELINE_THROUGHPUT=$THROUGHPUT
                RATIO="1.00"
            else
                RATIO=$(echo "scale=2; $THROUGHPUT / $BASELINE_THROUGHPUT" | bc)
            fi

            printf "%-8d  %-13s  %s\n" "$size" "$THROUGHPUT" "${RATIO}x" | \
                tee -a "$RESULTS_DIR/message_size.txt"
        fi
    fi
done

echo "" | tee -a "$RESULTS_DIR/message_size.txt"
echo ""

# 生成测试报告
{
    echo "Netperf 网络性能测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo "目标服务器: $SERVER_HOST"
    echo ""

    echo "测试结果汇总:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # TCP吞吐量
    if [[ -f "$RESULTS_DIR/tcp_stream.txt" ]]; then
        THROUGHPUT=$(grep "吞吐量:" "$RESULTS_DIR/tcp_stream.txt" | awk '{print $2, $3}')
        if [[ -n "$THROUGHPUT" ]]; then
            echo "✓ TCP吞吐量: $THROUGHPUT"
        fi
    fi

    # TCP延迟
    if [[ -f "$RESULTS_DIR/tcp_rr.txt" ]]; then
        TPS=$(grep "事务率:" "$RESULTS_DIR/tcp_rr.txt" | awk '{print $2, $3}')
        LATENCY=$(grep "平均延迟:" "$RESULTS_DIR/tcp_rr.txt" | awk '{print $2, $3}')
        if [[ -n "$TPS" ]]; then
            echo "✓ TCP事务率: $TPS"
            echo "  TCP延迟: $LATENCY"
        fi
    fi

    # TCP连接性能
    if [[ -f "$RESULTS_DIR/tcp_crr.txt" ]]; then
        CONN_RATE=$(grep "连接率:" "$RESULTS_DIR/tcp_crr.txt" | awk '{print $2, $3}')
        if [[ -n "$CONN_RATE" ]]; then
            echo "✓ TCP连接率: $CONN_RATE"
        fi
    fi

    # UDP吞吐量
    if [[ -f "$RESULTS_DIR/udp_stream.txt" ]]; then
        UDP_THROUGHPUT=$(grep "UDP吞吐量:" "$RESULTS_DIR/udp_stream.txt" | awk '{print $2, $3}')
        if [[ -n "$UDP_THROUGHPUT" ]]; then
            echo "✓ UDP吞吐量: $UDP_THROUGHPUT"
        fi
    fi

    echo ""

    echo "详细结果文件:"
    echo "  系统信息: $RESULTS_DIR/sysinfo.txt"
    echo "  测试原理: $RESULTS_DIR/principles.txt"
    echo "  TCP吞吐量: $RESULTS_DIR/tcp_stream.txt"
    echo "  TCP延迟: $RESULTS_DIR/tcp_rr.txt"
    echo "  TCP连接: $RESULTS_DIR/tcp_crr.txt"
    echo "  UDP吞吐量: $RESULTS_DIR/udp_stream.txt"
    echo "  消息大小分析: $RESULTS_DIR/message_size.txt"
    echo ""

    echo "高级测试:"
    echo "  如需进行更多高级测试，可使用:"
    echo "  $SCRIPT_DIR/netperf_advanced.sh"
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

# 清理：停止netserver（如果是本脚本启动的）
# 注意：不要停止用户手动启动的netserver
