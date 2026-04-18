#!/bin/bash
# 运行所有性能测试的主脚本（新版本 - 分类组织）

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

echo "========================================="
echo "Linux 性能测试套件"
echo "========================================="
echo "项目路径: $PROJECT_ROOT"
echo "开始时间: $(date)"
echo ""

# 检查权限
if [ "$EUID" -ne 0 ]; then
    echo "⚠ 警告: 某些测试需要 root 权限"
    echo "  建议使用: sudo $0"
    echo ""
fi

# 检查核心依赖
echo "检查依赖..."
MISSING_DEPS=0

if ! command -v perf >/dev/null 2>&1; then
    echo "✗ perf 未安装"
    echo "  运行安装脚本: sudo ./setup/install-tools.sh"
    MISSING_DEPS=1
else
    echo "✓ perf: $(perf --version 2>&1 | head -1)"
fi

if [ $MISSING_DEPS -eq 1 ]; then
    echo ""
    echo "错误: 缺少必要的依赖"
    echo "请运行: sudo ./setup/install-tools.sh"
    exit 1
fi

# 检查可选依赖
if ! command -v stress-ng >/dev/null 2>&1; then
    echo "⚠ stress-ng 未安装（调度测试可能受限）"
else
    echo "✓ stress-ng: $(stress-ng --version 2>&1 | head -1)"
fi

echo ""
echo "========================================="

# 创建结果目录
mkdir -p results/{network,sched,block,tcp}

# 测试计数
total_tests=0
passed_tests=0
failed_tests=0

# 运行测试函数
run_test() {
    local category="$1"
    local name="$2"
    local script="$3"

    total_tests=$((total_tests + 1))

    echo ""
    echo "========================================="
    echo "[$total_tests] 测试类别: $category"
    echo "测试名称: $name"
    echo "========================================="
    echo ""

    if [ -f "$script" ]; then
        chmod +x "$script"
        if bash "$script"; then
            echo ""
            echo "✓ $name 测试完成"
            passed_tests=$((passed_tests + 1))
            return 0
        else
            echo ""
            echo "✗ $name 测试失败"
            failed_tests=$((failed_tests + 1))
            return 1
        fi
    else
        echo "✗ 脚本不存在: $script"
        failed_tests=$((failed_tests + 1))
        return 1
    fi
}

# 运行各类测试
echo "开始运行测试..."

# 1. 网络测试
run_test "网络" "网络性能测试" "$SCRIPT_DIR/network/network-test.sh" || true

# 2. 进程调度测试
run_test "调度" "进程调度测试" "$SCRIPT_DIR/sched/sched-test.sh" || true

# 3. 块设备测试
run_test "块设备" "块设备I/O测试" "$SCRIPT_DIR/block/block-test.sh" || true

# 4. TCP 协议栈测试
run_test "TCP" "TCP 协议栈测试" "$SCRIPT_DIR/tcp/tcp-test.sh" || true

# 生成汇总报告
echo ""
echo "========================================="
echo "生成汇总报告..."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SUMMARY_FILE="results/summary_$TIMESTAMP.md"

{
    echo "# Linux 性能测试汇总报告"
    echo ""
    echo "**测试时间**: $(date)"
    echo "**主机名**: $(hostname)"
    echo "**内核版本**: $(uname -r)"
    echo ""

    echo "## 测试统计"
    echo ""
    echo "| 指标 | 数值 |"
    echo "|------|------|"
    echo "| 总测试数 | $total_tests |"
    echo "| 通过 | $passed_tests |"
    echo "| 失败 | $failed_tests |"
    echo "| 成功率 | $(awk "BEGIN {printf \"%.1f%%\", $passed_tests*100/$total_tests}") |"
    echo ""

    echo "## 系统信息"
    echo ""
    echo "### CPU"
    echo '```'
    lscpu | grep -E "Model name|CPU\(s\)|Thread|Core|Socket"
    echo '```'
    echo ""

    echo "### 内存"
    echo '```'
    free -h
    echo '```'
    echo ""

    echo "### 磁盘"
    echo '```'
    df -h | head -10
    echo '```'
    echo ""

    echo "### 网络"
    echo '```'
    ip link show | grep -E "^[0-9]|state"
    echo '```'
    echo ""

    echo "## 测试结果详情"
    echo ""

    # 网络测试结果
    echo "### 1. 网络性能测试"
    echo ""
    LATEST_NETWORK=$(ls -t results/network/report_*.txt 2>/dev/null | head -1)
    if [ -f "$LATEST_NETWORK" ]; then
        echo '```'
        head -30 "$LATEST_NETWORK"
        echo '```'
        echo ""
        echo "完整报告: $LATEST_NETWORK"
    else
        echo "未找到测试结果"
    fi
    echo ""

    # 调度测试结果
    echo "### 2. 进程调度测试"
    echo ""
    LATEST_SCHED=$(ls -t results/sched/report_*.txt 2>/dev/null | head -1)
    if [ -f "$LATEST_SCHED" ]; then
        echo '```'
        head -30 "$LATEST_SCHED"
        echo '```'
        echo ""
        echo "完整报告: $LATEST_SCHED"
    else
        echo "未找到测试结果"
    fi
    echo ""

    # 块设备测试结果
    echo "### 3. 块设备I/O测试"
    echo ""
    LATEST_BLOCK=$(ls -t results/block/report_*.txt 2>/dev/null | head -1)
    if [ -f "$LATEST_BLOCK" ]; then
        echo '```'
        head -30 "$LATEST_BLOCK"
        echo '```'
        echo ""
        echo "完整报告: $LATEST_BLOCK"
    else
        echo "未找到测试结果"
    fi
    echo ""

    # TCP 测试结果
    echo "### 4. TCP 协议栈测试"
    echo ""
    LATEST_TCP=$(ls -t results/tcp/report_*.txt 2>/dev/null | head -1)
    if [ -f "$LATEST_TCP" ]; then
        echo '```'
        head -30 "$LATEST_TCP"
        echo '```'
        echo ""
        echo "完整报告: $LATEST_TCP"
    else
        echo "未找到测试结果"
    fi

    echo ""
    echo "---"
    echo ""
    echo "**报告生成时间**: $(date)"

} > "$SUMMARY_FILE"

echo "✓ 汇总报告保存到: $SUMMARY_FILE"

echo ""
echo "========================================="
echo "所有测试完成！"
echo "========================================="
echo "完成时间: $(date)"
echo ""
echo "测试统计:"
echo "  总数: $total_tests"
echo "  通过: $passed_tests"
echo "  失败: $failed_tests"
echo "  成功率: $(awk "BEGIN {printf \"%.1f%%\", $passed_tests*100/$total_tests}")"
echo ""
echo "结果位置:"
echo "  - 网络测试: results/network/"
echo "  - 调度测试: results/sched/"
echo "  - 块设备测试: results/block/"
echo "  - TCP 测试: results/tcp/"
echo "  - 汇总报告: $SUMMARY_FILE"
echo ""

# 返回失败的测试数量作为退出码
exit $failed_tests
