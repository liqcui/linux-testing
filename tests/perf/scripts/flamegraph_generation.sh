#!/bin/bash
# flamegraph_generation.sh - 完整火焰图生成流程

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/../results/flamegraphs_$(date +%Y%m%d_%H%M%S)"

# 参数
INPUT_PERF_DATA=""
TARGET_PID=""
TARGET_PROCESS=""
DURATION=60
FREQUENCY=99
FLAMEGRAPH_DIR=""

# 使用说明
usage() {
    cat << EOF
用法: $0 [选项]

火焰图生成工具 - 可视化性能分析

选项:
  -i FILE         使用已有的perf.data文件
  -p PID          指定进程PID（新采样）
  -n NAME         指定进程名称（新采样）
  -d DURATION     采样时长（秒，默认60）
  -f FREQUENCY    采样频率（Hz，默认99）
  -o DIR          输出目录（默认自动生成）
  -h              显示此帮助信息

火焰图类型:
  • on-CPU:       CPU执行时间火焰图（默认）
  • off-CPU:      阻塞等待时间火焰图
  • differential: 差分火焰图（对比两个场景）
  • kernel:       内核专用火焰图

示例:
  # 使用已有perf.data生成火焰图
  $0 -i /path/to/perf.data

  # 新采样并生成火焰图
  $0 -p 1234 -d 60

  # 分析指定进程
  $0 -n nginx -d 60

  # 系统范围采样
  $0 -d 60

EOF
    exit 1
}

# 解析命令行参数
while getopts "i:p:n:d:f:o:h" opt; do
    case $opt in
        i) INPUT_PERF_DATA="$OPTARG" ;;
        p) TARGET_PID="$OPTARG" ;;
        n) TARGET_PROCESS="$OPTARG" ;;
        d) DURATION="$OPTARG" ;;
        f) FREQUENCY="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

mkdir -p "$OUTPUT_DIR"

echo "========================================"
echo "火焰图生成工具"
echo "========================================"
echo ""

# 检查和安装FlameGraph工具
FLAMEGRAPH_DIR="$SCRIPT_DIR/FlameGraph"

if [[ ! -d "$FLAMEGRAPH_DIR" ]]; then
    echo "步骤 0: 安装FlameGraph工具..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "正在克隆FlameGraph仓库..."

    if git clone https://github.com/brendangregg/FlameGraph.git "$FLAMEGRAPH_DIR"; then
        echo "✓ FlameGraph工具安装成功"
    else
        echo "✗ FlameGraph工具安装失败"
        echo ""
        echo "请手动安装:"
        echo "  cd $SCRIPT_DIR"
        echo "  git clone https://github.com/brendangregg/FlameGraph.git"
        exit 1
    fi
    echo ""
fi

# 确定perf.data来源
PERF_DATA=""

if [[ -n "$INPUT_PERF_DATA" ]]; then
    # 使用已有的perf.data
    if [[ ! -f "$INPUT_PERF_DATA" ]]; then
        echo "✗ 错误: perf.data文件不存在: $INPUT_PERF_DATA"
        exit 1
    fi
    PERF_DATA="$INPUT_PERF_DATA"
    echo "使用已有数据: $PERF_DATA"
    echo ""
else
    # 新采样
    echo "配置:"

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
        echo "  目标: 系统范围（全局）"
    fi

    echo "  采样时长: ${DURATION}秒"
    echo "  采样频率: ${FREQUENCY}Hz"
    echo ""

    echo "正在采样..."

    PERF_OPTS="-F $FREQUENCY -g"
    if [[ -n "$TARGET_PID" ]]; then
        PERF_OPTS="$PERF_OPTS -p $TARGET_PID"
    else
        PERF_OPTS="$PERF_OPTS -a"
    fi

    PERF_DATA="$OUTPUT_DIR/perf.data"

    if sudo perf record $PERF_OPTS -o "$PERF_DATA" -- sleep $DURATION; then
        echo "✓ 采样完成"
        DATA_SIZE=$(du -h "$PERF_DATA" | cut -f1)
        echo "  数据大小: $DATA_SIZE"
    else
        echo "✗ 采样失败"
        exit 1
    fi
    echo ""
fi

# ========== 火焰图1: on-CPU火焰图（CPU执行时间）==========

echo "步骤 1: 生成 on-CPU 火焰图..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "on-CPU火焰图显示CPU执行时间分布"
echo "  • 宽度: 函数在CPU上执行的时间占比"
echo "  • 高度: 调用栈深度"
echo "  • 颜色: 随机（仅用于区分函数）"
echo ""

# 解析为折叠格式
echo "正在处理数据..."
sudo perf script -i "$PERF_DATA" | \
    "$FLAMEGRAPH_DIR/stackcollapse-perf.pl" > "$OUTPUT_DIR/out.folded"

# 生成SVG火焰图
"$FLAMEGRAPH_DIR/flamegraph.pl" \
    --title="on-CPU Flame Graph" \
    --width=1600 \
    "$OUTPUT_DIR/out.folded" > "$OUTPUT_DIR/oncpu_flamegraph.svg"

if [[ -f "$OUTPUT_DIR/oncpu_flamegraph.svg" ]]; then
    echo "✓ on-CPU火焰图: $OUTPUT_DIR/oncpu_flamegraph.svg"

    # 显示文件大小
    SVG_SIZE=$(du -h "$OUTPUT_DIR/oncpu_flamegraph.svg" | cut -f1)
    echo "  文件大小: $SVG_SIZE"

    # 统计热点
    TOTAL_SAMPLES=$(wc -l < "$OUTPUT_DIR/out.folded")
    echo "  总样本数: $TOTAL_SAMPLES"
else
    echo "✗ 生成失败"
fi

echo ""

# ========== 火焰图2: off-CPU火焰图（阻塞等待时间）==========

echo "步骤 2: 生成 off-CPU 火焰图..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "off-CPU火焰图显示阻塞等待时间分布"
echo "  • 适用场景: I/O密集、锁等待、睡眠等"
echo "  • 需要: 调度事件追踪"
echo ""

if [[ -n "$INPUT_PERF_DATA" ]]; then
    echo "⚠ 使用已有perf.data，可能缺少调度事件"
    echo "  建议使用以下命令重新采样off-CPU数据:"
    echo "  sudo perf record -e sched:sched_stat_sleep -e sched:sched_switch \\"
    echo "      -e sched:sched_process_exit -a -g -- sleep 60"
    echo ""
else
    echo "正在采样调度事件（${DURATION}秒）..."

    OFFCPU_DATA="$OUTPUT_DIR/offcpu_perf.data"

    if sudo perf record \
        -e sched:sched_stat_sleep \
        -e sched:sched_switch \
        -e sched:sched_process_exit \
        -a -g \
        -o "$OFFCPU_DATA" \
        -- sleep $DURATION; then

        echo "✓ off-CPU采样完成"

        # 生成off-CPU火焰图
        sudo perf script -i "$OFFCPU_DATA" | \
            "$FLAMEGRAPH_DIR/stackcollapse-perf.pl" | \
            "$FLAMEGRAPH_DIR/flamegraph.pl" \
                --title="off-CPU Time Flame Graph" \
                --countname=us \
                --colors=io \
                --width=1600 \
                > "$OUTPUT_DIR/offcpu_flamegraph.svg"

        if [[ -f "$OUTPUT_DIR/offcpu_flamegraph.svg" ]]; then
            echo "✓ off-CPU火焰图: $OUTPUT_DIR/offcpu_flamegraph.svg"
        else
            echo "✗ 生成失败"
        fi
    else
        echo "✗ off-CPU采样失败"
    fi
fi

echo ""

# ========== 火焰图3: 差分火焰图（对比两个场景）==========

echo "步骤 3: 差分火焰图生成说明..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "差分火焰图用于对比两个场景的性能差异"
echo "  • 红色: 问题场景消耗更多CPU"
echo "  • 蓝色: 正常场景消耗更多CPU"
echo ""
echo "生成步骤:"
echo "  1. 采样正常场景:"
echo "     sudo perf record -F 99 -a -g -o perf.data.normal -- sleep 60"
echo ""
echo "  2. 采样问题场景:"
echo "     sudo perf record -F 99 -a -g -o perf.data.problem -- sleep 60"
echo ""
echo "  3. 生成差分火焰图:"
echo "     sudo perf script -i perf.data.normal | \\"
echo "         $FLAMEGRAPH_DIR/stackcollapse-perf.pl > normal.folded"
echo "     sudo perf script -i perf.data.problem | \\"
echo "         $FLAMEGRAPH_DIR/stackcollapse-perf.pl > problem.folded"
echo "     $FLAMEGRAPH_DIR/difffolded.pl normal.folded problem.folded | \\"
echo "         $FLAMEGRAPH_DIR/flamegraph.pl --title='Differential Flame Graph' \\"
echo "         > differential_flamegraph.svg"
echo ""

# 如果提供了差分对比文件，生成差分火焰图
if [[ -f "$OUTPUT_DIR/perf.data.normal" ]] && [[ -f "$OUTPUT_DIR/perf.data.problem" ]]; then
    echo "检测到对比数据文件，生成差分火焰图..."

    sudo perf script -i "$OUTPUT_DIR/perf.data.normal" | \
        "$FLAMEGRAPH_DIR/stackcollapse-perf.pl" > "$OUTPUT_DIR/normal.folded"

    sudo perf script -i "$OUTPUT_DIR/perf.data.problem" | \
        "$FLAMEGRAPH_DIR/stackcollapse-perf.pl" > "$OUTPUT_DIR/problem.folded"

    "$FLAMEGRAPH_DIR/difffolded.pl" \
        "$OUTPUT_DIR/normal.folded" \
        "$OUTPUT_DIR/problem.folded" | \
        "$FLAMEGRAPH_DIR/flamegraph.pl" \
            --title="Differential Flame Graph" \
            --width=1600 \
            > "$OUTPUT_DIR/differential_flamegraph.svg"

    if [[ -f "$OUTPUT_DIR/differential_flamegraph.svg" ]]; then
        echo "✓ 差分火焰图: $OUTPUT_DIR/differential_flamegraph.svg"
    fi
fi

echo ""

# ========== 火焰图4: 内核专用火焰图 ==========

echo "步骤 4: 生成内核专用火焰图..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "内核火焰图仅显示内核态调用栈"
echo "  • 适用: 分析内核性能问题"
echo "  • 过滤: 仅保留内核符号"
echo ""

# 提取内核调用栈
sudo perf script -i "$PERF_DATA" | \
    grep -v "^    " | \
    "$FLAMEGRAPH_DIR/stackcollapse-perf.pl" | \
    "$FLAMEGRAPH_DIR/flamegraph.pl" \
        --title="Kernel Flame Graph" \
        --colors=green \
        --width=1600 \
        > "$OUTPUT_DIR/kernel_flamegraph.svg"

if [[ -f "$OUTPUT_DIR/kernel_flamegraph.svg" ]]; then
    echo "✓ 内核火焰图: $OUTPUT_DIR/kernel_flamegraph.svg"

    # 检查是否有内核数据
    KERNEL_SAMPLES=$(sudo perf script -i "$PERF_DATA" | grep -v "^    " | wc -l)
    if [[ $KERNEL_SAMPLES -eq 0 ]]; then
        echo "  ⚠ 警告: 未检测到内核符号，可能需要安装调试符号"
    else
        echo "  内核样本数: $KERNEL_SAMPLES"
    fi
else
    echo "✗ 生成失败"
fi

echo ""

# ========== 火焰图5: 用户态专用火焰图 ==========

echo "步骤 5: 生成用户态专用火焰图..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

sudo perf script -i "$PERF_DATA" | \
    grep "^    " | \
    "$FLAMEGRAPH_DIR/stackcollapse-perf.pl" | \
    "$FLAMEGRAPH_DIR/flamegraph.pl" \
        --title="User-Space Flame Graph" \
        --colors=blue \
        --width=1600 \
        > "$OUTPUT_DIR/userspace_flamegraph.svg"

if [[ -f "$OUTPUT_DIR/userspace_flamegraph.svg" ]]; then
    echo "✓ 用户态火焰图: $OUTPUT_DIR/userspace_flamegraph.svg"
else
    echo "✗ 生成失败"
fi

echo ""

# ========== 生成分析报告 ==========

echo "步骤 6: 生成火焰图分析报告..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

REPORT_FILE="$OUTPUT_DIR/flamegraph_analysis_report.txt"

{
    echo "========================================"
    echo "火焰图分析报告"
    echo "========================================"
    echo ""
    echo "生成时间: $(date)"
    echo ""

    echo "一、生成的火焰图"
    echo "----------------------------------------"
    echo ""

    if [[ -f "$OUTPUT_DIR/oncpu_flamegraph.svg" ]]; then
        echo "✓ on-CPU火焰图: oncpu_flamegraph.svg"
        echo "  用途: 分析CPU执行时间热点"
    fi

    if [[ -f "$OUTPUT_DIR/offcpu_flamegraph.svg" ]]; then
        echo "✓ off-CPU火焰图: offcpu_flamegraph.svg"
        echo "  用途: 分析阻塞等待时间"
    fi

    if [[ -f "$OUTPUT_DIR/kernel_flamegraph.svg" ]]; then
        echo "✓ 内核火焰图: kernel_flamegraph.svg"
        echo "  用途: 分析内核态性能"
    fi

    if [[ -f "$OUTPUT_DIR/userspace_flamegraph.svg" ]]; then
        echo "✓ 用户态火焰图: userspace_flamegraph.svg"
        echo "  用途: 分析用户态性能"
    fi

    echo ""

    echo "二、Top 热点函数"
    echo "----------------------------------------"
    echo ""

    if [[ -f "$OUTPUT_DIR/out.folded" ]]; then
        echo "Top 10 热点函数（按采样次数）:"
        echo ""
        awk '{n[$NF]+=$1} END {for(i in n){print n[i],i}}' "$OUTPUT_DIR/out.folded" | \
            sort -rn | head -10 | \
            awk '{printf "  %6d  %s\n", $1, $2}'
    fi

    echo ""

    echo "三、性能模式检测"
    echo "----------------------------------------"
    echo ""

    # 检测锁相关热点
    if grep -qi "mutex\|spinlock\|semaphore\|rwlock" "$OUTPUT_DIR/out.folded"; then
        echo "⚠️  检测到锁相关热点"
        echo "  可能存在: 锁竞争问题"
        echo "  建议: 检查锁的持有时间和粒度"
        echo ""
    fi

    # 检测内存分配
    if grep -qi "kmalloc\|malloc\|alloc\|free" "$OUTPUT_DIR/out.folded"; then
        echo "⚠️  检测到内存分配热点"
        echo "  可能存在: 频繁内存分配/释放"
        echo "  建议: 使用内存池或减少分配次数"
        echo ""
    fi

    # 检测系统调用
    if grep -qi "sys_\|syscall\|entry_SYSCALL" "$OUTPUT_DIR/out.folded"; then
        echo "⚠️  检测到系统调用热点"
        echo "  可能存在: 频繁系统调用"
        echo "  建议: 批量操作、使用用户态缓存"
        echo ""
    fi

    # 检测内存拷贝
    if grep -qi "memcpy\|memmove\|memset\|copy" "$OUTPUT_DIR/out.folded"; then
        echo "⚠️  检测到内存操作热点"
        echo "  可能存在: 大量内存拷贝"
        echo "  建议: 减少不必要的拷贝、使用引用传递"
        echo ""
    fi

    # 检测字符串操作
    if grep -qi "strcmp\|strcpy\|strlen\|strcat" "$OUTPUT_DIR/out.folded"; then
        echo "⚠️  检测到字符串操作热点"
        echo "  可能存在: 频繁字符串处理"
        echo "  建议: 优化字符串算法、使用更高效的数据结构"
        echo ""
    fi

    echo "四、如何阅读火焰图"
    echo "----------------------------------------"
    echo ""
    echo "1. Y轴（高度）: 调用栈深度"
    echo "   • 从下往上代表函数调用层级"
    echo "   • 最下层是根函数，最上层是叶子函数"
    echo ""
    echo "2. X轴（宽度）: 函数执行时间占比"
    echo "   • 宽度越大，CPU时间越多"
    echo "   • X轴顺序不代表时间顺序，而是字母排序"
    echo ""
    echo "3. 颜色: 随机（仅用于区分）"
    echo "   • 红色/橙色: 通常表示CPU密集"
    echo "   • 蓝色/绿色: 可能表示I/O或内核"
    echo ""
    echo "4. 交互:"
    echo "   • 点击函数框: 放大显示该函数及其子调用"
    echo "   • Ctrl+F: 搜索函数名"
    echo "   • Reset Zoom: 恢复初始视图"
    echo ""

    echo "五、分析建议"
    echo "----------------------------------------"
    echo ""
    echo "1. 查找平顶山（plateau）"
    echo "   • 宽且平的函数框表示该函数直接消耗大量CPU"
    echo "   • 这是最值得优化的热点"
    echo ""
    echo "2. 查找塔尖（tower）"
    echo "   • 窄且高的调用栈表示深度递归或调用链长"
    echo "   • 可能存在过度抽象或递归问题"
    echo ""
    echo "3. 对比分析"
    echo "   • 使用差分火焰图对比正常和异常场景"
    echo "   • 关注红色区域（异常场景特有的热点）"
    echo ""
    echo "4. 结合其他工具"
    echo "   • perf report: 查看详细统计"
    echo "   • perf annotate: 查看源码级热点"
    echo "   • perf stat: 查看硬件计数器"
    echo ""

} | tee "$REPORT_FILE"

echo ""
echo "========================================"
echo "火焰图生成完成"
echo "========================================"
echo ""
echo "结果保存到: $OUTPUT_DIR"
echo ""
echo "生成的文件:"
ls -lh "$OUTPUT_DIR"/*.svg 2>/dev/null | awk '{printf "  • %s (%s)\n", $9, $5}'
echo ""
echo "查看火焰图:"
echo "  • 浏览器打开: file://$OUTPUT_DIR/oncpu_flamegraph.svg"
echo "  • 或使用: open $OUTPUT_DIR/oncpu_flamegraph.svg"
echo ""
echo "查看分析报告:"
echo "  cat $OUTPUT_DIR/flamegraph_analysis_report.txt"
echo ""
