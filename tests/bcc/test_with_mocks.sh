#!/bin/bash
# BCC 工具完整测试脚本（使用模拟程序）

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         BCC 工具完整测试（含模拟程序）                    ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# 检查权限
if [ "$EUID" -ne 0 ]; then
    echo "错误: 此测试需要 root 权限"
    echo "请使用: sudo $0"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOCK_DIR="$SCRIPT_DIR/mock_programs"

echo "========================================="
echo "1. 编译模拟程序"
echo "========================================="
echo ""

cd "$MOCK_DIR"
make clean
make

if [ $? -ne 0 ]; then
    echo "错误: 模拟程序编译失败"
    exit 1
fi

echo ""
echo "✓ 所有模拟程序编译成功"
echo ""

cd "$SCRIPT_DIR"

echo "========================================="
echo "2. 检查 BCC 工具"
echo "========================================="
echo ""

./check_bcc.sh | grep -E "✓|✗" | head -15
echo ""

# 询问是否继续
read -p "是否继续运行测试? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

echo "========================================="
echo "3. 运行测试"
echo "========================================="
echo ""

# 测试列表
tests=(
    "execsnoop:执行跟踪"
    "opensnoop:文件打开"
)

for test in "${tests[@]}"; do
    tool="${test%%:*}"
    desc="${test##*:}"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "测试: $tool ($desc)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [ -f "./test_${tool}.sh" ]; then
        read -p "运行 $tool 测试? (y/N) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ./test_${tool}.sh
        fi
    else
        echo "⊘ 测试脚本未找到: test_${tool}.sh"
    fi

    echo ""
done

echo "========================================="
echo "4. 快速演示所有工具"
echo "========================================="
echo ""

read -p "是否运行快速演示? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

# execsnoop 演示
echo ""
echo "═══ execsnoop 演示 ═══"
echo "命令: timeout 5 execsnoop"
timeout 5 execsnoop &
SNOOP_PID=$!
sleep 1
ls / > /dev/null
date > /dev/null
wait $SNOOP_PID 2>/dev/null
echo ""

# opensnoop 演示
if command -v opensnoop >/dev/null 2>&1; then
    echo "═══ opensnoop 演示 ═══"
    echo "命令: timeout 5 opensnoop"
    timeout 5 opensnoop > /tmp/opensnoop_demo.txt 2>&1 &
    SNOOP_PID=$!
    sleep 1
    "$MOCK_DIR/file_opener" 3 500 &
    wait $! 2>/dev/null
    wait $SNOOP_PID 2>/dev/null
    head -15 /tmp/opensnoop_demo.txt
    rm -f /tmp/opensnoop_demo.txt
    echo ""
fi

# biosnoop 演示
if command -v biosnoop >/dev/null 2>&1; then
    echo "═══ biosnoop 演示 ═══"
    echo "命令: timeout 5 biosnoop"
    timeout 5 biosnoop > /tmp/biosnoop_demo.txt 2>&1 &
    SNOOP_PID=$!
    sleep 1
    "$MOCK_DIR/disk_io" 2 500 &
    wait $! 2>/dev/null
    wait $SNOOP_PID 2>/dev/null
    head -15 /tmp/biosnoop_demo.txt
    rm -f /tmp/biosnoop_demo.txt
    echo ""
fi

# tcpconnect 演示
if command -v tcpconnect >/dev/null 2>&1; then
    echo "═══ tcpconnect 演示 ═══"
    echo "命令: timeout 5 tcpconnect"
    echo "说明: 需要网络连接才能看到输出"
    timeout 5 tcpconnect > /tmp/tcpconnect_demo.txt 2>&1 &
    SNOOP_PID=$!
    sleep 1
    # 尝试连接一些常见服务
    curl -s --max-time 2 http://www.google.com > /dev/null 2>&1 || true
    wait $SNOOP_PID 2>/dev/null
    if [ -s /tmp/tcpconnect_demo.txt ]; then
        head -10 /tmp/tcpconnect_demo.txt
    else
        echo "没有捕获到 TCP 连接（正常，如果没有外网）"
    fi
    rm -f /tmp/tcpconnect_demo.txt
    echo ""
fi

# profile 演示
if command -v profile >/dev/null 2>&1; then
    echo "═══ profile 演示 ═══"
    echo "命令: timeout 5 profile"
    echo "启动 CPU 密集型程序..."
    "$MOCK_DIR/cpu_burner" 2 5000000 &
    CPU_PID=$!
    sleep 1
    timeout 5 profile > /tmp/profile_demo.txt 2>&1
    wait $CPU_PID 2>/dev/null
    echo "CPU 采样结果（Top 10）:"
    head -20 /tmp/profile_demo.txt
    rm -f /tmp/profile_demo.txt
    echo ""
fi

echo "========================================="
echo "完成！"
echo "========================================="
echo ""

echo "模拟程序位置: $MOCK_DIR"
echo "测试脚本位置: $SCRIPT_DIR"
echo ""

echo "单独运行模拟程序:"
echo "  $MOCK_DIR/file_opener [iterations] [delay_ms]"
echo "  $MOCK_DIR/disk_io [iterations] [delay_ms]"
echo "  $MOCK_DIR/tcp_client [iterations] [delay_ms]"
echo "  $MOCK_DIR/tcp_server [port] [max_connections]"
echo "  $MOCK_DIR/cpu_burner [threads] [iterations]"
echo "  $MOCK_DIR/blocker [threads] [sleep_ms]"
echo "  $MOCK_DIR/memory_leaker [duration] [leak_interval]"
echo ""

echo "单独运行测试:"
echo "  sudo ./test_execsnoop.sh"
echo "  sudo ./test_opensnoop.sh"
echo ""
