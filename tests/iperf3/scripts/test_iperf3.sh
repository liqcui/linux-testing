#!/bin/bash
# test_iperf3.sh - iperf3网络性能综合测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results/iperf3-$(date +%Y%m%d-%H%M%S)"

# 默认配置
SERVER_HOST="${1:-localhost}"
TEST_DURATION=10
IPERF3_PORT=5201

echo "========================================"
echo "iperf3 网络性能综合测试"
echo "========================================"
echo ""

mkdir -p "$RESULTS_DIR"

# 检查iperf3
echo "步骤 1: 检查iperf3安装..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ! command -v iperf3 &> /dev/null; then
    echo "iperf3未安装，开始安装..."
    echo ""

    # 检测系统类型
    if [[ -f /etc/debian_version ]]; then
        echo "检测到Debian/Ubuntu系统"
        sudo apt-get update
        sudo apt-get install -y iperf3
    elif [[ -f /etc/redhat-release ]]; then
        echo "检测到RHEL/CentOS/Fedora系统"
        sudo yum install -y iperf3
    elif [[ "$(uname -s)" == "Darwin" ]]; then
        echo "检测到macOS系统"
        if command -v brew &> /dev/null; then
            brew install iperf3
        else
            echo "请先安装Homebrew: https://brew.sh/"
            exit 1
        fi
    else
        echo "✗ 不支持的系统，请手动安装iperf3"
        echo ""
        echo "源码安装:"
        echo "  wget https://downloads.es.net/pub/iperf/iperf-3.14.tar.gz"
        echo "  tar xzf iperf-3.14.tar.gz"
        echo "  cd iperf-3.14"
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
    echo "✓ iperf3已安装"
fi

echo ""
iperf3 --version | head -1
echo ""

# 检查并启动iperf3服务器
echo "步骤 2: 检查iperf3服务器..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if pgrep -x iperf3 > /dev/null; then
    echo "✓ iperf3服务器已在运行"
else
    echo "启动iperf3服务器..."
    iperf3 -s -D -p $IPERF3_PORT 2>/dev/null
    sleep 2
    if pgrep -x iperf3 > /dev/null; then
        echo "✓ iperf3服务器启动成功"
    else
        echo "⚠ iperf3服务器启动失败，某些测试可能无法运行"
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
    if [[ -f /proc/sys/net/ipv4/tcp_congestion_control ]]; then
        echo "  TCP拥塞控制: $(cat /proc/sys/net/ipv4/tcp_congestion_control)"
    fi
    if [[ -f /proc/sys/net/ipv4/tcp_rmem ]]; then
        echo "  TCP接收缓冲区: $(cat /proc/sys/net/ipv4/tcp_rmem)"
        echo "  TCP发送缓冲区: $(cat /proc/sys/net/ipv4/tcp_wmem)"
    fi
    echo ""

    echo "测试配置:"
    echo "  服务器: $SERVER_HOST"
    echo "  端口: $IPERF3_PORT"
    echo "  测试时长: ${TEST_DURATION}秒"
    echo ""

} | tee "$RESULTS_DIR/sysinfo.txt"

# iperf3测试原理
{
    echo "iperf3测试原理"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  - 网络带宽测试（TCP/UDP）"
    echo "  - 网络延迟和抖动测试"
    echo "  - 丢包率测试"
    echo "  - 双向同时测试"
    echo "  - 多流并发测试"
    echo ""
    echo "核心功能:"
    echo ""
    echo "1. TCP带宽测试"
    echo "   - 测量TCP最大吞吐量"
    echo "   - 支持单向和双向测试"
    echo "   - 实时显示带宽和重传"
    echo "   - 关键指标: Bandwidth (Mbps), Retransmits"
    echo ""
    echo "2. UDP带宽测试"
    echo "   - 测量UDP吞吐量和丢包"
    echo "   - 可设置目标带宽"
    echo "   - 统计丢包率和抖动"
    echo "   - 关键指标: Bandwidth, Jitter, Lost/Total"
    echo ""
    echo "3. 双向同时测试"
    echo "   - 同时测试上行和下行"
    echo "   - 评估全双工性能"
    echo "   - 检测链路对称性"
    echo ""
    echo "4. 多流并发测试"
    echo "   - 多个并发TCP/UDP流"
    echo "   - 测试多核扩展性"
    echo "   - 评估聚合带宽"
    echo ""
    echo "5. JSON输出"
    echo "   - 结构化测试结果"
    echo "   - 便于自动化解析"
    echo "   - 详细统计信息"
    echo ""
    echo "关键参数:"
    echo "  -c: 客户端模式，连接到服务器"
    echo "  -s: 服务器模式"
    echo "  -t: 测试时长（秒）"
    echo "  -b: UDP带宽限制"
    echo "  -P: 并发流数量"
    echo "  -R: 反向测试（服务器发送）"
    echo "  --bidir: 双向同时测试"
    echo "  -J: JSON格式输出"
    echo ""
} | tee "$RESULTS_DIR/principles.txt"

echo ""

# 测试1: TCP带宽测试（上行）
echo "步骤 4: TCP带宽测试（上行）..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "TCP带宽测试（上行：客户端→服务器）"
    echo "========================================"
    echo ""
    echo "测试说明:"
    echo "  - 客户端向服务器发送数据"
    echo "  - 测量上行带宽"
    echo "  - 模拟场景: 文件上传、数据备份"
    echo ""
} | tee "$RESULTS_DIR/tcp_upload.txt"

echo "运行TCP上行测试..."

if iperf3 -c $SERVER_HOST -p $IPERF3_PORT -t $TEST_DURATION -J \
    > "$RESULTS_DIR/tcp_upload_json.txt" 2>&1; then

    # 提取关键结果
    BANDWIDTH=$(grep -o '"bits_per_second":[^,]*' "$RESULTS_DIR/tcp_upload_json.txt" | \
        grep -A1 '"sum_sent"' | tail -1 | cut -d: -f2)
    RETRANSMITS=$(grep -o '"retransmits":[^,]*' "$RESULTS_DIR/tcp_upload_json.txt" | \
        tail -1 | cut -d: -f2)

    if [[ -n "$BANDWIDTH" ]]; then
        BANDWIDTH_MBPS=$(echo "scale=2; $BANDWIDTH / 1000000" | bc)
        {
            echo ""
            echo "测试结果:"
            echo "  带宽: ${BANDWIDTH_MBPS} Mbps"
            echo "  重传次数: ${RETRANSMITS:-0}"
            echo ""

            # 性能评级
            BANDWIDTH_INT=${BANDWIDTH_MBPS%.*}
            if [[ $BANDWIDTH_INT -ge 9000 ]]; then
                echo "  性能评级: ★★★★★ 卓越 (>= 9 Gbps)"
                echo "  网络类型: 10GbE或更高"
            elif [[ $BANDWIDTH_INT -ge 900 ]]; then
                echo "  性能评级: ★★★★☆ 优秀 (>= 900 Mbps)"
                echo "  网络类型: 1GbE线速"
            elif [[ $BANDWIDTH_INT -ge 500 ]]; then
                echo "  性能评级: ★★★☆☆ 良好 (>= 500 Mbps)"
                echo "  网络类型: 1GbE部分带宽"
            elif [[ $BANDWIDTH_INT -ge 90 ]]; then
                echo "  性能评级: ★★☆☆☆ 一般 (>= 90 Mbps)"
                echo "  网络类型: 100Mbps"
            else
                echo "  性能评级: ★☆☆☆☆ 较低 (< 90 Mbps)"
                echo "  网络类型: 受限或拥塞"
            fi

            # 重传分析
            if [[ -n "$RETRANSMITS" ]] && [[ $RETRANSMITS -gt 0 ]]; then
                echo ""
                echo "  ⚠ 检测到TCP重传: $RETRANSMITS 次"
                if [[ $RETRANSMITS -gt 100 ]]; then
                    echo "    严重: 可能存在网络丢包或拥塞"
                elif [[ $RETRANSMITS -gt 10 ]]; then
                    echo "    中等: 建议检查网络质量"
                else
                    echo "    轻微: 可接受范围"
                fi
            fi
            echo ""
        } | tee -a "$RESULTS_DIR/tcp_upload.txt"
    else
        echo "  ✗ 无法提取带宽数据" | tee -a "$RESULTS_DIR/tcp_upload.txt"
    fi

    # 保存可读格式
    iperf3 -c $SERVER_HOST -p $IPERF3_PORT -t $TEST_DURATION 2>&1 | \
        tee -a "$RESULTS_DIR/tcp_upload.txt"
else
    echo "  ⚠ TCP上行测试失败（可能服务器不可达）" | tee -a "$RESULTS_DIR/tcp_upload.txt"
fi

echo ""

# 测试2: TCP带宽测试（下行）
echo "步骤 5: TCP带宽测试（下行）..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "TCP带宽测试（下行：服务器→客户端）"
    echo "========================================"
    echo ""
    echo "测试说明:"
    echo "  - 服务器向客户端发送数据"
    echo "  - 测量下行带宽"
    echo "  - 模拟场景: 文件下载、视频流"
    echo ""
} | tee "$RESULTS_DIR/tcp_download.txt"

echo "运行TCP下行测试..."

if iperf3 -c $SERVER_HOST -p $IPERF3_PORT -R -t $TEST_DURATION -J \
    > "$RESULTS_DIR/tcp_download_json.txt" 2>&1; then

    BANDWIDTH=$(grep -o '"bits_per_second":[^,]*' "$RESULTS_DIR/tcp_download_json.txt" | \
        grep -A1 '"sum_received"' | tail -1 | cut -d: -f2)

    if [[ -n "$BANDWIDTH" ]]; then
        BANDWIDTH_MBPS=$(echo "scale=2; $BANDWIDTH / 1000000" | bc)
        {
            echo ""
            echo "测试结果:"
            echo "  带宽: ${BANDWIDTH_MBPS} Mbps"
            echo ""
        } | tee -a "$RESULTS_DIR/tcp_download.txt"
    fi

    iperf3 -c $SERVER_HOST -p $IPERF3_PORT -R -t $TEST_DURATION 2>&1 | \
        tee -a "$RESULTS_DIR/tcp_download.txt"
else
    echo "  ⚠ TCP下行测试失败" | tee -a "$RESULTS_DIR/tcp_download.txt"
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
    echo "  - UDP协议传输测试"
    echo "  - 测量带宽、抖动、丢包率"
    echo "  - 模拟场景: 视频直播、VoIP、游戏"
    echo ""
} | tee "$RESULTS_DIR/udp_test.txt"

echo "运行UDP测试（目标带宽1Gbps）..."

if iperf3 -c $SERVER_HOST -p $IPERF3_PORT -u -b 1G -t $TEST_DURATION -J \
    > "$RESULTS_DIR/udp_test_json.txt" 2>&1; then

    # 提取UDP结果
    BANDWIDTH=$(grep -o '"bits_per_second":[^,]*' "$RESULTS_DIR/udp_test_json.txt" | tail -1 | cut -d: -f2)
    JITTER=$(grep -o '"jitter_ms":[^,]*' "$RESULTS_DIR/udp_test_json.txt" | tail -1 | cut -d: -f2)
    LOST=$(grep -o '"lost_packets":[^,]*' "$RESULTS_DIR/udp_test_json.txt" | tail -1 | cut -d: -f2)
    TOTAL=$(grep -o '"packets":[^,]*' "$RESULTS_DIR/udp_test_json.txt" | tail -1 | cut -d: -f2)

    if [[ -n "$BANDWIDTH" ]]; then
        BANDWIDTH_MBPS=$(echo "scale=2; $BANDWIDTH / 1000000" | bc)
        LOSS_PERCENT=$(echo "scale=2; ($LOST / $TOTAL) * 100" | bc 2>/dev/null || echo "0")

        {
            echo ""
            echo "测试结果:"
            echo "  带宽: ${BANDWIDTH_MBPS} Mbps"
            echo "  抖动: ${JITTER} ms"
            echo "  丢包: ${LOST}/${TOTAL} (${LOSS_PERCENT}%)"
            echo ""

            # 丢包率评估
            LOSS_INT=${LOSS_PERCENT%.*}
            if [[ $LOSS_INT -eq 0 ]] || (( $(echo "$LOSS_PERCENT < 0.01" | bc -l) )); then
                echo "  丢包评级: ★★★★★ 优秀 (< 0.01%)"
            elif (( $(echo "$LOSS_PERCENT < 0.1" | bc -l) )); then
                echo "  丢包评级: ★★★★☆ 良好 (< 0.1%)"
            elif (( $(echo "$LOSS_PERCENT < 1" | bc -l) )); then
                echo "  丢包评级: ★★★☆☆ 一般 (< 1%)"
            elif (( $(echo "$LOSS_PERCENT < 5" | bc -l) )); then
                echo "  丢包评级: ★★☆☆☆ 较差 (< 5%)"
            else
                echo "  丢包评级: ★☆☆☆☆ 很差 (>= 5%)"
            fi
            echo ""
        } | tee -a "$RESULTS_DIR/udp_test.txt"
    fi

    iperf3 -c $SERVER_HOST -p $IPERF3_PORT -u -b 1G -t $TEST_DURATION 2>&1 | \
        tee -a "$RESULTS_DIR/udp_test.txt"
else
    echo "  ⚠ UDP测试失败" | tee -a "$RESULTS_DIR/udp_test.txt"
fi

echo ""

# 测试4: 双向同时测试
echo "步骤 7: 双向同时测试（全双工）..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "双向同时测试（全双工）"
    echo "========================================"
    echo ""
    echo "测试说明:"
    echo "  - 同时测试上行和下行"
    echo "  - 评估全双工性能"
    echo "  - 检测链路对称性"
    echo ""
} | tee "$RESULTS_DIR/bidirectional.txt"

echo "运行双向测试..."

if iperf3 -c $SERVER_HOST -p $IPERF3_PORT --bidir -t $TEST_DURATION 2>&1 | \
    tee -a "$RESULTS_DIR/bidirectional.txt"; then

    {
        echo ""
        echo "分析:"
        echo "  对比上行和下行带宽"
        echo "  检查是否存在不对称性"
        echo ""
    } | tee -a "$RESULTS_DIR/bidirectional.txt"
else
    echo "  ⚠ 双向测试失败" | tee -a "$RESULTS_DIR/bidirectional.txt"
fi

echo ""

# 测试5: 多流并发测试
echo "步骤 8: 多流并发测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "多流并发测试"
    echo "========================================"
    echo ""
    echo "测试说明:"
    echo "  - 测试多个并发TCP流"
    echo "  - 评估多核扩展性"
    echo "  - 测量聚合带宽"
    echo ""
    echo "流数量  带宽(Mbps)  相对基准"
    echo "------  ---------  --------"
} | tee "$RESULTS_DIR/parallel.txt"

STREAM_COUNTS=(1 2 4 8)

for count in "${STREAM_COUNTS[@]}"; do
    echo "测试 $count 个并发流..."

    OUTPUT=$(iperf3 -c $SERVER_HOST -p $IPERF3_PORT -P $count -t 5 -J 2>&1)
    echo "$OUTPUT" > "$RESULTS_DIR/parallel_${count}.json"

    BANDWIDTH=$(echo "$OUTPUT" | grep -o '"bits_per_second":[^,]*' | \
        grep -A1 '"sum_sent"' | tail -1 | cut -d: -f2)

    if [[ -n "$BANDWIDTH" ]]; then
        BANDWIDTH_MBPS=$(echo "scale=2; $BANDWIDTH / 1000000" | bc)

        if [[ $count -eq 1 ]]; then
            BASELINE=$BANDWIDTH_MBPS
            RATIO="1.00"
        else
            RATIO=$(echo "scale=2; $BANDWIDTH_MBPS / $BASELINE" | bc)
        fi

        printf "%-6d  %-11s  %sx\n" "$count" "$BANDWIDTH_MBPS" "$RATIO" | \
            tee -a "$RESULTS_DIR/parallel.txt"
    fi
done

echo "" | tee -a "$RESULTS_DIR/parallel.txt"
echo ""

# 生成测试报告
{
    echo "iperf3 网络性能测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo "目标服务器: $SERVER_HOST"
    echo ""

    echo "测试结果汇总:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # TCP上行
    if [[ -f "$RESULTS_DIR/tcp_upload.txt" ]]; then
        UPLOAD=$(grep "带宽:" "$RESULTS_DIR/tcp_upload.txt" | head -1 | awk '{print $2, $3}')
        if [[ -n "$UPLOAD" ]]; then
            echo "✓ TCP上行带宽: $UPLOAD"
        fi
    fi

    # TCP下行
    if [[ -f "$RESULTS_DIR/tcp_download.txt" ]]; then
        DOWNLOAD=$(grep "带宽:" "$RESULTS_DIR/tcp_download.txt" | head -1 | awk '{print $2, $3}')
        if [[ -n "$DOWNLOAD" ]]; then
            echo "✓ TCP下行带宽: $DOWNLOAD"
        fi
    fi

    # UDP测试
    if [[ -f "$RESULTS_DIR/udp_test.txt" ]]; then
        UDP_BW=$(grep "带宽:" "$RESULTS_DIR/udp_test.txt" | head -1 | awk '{print $2, $3}')
        UDP_LOSS=$(grep "丢包:" "$RESULTS_DIR/udp_test.txt" | head -1 | awk '{print $2}')
        if [[ -n "$UDP_BW" ]]; then
            echo "✓ UDP带宽: $UDP_BW"
            echo "  UDP丢包: $UDP_LOSS"
        fi
    fi

    echo ""

    echo "详细结果文件:"
    echo "  系统信息: $RESULTS_DIR/sysinfo.txt"
    echo "  测试原理: $RESULTS_DIR/principles.txt"
    echo "  TCP上行: $RESULTS_DIR/tcp_upload.txt"
    echo "  TCP下行: $RESULTS_DIR/tcp_download.txt"
    echo "  UDP测试: $RESULTS_DIR/udp_test.txt"
    echo "  双向测试: $RESULTS_DIR/bidirectional.txt"
    echo "  并发测试: $RESULTS_DIR/parallel.txt"
    echo ""

    echo "JSON格式结果:"
    echo "  TCP上行JSON: $RESULTS_DIR/tcp_upload_json.txt"
    echo "  TCP下行JSON: $RESULTS_DIR/tcp_download_json.txt"
    echo "  UDP测试JSON: $RESULTS_DIR/udp_test_json.txt"
    echo ""

    echo "高级测试:"
    echo "  如需进行更多高级测试，可使用:"
    echo "  $SCRIPT_DIR/iperf3_advanced.sh"
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
