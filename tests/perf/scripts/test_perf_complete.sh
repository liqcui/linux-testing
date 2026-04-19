#!/bin/bash
# test_perf_complete.sh - Perf完整性能分析工作流

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/../results/complete_analysis_$(date +%Y%m%d_%H%M%S)"

# 参数
TARGET_PID=""
TARGET_PROCESS=""
DURATION=30
SKIP_FLAMEGRAPH=0

# 使用说明
usage() {
    cat << EOF
用法: $0 [选项]

Perf完整性能分析工作流 - 一站式性能分析解决方案

选项:
  -p PID          指定进程PID
  -n NAME         指定进程名称
  -d DURATION     采样时长（秒，默认30）
  -s              跳过火焰图生成（仅快速分析）
  -h              显示此帮助信息

工作流程:
  1. 性能瓶颈分析（perf_bottleneck_analysis.sh）
     • CPU热点识别
     • 调用链分析
     • 性能统计
     • 源码级注解

  2. 火焰图生成（flamegraph_generation.sh）
     • on-CPU火焰图
     • off-CPU火焰图
     • 内核/用户态火焰图

  3. 自动化分析（auto_flame_analysis.sh）
     • 热点函数提取
     • 性能模式检测
     • 优化建议生成

示例:
  # 完整分析指定进程
  $0 -p 1234 -d 60

  # 快速分析（跳过火焰图）
  $0 -n nginx -d 30 -s

  # 系统范围完整分析
  $0 -d 60

EOF
    exit 1
}

# 解析命令行参数
while getopts "p:n:d:sh" opt; do
    case $opt in
        p) TARGET_PID="$OPTARG" ;;
        n) TARGET_PROCESS="$OPTARG" ;;
        d) DURATION="$OPTARG" ;;
        s) SKIP_FLAMEGRAPH=1 ;;
        h) usage ;;
        *) usage ;;
    esac
done

mkdir -p "$OUTPUT_DIR"

echo "========================================"
echo "Perf 完整性能分析工作流"
echo "========================================"
echo ""

# 确定目标
if [[ -n "$TARGET_PROCESS" ]]; then
    TARGET_PID=$(pidof "$TARGET_PROCESS" | awk '{print $1}')
    if [[ -z "$TARGET_PID" ]]; then
        echo "✗ 错误: 未找到进程 '$TARGET_PROCESS'"
        exit 1
    fi
    echo "目标进程: $TARGET_PROCESS (PID: $TARGET_PID)"
elif [[ -n "$TARGET_PID" ]]; then
    if ! kill -0 "$TARGET_PID" 2>/dev/null; then
        echo "✗ 错误: PID $TARGET_PID 不存在"
        exit 1
    fi
    TARGET_PROCESS=$(ps -p "$TARGET_PID" -o comm=)
    echo "目标PID: $TARGET_PID ($TARGET_PROCESS)"
else
    echo "分析范围: 系统范围（全局）"
fi

echo "采样时长: ${DURATION}秒"
echo "输出目录: $OUTPUT_DIR"
echo ""

# ========== 阶段1: 性能瓶颈分析 ==========

echo "========================================"
echo "阶段 1/3: 性能瓶颈分析"
echo "========================================"
echo ""

BOTTLENECK_OPTS="-d $DURATION"
if [[ -n "$TARGET_PID" ]]; then
    BOTTLENECK_OPTS="$BOTTLENECK_OPTS -p $TARGET_PID"
fi

# 创建临时目录用于瓶颈分析
BOTTLENECK_DIR="$OUTPUT_DIR/bottleneck_analysis"
mkdir -p "$BOTTLENECK_DIR"

# 直接在此处执行瓶颈分析（内联脚本逻辑）
echo "正在进行CPU采样和热点分析..."

PERF_OPTS="-F 99 -g --call-graph dwarf"
if [[ -n "$TARGET_PID" ]]; then
    PERF_OPTS="$PERF_OPTS -p $TARGET_PID"
else
    PERF_OPTS="$PERF_OPTS -a"
fi

if sudo perf record $PERF_OPTS \
    -o "$BOTTLENECK_DIR/perf.data" \
    -- sleep $DURATION; then
    echo "✓ CPU采样完成"

    # 生成热点报告
    sudo perf report -i "$BOTTLENECK_DIR/perf.data" \
        --stdio \
        --percent-limit 1.0 \
        > "$BOTTLENECK_DIR/hotspots.txt"

    # 生成调用链报告
    sudo perf report -i "$BOTTLENECK_DIR/perf.data" \
        -g graph,0.5,caller \
        --stdio \
        > "$BOTTLENECK_DIR/callgraph.txt"

    # 性能统计
    STAT_OPTS=""
    if [[ -n "$TARGET_PID" ]]; then
        STAT_OPTS="-p $TARGET_PID"
    else
        STAT_OPTS="-a"
    fi

    sudo perf stat $STAT_OPTS \
        -e cycles,instructions,cache-references,cache-misses \
        -- sleep 10 2>&1 > "$BOTTLENECK_DIR/stat.txt"

    echo "✓ 性能瓶颈分析完成"
    echo "  热点报告: $BOTTLENECK_DIR/hotspots.txt"
    echo "  调用链: $BOTTLENECK_DIR/callgraph.txt"
    echo "  统计: $BOTTLENECK_DIR/stat.txt"
else
    echo "✗ 性能采样失败"
    exit 1
fi

echo ""

# ========== 阶段2: 火焰图生成 ==========

if [[ $SKIP_FLAMEGRAPH -eq 0 ]]; then
    echo "========================================"
    echo "阶段 2/3: 火焰图生成"
    echo "========================================"
    echo ""

    # 使用已有的perf.data生成火焰图
    if "$SCRIPT_DIR/flamegraph_generation.sh" \
        -i "$BOTTLENECK_DIR/perf.data" \
        -o "$OUTPUT_DIR/flamegraphs"; then
        echo "✓ 火焰图生成完成"
    else
        echo "⚠ 火焰图生成失败或跳过"
    fi

    echo ""

    # ========== 阶段3: 自动化分析 ==========

    echo "========================================"
    echo "阶段 3/3: 自动化火焰图分析"
    echo "========================================"
    echo ""

    if [[ -f "$OUTPUT_DIR/flamegraphs/oncpu_flamegraph.svg" ]]; then
        if "$SCRIPT_DIR/auto_flame_analysis.sh" \
            "$OUTPUT_DIR/flamegraphs/oncpu_flamegraph.svg" \
            "$OUTPUT_DIR/auto_analysis_report.txt"; then
            echo "✓ 自动化分析完成"
        else
            echo "⚠ 自动化分析失败"
        fi
    else
        echo "⚠ 未找到火焰图，跳过自动化分析"
    fi

    echo ""
else
    echo "跳过火焰图生成（使用 -s 选项）"
    echo ""
fi

# ========== 生成综合报告 ==========

echo "========================================"
echo "生成综合报告"
echo "========================================"
echo ""

SUMMARY_REPORT="$OUTPUT_DIR/SUMMARY_REPORT.txt"

{
    echo "========================================"
    echo "Perf 完整性能分析综合报告"
    echo "========================================"
    echo ""
    echo "生成时间: $(date)"
    if [[ -n "$TARGET_PID" ]]; then
        echo "目标进程: $TARGET_PROCESS (PID: $TARGET_PID)"
    else
        echo "分析范围: 系统范围"
    fi
    echo "采样时长: ${DURATION}秒"
    echo ""

    echo "一、分析摘要"
    echo "----------------------------------------"
    echo ""

    # Top 5 热点函数
    echo "Top 5 CPU热点函数:"
    if [[ -f "$BOTTLENECK_DIR/hotspots.txt" ]]; then
        grep -E "^\s+[0-9]+\.[0-9]+%" "$BOTTLENECK_DIR/hotspots.txt" | \
            head -5 | \
            sed 's/^/  /'
    fi
    echo ""

    # 性能统计
    echo "性能计数器统计:"
    if [[ -f "$BOTTLENECK_DIR/stat.txt" ]]; then
        grep -E "cache-misses|instructions|cycles" "$BOTTLENECK_DIR/stat.txt" | \
            sed 's/^/  /'
    fi
    echo ""

    echo "二、生成的分析结果"
    echo "----------------------------------------"
    echo ""
    echo "1. 性能瓶颈分析:"
    echo "   • 热点报告: $BOTTLENECK_DIR/hotspots.txt"
    echo "   • 调用链分析: $BOTTLENECK_DIR/callgraph.txt"
    echo "   • 性能统计: $BOTTLENECK_DIR/stat.txt"
    echo "   • 原始数据: $BOTTLENECK_DIR/perf.data"
    echo ""

    if [[ $SKIP_FLAMEGRAPH -eq 0 ]]; then
        echo "2. 火焰图:"
        if [[ -f "$OUTPUT_DIR/flamegraphs/oncpu_flamegraph.svg" ]]; then
            echo "   • on-CPU火焰图: $OUTPUT_DIR/flamegraphs/oncpu_flamegraph.svg"
        fi
        if [[ -f "$OUTPUT_DIR/flamegraphs/kernel_flamegraph.svg" ]]; then
            echo "   • 内核火焰图: $OUTPUT_DIR/flamegraphs/kernel_flamegraph.svg"
        fi
        if [[ -f "$OUTPUT_DIR/flamegraphs/userspace_flamegraph.svg" ]]; then
            echo "   • 用户态火焰图: $OUTPUT_DIR/flamegraphs/userspace_flamegraph.svg"
        fi
        echo ""

        echo "3. 自动化分析报告:"
        if [[ -f "$OUTPUT_DIR/auto_analysis_report.txt" ]]; then
            echo "   • $OUTPUT_DIR/auto_analysis_report.txt"
        fi
        echo ""
    fi

    echo "三、快速查看方式"
    echo "----------------------------------------"
    echo ""
    echo "1. 查看热点函数:"
    echo "   head -30 $BOTTLENECK_DIR/hotspots.txt"
    echo ""
    echo "2. 查看调用链:"
    echo "   less $BOTTLENECK_DIR/callgraph.txt"
    echo ""

    if [[ $SKIP_FLAMEGRAPH -eq 0 ]]; then
        echo "3. 打开火焰图（推荐）:"
        if [[ -f "$OUTPUT_DIR/flamegraphs/oncpu_flamegraph.svg" ]]; then
            echo "   open $OUTPUT_DIR/flamegraphs/oncpu_flamegraph.svg"
        fi
        echo ""
        echo "4. 查看自动化分析:"
        if [[ -f "$OUTPUT_DIR/auto_analysis_report.txt" ]]; then
            echo "   cat $OUTPUT_DIR/auto_analysis_report.txt"
        fi
        echo ""
    fi

    echo "四、深入分析建议"
    echo "----------------------------------------"
    echo ""
    echo "1. 源码级分析（需要调试符号）:"
    echo "   sudo perf annotate -i $BOTTLENECK_DIR/perf.data"
    echo ""
    echo "2. 特定函数分析:"
    echo "   sudo perf report -i $BOTTLENECK_DIR/perf.data --symbol=函数名"
    echo ""
    echo "3. 硬件事件分析:"
    echo "   sudo perf stat -e cache-misses,branch-misses -p PID -- sleep 10"
    echo ""
    echo "4. 对比分析（优化前后）:"
    echo "   使用差分火焰图对比性能改进效果"
    echo ""

    echo "五、常见优化方向"
    echo "----------------------------------------"
    echo ""

    # 检查常见性能问题
    if [[ -f "$BOTTLENECK_DIR/hotspots.txt" ]]; then
        if grep -qi "mutex\|lock" "$BOTTLENECK_DIR/hotspots.txt"; then
            echo "• 检测到锁相关热点"
            echo "  建议: 减小锁粒度，考虑无锁数据结构"
            echo ""
        fi

        if grep -qi "malloc\|free" "$BOTTLENECK_DIR/hotspots.txt"; then
            echo "• 检测到内存分配热点"
            echo "  建议: 使用内存池，减少分配次数"
            echo ""
        fi

        if grep -qi "memcpy\|memmove" "$BOTTLENECK_DIR/hotspots.txt"; then
            echo "• 检测到内存拷贝热点"
            echo "  建议: 减少拷贝，使用引用传递"
            echo ""
        fi

        if grep -qi "sys_\|syscall" "$BOTTLENECK_DIR/hotspots.txt"; then
            echo "• 检测到系统调用热点"
            echo "  建议: 批量操作，使用异步I/O"
            echo ""
        fi
    fi

} | tee "$SUMMARY_REPORT"

echo ""
echo "========================================"
echo "完整分析流程完成！"
echo "========================================"
echo ""
echo "所有结果保存在: $OUTPUT_DIR"
echo ""
echo "推荐查看顺序:"
echo "  1. 综合报告: cat $SUMMARY_REPORT"

if [[ $SKIP_FLAMEGRAPH -eq 0 ]] && [[ -f "$OUTPUT_DIR/flamegraphs/oncpu_flamegraph.svg" ]]; then
    echo "  2. 火焰图: open $OUTPUT_DIR/flamegraphs/oncpu_flamegraph.svg"
fi

echo "  3. 热点详情: head -50 $BOTTLENECK_DIR/hotspots.txt"
echo ""
echo "目录结构:"
tree -L 2 "$OUTPUT_DIR" 2>/dev/null || ls -R "$OUTPUT_DIR"
echo ""
