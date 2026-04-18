#!/bin/bash
# lock_test 调试和诊断脚本

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         Perf Lock 诊断和增强测试                          ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# 检查是否已编译
if [ ! -f lock_test ]; then
    echo "编译 lock_test..."
    make
    echo ""
fi

echo "========================================="
echo "1. 系统环境检查"
echo "========================================="
echo ""

echo "内核版本:"
uname -r
echo ""

echo "perf 版本:"
perf --version
echo ""

echo "检查 lock 事件支持:"
perf list | grep -i lock: || echo "未找到 lock: 事件"
echo ""

echo "检查 perf_event_paranoid:"
cat /proc/sys/kernel/perf_event_paranoid
echo ""

echo "检查 debugfs 挂载:"
mount | grep debugfs || echo "debugfs 未挂载"
echo ""

echo "检查 lock_stat:"
if [ -f /proc/lock_stat ]; then
    echo "✓ /proc/lock_stat 存在"
else
    echo "✗ /proc/lock_stat 不存在 (需要 CONFIG_LOCK_STAT=y)"
fi
echo ""

echo "========================================="
echo "2. 增加锁竞争强度测试"
echo "========================================="
echo ""

echo "测试1: 高竞争 - 8线程 × 500K 迭代"
echo "命令: perf lock record -g ./lock_test -t 1 -p 8 -n 500000"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
perf lock record -g ./lock_test -t 1 -p 8 -n 500000 2>&1 | tail -5
echo ""

echo "查看记录的事件数量:"
perf script | head -20
echo ""

echo "生成报告:"
perf lock report
echo ""

echo "========================================="
echo "3. 使用 perf record 替代方案"
echo "========================================="
echo ""

echo "使用常规 perf record 捕获锁竞争:"
echo "命令: perf record -e sched:sched_stat_* -g ./lock_test -t 1 -p 8 -n 100000"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if perf list | grep -q "sched:sched_stat_sleep"; then
    perf record -e sched:sched_stat_sleep,sched:sched_stat_blocked \
        -g ./lock_test -t 1 -p 4 -n 100000 2>&1
    echo ""
    echo "查看报告:"
    perf report --stdio | head -40
else
    echo "⚠ sched 事件不可用"
fi
echo ""

echo "========================================="
echo "4. 使用 perf stat 查看性能指标"
echo "========================================="
echo ""

echo "测试伪共享 vs 无伪共享的性能差异:"
echo ""

echo "伪共享测试:"
if perf list | grep -q "cpu-clock"; then
    perf stat -e cpu-clock,task-clock,context-switches \
        ./lock_test -t 6 -p 8 2>&1 | grep -A 10 "Performance counter"
else
    time ./lock_test -t 6 -p 8 2>&1 | grep "伪共享"
fi
echo ""

echo "无伪共享测试:"
if perf list | grep -q "cpu-clock"; then
    perf stat -e cpu-clock,task-clock,context-switches \
        ./lock_test -t 7 -p 8 2>&1 | grep -A 10 "Performance counter"
else
    time ./lock_test -t 7 -p 8 2>&1 | grep "无伪共享"
fi
echo ""

echo "========================================="
echo "5. 使用 strace 查看锁竞争"
echo "========================================="
echo ""

if command -v strace >/dev/null 2>&1; then
    echo "使用 strace 跟踪 futex 系统调用（锁实现）:"
    echo "命令: strace -c -f ./lock_test -t 1 -p 4 -n 50000"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    strace -c -f ./lock_test -t 1 -p 4 -n 50000 2>&1 | tail -20
else
    echo "⚠ strace 未安装"
fi
echo ""

echo "========================================="
echo "6. 带调试符号重新编译"
echo "========================================="
echo ""

echo "使用 -g 重新编译以获得更好的符号信息:"
gcc -g -O2 -Wall -Wextra -pthread -o lock_test_debug lock_test.c
echo "✓ 编译完成: lock_test_debug"
echo ""

echo "使用带调试符号的版本测试:"
perf lock record -g ./lock_test_debug -t 1 -p 8 -n 200000 2>&1 | tail -5
echo ""

echo "查看报告:"
perf lock report
echo ""

echo "========================================="
echo "7. 对比不同测试场景"
echo "========================================="
echo ""

echo "直接运行程序，查看性能差异:"
echo ""

echo "场景1: 单锁竞争 (高竞争)"
./lock_test -t 1 -p 8 -n 100000 2>&1 | grep "ops/sec"
echo ""

echo "场景2: 多锁并发 (低竞争)"
./lock_test -t 2 -p 8 -n 100000 2>&1 | grep "ops/sec"
echo ""

echo "场景3: 伪共享 (缓存行颠簸)"
./lock_test -t 6 -p 8 2>&1 | grep "ops/sec"
echo ""

echo "场景4: 无伪共享 (无颠簸)"
./lock_test -t 7 -p 8 2>&1 | grep "ops/sec"
echo ""

echo "========================================="
echo "诊断总结"
echo "========================================="
echo ""

echo "如果 perf lock report 显示的信息很少，可能的原因："
echo ""
echo "1. 内核没有编译 CONFIG_LOCK_STAT=y"
echo "   解决：使用发行版提供的调试内核，或重新编译内核"
echo ""
echo "2. 锁事件跟踪点不可用"
echo "   检查：perf list | grep lock:"
echo "   解决：升级内核版本"
echo ""
echo "3. 锁竞争时间太短，未被采样"
echo "   解决：增加线程数和迭代次数"
echo ""
echo "4. 缺少调试符号"
echo "   解决：使用 -g 编译，或安装 debuginfo 包"
echo ""
echo "替代方案："
echo ""
echo "1. 使用程序自身的性能输出进行对比分析"
echo "   ./lock_test 会显示各场景的 ops/sec"
echo ""
echo "2. 使用 perf stat 查看系统级别的性能指标"
echo "   perf stat -e context-switches,cpu-migrations ./lock_test"
echo ""
echo "3. 使用 strace 查看 futex 系统调用（锁的底层实现）"
echo "   strace -c -f ./lock_test"
echo ""
echo "4. 对比不同场景的执行时间"
echo "   time ./lock_test -t 1  # 单锁"
echo "   time ./lock_test -t 2  # 多锁"
echo ""

echo "========================================="
echo "完成！"
echo "========================================="
