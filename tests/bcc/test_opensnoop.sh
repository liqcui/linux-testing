#!/bin/bash
# opensnoop 测试脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共函数
if [[ -f "$SCRIPT_DIR/common.sh" ]]; then
    source "$SCRIPT_DIR/common.sh"
fi

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         opensnoop - 文件打开跟踪测试                      ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# 检查是否以 root 运行
if [ "$EUID" -ne 0 ]; then
    echo "错误: 此测试需要 root 权限"
    echo "请使用: sudo $0"
    exit 1
fi

# 查找 opensnoop 工具
OPENSNOOP=$(find_bcc_tool opensnoop)

if [[ -z "$OPENSNOOP" ]]; then
    echo "错误: opensnoop 未找到"
    echo ""
    show_bcc_install_help
    exit 1
fi

echo "使用工具: $OPENSNOOP"
echo ""
MOCK_DIR="$SCRIPT_DIR/mock_programs"

# 编译模拟程序
if [ ! -f "$MOCK_DIR/file_opener" ]; then
    echo "编译模拟程序..."
    cd "$MOCK_DIR"
    make file_opener
    cd - > /dev/null
    echo ""
fi

echo "========================================="
echo "1. 基本使用 - 跟踪所有文件打开"
echo "========================================="
echo ""

echo "命令: opensnoop"
echo "说明: 实时显示所有文件打开操作"
echo ""

timeout 10 "$OPENSNOOP" > /tmp/opensnoop_basic.txt 2>&1 &
SNOOP_PID=$!

sleep 1

echo "启动文件打开模拟程序..."
"$MOCK_DIR/file_opener" 5 500 &
MOCK_PID=$!

wait $MOCK_PID
wait $SNOOP_PID

echo "捕获到的文件打开操作:"
cat /tmp/opensnoop_basic.txt | head -30
echo ""

echo "示例输出解析:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PID    COMM               FD ERR PATH"
echo "12345  file_opener         3   0 /etc/hosts"
echo "12345  file_opener         4   0 /etc/passwd"
echo "12345  file_opener        -1   2 /tmp/nonexistent_file_12345.txt"
echo ""
echo "字段说明:"
echo "- PID: 进程 ID"
echo "- COMM: 进程命令名"
echo "- FD: 文件描述符（-1 表示打开失败）"
echo "- ERR: 错误码（0=成功，2=ENOENT文件不存在）"
echo "- PATH: 文件路径"
echo ""

echo "========================================="
echo "2. 跟踪特定进程"
echo "========================================="
echo ""

echo "命令: opensnoop -p <PID>"
echo "说明: 只跟踪指定进程的文件打开"
echo ""

# 在后台启动模拟程序
"$MOCK_DIR/file_opener" 10 300 &
MOCK_PID=$!

sleep 1

echo "跟踪进程 $MOCK_PID..."
timeout 5 "$OPENSNOOP"-p $MOCK_PID > /tmp/opensnoop_pid.txt 2>&1 &
SNOOP_PID=$!

wait $MOCK_PID
wait $SNOOP_PID

echo "进程 $MOCK_PID 的文件打开:"
cat /tmp/opensnoop_pid.txt | head -20
echo ""

echo "========================================="
echo "3. 只显示失败的打开"
echo "========================================="
echo ""

echo "命令: opensnoop -x"
echo "说明: 只显示打开失败的操作（FD=-1）"
echo ""

timeout 5 "$OPENSNOOP"-x > /tmp/opensnoop_fail.txt 2>&1 &
SNOOP_PID=$!

sleep 1

"$MOCK_DIR/file_opener" 5 500 &
MOCK_PID=$!

wait $MOCK_PID
wait $SNOOP_PID

echo "失败的文件打开操作:"
cat /tmp/opensnoop_fail.txt
echo ""

echo "========================================="
echo "4. 按进程名过滤"
echo "========================================="
echo ""

echo "命令: opensnoop -n file_opener"
echo "说明: 只显示特定名称的进程"
echo ""

timeout 10 opensnoop -n file_opener > /tmp/opensnoop_name.txt 2>&1 &
SNOOP_PID=$!

sleep 1

"$MOCK_DIR/file_opener" 5 500 &
MOCK_PID=$!

wait $MOCK_PID
wait $SNOOP_PID

echo "file_opener 进程的文件打开:"
cat /tmp/opensnoop_name.txt
echo ""

echo "========================================="
echo "5. 带时间戳跟踪"
echo "========================================="
echo ""

echo "命令: opensnoop -t"
echo "说明: 显示每次文件打开的时间戳"
echo ""

timeout 10 opensnoop -t > /tmp/opensnoop_time.txt 2>&1 &
SNOOP_PID=$!

sleep 1

"$MOCK_DIR/file_opener" 3 1000 &
MOCK_PID=$!

wait $MOCK_PID
wait $SNOOP_PID

echo "带时间戳的输出:"
cat /tmp/opensnoop_time.txt | head -20
echo ""

echo "========================================="
echo "6. 实际应用场景"
echo "========================================="
echo ""

echo "场景1: 调试程序找不到配置文件"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "问题: 程序报错找不到配置文件，但不知道它在哪里找"
echo ""
echo "解决:"
echo "  sudo opensnoop -n myapp -x"
echo "  # 启动程序"
echo "  # 查看所有失败的文件打开，找到程序期望的路径"
echo ""

echo "场景2: 性能分析 - 发现频繁打开的文件"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  sudo opensnoop > opensnoop.log &"
echo "  # 运行一段时间"
echo "  fg  # 停止"
echo "  # 分析最频繁打开的文件"
echo "  awk '{print \$NF}' opensnoop.log | sort | uniq -c | sort -rn | head"
echo ""

echo "场景3: 安全审计 - 监控敏感文件访问"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  sudo opensnoop | grep -E '/etc/shadow|/etc/passwd|/root'"
echo ""

echo "场景4: 依赖分析 - 程序使用了哪些文件"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  sudo opensnoop -p \$(pgrep nginx) > nginx_files.txt"
echo "  # 分析 nginx 访问的所有文件"
echo ""

echo "========================================="
echo "总结"
echo "========================================="
echo ""
echo "✓ opensnoop 可以跟踪所有文件打开操作"
echo "✓ 支持按进程、进程名过滤"
echo "✓ 可以只显示失败的操作"
echo "✓ 开销极小，适合长时间运行"
echo "✓ 对排查文件访问问题非常有用"
echo ""

# 清理
rm -f /tmp/opensnoop_*.txt

echo "测试完成！"
echo ""
echo "更多信息: man opensnoop"
echo "详细结果解析: ../docs/results/RESULTS_OPENSNOOP.md"
