#!/bin/bash
# 内存测试示例脚本

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         内存访问性能测试示例                              ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

cd "$(dirname "$0")/../../tests/mem"

# 编译程序
if [ ! -f mem_test ]; then
    echo ">>> 编译测试程序..."
    make
    echo ""
fi

echo ">>> 示例1: 基本运行（所有测试）"
echo "命令: ./mem_test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./mem_test
echo ""

echo ">>> 示例2: 只测试顺序读，使用 128MB 缓冲区"
echo "命令: ./mem_test -t 1 -s 128"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./mem_test -t 1 -s 128
echo ""

echo ">>> 示例3: 对比顺序读 vs 随机读"
echo "命令: ./mem_test -t 1 -s 64 && ./mem_test -t 3 -s 64"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "顺序读:"
./mem_test -t 1 -s 64 -n 5 | grep "顺序读"
echo ""
echo "随机读:"
./mem_test -t 3 -s 64 -n 5 | grep "随机读"
echo ""

echo ">>> 示例4: 对比伪共享 vs 无伪共享"
echo "命令: ./mem_test -t 6 -p 8 && ./mem_test -t 7 -p 8"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "伪共享（性能差）:"
./mem_test -t 6 -p 8 | grep "伪共享"
echo ""
echo "无伪共享（性能好）:"
./mem_test -t 7 -p 8 | grep "无伪共享"
echo ""

echo ">>> 示例5: 使用 perf stat 分析缓存（如果支持）"
echo "命令: perf stat -e cache-references,cache-misses ./mem_test -t 1 -s 64 -n 5"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if command -v perf >/dev/null 2>&1; then
    if perf list | grep -q "cache-references"; then
        perf stat -e cache-references,cache-misses ./mem_test -t 1 -s 64 -n 5 2>&1 | tail -10
    else
        echo "⚠ 硬件缓存事件不可用"
        perf stat -e cpu-clock,page-faults ./mem_test -t 1 -s 64 -n 5 2>&1 | tail -10
    fi
else
    echo "⚠ perf 未安装"
fi
echo ""

echo ">>> 示例6: 使用 perf mem 分析（如果支持）"
echo "命令: perf mem record ./mem_test -t 1 -s 32 -n 3"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if command -v perf >/dev/null 2>&1; then
    if perf mem record --help >/dev/null 2>&1; then
        perf mem record ./mem_test -t 1 -s 32 -n 3 2>&1 | head -20
        echo ""
        echo ">>> 查看 perf mem report:"
        perf mem report 2>&1 | head -30
    else
        echo "⚠ perf mem 不支持（需要硬件 PEBS/IBS 支持）"
    fi
else
    echo "⚠ perf 未安装"
fi
echo ""

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  示例完成！                                               ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "更多用法，请查看: tests/mem/README.md"
