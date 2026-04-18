#!/bin/bash
# run_all_tests.sh - 运行所有 stress-ng 测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results_$(date +%Y%m%d_%H%M%S)"

mkdir -p "$RESULTS_DIR"

echo "========================================"
echo "stress-ng 完整测试套件"
echo "========================================"
echo ""
echo "结果目录: $RESULTS_DIR"
echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 检查 stress-ng
if ! command -v stress-ng &> /dev/null; then
    echo "错误: stress-ng 未安装"
    echo ""
    echo "安装命令:"
    echo "  Ubuntu/Debian: sudo apt install stress-ng"
    echo "  RHEL/CentOS:   sudo yum install stress-ng"
    echo "  Fedora:        sudo dnf install stress-ng"
    exit 1
fi

# 检查权限
if [[ $EUID -ne 0 ]]; then
   echo "警告: 某些测试需要 root 权限"
   echo "建议使用: sudo $0"
   echo ""
fi

TESTS=(
    "cpu:CPU压力测试"
    "memory:内存压力测试"
    "io:I/O压力测试"
    "network:网络压力测试"
    "comprehensive:综合压力测试"
)

TOTAL=${#TESTS[@]}
CURRENT=0

for test_info in "${TESTS[@]}"; do
    IFS=':' read -r test_dir test_name <<< "$test_info"
    CURRENT=$((CURRENT + 1))

    echo ""
    echo "========================================"
    echo "[$CURRENT/$TOTAL] $test_name"
    echo "========================================"
    echo ""

    cd "$SCRIPT_DIR/$test_dir"
    TEST_SCRIPT="test_${test_dir}_stress.sh"

    if [[ ! -f "$TEST_SCRIPT" ]]; then
        echo "错误: 测试脚本 $TEST_SCRIPT 不存在"
        continue
    fi

    LOG_FILE="$RESULTS_DIR/${test_dir}_test.log"

    echo "运行 $TEST_SCRIPT ..."
    echo "日志: $LOG_FILE"
    echo ""

    ./"$TEST_SCRIPT" 2>&1 | tee "$LOG_FILE"

    echo ""
    echo "✓ $test_name 完成"
    echo ""

    # 冷却期
    if [[ $CURRENT -lt $TOTAL ]]; then
        echo "冷却期 30 秒..."
        sleep 30
    fi
done

cd "$SCRIPT_DIR"

echo ""
echo "========================================"
echo "所有测试完成！"
echo "========================================"
echo ""
echo "结束时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "测试结果保存在: $RESULTS_DIR"
echo ""
echo "查看结果:"
echo "  ls -lh $RESULTS_DIR"
echo ""
echo "生成测试报告:"
echo "  cat $RESULTS_DIR/*.log > $RESULTS_DIR/full_report.txt"
echo ""

# 生成简要摘要
SUMMARY_FILE="$RESULTS_DIR/summary.txt"

{
    echo "========================================="
    echo "stress-ng 测试摘要"
    echo "========================================="
    echo ""
    echo "测试时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "系统信息:"
    echo "  主机名: $(hostname)"
    echo "  内核: $(uname -r)"
    echo "  CPU: $(nproc) 核心"
    echo "  内存: $(free -h | awk '/^Mem:/{print $2}')"
    echo ""
    echo "测试日志文件:"
    ls -1 "$RESULTS_DIR"/*.log 2>/dev/null || echo "  无"
    echo ""
    echo "========================================="
} > "$SUMMARY_FILE"

echo "摘要文件: $SUMMARY_FILE"
echo ""
cat "$SUMMARY_FILE"
