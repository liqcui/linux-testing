#!/bin/bash
# 网络性能测试脚本

set -e

OUTPUT_DIR="./results/network"
mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "========================================="
echo "网络性能测试"
echo "时间: $(date)"
echo "========================================="

# 1. 基本网络跟踪
echo ""
echo "[1/4] 跟踪 ping 数据包流程..."
perf trace -e 'net:*' ping -c 1 8.8.8.8 > "$OUTPUT_DIR/ping_trace_$TIMESTAMP.txt" 2>&1
echo "✓ 结果保存到: $OUTPUT_DIR/ping_trace_$TIMESTAMP.txt"

# 2. 完整的发送和接收事件
echo ""
echo "[2/4] 记录详细网络事件..."
perf record -e 'net:*' -a -o "$OUTPUT_DIR/ping_record_$TIMESTAMP.data" ping -c 3 8.8.8.8 2>&1
perf script -i "$OUTPUT_DIR/ping_record_$TIMESTAMP.data" > "$OUTPUT_DIR/ping_events_$TIMESTAMP.txt"
echo "✓ 结果保存到: $OUTPUT_DIR/ping_events_$TIMESTAMP.txt"

# 3. 网络接口统计
echo ""
echo "[3/4] 收集网络接口信息..."
{
    echo "=== 网络接口列表 ==="
    ip link show
    echo ""
    echo "=== 网络统计 ==="
    cat /proc/net/dev
    echo ""
    echo "=== Socket 统计 ==="
    ss -s
} > "$OUTPUT_DIR/network_info_$TIMESTAMP.txt"
echo "✓ 结果保存到: $OUTPUT_DIR/network_info_$TIMESTAMP.txt"

# 4. 生成报告
echo ""
echo "[4/4] 生成测试报告..."
{
    echo "网络性能测试报告"
    echo "================"
    echo "测试时间: $(date)"
    echo "主机名: $(hostname)"
    echo ""
    echo "## 关键发现"
    echo ""
    echo "### Ping 延迟"
    grep "time=" "$OUTPUT_DIR/ping_trace_$TIMESTAMP.txt" || echo "未找到延迟数据"
    echo ""
    echo "### 网络事件统计"
    grep -c "net:net_dev_xmit" "$OUTPUT_DIR/ping_events_$TIMESTAMP.txt" 2>/dev/null | \
        xargs -I {} echo "发送事件数: {}" || echo "发送事件数: 0"
    grep -c "net:netif_receive_skb" "$OUTPUT_DIR/ping_events_$TIMESTAMP.txt" 2>/dev/null | \
        xargs -I {} echo "接收事件数: {}" || echo "接收事件数: 0"
} > "$OUTPUT_DIR/report_$TIMESTAMP.txt"

echo "✓ 报告保存到: $OUTPUT_DIR/report_$TIMESTAMP.txt"
echo ""
echo "========================================="
echo "测试完成！"
echo "所有结果保存在: $OUTPUT_DIR"
echo "========================================="

# 清理 perf 数据文件（可选）
# rm -f "$OUTPUT_DIR/ping_record_$TIMESTAMP.data"
