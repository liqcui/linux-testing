#!/bin/bash
# execsnoop 测试脚本

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         execsnoop - 进程执行跟踪测试                      ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# 检查是否以 root 运行
if [ "$EUID" -ne 0 ]; then
    echo "错误: 此测试需要 root 权限"
    echo "请使用: sudo $0"
    exit 1
fi

# 检查 execsnoop 是否可用
if ! command -v execsnoop >/dev/null 2>&1; then
    echo "错误: execsnoop 未安装"
    echo ""
    echo "安装方法:"
    echo "  RHEL/CentOS/Fedora: sudo dnf install bcc-tools"
    echo "  Ubuntu/Debian:      sudo apt-get install bpfcc-tools"
    exit 1
fi

echo "========================================="
echo "1. 基本使用 - 跟踪所有进程执行"
echo "========================================="
echo ""

echo "命令: execsnoop"
echo "说明: 实时显示所有新执行的进程"
echo ""
echo "启动 execsnoop（5秒）..."
echo "同时在另一个终端运行一些命令来产生测试数据"
echo ""

# 后台运行 execsnoop 5秒
timeout 5 execsnoop > /tmp/execsnoop_basic.txt 2>&1 &
SNOOP_PID=$!

# 等待 execsnoop 启动
sleep 1

# 生成一些进程执行事件
echo "生成测试进程..."
ls /tmp > /dev/null
date > /dev/null
pwd > /dev/null
whoami > /dev/null
uname -a > /dev/null

# 等待 execsnoop 完成
wait $SNOOP_PID

echo "捕获到的进程执行:"
cat /tmp/execsnoop_basic.txt | head -20
echo ""

echo "示例输出解析:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PCOMM            PID    PPID   RET ARGS"
echo "bash             12345  12340    0 /bin/bash"
echo "ls               12346  12345    0 /bin/ls /tmp"
echo ""
echo "字段说明:"
echo "- PCOMM: 父进程命令"
echo "- PID: 进程 ID"
echo "- PPID: 父进程 ID"
echo "- RET: 返回值（0=成功，非0=失败）"
echo "- ARGS: 完整命令行参数"
echo ""

echo "========================================="
echo "2. 显示时间戳"
echo "========================================="
echo ""

echo "命令: execsnoop -t"
echo "说明: 显示每个进程执行的精确时间"
echo ""

timeout 5 execsnoop -t > /tmp/execsnoop_time.txt 2>&1 &
SNOOP_PID=$!

sleep 1

# 生成带时间戳的测试
for i in {1..3}; do
    echo "执行测试 $i..."
    ls / > /dev/null
    sleep 0.5
done

wait $SNOOP_PID

echo "带时间戳的输出:"
cat /tmp/execsnoop_time.txt | head -15
echo ""

echo "========================================="
echo "3. 只显示失败的执行"
echo "========================================="
echo ""

echo "命令: execsnoop -x"
echo "说明: 只显示返回值非 0 的失败执行"
echo ""

timeout 5 execsnoop -x > /tmp/execsnoop_fail.txt 2>&1 &
SNOOP_PID=$!

sleep 1

# 尝试执行不存在的命令
/bin/nonexistent_command 2>/dev/null || true
/usr/bin/fake_program 2>/dev/null || true

wait $SNOOP_PID

if [ -s /tmp/execsnoop_fail.txt ]; then
    echo "捕获到的失败执行:"
    cat /tmp/execsnoop_fail.txt
else
    echo "没有捕获到失败的执行（这是正常的）"
fi
echo ""

echo "========================================="
echo "4. 过滤特定进程名"
echo "========================================="
echo ""

echo "命令: execsnoop -n bash"
echo "说明: 只显示 bash 进程执行的命令"
echo ""

timeout 5 execsnoop -n bash > /tmp/execsnoop_filter.txt 2>&1 &
SNOOP_PID=$!

sleep 1

# 通过 bash 执行一些命令
bash -c "ls /tmp" > /dev/null
bash -c "date" > /dev/null
bash -c "whoami" > /dev/null

wait $SNOOP_PID

echo "bash 执行的命令:"
cat /tmp/execsnoop_filter.txt
echo ""

echo "========================================="
echo "5. 实际应用场景"
echo "========================================="
echo ""

echo "场景1: 调试启动脚本"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "使用 execsnoop 查看启动脚本执行了哪些子进程"
echo ""
echo "示例:"
echo "  sudo execsnoop -t > startup_trace.txt &"
echo "  ./startup.sh"
echo "  fg  # 停止 execsnoop"
echo ""

echo "场景2: 安全审计"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "监控可疑的进程执行（如反弹 shell）"
echo ""
echo "示例:"
echo "  sudo execsnoop | grep -E 'nc|bash|sh|python'"
echo ""

echo "场景3: 性能分析"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "发现频繁执行的短暂进程（可能影响性能）"
echo ""
echo "示例:"
echo "  sudo execsnoop > process_exec.log"
echo "  # 运行一段时间后"
echo "  sort process_exec.log | uniq -c | sort -rn | head"
echo ""

echo "场景4: 故障排查"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "追踪复杂脚本的执行流程"
echo ""
echo "示例:"
echo "  sudo execsnoop -t -p \$(pgrep complex_script)"
echo ""

echo "========================================="
echo "总结"
echo "========================================="
echo ""
echo "✓ execsnoop 可以捕获所有进程执行，包括短暂进程"
echo "✓ 支持时间戳、过滤、失败检测等功能"
echo "✓ 开销很小，适合长时间运行"
echo "✓ 是调试、审计、性能分析的强大工具"
echo ""

# 清理
rm -f /tmp/execsnoop_*.txt

echo "测试完成！"
echo ""
echo "更多信息: man execsnoop"
echo "详细结果解析: ../docs/results/RESULTS_EXECSNOOP.md"
