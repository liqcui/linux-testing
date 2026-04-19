#!/bin/bash
# test_valgrind.sh - Valgrind内存分析测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRAMS_DIR="$SCRIPT_DIR/../programs"
RESULTS_DIR="$SCRIPT_DIR/../results/valgrind-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "Valgrind 内存分析测试"
echo "========================================"
echo ""

mkdir -p "$RESULTS_DIR"

# 检查Valgrind是否安装
echo "步骤 1: 检查Valgrind安装..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ! command -v valgrind &> /dev/null; then
    echo "✗ Valgrind未安装"
    echo ""
    echo "安装方法:"
    echo "  Ubuntu/Debian: sudo apt-get install valgrind"
    echo "  RHEL/CentOS:   sudo yum install valgrind"
    echo "  Fedora:        sudo dnf install valgrind"
    exit 1
fi

VALGRIND_VERSION=$(valgrind --version)
echo "✓ Valgrind已安装: $VALGRIND_VERSION"
echo ""

# Valgrind原理说明
echo "步骤 2: Valgrind测试原理..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "Valgrind 内存分析原理"
    echo "========================================"
    echo ""
    echo "Valgrind是什么:"
    echo "  - 动态分析工具框架"
    echo "  - 主要用于内存调试和性能分析"
    echo "  - 在虚拟CPU上运行程序"
    echo "  - 监控所有内存访问和分配"
    echo ""
    echo "核心工具:"
    echo ""
    echo "1. Memcheck (默认工具)"
    echo "   - 内存泄漏检测"
    echo "   - 使用未初始化内存"
    echo "   - 无效内存访问"
    echo "   - 重复释放"
    echo "   - 使用已释放内存"
    echo ""
    echo "2. Cachegrind"
    echo "   - 缓存性能分析"
    echo "   - 模拟L1/L2缓存"
    echo "   - 统计缓存命中/失效"
    echo ""
    echo "3. Callgrind"
    echo "   - 调用图分析"
    echo "   - 函数调用关系"
    echo "   - 性能瓶颈定位"
    echo ""
    echo "4. Helgrind"
    echo "   - 线程错误检测"
    echo "   - 数据竞争"
    echo "   - 死锁检测"
    echo ""
    echo "5. Massif"
    echo "   - 堆分析器"
    echo "   - 内存使用趋势"
    echo "   - 峰值内存分析"
    echo ""
    echo "Memcheck检测的问题:"
    echo ""
    echo "1. 内存泄漏 (Memory Leaks)"
    echo "   - Definitely lost: 确定泄漏"
    echo "   - Indirectly lost: 间接泄漏"
    echo "   - Possibly lost: 可能泄漏"
    echo "   - Still reachable: 仍可达（程序结束时未释放）"
    echo ""
    echo "2. 无效读/写 (Invalid Read/Write)"
    echo "   - 数组越界"
    echo "   - 使用已释放内存"
    echo "   - 栈溢出"
    echo ""
    echo "3. 未初始化值 (Uninitialized Values)"
    echo "   - 使用未初始化的变量"
    echo "   - 条件跳转依赖未初始化值"
    echo ""
    echo "4. 无效释放 (Invalid Free)"
    echo "   - 重复释放"
    echo "   - 释放未分配的内存"
    echo "   - 释放栈内存"
    echo ""
    echo "工作原理:"
    echo "  1. 在虚拟CPU上运行程序（约慢20-30倍）"
    echo "  2. 拦截所有内存分配/释放调用"
    echo "  3. 跟踪每个字节的状态"
    echo "  4. 检测非法内存访问"
    echo "  5. 生成详细报告"
    echo ""
    echo "性能影响:"
    echo "  - 运行速度: 原程序的1/20 - 1/30"
    echo "  - 内存占用: 增加2-3倍"
    echo "  - 仅用于开发/测试环境"
    echo ""
} | tee "$RESULTS_DIR/principles.txt"

# 编译测试程序
echo "步骤 3: 编译测试程序..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd "$PROGRAMS_DIR"

PROGRAMS=(
    "memory_leak:内存泄漏示例"
    "valgrind_tests:Valgrind综合测试"
)

for prog_info in "${PROGRAMS[@]}"; do
    IFS=':' read -r prog desc <<< "$prog_info"

    echo "编译: $desc ($prog.c)"

    # 使用-g生成调试信息，Valgrind需要
    gcc -g -o $prog ${prog}.c

    if [[ $? -eq 0 ]]; then
        echo "  ✓ 编译成功: $prog"
    else
        echo "  ✗ 编译失败: $prog"
    fi
done

echo ""

# 运行Valgrind测试
echo "步骤 4: 运行Valgrind测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 测试1: 基本内存泄漏检测
if [[ -f "$PROGRAMS_DIR/memory_leak" ]]; then
    echo "测试 1: 内存泄漏检测"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    valgrind --leak-check=full \
             --show-leak-kinds=all \
             --track-origins=yes \
             --log-file="$RESULTS_DIR/memory_leak_valgrind.txt" \
             "$PROGRAMS_DIR/memory_leak"

    echo ""
    echo "✓ 内存泄漏检测完成"
    echo "  详细报告: $RESULTS_DIR/memory_leak_valgrind.txt"
    echo ""
fi

# 测试2: 综合测试
if [[ -f "$PROGRAMS_DIR/valgrind_tests" ]]; then
    echo "测试 2: Valgrind综合测试"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    valgrind --leak-check=full \
             --show-leak-kinds=all \
             --track-origins=yes \
             --verbose \
             --log-file="$RESULTS_DIR/valgrind_comprehensive.txt" \
             "$PROGRAMS_DIR/valgrind_tests"

    echo ""
    echo "✓ 综合测试完成"
    echo "  详细报告: $RESULTS_DIR/valgrind_comprehensive.txt"
    echo ""
fi

# 提取测试结果摘要
echo "步骤 5: 分析测试结果..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "Valgrind测试结果摘要"
    echo "========================================"
    echo ""

    for report in "$RESULTS_DIR"/*_valgrind.txt "$RESULTS_DIR"/valgrind_*.txt; do
        if [[ -f "$report" ]]; then
            basename_report=$(basename "$report")
            echo "报告: $basename_report"
            echo "----------------------------------------"

            # 提取堆摘要
            echo ""
            echo "堆摘要 (Heap Summary):"
            grep -A 10 "HEAP SUMMARY" "$report" | head -11

            # 提取泄漏摘要
            echo ""
            echo "泄漏摘要 (Leak Summary):"
            grep -A 10 "LEAK SUMMARY" "$report" | head -11

            # 提取错误摘要
            echo ""
            echo "错误摘要 (Error Summary):"
            grep "ERROR SUMMARY" "$report"

            echo ""
            echo "========================================"
            echo ""
        fi
    done

} | tee "$RESULTS_DIR/summary.txt"

# Valgrind选项说明
{
    echo "Valgrind常用选项"
    echo "========================================"
    echo ""

    echo "基本选项:"
    echo "  --tool=<name>         # 使用的工具(默认memcheck)"
    echo "  --leak-check=<no|summary|yes|full>"
    echo "                        # 泄漏检测级别"
    echo "  --show-leak-kinds=<set>"
    echo "                        # 显示的泄漏类型"
    echo "  --track-origins=yes   # 跟踪未初始化值的来源"
    echo ""

    echo "详细输出:"
    echo "  --verbose             # 详细输出"
    echo "  --log-file=<file>     # 输出到文件"
    echo "  --xml=yes             # XML格式输出"
    echo "  --xml-file=<file>     # XML输出文件"
    echo ""

    echo "抑制选项:"
    echo "  --suppressions=<file> # 抑制文件"
    echo "  --gen-suppressions=all"
    echo "                        # 生成抑制规则"
    echo ""

    echo "其他工具:"
    echo "  --tool=cachegrind     # 缓存性能分析"
    echo "  --tool=callgrind      # 调用图分析"
    echo "  --tool=helgrind       # 线程错误检测"
    echo "  --tool=massif         # 堆分析"
    echo ""

    echo "泄漏类型:"
    echo "  definitely lost       # 确定泄漏，没有指针指向"
    echo "  indirectly lost       # 间接泄漏，父结构泄漏导致"
    echo "  possibly lost         # 可能泄漏，有内部指针但无起始指针"
    echo "  still reachable       # 仍可达，程序结束时未释放"
    echo "  suppressed            # 被抑制的泄漏"
    echo ""

    echo "常见命令示例:"
    echo ""
    echo "1. 基本内存检查:"
    echo "   valgrind ./program"
    echo ""
    echo "2. 详细泄漏检查:"
    echo "   valgrind --leak-check=full ./program"
    echo ""
    echo "3. 完整检查（推荐）:"
    echo "   valgrind --leak-check=full \\"
    echo "            --show-leak-kinds=all \\"
    echo "            --track-origins=yes \\"
    echo "            ./program"
    echo ""
    echo "4. 缓存性能分析:"
    echo "   valgrind --tool=cachegrind ./program"
    echo "   cg_annotate cachegrind.out.<pid>"
    echo ""
    echo "5. 调用图分析:"
    echo "   valgrind --tool=callgrind ./program"
    echo "   callgrind_annotate callgrind.out.<pid>"
    echo ""
    echo "6. 堆分析:"
    echo "   valgrind --tool=massif ./program"
    echo "   ms_print massif.out.<pid>"
    echo ""

} | tee "$RESULTS_DIR/options_guide.txt"

# 常见问题和解决方法
{
    echo "Valgrind常见问题"
    echo "========================================"
    echo ""

    echo "问题1: 程序运行太慢"
    echo "原因: Valgrind使程序慢20-30倍"
    echo "解决:"
    echo "  - 使用小数据集测试"
    echo "  - 只测试关键代码路径"
    echo "  - 使用--leak-check=summary代替full"
    echo "  - 在快速机器上运行"
    echo ""

    echo "问题2: 误报（False Positives）"
    echo "原因: 某些库有已知的'泄漏'"
    echo "解决:"
    echo "  - 使用抑制文件"
    echo "  - 关注definitely lost"
    echo "  - 忽略still reachable（除非必要）"
    echo ""
    echo "生成抑制规则:"
    echo "  valgrind --gen-suppressions=all ./program 2>&1 | \\"
    echo "    grep -A 20 'insert a suppression' > suppressions.txt"
    echo ""

    echo "问题3: 无调试信息"
    echo "原因: 程序未用-g编译"
    echo "解决:"
    echo "  gcc -g -O0 program.c  # -O0禁用优化，方便调试"
    echo ""

    echo "问题4: 内存不足"
    echo "原因: Valgrind增加2-3倍内存占用"
    echo "解决:"
    echo "  - 增加系统内存或swap"
    echo "  - 减小测试数据集"
    echo ""

    echo "问题5: 输出信息太多"
    echo "解决:"
    echo "  - 使用--log-file输出到文件"
    echo "  - 使用--quiet减少输出"
    echo "  - 只关注特定类型的错误"
    echo ""

} | tee "$RESULTS_DIR/troubleshooting.txt"

# 生成报告
{
    echo "Valgrind内存分析测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo ""
    echo "Valgrind版本:"
    echo "  $VALGRIND_VERSION"
    echo ""
    echo "测试程序:"
    for prog_info in "${PROGRAMS[@]}"; do
        IFS=':' read -r prog desc <<< "$prog_info"
        if [[ -f "$PROGRAMS_DIR/$prog" ]]; then
            echo "  ✓ $desc"
        fi
    done
    echo ""
    echo "检测的内存问题:"
    echo "  - 内存泄漏 (definitely/indirectly/possibly lost)"
    echo "  - 无效内存访问 (invalid read/write)"
    echo "  - 使用未初始化值"
    echo "  - 重复释放"
    echo "  - 使用已释放内存"
    echo ""
    echo "结果文件:"
    echo "  测试原理: $RESULTS_DIR/principles.txt"
    echo "  结果摘要: $RESULTS_DIR/summary.txt"
    echo "  选项指南: $RESULTS_DIR/options_guide.txt"
    echo "  故障排查: $RESULTS_DIR/troubleshooting.txt"
    echo ""
    echo "详细报告:"
    for report in "$RESULTS_DIR"/*_valgrind.txt "$RESULTS_DIR"/valgrind_*.txt; do
        if [[ -f "$report" ]]; then
            echo "  $(basename "$report")"
        fi
    done
    echo ""
    echo "使用建议:"
    echo "  1. 开发阶段定期运行Valgrind"
    echo "  2. 关注'definitely lost'泄漏"
    echo "  3. 修复所有invalid read/write"
    echo "  4. 使用-g编译以获取行号信息"
    echo "  5. 配合单元测试使用"
    echo ""

} | tee "$RESULTS_DIR/report.txt"

echo ""
echo "========================================"
echo "测试完成"
echo "========================================"
echo ""
echo "✓ Valgrind内存分析测试完成"
echo ""
echo "查看摘要: cat $RESULTS_DIR/summary.txt"
echo "查看详细报告: cat $RESULTS_DIR/*_valgrind.txt"
echo ""
echo "结果目录: $RESULTS_DIR"
echo ""
