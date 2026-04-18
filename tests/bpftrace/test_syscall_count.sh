#!/bin/bash
# test_syscall_count.sh - 系统调用统计测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOCK_DIR="$SCRIPT_DIR/mock_programs"

echo "================================"
echo "bpftrace 系统调用统计测试"
echo "================================"
echo ""

# 检查 bpftrace
if ! command -v bpftrace &> /dev/null; then
    echo "错误: bpftrace 未安装"
    echo "安装方法:"
    echo "  Fedora/RHEL: sudo dnf install bpftrace"
    echo "  Ubuntu/Debian: sudo apt install bpftrace"
    exit 1
fi

# 检查权限
if [[ $EUID -ne 0 ]]; then
   echo "错误: 此脚本需要 root 权限运行"
   echo "使用: sudo $0"
   exit 1
fi

# 编译 mock 程序
cd "$MOCK_DIR"
if [[ ! -f syscall_simulator ]]; then
    echo "编译 syscall_simulator..."
    make syscall_simulator
fi

echo "测试场景 1: 统计所有系统调用（按进程）"
echo "=========================================="
echo ""

# 后台运行模拟程序
./syscall_simulator 50 &
PID=$!

echo "模拟程序 PID: $PID"
echo ""
echo "运行 bpftrace (10秒)..."
echo ""

# 统计系统调用
timeout 10 bpftrace -e "
tracepoint:raw_syscalls:sys_enter /pid == $PID/ {
    @[comm] = count();
}
END {
    printf(\"\\n进程系统调用统计:\\n\");
    print(@);
}
"

wait $PID 2>/dev/null

echo ""
echo "测试场景 2: 按系统调用类型统计"
echo "==============================="
echo ""

# 重新运行
./syscall_simulator 50 &
PID=$!

echo "模拟程序 PID: $PID"
echo ""
echo "运行 bpftrace (10秒)..."
echo ""

timeout 10 bpftrace -e "
tracepoint:syscalls:sys_enter_* /pid == $PID/ {
    @[probe] = count();
}
END {
    printf(\"\\n系统调用类型统计:\\n\");
    print(@);
}
"

wait $PID 2>/dev/null

echo ""
echo "================================"
echo "测试完成！"
echo "================================"
echo ""
echo "结果说明:"
echo "  - 第一个测试显示进程总的系统调用次数"
echo "  - 第二个测试显示每种系统调用的频率"
echo "  - syscall_simulator 主要使用: getpid, gettimeofday, open, read, close, stat, nanosleep"
echo ""
