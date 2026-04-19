#!/bin/bash
# test_lmbench.sh - LMbench微基准测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRAMS_DIR="$SCRIPT_DIR/../programs"
RESULTS_DIR="$SCRIPT_DIR/../results/lmbench-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "LMbench 微基准测试"
echo "========================================"
echo ""

mkdir -p "$RESULTS_DIR"

# 检查编译器
echo "步骤 1: 检查编译环境..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if command -v gcc &> /dev/null; then
    echo "✓ GCC: $(gcc --version | head -1)"
    COMPILER="gcc"
elif command -v clang &> /dev/null; then
    echo "✓ Clang: $(clang --version | head -1)"
    COMPILER="clang"
else
    echo "✗ 未找到C编译器（需要gcc或clang）"
    exit 1
fi

echo ""

# LMbench原理说明
echo "步骤 2: LMbench测试原理..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "LMbench Benchmark 原理"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  LMbench (Larry McVoy's Benchmark) 是一套微基准测试"
    echo "  用于测量操作系统和硬件的基本性能指标"
    echo ""
    echo "测试类别:"
    echo ""
    echo "1. 系统调用延迟 (lat_syscall)"
    echo "   - getpid(), getppid(), getuid() 等简单系统调用"
    echo "   - open/close, stat 等文件系统调用"
    echo "   - read/write I/O系统调用"
    echo "   - 典型延迟: 0.1-10 微秒"
    echo ""
    echo "2. 上下文切换延迟 (lat_ctx)"
    echo "   - 进程间上下文切换"
    echo "   - 不同数据大小的切换开销"
    echo "   - IPC通信延迟（pipe）"
    echo "   - 典型延迟: 1-20 微秒"
    echo ""
    echo "3. 内存访问延迟 (lat_mem)"
    echo "   - 随机访问延迟"
    echo "   - 顺序访问延迟"
    echo "   - 检测缓存层次结构"
    echo "   - L1: 1-5 ns, L2: 5-15 ns, L3: 15-50 ns, RAM: 50-200 ns"
    echo ""
    echo "4. 内存带宽 (bw_mem)"
    echo "   - 读带宽"
    echo "   - 写带宽"
    echo "   - 拷贝带宽（memcpy）"
    echo "   - 读修改写带宽"
    echo ""
    echo "应用场景:"
    echo "  - 系统性能评估和对比"
    echo "  - 硬件选型参考"
    echo "  - 性能回归测试"
    echo "  - 优化效果验证"
    echo "  - 虚拟化性能分析"
    echo ""
    echo "与其他基准测试的对比:"
    echo "  - STREAM: 专注于内存带宽"
    echo "  - LMbench: 全面的系统微基准（延迟+带宽）"
    echo "  - SPEC CPU: 应用级性能"
    echo "  - sysbench: 数据库和文件系统"
    echo ""
} | tee "$RESULTS_DIR/principles.txt"

# 编译程序
echo "步骤 3: 编译测试程序..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd "$PROGRAMS_DIR"

PROGRAMS=(
    "lat_syscall:系统调用延迟"
    "lat_ctx:上下文切换延迟"
    "lat_mem:内存访问延迟"
    "bw_mem:内存带宽"
)

{
    echo "编译信息"
    echo "========================================"
    echo ""
} > "$RESULTS_DIR/compile.txt"

for prog_info in "${PROGRAMS[@]}"; do
    IFS=':' read -r prog desc <<< "$prog_info"

    echo "编译: $desc ($prog.c)"

    $COMPILER -O2 -o $prog ${prog}.c -lm

    if [[ $? -eq 0 ]]; then
        echo "  ✓ 编译成功: $prog"
        {
            echo "$desc:"
            echo "  源文件: ${prog}.c"
            echo "  二进制: $prog"
            echo "  编译选项: -O2"
            echo ""
        } >> "$RESULTS_DIR/compile.txt"
    else
        echo "  ✗ 编译失败: $prog"
    fi
done

echo ""

# 系统信息
echo "步骤 4: 收集系统信息..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "系统信息"
    echo "========================================"
    echo ""

    echo "操作系统:"
    echo "  $(uname -s) $(uname -r)"
    echo "  $(lsb_release -d 2>/dev/null | cut -f2 || echo '未知发行版')"

    echo ""
    echo "CPU信息:"
    CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    CPU_COUNT=$(grep -c processor /proc/cpuinfo)
    CPU_CORES=$(grep "cpu cores" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    echo "  型号: $CPU_MODEL"
    echo "  逻辑核心: $CPU_COUNT"
    echo "  物理核心: $CPU_CORES"
    echo "  频率: $(grep "cpu MHz" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs) MHz"

    echo ""
    echo "缓存信息:"
    if [[ -d /sys/devices/system/cpu/cpu0/cache ]]; then
        for cache in /sys/devices/system/cpu/cpu0/cache/index*; do
            if [[ -d $cache ]]; then
                level=$(cat $cache/level)
                type=$(cat $cache/type)
                size=$(cat $cache/size)
                echo "  L${level} ${type}: $size"
            fi
        done
    else
        echo "  $(lscpu | grep -i cache)"
    fi

    echo ""
    echo "内存信息:"
    MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    MEM_FREE=$(grep MemFree /proc/meminfo | awk '{print $2}')
    echo "  总内存: $((MEM_TOTAL / 1024)) MB"
    echo "  可用内存: $((MEM_FREE / 1024)) MB"

    echo ""
    echo "内核配置:"
    echo "  HZ: $(grep "CONFIG_HZ=" /boot/config-$(uname -r) 2>/dev/null || echo '未知')"
    echo "  Preempt: $(grep "CONFIG_PREEMPT" /boot/config-$(uname -r) 2>/dev/null | head -1 || echo '未知')"

} | tee "$RESULTS_DIR/sysinfo.txt"

echo ""

# 运行系统调用延迟测试
echo "步骤 5: 系统调用延迟测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ -f "$PROGRAMS_DIR/lat_syscall" ]]; then
    "$PROGRAMS_DIR/lat_syscall" | tee "$RESULTS_DIR/lat_syscall.txt"
else
    echo "⚠ lat_syscall程序不存在"
fi

echo ""

# 运行上下文切换测试
echo "步骤 6: 上下文切换延迟测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ -f "$PROGRAMS_DIR/lat_ctx" ]]; then
    "$PROGRAMS_DIR/lat_ctx" | tee "$RESULTS_DIR/lat_ctx.txt"
else
    echo "⚠ lat_ctx程序不存在"
fi

echo ""

# 运行内存延迟测试
echo "步骤 7: 内存访问延迟测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ -f "$PROGRAMS_DIR/lat_mem" ]]; then
    "$PROGRAMS_DIR/lat_mem" | tee "$RESULTS_DIR/lat_mem.txt"
else
    echo "⚠ lat_mem程序不存在"
fi

echo ""

# 运行内存带宽测试
echo "步骤 8: 内存带宽测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ -f "$PROGRAMS_DIR/bw_mem" ]]; then
    "$PROGRAMS_DIR/bw_mem" | tee "$RESULTS_DIR/bw_mem.txt"
else
    echo "⚠ bw_mem程序不存在"
fi

echo ""

# 结果汇总
echo "步骤 9: 结果汇总..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "LMbench测试结果汇总"
    echo "========================================"
    echo ""

    echo "关键性能指标:"
    echo ""

    # 系统调用延迟
    if [[ -f "$RESULTS_DIR/lat_syscall.txt" ]]; then
        echo "系统调用延迟:"
        getpid_lat=$(grep "^getpid()" "$RESULTS_DIR/lat_syscall.txt" | awk '{print $2}')
        open_lat=$(grep "^open/close" "$RESULTS_DIR/lat_syscall.txt" | awk '{print $2}')
        echo "  getpid(): $getpid_lat us"
        echo "  open/close: $open_lat us"
        echo ""
    fi

    # 上下文切换
    if [[ -f "$RESULTS_DIR/lat_ctx.txt" ]]; then
        echo "上下文切换延迟:"
        ctx_0=$(grep "Process ctx switch (0 bytes)" "$RESULTS_DIR/lat_ctx.txt" | awk '{print $5}')
        echo "  进程切换(0字节): $ctx_0 us"
        echo ""
    fi

    # 内存延迟
    if [[ -f "$RESULTS_DIR/lat_mem.txt" ]]; then
        echo "内存访问延迟:"
        grep -A 10 "Random Access Latency" "$RESULTS_DIR/lat_mem.txt" | grep -E "^[0-9]" | head -4 | \
        while read size lat level; do
            echo "  $level ($size bytes): $lat ns"
        done
        echo ""
    fi

    # 内存带宽
    if [[ -f "$RESULTS_DIR/bw_mem.txt" ]]; then
        echo "内存带宽:"
        grep "^Read " "$RESULTS_DIR/bw_mem.txt" | awk '{print "  读: " $2 " MB/s"}'
        grep "^Write " "$RESULTS_DIR/bw_mem.txt" | awk '{print "  写: " $2 " MB/s"}'
        grep "^Copy " "$RESULTS_DIR/bw_mem.txt" | awk '{print "  拷贝: " $2 " MB/s"}'
        echo ""
    fi

    echo "性能分析:"
    echo "  - 系统调用开销反映内核效率"
    echo "  - 上下文切换影响多任务性能"
    echo "  - 内存延迟显示缓存层次"
    echo "  - 内存带宽决定数据密集型应用性能"
    echo ""

} | tee "$RESULTS_DIR/summary.txt"

# 性能建议
{
    echo "性能优化建议"
    echo "========================================"
    echo ""

    echo "1. 系统调用优化:"
    echo "   - 减少不必要的系统调用"
    echo "   - 批量处理（如批量I/O）"
    echo "   - 使用vDSO（虚拟动态共享对象）"
    echo "   - 考虑用户态替代方案"
    echo ""

    echo "2. 上下文切换优化:"
    echo "   - 减少线程/进程数量"
    echo "   - 使用CPU亲和性绑定"
    echo "   - 调整调度策略"
    echo "   - 减少锁竞争"
    echo ""

    echo "3. 内存访问优化:"
    echo "   - 提高数据局部性"
    echo "   - 使用缓存友好的数据结构"
    echo "   - 预取（prefetch）关键数据"
    echo "   - 对齐数据到缓存行"
    echo ""

    echo "4. 内存带宽优化:"
    echo "   - 使用SIMD指令"
    echo "   - 减少内存拷贝"
    echo "   - 使用Huge Pages"
    echo "   - NUMA感知的内存分配"
    echo ""

    echo "5. 系统调优:"
    echo "   - 禁用CPU节能模式"
    echo "     cpupower frequency-set -g performance"
    echo ""
    echo "   - 禁用透明大页（某些场景）"
    echo "     echo never > /sys/kernel/mm/transparent_hugepage/enabled"
    echo ""
    echo "   - 调整内核调度器"
    echo "     echo 0 > /proc/sys/kernel/sched_autogroup_enabled"
    echo ""

} | tee "$RESULTS_DIR/recommendations.txt"

echo ""

# 对比基准
{
    echo "性能参考值"
    echo "========================================"
    echo ""

    echo "典型系统性能范围:"
    echo ""

    echo "系统调用延迟:"
    echo "  getpid():     0.05 - 0.2 us  (快速系统调用)"
    echo "  open/close:   1 - 10 us      (涉及文件系统)"
    echo "  read/write:   0.5 - 5 us     (小数据I/O)"
    echo ""

    echo "上下文切换:"
    echo "  进程切换:     1 - 10 us      (取决于CPU和内核)"
    echo "  线程切换:     0.5 - 5 us     (共享地址空间)"
    echo ""

    echo "内存延迟:"
    echo "  L1 Cache:     1 - 5 ns       (~4 cycles @ 3GHz)"
    echo "  L2 Cache:     5 - 15 ns      (~10-40 cycles)"
    echo "  L3 Cache:     15 - 50 ns     (~50-150 cycles)"
    echo "  RAM:          50 - 200 ns    (~150-600 cycles)"
    echo ""

    echo "内存带宽 (单通道DDR4-3200):"
    echo "  读带宽:       15,000 - 25,000 MB/s"
    echo "  写带宽:       15,000 - 25,000 MB/s"
    echo "  拷贝带宽:     10,000 - 20,000 MB/s"
    echo ""

    echo "注: 实际性能受CPU型号、内存配置、系统负载等因素影响"
    echo ""

} | tee "$RESULTS_DIR/reference.txt"

# 生成总报告
{
    echo "LMbench 测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo ""
    echo "系统信息:"
    echo "  CPU: $CPU_MODEL"
    echo "  核心数: $CPU_CORES"
    echo "  内存: $((MEM_TOTAL / 1024)) MB"
    echo "  内核: $(uname -r)"
    echo ""
    echo "测试项目:"
    echo "  ✓ 系统调用延迟 (lat_syscall)"
    echo "  ✓ 上下文切换延迟 (lat_ctx)"
    echo "  ✓ 内存访问延迟 (lat_mem)"
    echo "  ✓ 内存带宽 (bw_mem)"
    echo ""
    echo "结果文件:"
    echo "  测试原理: $RESULTS_DIR/principles.txt"
    echo "  系统信息: $RESULTS_DIR/sysinfo.txt"
    echo "  编译信息: $RESULTS_DIR/compile.txt"
    echo "  系统调用: $RESULTS_DIR/lat_syscall.txt"
    echo "  上下文切换: $RESULTS_DIR/lat_ctx.txt"
    echo "  内存延迟: $RESULTS_DIR/lat_mem.txt"
    echo "  内存带宽: $RESULTS_DIR/bw_mem.txt"
    echo "  结果汇总: $RESULTS_DIR/summary.txt"
    echo "  优化建议: $RESULTS_DIR/recommendations.txt"
    echo "  参考值: $RESULTS_DIR/reference.txt"
    echo ""

} | tee "$RESULTS_DIR/report.txt"

echo "========================================"
echo "测试完成"
echo "========================================"
echo ""
echo "✓ LMbench微基准测试完成"
echo ""
echo "结果目录: $RESULTS_DIR"
echo ""
