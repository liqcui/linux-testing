#!/bin/bash
# test_memtester.sh - memtester内存测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results/memtester-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "Memtester 内存测试"
echo "========================================"
echo ""

mkdir -p "$RESULTS_DIR"

# 检查memtester是否安装
echo "步骤 1: 检查memtester安装..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ! command -v memtester &> /dev/null; then
    echo "✗ memtester未安装"
    echo ""
    echo "安装方法:"
    echo "  Ubuntu/Debian: sudo apt-get install memtester"
    echo "  RHEL/CentOS:   sudo yum install memtester"
    echo "  Fedora:        sudo dnf install memtester"
    echo ""
    echo "或从源码编译:"
    echo "  wget http://pyropus.ca/software/memtester/old-versions/memtester-4.5.1.tar.gz"
    echo "  tar xzf memtester-4.5.1.tar.gz"
    echo "  cd memtester-4.5.1"
    echo "  make"
    echo "  sudo make install"
    exit 1
fi

MEMTESTER_VERSION=$(memtester 2>&1 | head -1)
echo "✓ memtester已安装: $MEMTESTER_VERSION"
echo ""

# Memtester原理说明
echo "步骤 2: Memtester测试原理..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "Memtester 内存测试原理"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  memtester是一个用户空间内存测试工具"
    echo "  用于检测RAM硬件故障和问题"
    echo ""
    echo "测试算法:"
    echo ""
    echo "1. Stuck Address Test (地址线测试)"
    echo "   - 检测地址线是否卡死"
    echo "   - 确保每个内存地址都是唯一的"
    echo "   - 检测地址线短路或断路"
    echo ""
    echo "2. Random Value Test (随机值测试)"
    echo "   - 写入随机数据并验证"
    echo "   - 检测数据位错误"
    echo ""
    echo "3. XOR Comparison (异或比较)"
    echo "   - 使用XOR模式测试"
    echo "   - 检测相邻位干扰"
    echo ""
    echo "4. SUB Comparison (减法比较)"
    echo "   - 使用减法模式测试"
    echo ""
    echo "5. MUL Comparison (乘法比较)"
    echo "   - 使用乘法模式测试"
    echo ""
    echo "6. DIV Comparison (除法比较)"
    echo "   - 使用除法模式测试"
    echo ""
    echo "7. OR Comparison (或比较)"
    echo "   - 使用OR模式测试"
    echo ""
    echo "8. AND Comparison (与比较)"
    echo "   - 使用AND模式测试"
    echo ""
    echo "9. Sequential Increment (顺序递增)"
    echo "   - 顺序写入递增值"
    echo "   - 检测数据路径问题"
    echo ""
    echo "10. Solid Bits (固定位模式)"
    echo "    - 全0和全1测试"
    echo "    - 检测单元格是否卡死"
    echo ""
    echo "11. Block Sequential (块顺序)"
    echo "    - 块级顺序测试"
    echo ""
    echo "12. Checkerboard (棋盘模式)"
    echo "    - 0x55555555和0xAAAAAAAA交替"
    echo "    - 检测相邻位干扰"
    echo ""
    echo "13. Bit Spread (位扩散)"
    echo "    - 单个位在不同位置"
    echo ""
    echo "14. Bit Flip (位翻转)"
    echo "    - 翻转单个位"
    echo ""
    echo "15. Walking Ones (移动的1)"
    echo "    - 单个1在所有位位置移动"
    echo ""
    echo "16. Walking Zeros (移动的0)"
    echo "    - 单个0在所有位位置移动"
    echo ""
    echo "测试特点:"
    echo "  - 用户空间测试（不需要内核模块）"
    echo "  - 测试已分配的物理内存"
    echo "  - 可以指定测试大小和迭代次数"
    echo "  - 检测硬件故障，非性能测试"
    echo ""
    echo "典型故障:"
    echo "  - 地址线故障（某些地址无法访问）"
    echo "  - 数据线故障（某些位总是0或1）"
    echo "  - 内存单元故障（单元格损坏）"
    echo "  - 刷新问题（数据随时间消失）"
    echo "  - 相邻位干扰"
    echo ""
    echo "使用场景:"
    echo "  - 新硬件验收测试"
    echo "  - 系统不稳定诊断"
    echo "  - 超频稳定性测试"
    echo "  - 内存故障排查"
    echo "  - 长期压力测试"
    echo ""
} | tee "$RESULTS_DIR/principles.txt"

# 系统信息
echo "步骤 3: 收集系统信息..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "系统信息"
    echo "========================================"
    echo ""

    echo "操作系统:"
    echo "  $(uname -s) $(uname -r)"

    echo ""
    echo "CPU信息:"
    CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    CPU_COUNT=$(grep -c processor /proc/cpuinfo)
    echo "  型号: $CPU_MODEL"
    echo "  核心数: $CPU_COUNT"

    echo ""
    echo "内存信息:"
    MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    MEM_FREE=$(grep MemFree /proc/meminfo | awk '{print $2}')
    MEM_AVAIL=$(grep MemAvailable /proc/meminfo | awk '{print $2}')

    echo "  总内存: $((MEM_TOTAL / 1024)) MB"
    echo "  空闲内存: $((MEM_FREE / 1024)) MB"
    echo "  可用内存: $((MEM_AVAIL / 1024)) MB"

    echo ""
    echo "内存详细信息 (dmidecode):"
    if command -v dmidecode &> /dev/null && [[ $EUID -eq 0 ]]; then
        dmidecode -t memory | grep -E "Size:|Speed:|Type:|Manufacturer:|Part Number:" | head -20
    else
        echo "  需要root权限查看详细信息"
    fi

    echo ""
    echo "当前内存使用:"
    free -h

} | tee "$RESULTS_DIR/sysinfo.txt"

echo ""

# 计算测试大小
echo "步骤 4: 计算测试参数..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 可用内存（MB）
AVAIL_MB=$((MEM_AVAIL / 1024))

# 测试大小建议（可用内存的50-80%）
TEST_SIZE_50=$((AVAIL_MB / 2))
TEST_SIZE_80=$((AVAIL_MB * 8 / 10))

echo "可用内存: ${AVAIL_MB} MB"
echo ""
echo "推荐测试大小:"
echo "  快速测试: ${TEST_SIZE_50} MB (50%可用内存)"
echo "  标准测试: ${TEST_SIZE_80} MB (80%可用内存)"
echo ""

# 询问用户选择测试大小（如果交互式）
if [[ -t 0 ]]; then
    read -p "请输入测试大小(MB) [默认: ${TEST_SIZE_50}]: " USER_SIZE
    if [[ -n "$USER_SIZE" ]]; then
        TEST_SIZE=$USER_SIZE
    else
        TEST_SIZE=$TEST_SIZE_50
    fi

    read -p "请输入迭代次数 [默认: 1]: " USER_ITER
    if [[ -n "$USER_ITER" ]]; then
        ITERATIONS=$USER_ITER
    else
        ITERATIONS=1
    fi
else
    # 非交互式，使用默认值
    TEST_SIZE=$TEST_SIZE_50
    ITERATIONS=1
fi

echo ""
echo "测试配置:"
echo "  测试大小: ${TEST_SIZE} MB"
echo "  迭代次数: ${ITERATIONS}"
echo ""

# 运行memtester
echo "步骤 5: 运行memtester测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "开始测试 (这可能需要较长时间)..."
echo "测试命令: memtester ${TEST_SIZE}M ${ITERATIONS}"
echo ""

# 运行测试并捕获输出
START_TIME=$(date +%s)

if [[ $EUID -eq 0 ]]; then
    # root用户，使用mlock锁定内存
    memtester ${TEST_SIZE}M ${ITERATIONS} 2>&1 | tee "$RESULTS_DIR/memtester.txt"
else
    # 普通用户
    echo "提示: 以root运行可以锁定内存(mlock)获得更准确的结果"
    memtester ${TEST_SIZE}M ${ITERATIONS} 2>&1 | tee "$RESULTS_DIR/memtester.txt"
fi

TEST_RESULT=$?
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "测试耗时: ${DURATION} 秒 ($((DURATION / 60)) 分钟)"
echo ""

# 分析结果
echo "步骤 6: 分析测试结果..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "Memtester测试结果分析"
    echo "========================================"
    echo ""

    if [[ $TEST_RESULT -eq 0 ]]; then
        if grep -q "FAILURE" "$RESULTS_DIR/memtester.txt"; then
            echo "测试状态: ✗ 检测到内存错误"
            echo ""
            echo "错误详情:"
            grep "FAILURE" "$RESULTS_DIR/memtester.txt"
            echo ""
            echo "建议:"
            echo "  1. 重新运行测试确认错误"
            echo "  2. 检查内存是否松动"
            echo "  3. 尝试移除并重新插入内存条"
            echo "  4. 逐条测试内存条（移除其他条）"
            echo "  5. 检查BIOS中的内存设置"
            echo "  6. 考虑更换故障内存"
        else
            echo "测试状态: ✓ 所有测试通过"
            echo ""
            echo "测试统计:"
            grep -E "ok$" "$RESULTS_DIR/memtester.txt" | wc -l | awk '{print "  通过测试: " $1 " 项"}'
            echo ""
            echo "结论: 内存工作正常，未检测到硬件故障"
        fi
    else
        echo "测试状态: ✗ 测试异常终止"
        echo ""
        echo "可能原因:"
        echo "  - 系统内存不足"
        echo "  - 测试被中断"
        echo "  - 权限问题"
    fi

    echo ""
    echo "测试参数:"
    echo "  测试大小: ${TEST_SIZE} MB"
    echo "  迭代次数: ${ITERATIONS}"
    echo "  测试时长: ${DURATION} 秒"

} | tee "$RESULTS_DIR/analysis.txt"

# 测试详情
{
    echo "测试算法执行情况"
    echo "========================================"
    echo ""

    # 提取各测试结果
    for test in "Stuck Address" "Random Value" "Compare XOR" "Compare SUB" \
                "Compare MUL" "Compare DIV" "Compare OR" "Compare AND" \
                "Sequential Increment" "Solid Bits" "Block Sequential" \
                "Checkerboard" "Bit Spread" "Bit Flip" "Walking Ones" "Walking Zeros"; do

        if grep -q "$test" "$RESULTS_DIR/memtester.txt"; then
            result=$(grep "$test" "$RESULTS_DIR/memtester.txt" | tail -1 | awk '{print $NF}')
            printf "%-25s : %s\n" "$test" "$result"
        fi
    done

} | tee "$RESULTS_DIR/test_details.txt"

echo ""

# 使用建议
{
    echo "Memtester使用建议"
    echo "========================================"
    echo ""

    echo "测试大小建议:"
    echo "  - 快速测试: 可用内存的50% (几分钟)"
    echo "  - 标准测试: 可用内存的80% (10-30分钟)"
    echo "  - 全面测试: 总内存的90% (需root, 30-60分钟)"
    echo ""

    echo "迭代次数建议:"
    echo "  - 快速验证: 1次迭代"
    echo "  - 常规测试: 2-3次迭代"
    echo "  - 压力测试: 10+次迭代（几小时）"
    echo "  - 长期稳定性: 连续运行24-72小时"
    echo ""

    echo "以root运行的优势:"
    echo "  - 使用mlock()锁定内存页"
    echo "  - 防止测试内存被swap"
    echo "  - 获得更准确的测试结果"
    echo "  - 可以测试更大的内存区域"
    echo ""
    echo "运行示例:"
    echo "  # 快速测试512MB, 1次迭代"
    echo "  sudo memtester 512M 1"
    echo ""
    echo "  # 标准测试2GB, 3次迭代"
    echo "  sudo memtester 2G 3"
    echo ""
    echo "  # 长期测试4GB, 持续运行"
    echo "  sudo memtester 4G 100"
    echo ""

    echo "故障排查流程:"
    echo "  1. 运行memtester初步测试"
    echo "  2. 如果发现错误，重启系统再次测试"
    echo "  3. 确认错误后，关机并重新插拔内存"
    echo "  4. 逐条测试内存（单条插入）"
    echo "  5. 更换插槽测试"
    echo "  6. 检查BIOS内存设置（频率、时序）"
    echo "  7. 降低内存频率测试"
    echo "  8. 更换确认故障的内存条"
    echo ""

    echo "内存问题的常见症状:"
    echo "  - 系统随机重启或崩溃"
    echo "  - 蓝屏/内核panic"
    echo "  - 应用程序频繁崩溃"
    echo "  - 文件损坏"
    echo "  - 编译错误（随机）"
    echo "  - 图形显示异常"
    echo ""

} | tee "$RESULTS_DIR/usage_guide.txt"

# 生成报告
{
    echo "Memtester内存测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo ""
    echo "系统信息:"
    echo "  操作系统: $(uname -s) $(uname -r)"
    echo "  CPU: $CPU_MODEL"
    echo "  总内存: $((MEM_TOTAL / 1024)) MB"
    echo "  可用内存: $((MEM_AVAIL / 1024)) MB"
    echo ""
    echo "测试配置:"
    echo "  测试大小: ${TEST_SIZE} MB"
    echo "  迭代次数: ${ITERATIONS}"
    echo "  测试时长: ${DURATION} 秒 ($((DURATION / 60)) 分钟)"
    echo "  执行权限: $(if [[ $EUID -eq 0 ]]; then echo 'root'; else echo '普通用户'; fi)"
    echo ""

    if [[ $TEST_RESULT -eq 0 ]]; then
        if grep -q "FAILURE" "$RESULTS_DIR/memtester.txt"; then
            echo "测试结果: ✗ 检测到内存错误"
            echo ""
            echo "警告: 系统内存可能存在硬件故障"
            echo "建议: 尽快排查并更换故障内存"
        else
            echo "测试结果: ✓ 所有测试通过"
            echo ""
            echo "结论: 未检测到内存硬件故障"
        fi
    else
        echo "测试结果: ✗ 测试异常终止"
    fi

    echo ""
    echo "结果文件:"
    echo "  测试原理: $RESULTS_DIR/principles.txt"
    echo "  系统信息: $RESULTS_DIR/sysinfo.txt"
    echo "  测试输出: $RESULTS_DIR/memtester.txt"
    echo "  结果分析: $RESULTS_DIR/analysis.txt"
    echo "  测试详情: $RESULTS_DIR/test_details.txt"
    echo "  使用指南: $RESULTS_DIR/usage_guide.txt"
    echo ""

} | tee "$RESULTS_DIR/report.txt"

echo ""
echo "========================================"
echo "测试完成"
echo "========================================"
echo ""

if [[ $TEST_RESULT -eq 0 ]]; then
    if grep -q "FAILURE" "$RESULTS_DIR/memtester.txt"; then
        echo "⚠ 警告: 检测到内存错误！"
        echo ""
        echo "建议措施:"
        echo "  1. 立即备份重要数据"
        echo "  2. 重新运行测试确认"
        echo "  3. 排查故障内存条"
        echo "  4. 更换故障硬件"
    else
        echo "✓ 内存测试通过，未检测到硬件故障"
    fi
else
    echo "✗ 测试异常，请检查系统状态"
fi

echo ""
echo "结果目录: $RESULTS_DIR"
echo "详细报告: cat $RESULTS_DIR/report.txt"
echo ""
