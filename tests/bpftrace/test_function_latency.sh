#!/bin/bash
# test_function_latency.sh - 内核函数延迟直方图测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOCK_DIR="$SCRIPT_DIR/mock_programs"

echo "================================"
echo "bpftrace 内核函数延迟测试"
echo "================================"
echo ""

# 检查 bpftrace
if ! command -v bpftrace &> /dev/null; then
    echo "错误: bpftrace 未安装"
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
if [[ ! -f latency_simulator ]]; then
    echo "编译 latency_simulator..."
    make latency_simulator
fi

echo "测试场景 1: do_nanosleep 延迟直方图"
echo "===================================="
echo ""
echo "latency_simulator 将产生不同延迟: 1ms, 5ms, 10ms, 50ms, 100ms"
echo ""

# 后台运行模拟程序
./latency_simulator 30 &
PID=$!

echo "模拟程序 PID: $PID"
echo ""
echo "运行 bpftrace 跟踪 do_nanosleep 延迟..."
echo ""

# 跟踪延迟
timeout 35 bpftrace -e "
kprobe:do_nanosleep {
    @start[tid] = nsecs;
}

kretprobe:do_nanosleep /@start[tid]/ {
    @usecs = hist((nsecs - @start[tid]) / 1000);
    delete(@start[tid]);
}

END {
    printf(\"\\ndo_nanosleep 延迟分布 (微秒):\\n\");
    print(@usecs);
    clear(@start);
}
"

wait $PID 2>/dev/null

echo ""
echo "测试场景 2: 通用睡眠延迟分析"
echo "============================="
echo ""

./latency_simulator 30 &
PID=$!

echo "模拟程序 PID: $PID"
echo ""
echo "运行 bpftrace 跟踪所有睡眠操作..."
echo ""

timeout 35 bpftrace -e "
kprobe:do_nanosleep /pid == $PID/ {
    @start[tid] = nsecs;
    @sleep_count++;
}

kretprobe:do_nanosleep /@start[tid]/ {
    \$duration_us = (nsecs - @start[tid]) / 1000;
    @latency_hist = hist(\$duration_us);
    @total_sleep_us += \$duration_us;
    delete(@start[tid]);
}

interval:s:5 {
    printf(\"\\n[%d秒] 已跟踪 %d 次睡眠，总延迟 %d us\\n\",
           elapsed / 1000000000, @sleep_count, @total_sleep_us);
}

END {
    printf(\"\\n=== 最终统计 ===\\n\");
    printf(\"总睡眠次数: %d\\n\", @sleep_count);
    printf(\"总延迟时间: %d us (%.2f ms)\\n\",
           @total_sleep_us, @total_sleep_us / 1000.0);
    if (@sleep_count > 0) {
        printf(\"平均延迟: %d us\\n\", @total_sleep_us / @sleep_count);
    }
    printf(\"\\n延迟分布:\\n\");
    print(@latency_hist);
    clear(@start);
}
"

wait $PID 2>/dev/null

echo ""
echo "================================"
echo "测试完成！"
echo "================================"
echo ""
echo "结果说明:"
echo "  - 直方图显示延迟分布，横轴是微秒(us)"
echo "  - 可以看到 1ms, 5ms, 10ms, 50ms, 100ms 的延迟峰值"
echo "  - @usecs 是延迟时间的直方图"
echo "  - 数字越大延迟越高"
echo ""
echo "直方图解读:"
echo "  [1K, 2K)   : 1000-2000 us (1-2 ms)"
echo "  [4K, 8K)   : 4000-8000 us (4-8 ms)"
echo "  [8K, 16K)  : 8000-16000 us (8-16 ms)"
echo "  [32K, 64K) : 32000-64000 us (32-64 ms)"
echo "  [64K, 128K): 64000-128000 us (64-128 ms)"
echo ""
