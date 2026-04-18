#!/bin/bash
# test_pi_stress.sh - 优先级继承互斥锁测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results/pi-stress-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "优先级继承 (PI) 互斥锁测试"
echo "========================================"
echo ""

# 检查 pi_stress
if ! command -v pi_stress &> /dev/null; then
    echo "错误: pi_stress 未安装"
    echo "请运行: sudo ../install_rt_tests.sh"
    exit 1
fi

# 检查权限
if [[ $EUID -ne 0 ]]; then
   echo "错误: 此脚本需要 root 权限"
   echo "使用: sudo $0"
   exit 1
fi

mkdir -p "$RESULTS_DIR"

CPU_COUNT=$(nproc)

echo "测试目的:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "验证系统是否正确实现优先级继承（Priority Inheritance），"
echo "防止优先级反转问题。"
echo ""
echo "优先级反转场景:"
echo "  1. 低优先级任务 L 获得锁"
echo "  2. 高优先级任务 H 尝试获取同一锁，被阻塞"
echo "  3. 中优先级任务 M 抢占 L"
echo "  4. 结果: H 被 M 间接阻塞（优先级反转）"
echo ""
echo "优先级继承解决方案:"
echo "  当 H 被 L 持有的锁阻塞时，L 临时继承 H 的优先级"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 测试 1: 基础 PI 测试
echo "测试 1: 基础优先级继承测试（60秒）"
echo "==================================="
echo ""
echo "参数: 默认配置"
echo ""

pi_stress --duration=60 2>&1 | tee "$RESULTS_DIR/basic-pi-test.log"

echo ""
echo ""

# 测试 2: 多线程组测试
echo "测试 2: 多线程组测试（120秒）"
echo "============================="
echo ""
echo "参数:"
echo "  --groups=10      : 10 个线程组"
echo "  --duration=120   : 运行 120 秒"
echo ""

pi_stress --groups=10 --duration=120 2>&1 | tee "$RESULTS_DIR/multigroup-pi-test.log"

echo ""
echo ""

# 测试 3: 详细模式测试
echo "测试 3: 详细输出模式测试（60秒）"
echo "==============================="
echo ""
echo "参数: --verbose"
echo ""

pi_stress --groups=5 --duration=60 --verbose 2>&1 | tee "$RESULTS_DIR/verbose-pi-test.log"

echo ""
echo ""

# 测试 4: 长时间稳定性测试
echo "测试 4: 长时间稳定性测试（300秒）"
echo "================================="
echo ""
echo "测试长时间运行的稳定性..."
echo ""

pi_stress --groups=8 --duration=300 2>&1 | tee "$RESULTS_DIR/long-run-pi-test.log"

echo ""
echo ""

# 分析结果
echo "========================================"
echo "测试完成 - 结果分析"
echo "========================================"
echo ""

SUCCESS_COUNT=0
FAIL_COUNT=0

for log in "$RESULTS_DIR"/*.log; do
    if grep -qi "SUCCESS" "$log"; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    fi

    if grep -qi "FAIL\|ERROR" "$log"; then
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done

{
    echo "PI Stress 测试摘要"
    echo "========================================"
    echo ""
    echo "测试日期: $(date)"
    echo "系统: $(hostname) - $(uname -r)"
    echo ""
    echo "测试结果:"
    echo "  成功测试数: $SUCCESS_COUNT"
    echo "  失败测试数: $FAIL_COUNT"
    echo ""

    if [[ $FAIL_COUNT -eq 0 ]]; then
        echo "状态: ✓ 所有测试通过"
        echo ""
        echo "结论:"
        echo "  系统正确实现了优先级继承机制"
        echo "  可以有效防止优先级反转问题"
    else
        echo "状态: ✗ 存在测试失败"
        echo ""
        echo "警告:"
        echo "  系统的优先级继承可能存在问题"
        echo "  建议检查内核配置和实时补丁"
        echo ""
        echo "失败日志:"
        for log in "$RESULTS_DIR"/*.log; do
            if grep -qi "FAIL\|ERROR" "$log"; then
                echo "  - $(basename "$log")"
                grep -i "FAIL\|ERROR" "$log" | head -5
            fi
        done
    fi

    echo ""
    echo "详细日志: $RESULTS_DIR"

} | tee "$RESULTS_DIR/summary.txt"

echo ""
echo "结果文件:"
ls -lh "$RESULTS_DIR"
echo ""

if [[ $FAIL_COUNT -gt 0 ]]; then
    exit 1
else
    exit 0
fi
