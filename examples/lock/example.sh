#!/bin/bash
# 锁测试示例脚本

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         锁性能测试示例                                    ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

cd "$(dirname "$0")/../../tests/lock"

# 编译程序
if [ ! -f lock_test ]; then
    echo ">>> 编译测试程序..."
    make
    echo ""
fi

echo ">>> 示例1: 基本运行"
echo "命令: ./lock_test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./lock_test
echo ""

echo ">>> 示例2: 只测试单锁竞争，8个线程"
echo "命令: ./lock_test -t 1 -p 8 -n 50000"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./lock_test -t 1 -p 8 -n 50000
echo ""

echo ">>> 示例3: 测试读写锁，4个线程"
echo "命令: ./lock_test -t 4 -p 4 -n 50000"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./lock_test -t 4 -p 4 -n 50000
echo ""

echo ">>> 示例4: 使用 perf lock 分析（如果支持）"
echo "命令: perf lock record ./lock_test -t 1 -p 4 -n 10000"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if command -v perf >/dev/null 2>&1; then
    if perf list | grep -q "lock:"; then
        perf lock record ./lock_test -t 1 -p 4 -n 10000 2>&1 | head -20
        echo ""
        echo ">>> 查看 perf lock report:"
        perf lock report 2>&1 | head -30
    else
        echo "⚠ 内核不支持 lock 事件跟踪"
        echo "  需要内核编译时开启 CONFIG_LOCK_STAT=y"
    fi
else
    echo "⚠ perf 未安装"
fi
echo ""

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  示例完成！                                               ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "更多用法，请查看: tests/lock/README.md"
