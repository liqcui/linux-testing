#!/bin/bash
# perf_bottleneck_analysis.sh - 完整性能瓶颈定位流程

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/../results/bottleneck_analysis_$(date +%Y%m%d_%H%M%S)"

# 参数解析
TARGET_PID=""
TARGET_PROCESS=""
DURATION=30
FREQUENCY=99

# 使用说明
usage() {
    cat << EOF
用法: $0 [选项]

性能瓶颈分析工具 - 全面分析应用性能问题

选项:
  -p PID          指定进程PID
  -n NAME         指定进程名称（自动查找PID）
  -d DURATION     采样时长（秒，默认30）
  -f FREQUENCY    采样频率（Hz，默认99）
  -h              显示此帮助信息

示例:
  # 分析指定PID的进程
  $0 -p 1234 -d 60

  # 分析指定名称的进程
  $0 -n nginx -d 60

  # 分析系统范围（无-p/-n参数）
  $0 -d 60

EOF
    exit 1
}

# 解析命令行参数
while getopts "p:n:d:f:h" opt; do
    case $opt in
        p) TARGET_PID="$OPTARG" ;;
        n) TARGET_PROCESS="$OPTARG" ;;
        d) DURATION="$OPTARG" ;;
        f) FREQUENCY="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

mkdir -p "$OUTPUT_DIR"

echo "========================================"
echo "Perf 性能瓶颈分析"
echo "========================================"
echo ""
echo "分析配置:"

# 确定目标进程
if [[ -n "$TARGET_PROCESS" ]]; then
    TARGET_PID=$(pidof "$TARGET_PROCESS" | awk '{print $1}')
    if [[ -z "$TARGET_PID" ]]; then
        echo "✗ 错误: 未找到进程 '$TARGET_PROCESS'"
        exit 1
    fi
    echo "  目标进程: $TARGET_PROCESS (PID: $TARGET_PID)"
elif [[ -n "$TARGET_PID" ]]; then
    if ! kill -0 "$TARGET_PID" 2>/dev/null; then
        echo "✗ 错误: PID $TARGET_PID 不存在"
        exit 1
    fi
    TARGET_PROCESS=$(ps -p "$TARGET_PID" -o comm=)
    echo "  目标PID: $TARGET_PID ($TARGET_PROCESS)"
else
    echo "  目标: 系统范围（全局分析）"
fi

echo "  采样时长: ${DURATION}秒"
echo "  采样频率: ${FREQUENCY}Hz"
echo "  结果目录: $OUTPUT_DIR"
echo ""

# 检查perf可用性
if ! command -v perf &> /dev/null; then
    echo "✗ 错误: perf未安装"
    echo ""
    echo "安装方法:"
    echo "  Ubuntu/Debian: sudo apt-get install linux-tools-common linux-tools-\$(uname -r)"
    echo "  RHEL/CentOS:   sudo yum install perf"
    exit 1
fi

# 检查权限
if [[ $EUID -ne 0 ]] && [[ ! -w /proc/sys/kernel/perf_event_paranoid ]]; then
    echo "⚠ 警告: 需要root权限或调整perf_event_paranoid设置"
    echo "临时允许用户使用perf:"
    echo "  sudo sysctl -w kernel.perf_event_paranoid=-1"
fi

# ========== Step 1: 基础采样记录 ==========
echo "步骤 1/7: 基础CPU采样记录..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

PERF_OPTS="-F $FREQUENCY -g --call-graph dwarf"

if [[ -n "$TARGET_PID" ]]; then
    PERF_OPTS="$PERF_OPTS -p $TARGET_PID"
else
    PERF_OPTS="$PERF_OPTS -a"
fi

echo "正在采样 ${DURATION}秒..."
if sudo perf record $PERF_OPTS \
    -o "$OUTPUT_DIR/perf.data" \
    -- sleep $DURATION; then
    echo "✓ 采样完成"

    # 显示数据文件信息
    DATA_SIZE=$(du -h "$OUTPUT_DIR/perf.data" | cut -f1)
    echo "  数据大小: $DATA_SIZE"
else
    echo "✗ 采样失败"
    exit 1
fi

echo ""

# ========== Step 2: 生成热点报告 ==========
echo "步骤 2/7: 生成热点函数报告..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "性能热点分析报告"
    echo "========================================"
    echo "生成时间: $(date)"
    echo "采样时长: ${DURATION}秒"
    echo "采样频率: ${FREQUENCY}Hz"
    if [[ -n "$TARGET_PID" ]]; then
        echo "目标进程: $TARGET_PROCESS (PID: $TARGET_PID)"
    else
        echo "目标: 系统范围"
    fi
    echo ""
    echo "Top 热点函数（CPU时间占比 >= 1.0%）:"
    echo "----------------------------------------"
} > "$OUTPUT_DIR/hotspots_report.txt"

sudo perf report -i "$OUTPUT_DIR/perf.data" \
    --stdio \
    --percent-limit 1.0 \
    --sort comm,dso,symbol \
    >> "$OUTPUT_DIR/hotspots_report.txt"

# 提取Top 10热点
echo "Top 10 热点函数:"
sudo perf report -i "$OUTPUT_DIR/perf.data" \
    --stdio \
    --percent-limit 1.0 \
    --sort symbol \
    | grep -E "^\s+[0-9]+\.[0-9]+%" \
    | head -10

echo ""

# ========== Step 3: 调用链分析 ==========
echo "步骤 3/7: 调用链分析..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "调用链分析报告"
    echo "========================================"
    echo ""
    echo "调用图（显示 >= 0.5% 的调用路径）:"
    echo "----------------------------------------"
} > "$OUTPUT_DIR/callgraph_report.txt"

sudo perf report -i "$OUTPUT_DIR/perf.data" \
    -g graph,0.5,caller \
    --stdio \
    >> "$OUTPUT_DIR/callgraph_report.txt"

echo "✓ 调用链分析完成"
echo ""

# ========== Step 4: 源码级注解分析 ==========
echo "步骤 4/7: 源码级性能注解..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 获取最热的函数
HOT_SYMBOL=$(sudo perf report -i "$OUTPUT_DIR/perf.data" \
    --stdio \
    --percent-limit 1.0 \
    --sort symbol \
    | grep -E "^\s+[0-9]+\.[0-9]+%" \
    | head -1 \
    | awk '{print $NF}' \
    | sed 's/\[.\]//g')

if [[ -n "$HOT_SYMBOL" ]]; then
    echo "分析最热函数: $HOT_SYMBOL"

    {
        echo "源码级注解分析"
        echo "========================================"
        echo "函数: $HOT_SYMBOL"
        echo ""
    } > "$OUTPUT_DIR/annotate_${HOT_SYMBOL//\//_}.txt"

    sudo perf annotate -i "$OUTPUT_DIR/perf.data" \
        --stdio \
        --symbol="$HOT_SYMBOL" \
        >> "$OUTPUT_DIR/annotate_${HOT_SYMBOL//\//_}.txt" 2>/dev/null || true

    echo "✓ 源码注解完成"
else
    echo "⚠ 未找到明显热点函数"
fi

echo ""

# ========== Step 5: 性能统计摘要 ==========
echo "步骤 5/7: 性能统计摘要..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "性能统计摘要"
    echo "========================================"
    echo "测量时间: $(date)"
    echo ""
} > "$OUTPUT_DIR/stat_summary.txt"

STAT_OPTS=""
if [[ -n "$TARGET_PID" ]]; then
    STAT_OPTS="-p $TARGET_PID"
else
    STAT_OPTS="-a"
fi

echo "正在统计10秒性能计数器..."
sudo perf stat $STAT_OPTS \
    -e cycles,instructions,cache-references,cache-misses,branch-instructions,branch-misses \
    -e page-faults,context-switches,cpu-migrations \
    -- sleep 10 2>&1 | tee -a "$OUTPUT_DIR/stat_summary.txt"

echo ""

# ========== Step 6: 事件频率分析 ==========
echo "步骤 6/7: 事件频率分析..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "事件频率统计"
    echo "========================================"
    echo ""
} > "$OUTPUT_DIR/event_frequency.txt"

sudo perf script -i "$OUTPUT_DIR/perf.data" \
    | head -1000 \
    >> "$OUTPUT_DIR/event_frequency.txt"

echo "✓ 事件数据已导出"
echo ""

# ========== Step 7: 生成分析摘要 ==========
echo "步骤 7/7: 生成综合分析报告..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "========================================"
    echo "性能瓶颈综合分析报告"
    echo "========================================"
    echo ""
    echo "分析时间: $(date)"
    echo "采样时长: ${DURATION}秒"
    echo "采样频率: ${FREQUENCY}Hz"
    if [[ -n "$TARGET_PID" ]]; then
        echo "目标进程: $TARGET_PROCESS (PID: $TARGET_PID)"
    else
        echo "分析范围: 系统范围"
    fi
    echo ""

    echo "一、性能热点摘要"
    echo "----------------------------------------"
    echo ""
    echo "Top 5 热点函数:"
    sudo perf report -i "$OUTPUT_DIR/perf.data" \
        --stdio \
        --percent-limit 1.0 \
        --sort symbol \
        | grep -E "^\s+[0-9]+\.[0-9]+%" \
        | head -5
    echo ""

    echo "二、性能计数器分析"
    echo "----------------------------------------"
    echo ""
    grep -A 20 "Performance counter stats" "$OUTPUT_DIR/stat_summary.txt" || true
    echo ""

    echo "三、潜在性能问题"
    echo "----------------------------------------"
    echo ""

    # 分析cache miss率
    CACHE_REFS=$(grep "cache-references" "$OUTPUT_DIR/stat_summary.txt" | awk '{print $1}' | tr -d ',')
    CACHE_MISS=$(grep "cache-misses" "$OUTPUT_DIR/stat_summary.txt" | awk '{print $1}' | tr -d ',')
    if [[ -n "$CACHE_REFS" ]] && [[ -n "$CACHE_MISS" ]] && [[ $CACHE_REFS -gt 0 ]]; then
        CACHE_MISS_RATE=$(echo "scale=2; $CACHE_MISS * 100 / $CACHE_REFS" | bc)
        echo "• Cache Miss率: ${CACHE_MISS_RATE}%"
        if (( $(echo "$CACHE_MISS_RATE > 10" | bc -l) )); then
            echo "  ⚠️  警告: Cache miss率较高，可能存在缓存效率问题"
        else
            echo "  ✓ Cache使用效率良好"
        fi
    fi
    echo ""

    # 分析分支预测失败率
    BRANCH_INST=$(grep "branch-instructions" "$OUTPUT_DIR/stat_summary.txt" | awk '{print $1}' | tr -d ',')
    BRANCH_MISS=$(grep "branch-misses" "$OUTPUT_DIR/stat_summary.txt" | awk '{print $1}' | tr -d ',')
    if [[ -n "$BRANCH_INST" ]] && [[ -n "$BRANCH_MISS" ]] && [[ $BRANCH_INST -gt 0 ]]; then
        BRANCH_MISS_RATE=$(echo "scale=2; $BRANCH_MISS * 100 / $BRANCH_INST" | bc)
        echo "• 分支预测失败率: ${BRANCH_MISS_RATE}%"
        if (( $(echo "$BRANCH_MISS_RATE > 5" | bc -l) )); then
            echo "  ⚠️  警告: 分支预测失败率较高，可能存在分支逻辑问题"
        else
            echo "  ✓ 分支预测效率良好"
        fi
    fi
    echo ""

    # 检查热点函数类型
    echo "• 热点函数类型分析:"
    if sudo perf report -i "$OUTPUT_DIR/perf.data" --stdio | grep -q "mutex\|lock\|spin"; then
        echo "  ⚠️  检测到锁相关热点，可能存在锁竞争问题"
    fi
    if sudo perf report -i "$OUTPUT_DIR/perf.data" --stdio | grep -q "malloc\|free\|alloc"; then
        echo "  ⚠️  检测到内存分配热点，可能存在频繁分配问题"
    fi
    if sudo perf report -i "$OUTPUT_DIR/perf.data" --stdio | grep -q "memcpy\|memmove\|memset"; then
        echo "  ⚠️  检测到内存操作热点，可能存在大量内存拷贝"
    fi
    if sudo perf report -i "$OUTPUT_DIR/perf.data" --stdio | grep -q "sys_\|syscall"; then
        echo "  ⚠️  检测到系统调用热点，可能存在频繁系统调用"
    fi
    echo ""

    echo "四、优化建议"
    echo "----------------------------------------"
    echo ""
    echo "1. 查看详细热点分析:"
    echo "   cat $OUTPUT_DIR/hotspots_report.txt"
    echo ""
    echo "2. 查看调用链分析:"
    echo "   cat $OUTPUT_DIR/callgraph_report.txt"
    echo ""
    echo "3. 查看源码级注解:"
    echo "   ls $OUTPUT_DIR/annotate_*.txt"
    echo ""
    echo "4. 生成火焰图（推荐）:"
    echo "   $SCRIPT_DIR/flamegraph_generation.sh -i $OUTPUT_DIR/perf.data"
    echo ""
    echo "5. 深入分析特定函数:"
    echo "   sudo perf report -i $OUTPUT_DIR/perf.data --stdio"
    echo ""

} | tee "$OUTPUT_DIR/summary_report.txt"

echo ""
echo "========================================"
echo "分析完成"
echo "========================================"
echo ""
echo "结果已保存到: $OUTPUT_DIR"
echo ""
echo "主要文件:"
echo "  • summary_report.txt      - 综合分析报告（推荐查看）"
echo "  • hotspots_report.txt     - 热点函数详细报告"
echo "  • callgraph_report.txt    - 调用链分析报告"
echo "  • stat_summary.txt        - 性能统计摘要"
echo "  • perf.data               - 原始采样数据"
echo ""
echo "下一步:"
echo "  1. 查看综合报告: cat $OUTPUT_DIR/summary_report.txt"
echo "  2. 生成火焰图: $SCRIPT_DIR/flamegraph_generation.sh -i $OUTPUT_DIR/perf.data"
echo ""
