#!/bin/bash
# stressapptest_long_duration.sh - 长时间内存稳定性测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results/stressapptest-long-$(date +%Y%m%d-%H%M%S)"

# 配置参数
DURATION_HOURS="${1:-72}"      # 测试时长：默认72小时
MEMORY_PERCENT="${2:-90}"      # 内存使用比例：默认90%
THREADS=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
LOG_FILE="$RESULTS_DIR/stressapptest_long.log"

mkdir -p "$RESULTS_DIR"

echo "========================================"
echo "StressAppTest 长时间稳定性测试"
echo "========================================"
echo ""
echo "测试配置:"
echo "  时长: ${DURATION_HOURS} 小时"
echo "  内存使用: ${MEMORY_PERCENT}%"
echo "  线程数: ${THREADS}"
echo "  日志文件: $LOG_FILE"
echo ""

# 检查stressapptest
if ! command -v stressapptest &> /dev/null; then
    echo "✗ 错误: stressapptest未安装"
    echo ""
    echo "请先运行: $SCRIPT_DIR/test_stressapptest.sh"
    exit 1
fi

# 创建临时磁盘文件目录
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# 系统信息
{
    echo "长时间内存稳定性测试"
    echo "========================================"
    echo ""
    echo "开始时间: $(date)"
    echo ""
    echo "测试配置:"
    echo "  时长: ${DURATION_HOURS} 小时 ($(($DURATION_HOURS * 3600)) 秒)"
    echo "  内存使用: ${MEMORY_PERCENT}%"
    echo "  线程数: ${THREADS}"
    echo "  严格检查: 启用 (-W)"
    echo "  磁盘压力: $TEMP_DIR/stressapptest_disk"
    echo "  暂停检查: 每10秒"
    echo "  暂停间隔: 每5分钟"
    echo ""

    echo "系统信息:"
    if [[ -f /proc/cpuinfo ]]; then
        CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
        echo "  CPU: $CPU_MODEL"
    else
        CPU_MODEL=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
        echo "  CPU: $CPU_MODEL"
    fi

    if [[ -f /proc/meminfo ]]; then
        MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        echo "  总内存: $((MEM_TOTAL / 1024 / 1024)) GB"
    else
        MEM_TOTAL=$(sysctl -n hw.memsize 2>/dev/null)
        echo "  总内存: $((MEM_TOTAL / 1024 / 1024 / 1024)) GB"
    fi
    echo ""

    echo "预计完成时间: $(date -d "+${DURATION_HOURS} hours" 2>/dev/null || date -v +${DURATION_HOURS}H 2>/dev/null || echo "N/A")"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
} | tee "$LOG_FILE"

# 长时间测试（生产环境硬件验证）
echo "Starting ${DURATION_HOURS}-hour memory stress test..."
echo ""
START_TIME=$(date +%s)

stressapptest \
    -s $(($DURATION_HOURS * 3600)) \
    -M ${MEMORY_PERCENT} \
    -m ${THREADS} \
    -W \
    -d "$TEMP_DIR/stressapptest_disk" \
    --pause_duration 10 \
    --pause_delay 300 \
    2>&1 | tee -a "$LOG_FILE"

RESULT=$?
END_TIME=$(date +%s)
ACTUAL_DURATION=$((END_TIME - START_TIME))
ACTUAL_HOURS=$((ACTUAL_DURATION / 3600))
ACTUAL_MINUTES=$(((ACTUAL_DURATION % 3600) / 60))

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$LOG_FILE"

# 结果检查
{
    echo ""
    echo "测试结果"
    echo "========================================"
    echo ""
    echo "结束时间: $(date)"
    echo "实际运行时间: ${ACTUAL_HOURS}小时${ACTUAL_MINUTES}分钟 (${ACTUAL_DURATION}秒)"
    echo ""

    if [[ $RESULT -eq 0 ]]; then
        echo "✓✓✓ TEST PASSED ✓✓✓"
        echo ""
        echo "未检测到内存错误"
        echo ""
        echo "结论:"
        echo "  - 内存系统在 ${DURATION_HOURS} 小时压力测试下保持稳定"
        echo "  - 未检测到位翻转、数据损坏等问题"
        echo "  - 系统通过生产环境验收标准"
        echo ""
        echo "建议:"
        echo "  ✓ 系统可投入生产环境使用"
        echo "  ✓ 内存硬件质量良好"
        echo "  ✓ 散热系统工作正常"
        echo ""
    else
        echo "✗✗✗ TEST FAILED ✗✗✗"
        echo ""
        echo "检测到内存错误!"
        echo "退出码: $RESULT"
        echo ""
        echo "错误分类:"
        case $RESULT in
            1)
                echo "  - 检测到内存错误（位翻转或数据损坏）"
                ;;
            2)
                echo "  - 测试被中断"
                ;;
            *)
                echo "  - 其他错误（退出码: $RESULT）"
                ;;
        esac
        echo ""
        echo "紧急建议:"
        echo "  ✗ 请勿将此系统用于生产环境"
        echo "  1. 立即运行 memtest86+ 进行硬件级诊断"
        echo "  2. 检查内存条："
        echo "     - 重新插拔所有内存条"
        echo "     - 清理金手指"
        echo "     - 逐条测试隔离故障内存"
        echo "  3. 检查BIOS设置："
        echo "     - 内存电压是否正确"
        echo "     - 内存时序是否匹配"
        echo "     - 如果超频，恢复默认设置"
        echo "  4. 检查散热系统："
        echo "     - CPU温度是否过高"
        echo "     - 机箱通风是否良好"
        echo "  5. 联系硬件供应商进行RMA"
        echo ""

        # 发送告警（如果配置了邮件）
        if command -v mail &> /dev/null && [[ -n "${ADMIN_EMAIL:-}" ]]; then
            echo "Sending alert email to ${ADMIN_EMAIL}..."
            mail -s "CRITICAL: Memory Test FAILED on $(hostname)" "${ADMIN_EMAIL}" < "$LOG_FILE"
        fi
    fi

    echo "详细日志: $LOG_FILE"
    echo ""

} | tee -a "$LOG_FILE"

# 生成报告摘要
{
    echo "测试摘要"
    echo "========================================"
    echo ""
    echo "主机名: $(hostname)"
    echo "测试时间: $(date -r $START_TIME 2>/dev/null || date) - $(date)"
    echo "测试时长: ${DURATION_HOURS}小时 (目标) / ${ACTUAL_HOURS}小时${ACTUAL_MINUTES}分钟 (实际)"
    echo "内存使用: ${MEMORY_PERCENT}%"
    echo "线程数: ${THREADS}"
    echo ""

    if [[ $RESULT -eq 0 ]]; then
        echo "状态: ✓ PASS"
        echo "评级: ★★★★★ 生产就绪"
    else
        echo "状态: ✗ FAIL"
        echo "评级: ☆☆☆☆☆ 需要维修"
        echo "退出码: $RESULT"
    fi
    echo ""

} | tee "$RESULTS_DIR/summary.txt"

echo "========================================"
echo "测试完成"
echo "========================================"
echo ""
echo "查看完整日志: cat $LOG_FILE"
echo "查看摘要: cat $RESULTS_DIR/summary.txt"
echo "结果目录: $RESULTS_DIR"
echo ""

exit $RESULT
