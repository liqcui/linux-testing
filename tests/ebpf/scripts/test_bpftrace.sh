#!/bin/bash
# test_bpftrace.sh - bpftrace eBPF追踪工具测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results/bpftrace_test_$(date +%Y%m%d_%H%M%S)"

# 参数
DURATION=10

# 使用说明
usage() {
    cat << EOF
用法: $0 [选项]

bpftrace eBPF追踪工具测试套件

选项:
  -d DURATION     测试时长（秒，默认10）
  -h              显示此帮助信息

示例:
  sudo $0 -d 30

EOF
    exit 1
}

# 解析参数
while getopts "d:h" opt; do
    case $opt in
        d) DURATION="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

mkdir -p "$RESULTS_DIR"
mkdir -p "$SCRIPT_DIR/bpftrace"

echo "========================================"
echo "bpftrace eBPF 追踪工具测试"
echo "========================================"
echo ""

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    echo "✗ 错误: 此脚本需要root权限运行"
    echo "请使用: sudo $0"
    exit 1
fi

echo "系统信息:"
echo "  内核版本: $(uname -r)"
echo "  测试时长: ${DURATION}秒"
echo "  结果目录: $RESULTS_DIR"
echo ""

# 检查bpftrace安装
echo "步骤 1: 检查bpftrace安装..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ! command -v bpftrace &> /dev/null; then
    echo "✗ bpftrace未安装"
    echo ""
    echo "安装方法:"
    echo ""
    echo "Ubuntu 20.04+:"
    echo "  sudo apt-get install bpftrace"
    echo ""
    echo "Fedora/RHEL 8+:"
    echo "  sudo dnf install bpftrace"
    echo ""
    exit 1
fi

echo "✓ bpftrace已安装"
bpftrace --version
echo ""

# bpftrace原理说明
{
    echo "bpftrace追踪原理"
    echo "========================================"
    echo ""
    echo "bpftrace 是高级eBPF追踪语言"
    echo ""
    echo "核心特点:"
    echo "  • 类awk语法: 简洁易学"
    echo "  • 一行代码: 可以完成复杂追踪"
    echo "  • 内置变量: 丰富的内核信息访问"
    echo "  • 内置函数: 时间戳、栈追踪、统计等"
    echo ""
    echo "基本语法:"
    echo "  probe /filter/ { action }"
    echo ""
    echo "探测点类型:"
    echo "  • kprobe:     内核函数探测"
    echo "  • kretprobe:  内核函数返回探测"
    echo "  • tracepoint: 静态追踪点"
    echo "  • uprobe:     用户态函数探测"
    echo "  • usdt:       用户态静态追踪点"
    echo "  • profile:    定时采样"
    echo "  • interval:   定时执行"
    echo ""
} | tee "$RESULTS_DIR/principles.txt"

echo ""

# 创建bpftrace脚本

# 脚本1: 系统调用统计
cat > "$SCRIPT_DIR/bpftrace/syscall_count.bt" << 'EOF'
#!/usr/bin/env bpftrace
/*
 * syscall_count.bt - 统计系统调用频率
 *
 * 功能: 统计每个系统调用的调用次数
 * 用途: 识别频繁的系统调用，优化应用性能
 */

tracepoint:raw_syscalls:sys_enter
{
    @syscall[args->id] = count();
}

interval:s:1
{
    print(@syscall);
    clear(@syscall);
}

END
{
    clear(@syscall);
}
EOF

# 脚本2: 文件I/O延迟分析
cat > "$SCRIPT_DIR/bpftrace/vfs_latency.bt" << 'EOF'
#!/usr/bin/env bpftrace
/*
 * vfs_latency.bt - VFS操作延迟分析
 *
 * 功能: 追踪VFS read/write延迟直方图
 * 用途: 识别慢速文件I/O操作
 */

kprobe:vfs_read,
kprobe:vfs_write
{
    @start[tid] = nsecs;
    @io_type[tid] = func;
}

kretprobe:vfs_read,
kretprobe:vfs_write
/@start[tid]/
{
    $duration_us = (nsecs - @start[tid]) / 1000;

    @latency_us[str(@io_type[tid])] = hist($duration_us);

    delete(@start[tid]);
    delete(@io_type[tid]);
}

END
{
    clear(@start);
    clear(@io_type);
}
EOF

# 脚本3: TCP连接延迟追踪
cat > "$SCRIPT_DIR/bpftrace/tcp_connect_latency.bt" << 'EOF'
#!/usr/bin/env bpftrace
/*
 * tcp_connect_latency.bt - TCP连接延迟追踪
 *
 * 功能: 测量TCP连接建立的延迟
 * 用途: 网络性能分析，识别慢速连接
 */

#include <linux/socket.h>
#include <net/sock.h>

kprobe:tcp_connect
{
    @start[tid] = nsecs;
}

kretprobe:tcp_connect
/@start[tid]/
{
    $duration_ms = (nsecs - @start[tid]) / 1000000;

    printf("%-8d %-16s %8.2f ms\n",
           pid, comm, $duration_ms);

    @latency_ms = hist($duration_ms);

    delete(@start[tid]);
}

END
{
    clear(@start);
}
EOF

# 脚本4: 内存分配追踪
cat > "$SCRIPT_DIR/bpftrace/kmalloc_stats.bt" << 'EOF'
#!/usr/bin/env bpftrace
/*
 * kmalloc_stats.bt - 内核内存分配统计
 *
 * 功能: 统计kmalloc分配大小和调用栈
 * 用途: 内存泄漏排查，内存使用分析
 */

kprobe:__kmalloc
{
    $size = arg0;

    @kmalloc_bytes[comm] = sum($size);
    @kmalloc_count[comm] = count();

    if ($size >= 65536) {
        printf("Large alloc: %s %d bytes\n", comm, $size);
        printf("%s\n", kstack);
    }
}

interval:s:5
{
    printf("\n=== Top 10 memory allocators ===\n");
    print(@kmalloc_bytes, 10);
    printf("\n=== Allocation counts ===\n");
    print(@kmalloc_count, 10);
}

END
{
    clear(@kmalloc_bytes);
    clear(@kmalloc_count);
}
EOF

# 脚本5: CPU调度延迟
cat > "$SCRIPT_DIR/bpftrace/sched_latency.bt" << 'EOF'
#!/usr/bin/env bpftrace
/*
 * sched_latency.bt - CPU调度延迟分析
 *
 * 功能: 测量进程从唤醒到运行的延迟
 * 用途: 调度性能分析，实时性评估
 */

tracepoint:sched:sched_wakeup
{
    @wakeup[args->pid] = nsecs;
}

tracepoint:sched:sched_switch
/@wakeup[args->next_pid]/
{
    $latency_us = (nsecs - @wakeup[args->next_pid]) / 1000;

    @sched_latency = hist($latency_us);

    if ($latency_us > 10000) {
        printf("High latency: %s (pid %d) %d us\n",
               args->next_comm, args->next_pid, $latency_us);
    }

    delete(@wakeup[args->next_pid]);
}

END
{
    clear(@wakeup);
}
EOF

chmod +x "$SCRIPT_DIR/bpftrace"/*.bt

echo "步骤 2: 创建bpftrace追踪脚本..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✓ 已创建5个追踪脚本:"
echo "  • syscall_count.bt       - 系统调用统计"
echo "  • vfs_latency.bt         - 文件I/O延迟"
echo "  • tcp_connect_latency.bt - TCP连接延迟"
echo "  • kmalloc_stats.bt       - 内存分配统计"
echo "  • sched_latency.bt       - CPU调度延迟"
echo ""

# 测试1: 系统调用统计
echo "步骤 3: 系统调用频率统计..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "系统调用频率统计"
    echo "========================================"
    echo ""
    echo "功能:"
    echo "  统计每秒各系统调用的调用次数"
    echo ""
    echo "应用场景:"
    echo "  • 性能优化: 识别频繁的系统调用"
    echo "  • 异常检测: 发现异常高频的系统调用"
    echo "  • 容量规划: 评估系统调用开销"
    echo ""
    echo "测试结果（${DURATION}秒）:"
    echo "----------------------------------------"
} | tee "$RESULTS_DIR/syscall_count.txt"

echo "正在统计系统调用（${DURATION}秒）..."

timeout ${DURATION}s bpftrace "$SCRIPT_DIR/bpftrace/syscall_count.bt" 2>&1 | \
    tee -a "$RESULTS_DIR/syscall_count.txt"

echo ""
echo "✓ 系统调用统计完成"
echo ""

# 测试2: VFS延迟分析
echo "步骤 4: VFS I/O延迟分析..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "VFS I/O延迟分析"
    echo "========================================"
    echo ""
    echo "功能:"
    echo "  生成read/write操作的延迟直方图"
    echo ""
    echo "应用场景:"
    echo "  • I/O性能分析"
    echo "  • 存储瓶颈定位"
    echo "  • 应用调优"
    echo ""
    echo "测试结果（${DURATION}秒）:"
    echo "----------------------------------------"
} | tee "$RESULTS_DIR/vfs_latency.txt"

echo "正在分析VFS延迟（${DURATION}秒）..."

timeout ${DURATION}s bpftrace "$SCRIPT_DIR/bpftrace/vfs_latency.bt" 2>&1 | \
    tee -a "$RESULTS_DIR/vfs_latency.txt"

echo ""
echo "✓ VFS延迟分析完成"
echo ""

# 测试3: TCP连接延迟
echo "步骤 5: TCP连接延迟追踪..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "TCP连接延迟追踪"
    echo "========================================"
    echo ""
    echo "功能:"
    echo "  测量TCP connect()的延迟"
    echo ""
    echo "应用场景:"
    echo "  • 网络性能分析"
    echo "  • 连接超时排查"
    echo "  • 微服务性能优化"
    echo ""
    echo "测试结果（${DURATION}秒）:"
    echo "----------------------------------------"
} | tee "$RESULTS_DIR/tcp_connect_latency.txt"

echo "正在追踪TCP连接延迟（${DURATION}秒）..."
echo "提示: 在另一个终端执行网络操作以产生数据"

timeout ${DURATION}s bpftrace "$SCRIPT_DIR/bpftrace/tcp_connect_latency.bt" 2>&1 | \
    head -100 | tee -a "$RESULTS_DIR/tcp_connect_latency.txt"

echo ""
echo "✓ TCP连接延迟追踪完成"
echo ""

# 测试4: 内存分配统计
echo "步骤 6: 内核内存分配统计..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "内核内存分配统计"
    echo "========================================"
    echo ""
    echo "功能:"
    echo "  统计kmalloc内存分配"
    echo "  追踪大块内存分配"
    echo ""
    echo "应用场景:"
    echo "  • 内存泄漏排查"
    echo "  • 内存使用优化"
    echo "  • 内核模块分析"
    echo ""
    echo "测试结果（${DURATION}秒）:"
    echo "----------------------------------------"
} | tee "$RESULTS_DIR/kmalloc_stats.txt"

echo "正在统计内存分配（${DURATION}秒）..."

timeout ${DURATION}s bpftrace "$SCRIPT_DIR/bpftrace/kmalloc_stats.bt" 2>&1 | \
    tee -a "$RESULTS_DIR/kmalloc_stats.txt"

echo ""
echo "✓ 内存分配统计完成"
echo ""

# 测试5: CPU调度延迟
echo "步骤 7: CPU调度延迟分析..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "CPU调度延迟分析"
    echo "========================================"
    echo ""
    echo "功能:"
    echo "  测量进程调度延迟（wakeup到运行）"
    echo "  生成延迟直方图"
    echo ""
    echo "应用场景:"
    echo "  • 实时性能评估"
    echo "  • 调度器优化"
    echo "  • 延迟敏感应用分析"
    echo ""
    echo "测试结果（${DURATION}秒）:"
    echo "----------------------------------------"
} | tee "$RESULTS_DIR/sched_latency.txt"

echo "正在分析调度延迟（${DURATION}秒）..."

timeout ${DURATION}s bpftrace "$SCRIPT_DIR/bpftrace/sched_latency.bt" 2>&1 | \
    tee -a "$RESULTS_DIR/sched_latency.txt"

echo ""
echo "✓ 调度延迟分析完成"
echo ""

# 生成综合报告
echo "步骤 8: 生成综合分析报告..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "========================================"
    echo "bpftrace eBPF 追踪测试综合报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo "内核版本: $(uname -r)"
    echo "测试时长: ${DURATION}秒"
    echo ""

    echo "一、执行的追踪脚本"
    echo "----------------------------------------"
    echo ""
    echo "✓ syscall_count.bt       - 系统调用统计"
    echo "✓ vfs_latency.bt         - VFS I/O延迟"
    echo "✓ tcp_connect_latency.bt - TCP连接延迟"
    echo "✓ kmalloc_stats.bt       - 内存分配统计"
    echo "✓ sched_latency.bt       - CPU调度延迟"
    echo ""

    echo "二、关键发现"
    echo "----------------------------------------"
    echo ""

    # 分析系统调用
    if [[ -f "$RESULTS_DIR/syscall_count.txt" ]]; then
        echo "• 系统调用分析:"
        TOP_SYSCALL=$(grep -E "^\s+[0-9]+:" "$RESULTS_DIR/syscall_count.txt" 2>/dev/null | \
            head -1 | awk '{print $2}')
        if [[ -n "$TOP_SYSCALL" ]]; then
            echo "  最频繁系统调用: ID $TOP_SYSCALL"
        fi
        echo "  详见: syscall_count.txt"
        echo ""
    fi

    # 分析I/O延迟
    if [[ -f "$RESULTS_DIR/vfs_latency.txt" ]]; then
        echo "• VFS I/O延迟:"
        if grep -q "vfs_read\|vfs_write" "$RESULTS_DIR/vfs_latency.txt" 2>/dev/null; then
            echo "  延迟分布: 已生成直方图"
        fi
        echo "  详见: vfs_latency.txt"
        echo ""
    fi

    # 分析TCP连接
    if [[ -f "$RESULTS_DIR/tcp_connect_latency.txt" ]]; then
        echo "• TCP连接延迟:"
        TCP_SAMPLES=$(grep -c "ms$" "$RESULTS_DIR/tcp_connect_latency.txt" 2>/dev/null || echo "0")
        if [[ $TCP_SAMPLES -gt 0 ]]; then
            echo "  采样连接: $TCP_SAMPLES 次"
        fi
        echo "  详见: tcp_connect_latency.txt"
        echo ""
    fi

    # 分析内存分配
    if [[ -f "$RESULTS_DIR/kmalloc_stats.txt" ]]; then
        echo "• 内存分配统计:"
        LARGE_ALLOCS=$(grep -c "Large alloc" "$RESULTS_DIR/kmalloc_stats.txt" 2>/dev/null || echo "0")
        if [[ $LARGE_ALLOCS -gt 0 ]]; then
            echo "  大块分配(≥64KB): $LARGE_ALLOCS 次"
        fi
        echo "  详见: kmalloc_stats.txt"
        echo ""
    fi

    # 分析调度延迟
    if [[ -f "$RESULTS_DIR/sched_latency.txt" ]]; then
        echo "• CPU调度延迟:"
        HIGH_LATENCY=$(grep -c "High latency" "$RESULTS_DIR/sched_latency.txt" 2>/dev/null || echo "0")
        if [[ $HIGH_LATENCY -gt 0 ]]; then
            echo "  高延迟(>10ms): $HIGH_LATENCY 次"
        fi
        echo "  详见: sched_latency.txt"
        echo ""
    fi

    echo "三、bpftrace脚本库"
    echo "----------------------------------------"
    echo ""
    echo "已创建的脚本位于: $SCRIPT_DIR/bpftrace/"
    echo ""
    echo "使用方法:"
    echo "  bpftrace script.bt              # 运行脚本"
    echo "  bpftrace -e 'one-liner'        # 一行代码"
    echo "  bpftrace -l 'kprobe:*'         # 列出探测点"
    echo ""

    echo "四、常用bpftrace一行代码示例"
    echo "----------------------------------------"
    echo ""
    echo "1. 统计系统调用:"
    echo "   bpftrace -e 'tracepoint:syscalls:sys_enter_* { @[probe] = count(); }'"
    echo ""
    echo "2. 追踪进程创建:"
    echo "   bpftrace -e 'tracepoint:sched:sched_process_exec { printf(\"%s\\n\", str(args->filename)); }'"
    echo ""
    echo "3. 文件打开监控:"
    echo "   bpftrace -e 'tracepoint:syscalls:sys_enter_openat { printf(\"%s %s\\n\", comm, str(args->filename)); }'"
    echo ""
    echo "4. TCP连接监控:"
    echo "   bpftrace -e 'kprobe:tcp_connect { printf(\"%s\\n\", comm); }'"
    echo ""
    echo "5. CPU采样:"
    echo "   bpftrace -e 'profile:hz:99 { @[kstack] = count(); }'"
    echo ""

    echo "五、详细结果文件"
    echo "----------------------------------------"
    echo ""
    ls -lh "$RESULTS_DIR"/*.txt 2>/dev/null | awk '{printf "  • %s (%s)\n", $9, $5}'
    echo ""

} | tee "$RESULTS_DIR/summary_report.txt"

echo ""
echo "========================================"
echo "测试完成"
echo "========================================"
echo ""
echo "结果保存到: $RESULTS_DIR"
echo ""
echo "查看综合报告:"
echo "  cat $RESULTS_DIR/summary_report.txt"
echo ""
echo "查看详细结果:"
for file in "$RESULTS_DIR"/*.txt; do
    if [[ -f "$file" ]] && [[ "$(basename "$file")" != "summary_report.txt" ]] && [[ "$(basename "$file")" != "principles.txt" ]]; then
        echo "  cat $file"
    fi
done
echo ""
echo "bpftrace脚本位置:"
echo "  $SCRIPT_DIR/bpftrace/"
echo ""
echo "自定义追踪:"
echo "  编辑脚本或使用一行代码进行灵活追踪"
echo ""
