#!/bin/bash
# auto_flame_analysis.sh - 自动化火焰图分析工具

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 参数
FLAMEGRAPH_SVG=""
OUTPUT_REPORT=""

# 使用说明
usage() {
    cat << EOF
用法: $0 <flamegraph.svg> [output_report.txt]

自动化火焰图分析工具 - 从火焰图中提取关键性能信息

参数:
  flamegraph.svg     火焰图SVG文件路径
  output_report.txt  输出报告文件（可选，默认同目录下）

示例:
  $0 oncpu_flamegraph.svg
  $0 oncpu_flamegraph.svg custom_report.txt

EOF
    exit 1
}

# 检查参数
if [[ $# -lt 1 ]]; then
    usage
fi

FLAMEGRAPH_SVG="$1"
OUTPUT_REPORT="${2:-${FLAMEGRAPH_SVG%.svg}_analysis.txt}"

# 检查文件存在
if [[ ! -f "$FLAMEGRAPH_SVG" ]]; then
    echo "✗ 错误: 火焰图文件不存在: $FLAMEGRAPH_SVG"
    exit 1
fi

echo "========================================"
echo "自动化火焰图分析"
echo "========================================"
echo ""
echo "输入文件: $FLAMEGRAPH_SVG"
echo "输出报告: $OUTPUT_REPORT"
echo ""
echo "分析中..."
echo ""

# 开始生成报告
{
    echo "========================================"
    echo "火焰图自动分析报告"
    echo "========================================"
    echo ""
    echo "分析时间: $(date)"
    echo "输入文件: $FLAMEGRAPH_SVG"
    echo ""

    # ========== 1. 基本统计信息 ==========
    echo "一、基本统计信息"
    echo "----------------------------------------"
    echo ""

    # SVG文件大小
    FILE_SIZE=$(du -h "$FLAMEGRAPH_SVG" | cut -f1)
    echo "• 文件大小: $FILE_SIZE"

    # 提取总样本数（从SVG中提取）
    TOTAL_SAMPLES=$(grep -oP 'samples, ' "$FLAMEGRAPH_SVG" | head -1 | grep -oP '[0-9,]+' | tr -d ',')
    if [[ -n "$TOTAL_SAMPLES" ]]; then
        echo "• 总样本数: $TOTAL_SAMPLES"
    fi

    # 函数数量（估算）
    FUNC_COUNT=$(grep -c 'class="func_g"' "$FLAMEGRAPH_SVG")
    echo "• 函数框数量: $FUNC_COUNT"

    echo ""

    # ========== 2. Top热点函数 ==========
    echo "二、Top 热点函数"
    echo "----------------------------------------"
    echo ""
    echo "（按CPU时间占比排序）"
    echo ""

    # 提取函数调用信息
    # SVG格式: <title>function_name (samples)</title>
    grep -oP '<title>[^<]+</title>' "$FLAMEGRAPH_SVG" | \
        sed 's/<title>//; s/<\/title>//' | \
        grep -E '\([0-9,]+ samples' | \
        sed 's/ (\([0-9,]*\) samples.*/|\1/' | \
        sed 's/,//g' | \
        sort -t'|' -k2 -rn | \
        head -20 | \
        awk -F'|' 'BEGIN {
            printf "  %-60s %12s %8s\n", "函数名", "样本数", "占比%"
            printf "  %s\n", "--------------------------------------------------------------------------------"
        }
        {
            if (total == 0) total = TOTAL_SAMPLES
            percent = ($2 / total) * 100
            printf "  %-60s %12s %7.2f%%\n", substr($1, 1, 60), $2, percent
        }' TOTAL_SAMPLES="${TOTAL_SAMPLES:-1000000}"

    echo ""

    # ========== 3. 调用栈深度分析 ==========
    echo "三、调用栈深度分析"
    echo "----------------------------------------"
    echo ""

    # 从SVG中提取y坐标来估算栈深度
    MAX_DEPTH=$(grep -oP 'y="[0-9]+"' "$FLAMEGRAPH_SVG" | \
        grep -oP '[0-9]+' | sort -rn | head -1)

    if [[ -n "$MAX_DEPTH" ]]; then
        # SVG中每16像素代表一层
        STACK_DEPTH=$((MAX_DEPTH / 16 + 1))
        echo "• 最大调用栈深度: 约 $STACK_DEPTH 层"

        if [[ $STACK_DEPTH -gt 50 ]]; then
            echo "  ⚠️  警告: 调用栈很深，可能存在:"
            echo "     - 深度递归"
            echo "     - 过度抽象"
            echo "     - 框架层次过多"
        elif [[ $STACK_DEPTH -gt 30 ]]; then
            echo "  ⚠️  调用栈较深，建议检查调用链"
        else
            echo "  ✓ 调用栈深度正常"
        fi
    fi

    echo ""

    # ========== 4. 内核vs用户空间分析 ==========
    echo "四、内核 vs 用户空间分析"
    echo "----------------------------------------"
    echo ""

    # 统计内核函数（通常以[kernel]或系统调用标记）
    KERNEL_FUNCS=$(grep -i '<title>.*\[kernel\]' "$FLAMEGRAPH_SVG" | wc -l)
    USER_FUNCS=$(grep '<title>' "$FLAMEGRAPH_SVG" | grep -v '\[kernel\]' | wc -l)

    TOTAL_FUNCS=$((KERNEL_FUNCS + USER_FUNCS))

    if [[ $TOTAL_FUNCS -gt 0 ]]; then
        KERNEL_PCT=$((KERNEL_FUNCS * 100 / TOTAL_FUNCS))
        USER_PCT=$((USER_FUNCS * 100 / TOTAL_FUNCS))

        echo "• 内核态函数: $KERNEL_FUNCS ($KERNEL_PCT%)"
        echo "• 用户态函数: $USER_FUNCS ($USER_PCT%)"
        echo ""

        if [[ $KERNEL_PCT -gt 50 ]]; then
            echo "  ⚠️  内核态占比高，可能原因:"
            echo "     - 频繁系统调用"
            echo "     - I/O密集操作"
            echo "     - 中断处理较多"
        elif [[ $KERNEL_PCT -gt 20 ]]; then
            echo "  ℹ️  内核态占比适中"
        else
            echo "  ✓ CPU主要在用户态执行"
        fi
    fi

    echo ""

    # ========== 5. 性能模式检测 ==========
    echo "五、潜在性能问题检测"
    echo "----------------------------------------"
    echo ""

    ISSUES_FOUND=0

    # 检测1: 锁竞争
    if grep -qi 'mutex\|spinlock\|semaphore\|rwlock\|pthread_mutex' "$FLAMEGRAPH_SVG"; then
        echo "⚠️  检测到锁相关热点"
        echo ""
        echo "  可能的问题:"
        echo "    • 锁竞争严重"
        echo "    • 临界区过大"
        echo "    • 锁持有时间过长"
        echo ""
        echo "  相关函数:"
        grep -oP '<title>[^<]*(?:mutex|spinlock|semaphore|rwlock)[^<]*</title>' "$FLAMEGRAPH_SVG" | \
            sed 's/<title>//; s/<\/title>//' | \
            head -5 | \
            sed 's/^/    • /'
        echo ""
        echo "  优化建议:"
        echo "    • 减小锁粒度"
        echo "    • 使用读写锁代替互斥锁"
        echo "    • 考虑无锁数据结构"
        echo "    • 使用RCU（内核）"
        echo ""
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi

    # 检测2: 内存分配
    if grep -qi 'malloc\|free\|kmalloc\|kfree\|alloc\|new\|delete' "$FLAMEGRAPH_SVG"; then
        echo "⚠️  检测到内存分配热点"
        echo ""
        echo "  可能的问题:"
        echo "    • 频繁内存分配/释放"
        echo "    • 内存碎片化"
        echo "    • 分配器性能瓶颈"
        echo ""
        echo "  相关函数:"
        grep -oP '<title>[^<]*(?:malloc|free|alloc|new|delete)[^<]*</title>' "$FLAMEGRAPH_SVG" | \
            sed 's/<title>//; s/<\/title>//' | \
            head -5 | \
            sed 's/^/    • /'
        echo ""
        echo "  优化建议:"
        echo "    • 使用内存池（memory pool）"
        echo "    • 对象复用（object pooling）"
        echo "    • 批量分配"
        echo "    • 使用更快的分配器（jemalloc/tcmalloc）"
        echo ""
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi

    # 检测3: 系统调用
    if grep -qi 'sys_\|syscall\|entry_SYSCALL' "$FLAMEGRAPH_SVG"; then
        echo "⚠️  检测到系统调用热点"
        echo ""
        echo "  可能的问题:"
        echo "    • 频繁系统调用"
        echo "    • 上下文切换开销"
        echo "    • 内核态切换代价"
        echo ""
        echo "  相关函数:"
        grep -oP '<title>[^<]*(?:sys_|syscall|entry_SYSCALL)[^<]*</title>' "$FLAMEGRAPH_SVG" | \
            sed 's/<title>//; s/<\/title>//' | \
            head -5 | \
            sed 's/^/    • /'
        echo ""
        echo "  优化建议:"
        echo "    • 批量操作（如批量I/O）"
        echo "    • 使用用户态缓存"
        echo "    • 减少读写调用（使用mmap）"
        echo "    • 异步I/O（io_uring）"
        echo ""
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi

    # 检测4: 内存拷贝
    if grep -qi 'memcpy\|memmove\|memset\|copy_\|__copy' "$FLAMEGRAPH_SVG"; then
        echo "⚠️  检测到内存操作热点"
        echo ""
        echo "  可能的问题:"
        echo "    • 大量内存拷贝"
        echo "    • 数据重复复制"
        echo "    • 缓存未命中"
        echo ""
        echo "  相关函数:"
        grep -oP '<title>[^<]*(?:memcpy|memmove|memset|copy)[^<]*</title>' "$FLAMEGRAPH_SVG" | \
            sed 's/<title>//; s/<\/title>//' | \
            head -5 | \
            sed 's/^/    • /'
        echo ""
        echo "  优化建议:"
        echo "    • 减少不必要的拷贝"
        echo "    • 使用引用传递"
        echo "    • 零拷贝技术（sendfile, splice）"
        echo "    • 使用SIMD指令优化"
        echo ""
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi

    # 检测5: 字符串操作
    if grep -qi 'strcmp\|strcpy\|strlen\|strcat\|sprintf\|snprintf' "$FLAMEGRAPH_SVG"; then
        echo "⚠️  检测到字符串操作热点"
        echo ""
        echo "  可能的问题:"
        echo "    • 频繁字符串处理"
        echo "    • 字符串拼接效率低"
        echo "    • 重复字符串操作"
        echo ""
        echo "  相关函数:"
        grep -oP '<title>[^<]*(?:strcmp|strcpy|strlen|strcat|sprintf)[^<]*</title>' "$FLAMEGRAPH_SVG" | \
            sed 's/<title>//; s/<\/title>//' | \
            head -5 | \
            sed 's/^/    • /'
        echo ""
        echo "  优化建议:"
        echo "    • 使用更高效的字符串库"
        echo "    • 字符串缓存和复用"
        echo "    • 避免重复的strlen调用"
        echo "    • 使用StringBuilder模式"
        echo ""
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi

    # 检测6: JSON/XML解析
    if grep -qi 'json\|xml\|parse' "$FLAMEGRAPH_SVG"; then
        echo "⚠️  检测到数据解析热点"
        echo ""
        echo "  可能的问题:"
        echo "    • 数据解析性能瓶颈"
        echo "    • 使用低效的解析器"
        echo ""
        echo "  优化建议:"
        echo "    • 使用更快的解析库（simdjson, rapidjson）"
        echo "    • 解析结果缓存"
        echo "    • 使用二进制格式（protobuf, msgpack）"
        echo ""
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi

    # 检测7: 哈希操作
    if grep -qi 'hash\|__hash' "$FLAMEGRAPH_SVG"; then
        echo "⚠️  检测到哈希计算热点"
        echo ""
        echo "  可能的问题:"
        echo "    • 哈希碰撞"
        echo "    • 哈希函数效率低"
        echo ""
        echo "  优化建议:"
        echo "    • 使用更快的哈希算法（xxHash, CityHash）"
        echo "    • 增大哈希表容量"
        echo "    • 使用完美哈希"
        echo ""
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi

    if [[ $ISSUES_FOUND -eq 0 ]]; then
        echo "✓ 未检测到明显的性能问题模式"
        echo ""
    else
        echo "共检测到 $ISSUES_FOUND 类潜在性能问题"
        echo ""
    fi

    # ========== 6. 火焰图阅读指南 ==========
    echo "六、火焰图阅读指南"
    echo "----------------------------------------"
    echo ""
    echo "1. 查找\"平顶山\"（Plateau）"
    echo "   • 特征: 宽且平的矩形"
    echo "   • 含义: 该函数直接消耗大量CPU"
    echo "   • 优先级: ★★★★★ 最值得优化"
    echo ""
    echo "2. 查找\"塔尖\"（Tower）"
    echo "   • 特征: 窄且高的调用栈"
    echo "   • 含义: 深度递归或调用链长"
    echo "   • 优先级: ★★★☆☆ 可能存在设计问题"
    echo ""
    echo "3. 注意颜色"
    echo "   • 红色/橙色: 通常表示CPU密集"
    echo "   • 蓝色/绿色: 可能表示I/O或内核"
    echo "   • 颜色仅用于区分，无性能含义"
    echo ""
    echo "4. 交互操作"
    echo "   • 点击: 放大该函数及其子调用"
    echo "   • Ctrl+F: 搜索函数名"
    echo "   • Reset Zoom: 恢复初始视图"
    echo ""

    # ========== 7. 下一步建议 ==========
    echo "七、分析建议和后续步骤"
    echo "----------------------------------------"
    echo ""
    echo "1. 深入分析热点函数"
    echo "   • 使用 perf annotate 查看源码级热点:"
    echo "     sudo perf annotate -i perf.data --symbol=<函数名>"
    echo ""
    echo "2. 查看调用关系"
    echo "   • 使用 perf report 查看调用链:"
    echo "     sudo perf report -i perf.data -g graph,0.5,caller"
    echo ""
    echo "3. 性能对比"
    echo "   • 优化前后生成差分火焰图:"
    echo "     $SCRIPT_DIR/flamegraph_generation.sh"
    echo "     （生成差分火焰图对比改进效果）"
    echo ""
    echo "4. 硬件计数器分析"
    echo "   • 使用 perf stat 查看硬件事件:"
    echo "     sudo perf stat -e cycles,instructions,cache-misses ..."
    echo ""
    echo "5. off-CPU分析"
    echo "   • 如果CPU使用率不高，生成off-CPU火焰图:"
    echo "     $SCRIPT_DIR/flamegraph_generation.sh （包含off-CPU）"
    echo ""

} | tee "$OUTPUT_REPORT"

echo "========================================"
echo "分析完成"
echo "========================================"
echo ""
echo "报告已保存到: $OUTPUT_REPORT"
echo ""
echo "查看完整报告:"
echo "  cat $OUTPUT_REPORT"
echo ""
echo "查看火焰图:"
echo "  open $FLAMEGRAPH_SVG"
echo ""
