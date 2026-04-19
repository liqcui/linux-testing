#!/bin/bash
# test_pmap.sh - pmap内存映射分析测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRAMS_DIR="$SCRIPT_DIR/../programs"
RESULTS_DIR="$SCRIPT_DIR/../results/pmap-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "Pmap 内存映射分析测试"
echo "========================================"
echo ""

mkdir -p "$RESULTS_DIR"

# 检查pmap是否可用
echo "步骤 1: 检查pmap工具..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ! command -v pmap &> /dev/null; then
    echo "✗ pmap未找到"
    echo ""
    echo "pmap通常包含在procps或procps-ng包中:"
    echo "  Ubuntu/Debian: sudo apt-get install procps"
    echo "  RHEL/CentOS:   sudo yum install procps-ng"
    exit 1
fi

echo "✓ pmap可用"
echo ""

# Pmap原理说明
echo "步骤 2: Pmap工具原理..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "Pmap 内存映射分析原理"
    echo "========================================"
    echo ""
    echo "Pmap是什么:"
    echo "  - 报告进程内存映射的工具"
    echo "  - 读取/proc/<pid>/maps和/proc/<pid>/smaps"
    echo "  - 显示虚拟内存布局"
    echo ""
    echo "内存映射类型:"
    echo ""
    echo "1. 代码段 (Text Segment)"
    echo "   - 可执行代码"
    echo "   - 只读，可执行"
    echo "   - 权限: r-x"
    echo ""
    echo "2. 数据段 (Data Segment)"
    echo "   - 已初始化全局变量"
    echo "   - 可读写"
    echo "   - 权限: rw-"
    echo ""
    echo "3. BSS段"
    echo "   - 未初始化全局变量"
    echo "   - 可读写"
    echo "   - 权限: rw-"
    echo ""
    echo "4. 堆 (Heap)"
    echo "   - malloc/calloc/realloc分配"
    echo "   - 向上增长"
    echo "   - 标记为[heap]"
    echo ""
    echo "5. 栈 (Stack)"
    echo "   - 局部变量和函数调用"
    echo "   - 向下增长"
    echo "   - 标记为[stack]"
    echo ""
    echo "6. 共享库 (Shared Libraries)"
    echo "   - .so文件映射"
    echo "   - 代码和数据分段"
    echo ""
    echo "7. 匿名映射 (Anonymous)"
    echo "   - mmap(MAP_ANONYMOUS)分配"
    echo "   - 大块内存分配"
    echo ""
    echo "8. 文件映射 (File-backed)"
    echo "   - mmap文件"
    echo "   - 内存映射I/O"
    echo ""
    echo "Pmap输出字段:"
    echo "  Address   - 虚拟地址范围"
    echo "  Kbytes    - 大小（KB）"
    echo "  RSS       - 实际物理内存（Resident Set Size）"
    echo "  Dirty     - 脏页（已修改但未写回）"
    echo "  Mode      - 权限（r/w/x/s/p）"
    echo "  Mapping   - 映射名称或文件"
    echo ""
    echo "权限标志:"
    echo "  r - 可读 (Read)"
    echo "  w - 可写 (Write)"
    echo "  x - 可执行 (Execute)"
    echo "  s - 共享 (Shared)"
    echo "  p - 私有 (Private)"
    echo ""
    echo "Pmap选项:"
    echo "  -x  扩展格式（显示RSS、Dirty等）"
    echo "  -X  更详细的扩展格式"
    echo "  -d  设备格式"
    echo "  -q  静默模式（不显示头尾）"
    echo "  -p  显示完整路径"
    echo ""
    echo "相关文件:"
    echo "  /proc/<pid>/maps     - 内存映射（简单格式）"
    echo "  /proc/<pid>/smaps    - 详细内存映射"
    echo "  /proc/<pid>/status   - 进程状态和内存统计"
    echo ""
} | tee "$RESULTS_DIR/principles.txt"

# 编译测试程序
echo "步骤 3: 编译测试程序..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd "$PROGRAMS_DIR"

if [[ -f memory_layout.c ]]; then
    echo "编译: memory_layout.c"
    gcc -g -o memory_layout memory_layout.c

    if [[ $? -eq 0 ]]; then
        echo "  ✓ 编译成功: memory_layout"
    else
        echo "  ✗ 编译失败: memory_layout"
        exit 1
    fi
fi

echo ""

# 分析当前运行的进程
echo "步骤 4: 分析系统进程内存映射..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "系统进程内存映射分析"
    echo "========================================"
    echo ""

    # 选择一些常见进程
    PROCS=(systemd bash sshd)

    for proc in "${PROCS[@]}"; do
        pid=$(pgrep -o "$proc" 2>/dev/null)
        if [[ -n "$pid" ]]; then
            echo ""
            echo "进程: $proc (PID: $pid)"
            echo "----------------------------------------"

            # 基本pmap
            echo ""
            echo "基本映射 (pmap):"
            pmap "$pid" 2>/dev/null | head -20

            # 扩展格式
            echo ""
            echo "扩展格式 (pmap -x):"
            pmap -x "$pid" 2>/dev/null | head -20

            echo ""
            echo "总计信息:"
            pmap -x "$pid" 2>/dev/null | tail -5

            break  # 只分析第一个找到的进程
        fi
    done

} | tee "$RESULTS_DIR/system_processes.txt"

echo ""

# 分析测试程序
if [[ -f "$PROGRAMS_DIR/memory_layout" ]]; then
    echo "步骤 5: 运行并分析测试程序..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # 在后台运行测试程序
    "$PROGRAMS_DIR/memory_layout" < /dev/null > "$RESULTS_DIR/program_output.txt" 2>&1 &
    TEST_PID=$!

    sleep 2  # 等待程序分配内存

    if kill -0 "$TEST_PID" 2>/dev/null; then
        echo "测试程序运行中 (PID: $TEST_PID)"
        echo ""

        {
            echo "测试程序内存映射分析"
            echo "========================================"
            echo "PID: $TEST_PID"
            echo ""

            echo "1. 基本映射 (pmap):"
            echo "----------------------------------------"
            pmap "$TEST_PID"

            echo ""
            echo "2. 扩展格式 (pmap -x):"
            echo "----------------------------------------"
            pmap -x "$TEST_PID"

            echo ""
            echo "3. 详细格式 (pmap -X):"
            echo "----------------------------------------"
            pmap -X "$TEST_PID" 2>/dev/null || echo "pmap -X not supported"

            echo ""
            echo "4. /proc/$TEST_PID/maps:"
            echo "----------------------------------------"
            cat "/proc/$TEST_PID/maps"

            echo ""
            echo "5. /proc/$TEST_PID/smaps 摘要:"
            echo "----------------------------------------"
            if [[ -f "/proc/$TEST_PID/smaps" ]]; then
                # 提取总计信息
                awk '/^Rss:/ {rss+=$2} /^Pss:/ {pss+=$2} /^Shared_Clean:/ {sc+=$2}
                     /^Shared_Dirty:/ {sd+=$2} /^Private_Clean:/ {pc+=$2} /^Private_Dirty:/ {pd+=$2}
                     END {print "Total RSS: " rss " kB"; print "Total PSS: " pss " kB";
                          print "Shared Clean: " sc " kB"; print "Shared Dirty: " sd " kB";
                          print "Private Clean: " pc " kB"; print "Private Dirty: " pd " kB"}' \
                    "/proc/$TEST_PID/smaps"
            fi

            echo ""
            echo "6. /proc/$TEST_PID/status (内存相关):"
            echo "----------------------------------------"
            grep -E "^Vm|^Rss" "/proc/$TEST_PID/status"

        } | tee "$RESULTS_DIR/test_program_analysis.txt"

        # 终止测试程序
        kill "$TEST_PID" 2>/dev/null
        wait "$TEST_PID" 2>/dev/null
    else
        echo "✗ 测试程序未运行或已退出"
    fi
fi

echo ""

# 内存映射解析
{
    echo "内存映射字段解析"
    echo "========================================"
    echo ""

    echo "RSS (Resident Set Size):"
    echo "  - 实际占用的物理内存"
    echo "  - 包括共享库的共享部分"
    echo "  - 单位: KB"
    echo ""

    echo "PSS (Proportional Set Size):"
    echo "  - 按比例分摊的内存"
    echo "  - 共享内存按使用进程数分摊"
    echo "  - 更准确反映进程实际内存占用"
    echo ""

    echo "Dirty Pages (脏页):"
    echo "  - 已修改但未写回磁盘的页"
    echo "  - 私有脏页: 进程独占的已修改页"
    echo "  - 共享脏页: 多进程共享的已修改页"
    echo ""

    echo "Shared vs Private:"
    echo "  - Shared: 可被多个进程共享（如共享库）"
    echo "  - Private: 进程私有（如堆、栈）"
    echo ""

    echo "Clean vs Dirty:"
    echo "  - Clean: 未修改，可以直接丢弃重新从文件加载"
    echo "  - Dirty: 已修改，需要保存才能丢弃"
    echo ""

    echo "内存统计关系:"
    echo "  VmSize  = 虚拟内存大小（总分配）"
    echo "  VmRSS   = 实际物理内存"
    echo "  VmData  = 数据段大小"
    echo "  VmStk   = 栈大小"
    echo "  VmExe   = 代码段大小"
    echo "  VmLib   = 共享库大小"
    echo ""

} | tee "$RESULTS_DIR/field_explanation.txt"

# 常见分析场景
{
    echo "Pmap常见分析场景"
    echo "========================================"
    echo ""

    echo "1. 查找内存泄漏:"
    echo "   # 多次运行pmap查看堆增长"
    echo "   while true; do"
    echo "     pmap -x <pid> | grep heap"
    echo "     sleep 5"
    echo "   done"
    echo ""

    echo "2. 分析共享库占用:"
    echo "   pmap -x <pid> | grep '.so'"
    echo ""

    echo "3. 查看匿名内存映射:"
    echo "   pmap <pid> | grep 'anon'"
    echo ""

    echo "4. 对比两个进程的内存布局:"
    echo "   diff <(pmap <pid1>) <(pmap <pid2>)"
    echo ""

    echo "5. 统计总物理内存占用:"
    echo "   pmap -x <pid> | tail -1"
    echo ""

    echo "6. 查找大块内存分配:"
    echo "   pmap -x <pid> | awk '\$2 > 10240 {print}'"
    echo "   # 显示大于10MB的映射"
    echo ""

    echo "7. 监控内存变化:"
    echo "   watch -n 1 'pmap -x <pid> | tail'"
    echo ""

    echo "8. 生成内存映射图:"
    echo "   pmap -X <pid> > memory_map.txt"
    echo ""

} | tee "$RESULTS_DIR/usage_examples.txt"

# 与其他工具对比
{
    echo "内存分析工具对比"
    echo "========================================"
    echo ""

    echo "Pmap vs /proc/maps:"
    echo "  pmap:"
    echo "    - 更友好的格式"
    echo "    - 显示大小统计"
    echo "    - 扩展信息（RSS、Dirty）"
    echo ""
    echo "  /proc/maps:"
    echo "    - 原始格式"
    echo "    - 更详细的权限信息"
    echo "    - 可编程处理"
    echo ""

    echo "Pmap vs Valgrind:"
    echo "  pmap:"
    echo "    - 静态快照"
    echo "    - 无性能影响"
    echo "    - 显示内存布局"
    echo ""
    echo "  Valgrind:"
    echo "    - 动态分析"
    echo "    - 检测内存错误"
    echo "    - 性能影响大"
    echo ""

    echo "Pmap vs top/ps:"
    echo "  pmap:"
    echo "    - 详细内存映射"
    echo "    - 各区域大小"
    echo "    - 单个进程深入分析"
    echo ""
    echo "  top/ps:"
    echo "    - 总体内存统计"
    echo "    - 多进程对比"
    echo "    - 实时监控"
    echo ""

    echo "选择建议:"
    echo "  - 查看内存布局: pmap"
    echo "  - 检测内存泄漏: Valgrind + pmap"
    echo "  - 监控内存使用: top/htop"
    echo "  - 深入分析: pmap + /proc/smaps"
    echo ""

} | tee "$RESULTS_DIR/tool_comparison.txt"

# 生成报告
{
    echo "Pmap内存映射分析测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo ""
    echo "分析内容:"
    echo "  ✓ 系统进程内存映射"
    echo "  ✓ 测试程序内存布局"
    echo "  ✓ /proc文件系统分析"
    echo "  ✓ 内存映射字段解析"
    echo ""
    echo "内存区域类型:"
    echo "  - 代码段 (Text)"
    echo "  - 数据段 (Data/BSS)"
    echo "  - 堆 (Heap)"
    echo "  - 栈 (Stack)"
    echo "  - 共享库 (.so)"
    echo "  - 匿名映射 (Anonymous)"
    echo "  - 文件映射 (File-backed)"
    echo ""
    echo "结果文件:"
    echo "  测试原理: $RESULTS_DIR/principles.txt"
    echo "  系统进程: $RESULTS_DIR/system_processes.txt"
    echo "  测试程序: $RESULTS_DIR/test_program_analysis.txt"
    echo "  字段说明: $RESULTS_DIR/field_explanation.txt"
    echo "  使用示例: $RESULTS_DIR/usage_examples.txt"
    echo "  工具对比: $RESULTS_DIR/tool_comparison.txt"
    echo "  程序输出: $RESULTS_DIR/program_output.txt"
    echo ""
    echo "使用建议:"
    echo "  1. 定期pmap检查内存增长"
    echo "  2. 关注堆段大小变化"
    echo "  3. 检查异常的匿名映射"
    echo "  4. 分析共享库占用"
    echo "  5. 配合Valgrind使用"
    echo ""

} | tee "$RESULTS_DIR/report.txt"

echo ""
echo "========================================"
echo "测试完成"
echo "========================================"
echo ""
echo "✓ Pmap内存映射分析测试完成"
echo ""
echo "查看报告: cat $RESULTS_DIR/report.txt"
echo "查看详细分析: cat $RESULTS_DIR/test_program_analysis.txt"
echo ""
echo "结果目录: $RESULTS_DIR"
echo ""
