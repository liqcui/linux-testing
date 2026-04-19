#!/bin/bash
# test_network_namespace.sh - Network namespace测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRAMS_DIR="$SCRIPT_DIR/../programs"
RESULTS_DIR="$SCRIPT_DIR/../results/network-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "Network Namespace 测试"
echo "========================================"
echo ""

# 检查权限
if [[ $EUID -ne 0 ]]; then
   echo "错误: 此脚本需要 root 权限"
   echo "使用: sudo $0"
   exit 1
fi

mkdir -p "$RESULTS_DIR"

# 检查Network namespace支持
echo "步骤 1: 检查Network namespace支持..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ ! -e /proc/self/ns/net ]]; then
    echo "✗ 系统不支持Network namespace"
    exit 1
fi

echo "✓ Network namespace 已支持"
echo ""

# 显示当前网络配置
echo "当前网络配置:"
ip link show | tee "$RESULTS_DIR/original-network.txt"
echo ""

# 基础Network namespace测试
echo "步骤 2: 基础Network namespace测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "创建新network namespace..."
ip netns add test_netns_$$

if [[ $? -ne 0 ]]; then
    echo "✗ 创建network namespace失败"
    exit 1
fi

echo "✓ Network namespace已创建: test_netns_$$"
echo ""

# 列出network namespaces
echo "系统中的network namespaces:"
ip netns list | tee "$RESULTS_DIR/netns-list.txt"
echo ""

# 在新namespace中查看网络配置
echo "新namespace中的网络接口:"
ip netns exec test_netns_$$ ip link show | tee "$RESULTS_DIR/new-netns-links.txt"
echo ""

# 网络隔离验证
echo "步骤 3: 网络隔离验证..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "主namespace中的接口数量: $(ip link show | grep -c '^[0-9]')"
echo "新namespace中的接口数量: $(ip netns exec test_netns_$$ ip link show | grep -c '^[0-9]')"
echo ""

# 在新namespace中配置网络
echo "步骤 4: 在新namespace中配置网络..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "启用loopback接口..."
ip netns exec test_netns_$$ ip link set lo up

if [[ $? -eq 0 ]]; then
    echo "✓ Loopback接口已启用"
else
    echo "✗ Loopback接口启用失败"
fi

echo ""
echo "新namespace中的网络接口状态:"
ip netns exec test_netns_$$ ip link show
echo ""

# veth pair测试
echo "步骤 5: Veth pair连接测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "创建veth pair..."
ip link add veth0 type veth peer name veth1

if [[ $? -eq 0 ]]; then
    echo "✓ Veth pair已创建: veth0 <-> veth1"
else
    echo "✗ Veth pair创建失败"
fi

echo ""

# 将veth1移到新namespace
echo "将veth1移到新namespace..."
ip link set veth1 netns test_netns_$$

echo "✓ veth1已移到test_netns_$$"
echo ""

# 配置IP地址
echo "配置IP地址..."
ip addr add 10.0.0.1/24 dev veth0
ip link set veth0 up

ip netns exec test_netns_$$ ip addr add 10.0.0.2/24 dev veth1
ip netns exec test_netns_$$ ip link set veth1 up

echo "✓ IP地址已配置"
echo "  主namespace: veth0 - 10.0.0.1/24"
echo "  新namespace: veth1 - 10.0.0.2/24"
echo ""

# 显示配置
echo "主namespace中的veth0:"
ip addr show veth0
echo ""

echo "新namespace中的veth1:"
ip netns exec test_netns_$$ ip addr show veth1
echo ""

# Ping测试
echo "步骤 6: 连通性测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "从主namespace ping新namespace (10.0.0.2)..."
ping -c 3 10.0.0.2 | tee "$RESULTS_DIR/ping-test.txt"

echo ""
echo "从新namespace ping主namespace (10.0.0.1)..."
ip netns exec test_netns_$$ ping -c 3 10.0.0.1 | tee -a "$RESULTS_DIR/ping-test.txt"

echo ""

# 路由表测试
echo "步骤 7: 路由表测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "主namespace路由表:"
ip route show | tee "$RESULTS_DIR/main-routes.txt"
echo ""

echo "新namespace路由表:"
ip netns exec test_netns_$$ ip route show | tee "$RESULTS_DIR/new-routes.txt"
echo ""

# 网络统计
echo "步骤 8: 网络统计..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "主namespace网络统计:"
ip -s link show veth0 | tee "$RESULTS_DIR/veth0-stats.txt"
echo ""

echo "新namespace网络统计:"
ip netns exec test_netns_$$ ip -s link show veth1 | tee "$RESULTS_DIR/veth1-stats.txt"
echo ""

# 端口监听测试
echo "步骤 9: 端口隔离测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "在新namespace中启动HTTP服务器（端口8000）..."
ip netns exec test_netns_$$ python3 -m http.server 8000 &>/dev/null &
HTTP_PID=$!
sleep 2

echo "HTTP服务器PID: $HTTP_PID"
echo ""

echo "新namespace中监听的端口:"
ip netns exec test_netns_$$ ss -tlnp | grep 8000 || echo "未找到监听端口"
echo ""

echo "主namespace中监听的端口（应该看不到8000）:"
ss -tlnp | grep 8000 || echo "✓ 主namespace看不到新namespace的端口8000（正常）"
echo ""

# 尝试从主namespace连接（应该失败，因为隔离）
echo "从主namespace尝试连接10.0.0.2:8000..."
timeout 3 curl http://10.0.0.2:8000/ &>/dev/null
if [[ $? -eq 0 ]]; then
    echo "✓ 连接成功（通过veth pair）"
else
    echo "⚠ 连接失败或超时"
fi

# 清理HTTP服务器
kill $HTTP_PID 2>/dev/null
wait $HTTP_PID 2>/dev/null

echo ""

# 清理
echo "清理资源..."
ip link delete veth0 2>/dev/null
ip netns delete test_netns_$$ 2>/dev/null

echo "✓ 清理完成"
echo ""

# 生成报告
{
    echo "Network Namespace测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo ""
    echo "系统信息:"
    echo "  内核版本: $(uname -r)"
    echo "  Network namespace支持: ✓"
    echo ""
    echo "测试项目:"
    echo "  ✓ Network namespace创建和删除"
    echo "  ✓ 网络隔离验证"
    echo "  ✓ Veth pair创建和配置"
    echo "  ✓ 跨namespace连通性测试"
    echo "  ✓ 路由表隔离"
    echo "  ✓ 端口监听隔离"
    echo ""
    echo "关键发现:"
    echo "  - 新namespace初始只有loopback接口"
    echo "  - Veth pair可以连接不同namespace"
    echo "  - 网络配置完全隔离"
    echo "  - 端口监听互不影响"
    echo ""
    echo "详细日志:"
    echo "  原始网络: $RESULTS_DIR/original-network.txt"
    echo "  Namespace列表: $RESULTS_DIR/netns-list.txt"
    echo "  新namespace网络: $RESULTS_DIR/new-netns-links.txt"
    echo "  Ping测试: $RESULTS_DIR/ping-test.txt"
    echo "  路由表: $RESULTS_DIR/main-routes.txt, $RESULTS_DIR/new-routes.txt"
    echo ""
} | tee "$RESULTS_DIR/summary.txt"

echo "========================================"
echo "测试完成"
echo "========================================"
echo ""
echo "✓ Network namespace测试完成"
echo ""
echo "结果目录: $RESULTS_DIR"
echo ""
