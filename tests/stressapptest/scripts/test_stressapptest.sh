#!/bin/bash
# test_stressapptest.sh - StressAppTest内存稳定性测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results/stressapptest-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "StressAppTest 内存稳定性测试"
echo "========================================"
echo ""

mkdir -p "$RESULTS_DIR"

# 检查stressapptest
echo "步骤 1: 检查StressAppTest安装..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ! command -v stressapptest &> /dev/null; then
    echo "StressAppTest未安装，开始安装..."
    echo ""

    # 检测系统类型
    if [[ -f /etc/debian_version ]]; then
        echo "检测到Debian/Ubuntu系统"
        sudo apt-get update
        sudo apt-get install -y stressapptest
    elif [[ -f /etc/redhat-release ]]; then
        echo "检测到RHEL/CentOS/Fedora系统"
        sudo yum install -y epel-release
        sudo yum install -y stressapptest
    elif [[ "$(uname -s)" == "Darwin" ]]; then
        echo "检测到macOS系统"
        if command -v brew &> /dev/null; then
            brew install stressapptest
        else
            echo "请先安装Homebrew: https://brew.sh/"
            exit 1
        fi
    else
        echo "✗ 不支持的系统，请手动安装stressapptest"
        echo ""
        echo "源码安装:"
        echo "  git clone https://github.com/stressapptest/stressapptest.git"
        echo "  cd stressapptest"
        echo "  ./configure"
        echo "  make"
        echo "  sudo make install"
        exit 1
    fi

    if [[ $? -eq 0 ]]; then
        echo "✓ 安装成功"
    else
        echo "✗ 安装失败"
        exit 1
    fi
else
    echo "✓ StressAppTest已安装"
fi

echo ""
stressapptest --version 2>&1 | head -1
echo ""

# 系统信息收集
echo "步骤 2: 收集系统信息..."
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
    if [[ -f /proc/cpuinfo ]]; then
        CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
        CPU_CORES=$(nproc)
        echo "  型号: $CPU_MODEL"
        echo "  核心数: $CPU_CORES"
    else
        CPU_MODEL=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
        CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null)
        echo "  型号: $CPU_MODEL"
        echo "  核心数: $CPU_CORES"
    fi
    echo ""

    echo "内存信息:"
    if [[ -f /proc/meminfo ]]; then
        MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        MEM_TOTAL_GB=$((MEM_TOTAL / 1024 / 1024))
        MEM_AVAILABLE=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
        MEM_AVAILABLE_GB=$((MEM_AVAILABLE / 1024 / 1024))
        echo "  总内存: ${MEM_TOTAL_GB} GB"
        echo "  可用内存: ${MEM_AVAILABLE_GB} GB"
    else
        MEM_TOTAL=$(sysctl -n hw.memsize 2>/dev/null)
        MEM_TOTAL_GB=$((MEM_TOTAL / 1024 / 1024 / 1024))
        echo "  总内存: ${MEM_TOTAL_GB} GB"
    fi
    echo ""

    # 内存详细信息
    if command -v dmidecode &> /dev/null && [[ $(id -u) -eq 0 ]]; then
        echo "内存条详细信息:"
        dmidecode -t memory | grep -E "Size:|Speed:|Type:|Manufacturer:" | grep -v "No Module Installed"
        echo ""
    fi

} | tee "$RESULTS_DIR/sysinfo.txt"

# StressAppTest测试原理
{
    echo "StressAppTest测试原理"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  - 内存硬件稳定性验证"
    echo "  - 内存错误检测（位翻转、行锤攻击等）"
    echo "  - 系统在极端负载下的可靠性"
    echo "  - 超频配置验证"
    echo "  - 服务器验收测试"
    echo ""
    echo "测试原理:"
    echo ""
    echo "1. 内存填充测试"
    echo "   - 分配大量内存（可达物理内存的95%）"
    echo "   - 使用多种数据模式填充"
    echo "   - 持续读写验证数据完整性"
    echo ""
    echo "2. 多线程压力"
    echo "   - 每个CPU核心一个线程"
    echo "   - 并发内存访问"
    echo "   - 检测内存总线竞争问题"
    echo ""
    echo "3. 数据完整性检查"
    echo "   - 写入已知模式"
    echo "   - 持续读取并验证"
    echo "   - 检测位翻转、数据损坏"
    echo ""
    echo "4. 温度压力测试"
    echo "   - 高强度计算产生热量"
    echo "   - 验证散热系统有效性"
    echo "   - 检测温度相关的内存错误"
    echo ""
    echo "关键参数:"
    echo "  -s: 测试时长（秒）"
    echo "  -M: 内存使用百分比（0-100）"
    echo "  -m: 线程数（通常等于CPU核心数）"
    echo "  -W: 启用更严格的内存检查"
    echo "  -C: 内存复制测试大小（MB）"
    echo "  -d: 使用磁盘文件增加压力"
    echo "  --pause_duration: 暂停检查间隔"
    echo "  --pause_delay: 暂停之间的延迟"
    echo ""
    echo "典型测试场景:"
    echo "  快速测试: 300秒（5分钟）"
    echo "  标准测试: 3600秒（1小时）"
    echo "  深度测试: 86400秒（24小时）"
    echo "  验收测试: 259200秒（72小时）"
    echo ""
} | tee "$RESULTS_DIR/principles.txt"

echo ""

# 获取CPU核心数和内存信息
CPU_CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

if [[ -f /proc/meminfo ]]; then
    TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    AVAILABLE_MEM_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
else
    TOTAL_MEM=$(sysctl -n hw.memsize 2>/dev/null || echo $((8 * 1024 * 1024 * 1024)))
    TOTAL_MEM_KB=$((TOTAL_MEM / 1024))
    AVAILABLE_MEM_KB=$TOTAL_MEM_KB
fi

# 测试1: 快速内存测试（5分钟）
echo "步骤 3: 快速内存测试（5分钟）..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "快速内存测试（5分钟）"
    echo "========================================"
    echo ""
    echo "测试参数:"
    echo "  时长: 5分钟"
    echo "  内存使用: 80%"
    echo "  线程数: $CPU_CORES"
    echo ""
} | tee "$RESULTS_DIR/quick_test.txt"

echo "开始测试..."
START_TIME=$(date +%s)

stressapptest -s 300 -M 80 -m $CPU_CORES -W 2>&1 | tee -a "$RESULTS_DIR/quick_test.txt"
QUICK_RESULT=$?

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

{
    echo ""
    echo "测试结果:"
    echo "  实际运行时间: ${DURATION}秒"
    if [[ $QUICK_RESULT -eq 0 ]]; then
        echo "  状态: ✓ PASS - 未检测到内存错误"
    else
        echo "  状态: ✗ FAIL - 检测到内存错误"
        echo "  退出码: $QUICK_RESULT"
    fi
    echo ""
} | tee -a "$RESULTS_DIR/quick_test.txt"

echo ""

# 测试2: 标准内存测试（1小时，如果快速测试通过）
if [[ $QUICK_RESULT -eq 0 ]]; then
    echo "步骤 4: 标准内存测试（1小时）..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    {
        echo "标准内存测试（1小时）"
        echo "========================================"
        echo ""
        echo "测试参数:"
        echo "  时长: 1小时"
        echo "  内存使用: 90%"
        echo "  线程数: $CPU_CORES"
        echo "  复制块大小: 64 MB"
        echo ""
    } | tee "$RESULTS_DIR/standard_test.txt"

    echo "开始测试（这将需要1小时）..."
    START_TIME=$(date +%s)

    stressapptest -s 3600 -M 90 -m $CPU_CORES -W -C 64 2>&1 | tee -a "$RESULTS_DIR/standard_test.txt"
    STANDARD_RESULT=$?

    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    {
        echo ""
        echo "测试结果:"
        echo "  实际运行时间: ${DURATION}秒 ($((DURATION / 60))分钟)"
        if [[ $STANDARD_RESULT -eq 0 ]]; then
            echo "  状态: ✓ PASS - 未检测到内存错误"
        else
            echo "  状态: ✗ FAIL - 检测到内存错误"
            echo "  退出码: $STANDARD_RESULT"
        fi
        echo ""
    } | tee -a "$RESULTS_DIR/standard_test.txt"

    echo ""
else
    echo "⚠ 快速测试失败，跳过标准测试"
    echo ""
    STANDARD_RESULT=255
fi

# 测试3: 磁盘+内存压力测试
echo "步骤 5: 磁盘+内存压力测试（10分钟）..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 创建临时目录
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

{
    echo "磁盘+内存压力测试（10分钟）"
    echo "========================================"
    echo ""
    echo "测试参数:"
    echo "  时长: 10分钟"
    echo "  内存使用: 85%"
    echo "  线程数: $CPU_CORES"
    echo "  磁盘文件: $TEMP_DIR/stressapptest_disk"
    echo ""
} | tee "$RESULTS_DIR/disk_memory_test.txt"

echo "开始测试..."
START_TIME=$(date +%s)

stressapptest -s 600 -M 85 -m $CPU_CORES -W -d "$TEMP_DIR/stressapptest_disk" 2>&1 | tee -a "$RESULTS_DIR/disk_memory_test.txt"
DISK_RESULT=$?

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

{
    echo ""
    echo "测试结果:"
    echo "  实际运行时间: ${DURATION}秒 ($((DURATION / 60))分钟)"
    if [[ $DISK_RESULT -eq 0 ]]; then
        echo "  状态: ✓ PASS - 未检测到错误"
    else
        echo "  状态: ✗ FAIL - 检测到错误"
        echo "  退出码: $DISK_RESULT"
    fi
    echo ""
} | tee -a "$RESULTS_DIR/disk_memory_test.txt"

echo ""

# 测试4: 多次短周期测试（热重启测试）
echo "步骤 6: 热重启压力测试（5次×3分钟）..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "热重启压力测试（5次×3分钟）"
    echo "========================================"
    echo ""
    echo "测试目的: 模拟频繁重启场景，检测冷热循环问题"
    echo ""
    echo "测试参数:"
    echo "  单次时长: 3分钟"
    echo "  重复次数: 5次"
    echo "  内存使用: 95%"
    echo "  线程数: $CPU_CORES"
    echo ""
} | tee "$RESULTS_DIR/cycle_test.txt"

CYCLE_FAILURES=0

for i in {1..5}; do
    echo "第 $i/5 次测试..."
    START_TIME=$(date +%s)

    stressapptest -s 180 -M 95 -m $CPU_CORES -W 2>&1 | tee -a "$RESULTS_DIR/cycle_test_${i}.txt"
    CYCLE_RESULT=$?

    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    if [[ $CYCLE_RESULT -eq 0 ]]; then
        echo "  第${i}次: ✓ PASS (${DURATION}秒)" | tee -a "$RESULTS_DIR/cycle_test.txt"
    else
        echo "  第${i}次: ✗ FAIL (退出码: $CYCLE_RESULT)" | tee -a "$RESULTS_DIR/cycle_test.txt"
        CYCLE_FAILURES=$((CYCLE_FAILURES + 1))
    fi

    # 间隔30秒（模拟冷却）
    if [[ $i -lt 5 ]]; then
        echo "  冷却30秒..."
        sleep 30
    fi
    echo ""
done

{
    echo ""
    echo "热重启测试总结:"
    echo "  成功次数: $((5 - CYCLE_FAILURES))/5"
    echo "  失败次数: $CYCLE_FAILURES/5"
    if [[ $CYCLE_FAILURES -eq 0 ]]; then
        echo "  状态: ✓ PASS - 所有测试通过"
    else
        echo "  状态: ✗ FAIL - ${CYCLE_FAILURES}次测试失败"
    fi
    echo ""
} | tee -a "$RESULTS_DIR/cycle_test.txt"

# 生成测试报告
{
    echo "StressAppTest 内存稳定性测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo ""

    echo "系统配置:"
    echo "  CPU: $CPU_MODEL"
    echo "  核心数: $CPU_CORES"
    if [[ -f /proc/meminfo ]]; then
        echo "  总内存: $((TOTAL_MEM_KB / 1024 / 1024)) GB"
    fi
    echo ""

    echo "测试结果汇总:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # 快速测试
    if [[ $QUICK_RESULT -eq 0 ]]; then
        echo "✓ 快速测试（5分钟）: PASS"
    else
        echo "✗ 快速测试（5分钟）: FAIL"
    fi

    # 标准测试
    if [[ $STANDARD_RESULT -eq 0 ]]; then
        echo "✓ 标准测试（1小时）: PASS"
    elif [[ $STANDARD_RESULT -eq 255 ]]; then
        echo "⊘ 标准测试（1小时）: SKIPPED"
    else
        echo "✗ 标准测试（1小时）: FAIL"
    fi

    # 磁盘+内存测试
    if [[ $DISK_RESULT -eq 0 ]]; then
        echo "✓ 磁盘+内存测试（10分钟）: PASS"
    else
        echo "✗ 磁盘+内存测试（10分钟）: FAIL"
    fi

    # 热重启测试
    if [[ $CYCLE_FAILURES -eq 0 ]]; then
        echo "✓ 热重启测试（5次×3分钟）: PASS (5/5)"
    else
        echo "✗ 热重启测试（5次×3分钟）: FAIL ($((5 - CYCLE_FAILURES))/5)"
    fi

    echo ""
    echo "总体评估:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    TOTAL_FAILURES=0
    [[ $QUICK_RESULT -ne 0 ]] && TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
    [[ $STANDARD_RESULT -ne 0 ]] && [[ $STANDARD_RESULT -ne 255 ]] && TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
    [[ $DISK_RESULT -ne 0 ]] && TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
    [[ $CYCLE_FAILURES -gt 0 ]] && TOTAL_FAILURES=$((TOTAL_FAILURES + 1))

    if [[ $TOTAL_FAILURES -eq 0 ]]; then
        echo "✓✓✓ 所有测试通过 - 内存系统稳定 ✓✓✓"
        echo ""
        echo "建议:"
        echo "  - 内存硬件工作正常"
        echo "  - 可以进行更长时间的验收测试（24-72小时）"
        echo "  - 适合生产环境使用"
    elif [[ $TOTAL_FAILURES -eq 1 ]] && [[ $CYCLE_FAILURES -gt 0 ]] && [[ $CYCLE_FAILURES -le 1 ]]; then
        echo "⚠ 轻微问题 - 建议重新测试"
        echo ""
        echo "建议:"
        echo "  - 热重启测试偶发失败可能是温度波动"
        echo "  - 重新运行测试验证"
        echo "  - 检查散热系统"
    else
        echo "✗✗✗ 检测到内存问题 - 需要排查 ✗✗✗"
        echo ""
        echo "建议:"
        echo "  1. 检查内存条是否插紧"
        echo "  2. 运行memtest86+进行更深入的硬件级测试"
        echo "  3. 逐条测试内存条，隔离故障内存"
        echo "  4. 检查内存电压和时序设置"
        echo "  5. 如果是超频，恢复默认频率测试"
        echo "  6. 联系硬件供应商"
    fi
    echo ""

    echo "详细结果文件:"
    echo "  系统信息: $RESULTS_DIR/sysinfo.txt"
    echo "  测试原理: $RESULTS_DIR/principles.txt"
    echo "  快速测试: $RESULTS_DIR/quick_test.txt"
    if [[ $STANDARD_RESULT -ne 255 ]]; then
        echo "  标准测试: $RESULTS_DIR/standard_test.txt"
    fi
    echo "  磁盘测试: $RESULTS_DIR/disk_memory_test.txt"
    echo "  热重启测试: $RESULTS_DIR/cycle_test.txt"
    echo ""

    echo "长时间测试脚本:"
    echo "  如需进行24小时或72小时验收测试，可使用:"
    echo "  $SCRIPT_DIR/stressapptest_long_duration.sh [24|72]"
    echo ""

} | tee "$RESULTS_DIR/report.txt"

echo ""
echo "========================================"
echo "测试完成"
echo "========================================"
echo ""
echo "查看报告: cat $RESULTS_DIR/report.txt"
echo "结果目录: $RESULTS_DIR"
echo ""
