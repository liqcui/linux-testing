#!/bin/bash
# 系统调用测试示例脚本

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         系统调用性能测试示例                              ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

cd "$(dirname "$0")/../../tests/syscalls"

# 编译程序
if [ ! -f syscalls_test ]; then
    echo ">>> 编译测试程序..."
    make
    echo ""
fi

echo ">>> 示例1: 基本运行"
echo "命令: ./syscalls_test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./syscalls_test
echo ""

echo ">>> 示例2: 只测试 getpid()"
echo "命令: ./syscalls_test -t 1 -n 100000"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./syscalls_test -t 1 -n 100000
echo ""

echo ">>> 示例3: 使用 perf 分析"
echo "命令: perf stat -e cycles -e instructions ./syscalls_test -t 1"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if command -v perf >/dev/null 2>&1; then
    perf stat -e cycles -e instructions -e cache-misses ./syscalls_test -t 1 2>&1 | head -20
else
    echo "⚠ perf 未安装"
fi
echo ""

echo ">>> 示例4: 使用 strace 统计"
echo "命令: strace -c ./syscalls_test -t 1 -n 10000"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if command -v strace >/dev/null 2>&1; then
    strace -c ./syscalls_test -t 1 -n 10000 2>&1
else
    echo "⚠ strace 未安装"
fi
echo ""

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  示例完成！                                               ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "更多用法，请查看: tests/syscalls/README.md"
