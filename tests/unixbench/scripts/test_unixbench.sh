#!/bin/bash
# test_unixbench.sh - UnixBench综合性能测试
# UnixBench是一个综合性能基准测试套件，测试Unix/Linux系统的多方面性能

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNIXBENCH_DIR="$SCRIPT_DIR/../UnixBench"
RESULTS_DIR="$SCRIPT_DIR/../results/unixbench-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "UnixBench 综合性能测试"
echo "========================================"
echo ""

mkdir -p "$RESULTS_DIR"

# 检查UnixBench是否安装
echo "步骤 1: 检查UnixBench安装..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ ! -d "$UNIXBENCH_DIR" ]]; then
    echo "UnixBench未安装，开始下载和安装..."
    echo ""

    cd "$SCRIPT_DIR/.."

    # 下载UnixBench
    if command -v git &> /dev/null; then
        echo "使用git克隆UnixBench..."
        git clone https://github.com/kdlucas/byte-unixbench.git UnixBench
    else
        echo "使用wget下载UnixBench..."
        wget https://github.com/kdlucas/byte-unixbench/archive/refs/heads/master.zip
        unzip master.zip
        mv byte-unixbench-master UnixBench
        rm master.zip
    fi

    if [[ $? -ne 0 ]]; then
        echo "✗ UnixBench下载失败"
        exit 1
    fi

    echo "✓ UnixBench下载完成"
else
    echo "✓ UnixBench已安装"
fi

echo ""

# 检查编译环境
echo "步骤 2: 检查编译环境..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

MISSING_DEPS=()

if ! command -v gcc &> /dev/null; then
    MISSING_DEPS+=("gcc")
fi

if ! command -v make &> /dev/null; then
    MISSING_DEPS+=("make")
fi

if ! command -v perl &> /dev/null; then
    MISSING_DEPS+=("perl")
fi

if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
    echo "✗ 缺少依赖: ${MISSING_DEPS[*]}"
    echo ""
    echo "安装方法:"
    echo "  Ubuntu/Debian: sudo apt-get install build-essential perl"
    echo "  RHEL/CentOS:   sudo yum install gcc make perl"
    echo "  Fedora:        sudo dnf install gcc make perl"
    exit 1
fi

echo "✓ 编译环境完整"
echo ""

# UnixBench原理说明
echo "步骤 3: UnixBench测试原理..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "UnixBench 综合性能测试原理"
    echo "========================================"
    echo ""
    echo "UnixBench是什么:"
    echo "  - 源自1983年的BYTE杂志基准测试"
    echo "  - 综合评估Unix/Linux系统性能"
    echo "  - 提供统一的性能指数（Index Score）"
    echo "  - 业界广泛使用的标准基准测试"
    echo ""
    echo "测试类别:"
    echo ""
    echo "1. 系统性能测试 (System Benchmarks)"
    echo "   - Dhrystone 2: CPU整数运算性能"
    echo "   - Whetstone: CPU浮点运算性能"
    echo "   - Execl Throughput: 进程执行吞吐量"
    echo "   - File Copy: 文件拷贝性能"
    echo "   - Pipe Throughput: 管道通信吞吐量"
    echo "   - Pipe-based Context Switching: 基于管道的上下文切换"
    echo "   - Process Creation: 进程创建性能"
    echo "   - Shell Scripts: Shell脚本执行性能"
    echo "   - System Call Overhead: 系统调用开销"
    echo ""
    echo "2. 图形性能测试 (2D Graphics)"
    echo "   - 2D graphics tests (需要X11)"
    echo ""
    echo "3. 3D图形测试 (3D Graphics)"
    echo "   - 3D graphics tests (需要OpenGL)"
    echo ""
    echo "测试模式:"
    echo "  - 单核测试: 测试单个CPU核心性能"
    echo "  - 多核测试: 测试多核并行性能"
    echo "  - 全面测试: 单核+多核完整测试"
    echo ""
    echo "性能指数 (Index Score):"
    echo "  - 基准系统: SPARCstation 20-61 (Index = 10.0)"
    echo "  - 现代系统: 通常 Index = 1000-5000"
    echo "  - 高性能服务器: Index > 5000"
    echo ""
    echo "应用场景:"
    echo "  - 系统性能评估和对比"
    echo "  - 硬件选型决策"
    echo "  - 虚拟化性能分析"
    echo "  - 性能回归测试"
    echo "  - 优化效果验证"
    echo ""
} | tee "$RESULTS_DIR/principles.txt"

# 编译UnixBench
echo "步骤 4: 编译UnixBench..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd "$UNIXBENCH_DIR/UnixBench"

if [[ ! -f "pgms/dhry2reg" ]] || [[ ! -f "pgms/whetstone-double" ]]; then
    echo "编译UnixBench测试程序..."
    make clean > /dev/null 2>&1
    make 2>&1 | tee "$RESULTS_DIR/compile.log"

    if [[ $? -eq 0 ]]; then
        echo "✓ 编译成功"
    else
        echo "✗ 编译失败，查看日志: $RESULTS_DIR/compile.log"
        exit 1
    fi
else
    echo "✓ UnixBench已编译"
fi

echo ""

# 收集系统信息
echo "步骤 5: 收集系统信息..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "系统信息"
    echo "========================================"
    echo ""

    echo "主机信息:"
    echo "  主机名: $(hostname)"
    echo "  操作系统: $(uname -s) $(uname -r)"
    if command -v lsb_release &> /dev/null; then
        echo "  发行版: $(lsb_release -d | cut -f2)"
    fi
    echo "  架构: $(uname -m)"
    echo ""

    echo "CPU信息:"
    if [[ -f /proc/cpuinfo ]]; then
        CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
        CPU_COUNT=$(grep -c processor /proc/cpuinfo)
        CPU_CORES=$(grep "cpu cores" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
        CPU_MHZ=$(grep "cpu MHz" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)

        echo "  型号: $CPU_MODEL"
        echo "  逻辑核心数: $CPU_COUNT"
        echo "  物理核心数: ${CPU_CORES:-N/A}"
        echo "  当前频率: ${CPU_MHZ:-N/A} MHz"
    fi

    if command -v lscpu &> /dev/null; then
        echo ""
        echo "  缓存信息:"
        lscpu | grep -i cache | sed 's/^/    /'
    fi
    echo ""

    echo "内存信息:"
    if [[ -f /proc/meminfo ]]; then
        MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        MEM_FREE=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
        echo "  总内存: $((MEM_TOTAL / 1024)) MB"
        echo "  可用内存: $((MEM_FREE / 1024)) MB"
    fi
    echo ""

    echo "磁盘信息:"
    df -h / | tail -1 | awk '{print "  根分区: " $2 " (使用率: " $5 ")"}'
    echo ""

    echo "负载信息:"
    uptime | awk '{print "  负载: " $(NF-2) " " $(NF-1) " " $NF}'
    echo ""

} | tee "$RESULTS_DIR/sysinfo.txt"

# 运行UnixBench测试
echo "步骤 6: 运行UnixBench测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "测试模式选择:"
echo "  1) 快速测试 (仅单核)"
echo "  2) 标准测试 (单核+多核)"
echo "  3) 完整测试 (所有测试项)"
echo ""

# 默认运行标准测试
TEST_MODE="${1:-2}"

case $TEST_MODE in
    1)
        echo "运行快速测试（单核）..."
        TEST_ARGS="-c 1"
        TEST_DESC="快速单核测试"
        ;;
    2)
        echo "运行标准测试（单核+多核）..."
        TEST_ARGS=""
        TEST_DESC="标准测试"
        ;;
    3)
        echo "运行完整测试（所有项目）..."
        TEST_ARGS="-i 5"  # 5次迭代
        TEST_DESC="完整测试"
        ;;
    *)
        echo "未知测试模式，使用标准测试"
        TEST_ARGS=""
        TEST_DESC="标准测试"
        ;;
esac

echo ""
echo "开始测试 (预计耗时: 5-30分钟)..."
echo "测试过程中请勿运行其他高负载程序"
echo ""

# 运行UnixBench
./Run $TEST_ARGS 2>&1 | tee "$RESULTS_DIR/unixbench_output.txt"

if [[ $? -eq 0 ]]; then
    echo ""
    echo "✓ UnixBench测试完成"
else
    echo ""
    echo "✗ UnixBench测试失败"
    exit 1
fi

# 提取结果
echo ""
echo "步骤 7: 提取测试结果..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 找到最新的结果文件
LATEST_RESULT=$(ls -t results/*.log 2>/dev/null | head -1)

if [[ -n "$LATEST_RESULT" ]]; then
    cp "$LATEST_RESULT" "$RESULTS_DIR/result.log"
    echo "✓ 结果已保存到: $RESULTS_DIR/result.log"

    # 提取关键指标
    {
        echo "UnixBench测试结果摘要"
        echo "========================================"
        echo ""
        echo "测试描述: $TEST_DESC"
        echo "测试时间: $(date)"
        echo ""

        # 提取系统基准测试结果
        if grep -q "System Benchmarks Index Score" "$RESULTS_DIR/result.log"; then
            echo "系统基准测试 (System Benchmarks):"
            echo "----------------------------------------"
            grep -A 20 "System Benchmarks Index Values" "$RESULTS_DIR/result.log" | \
                grep -E "Dhrystone|Whetstone|Execl|File Copy|Pipe|Process|System Call|Shell" | \
                sed 's/^/  /'
            echo ""

            echo "性能指数 (Index Score):"
            echo "----------------------------------------"
            grep "System Benchmarks Index Score" "$RESULTS_DIR/result.log" | sed 's/^/  /'
            echo ""
        fi

    } | tee "$RESULTS_DIR/summary.txt"

    echo ""
    echo "✓ 结果摘要已生成"
else
    echo "⚠ 未找到测试结果文件"
fi

echo ""

# 生成详细分析
cd "$SCRIPT_DIR"
if [[ -f "analyze_unixbench.sh" ]]; then
    echo "步骤 8: 生成详细分析报告..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    ./analyze_unixbench.sh "$RESULTS_DIR"
    echo ""
fi

# 生成最终报告
{
    echo "UnixBench测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo "测试模式: $TEST_DESC"
    echo ""
    echo "系统信息:"
    echo "  CPU: $CPU_MODEL"
    echo "  核心数: $CPU_COUNT"
    echo "  内存: $((MEM_TOTAL / 1024)) MB"
    echo ""
    echo "测试结果文件:"
    echo "  完整日志: $RESULTS_DIR/result.log"
    echo "  测试输出: $RESULTS_DIR/unixbench_output.txt"
    echo "  结果摘要: $RESULTS_DIR/summary.txt"
    if [[ -f "$RESULTS_DIR/detailed_analysis.txt" ]]; then
        echo "  详细分析: $RESULTS_DIR/detailed_analysis.txt"
    fi
    echo ""
    echo "性能评估:"
    if [[ -f "$RESULTS_DIR/result.log" ]]; then
        SCORE=$(grep "System Benchmarks Index Score" "$RESULTS_DIR/result.log" | tail -1 | awk '{print $NF}')
        if [[ -n "$SCORE" ]]; then
            echo "  总体性能指数: $SCORE"

            # 性能等级评估
            if (( $(echo "$SCORE > 5000" | bc -l) )); then
                echo "  性能等级: 优秀 (高性能服务器级别)"
            elif (( $(echo "$SCORE > 3000" | bc -l) )); then
                echo "  性能等级: 良好 (主流服务器级别)"
            elif (( $(echo "$SCORE > 1500" | bc -l) )); then
                echo "  性能等级: 一般 (普通工作站级别)"
            else
                echo "  性能等级: 较低 (入门级或虚拟化环境)"
            fi
        fi
    fi
    echo ""
    echo "使用建议:"
    echo "  - 查看完整结果: cat $RESULTS_DIR/result.log"
    echo "  - 查看详细分析: cat $RESULTS_DIR/detailed_analysis.txt"
    echo "  - 对比测试: 保存本次结果作为baseline，优化后重新测试对比"
    echo ""

} | tee "$RESULTS_DIR/report.txt"

echo ""
echo "========================================"
echo "测试完成"
echo "========================================"
echo ""
echo "✓ UnixBench综合性能测试完成"
echo ""
echo "查看报告: cat $RESULTS_DIR/report.txt"
echo "查看详细结果: cat $RESULTS_DIR/result.log"
if [[ -f "$RESULTS_DIR/detailed_analysis.txt" ]]; then
    echo "查看详细解读: cat $RESULTS_DIR/detailed_analysis.txt"
fi
echo ""
echo "结果目录: $RESULTS_DIR"
echo ""
