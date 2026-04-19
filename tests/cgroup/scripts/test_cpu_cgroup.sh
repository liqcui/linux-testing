#!/bin/bash
# test_cpu_cgroup.sh - cgroup CPU限制测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRAMS_DIR="$SCRIPT_DIR/../programs"
RESULTS_DIR="$SCRIPT_DIR/../results/cpu-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "Cgroup CPU 限制测试"
echo "========================================"
echo ""

# 检查权限
if [[ $EUID -ne 0 ]]; then
   echo "错误: 此脚本需要 root 权限"
   echo "使用: sudo $0"
   exit 1
fi

mkdir -p "$RESULTS_DIR"

# 编译测试程序
echo "步骤 1: 编译测试程序..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd "$PROGRAMS_DIR"
make cpu_hog &>/dev/null

if [[ ! -f cpu_hog ]]; then
    echo "✗ 编译失败"
    exit 1
fi

echo "✓ 编译成功: cpu_hog"
echo ""

# 检测cgroup版本
echo "步骤 2: 检测cgroup版本..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

CGROUP_V2=0
if [[ -f /sys/fs/cgroup/cgroup.controllers ]]; then
    echo "✓ 检测到 cgroup v2"
    CGROUP_V2=1
    CGROUP_ROOT="/sys/fs/cgroup"
elif [[ -d /sys/fs/cgroup/cpu ]]; then
    echo "✓ 检测到 cgroup v1"
    CGROUP_V2=0
    CGROUP_ROOT="/sys/fs/cgroup/cpu"
else
    echo "✗ 无法检测到cgroup"
    exit 1
fi

echo "Cgroup根目录: $CGROUP_ROOT"
echo ""

# 创建测试cgroup
echo "步骤 3: 创建测试cgroup..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

TEST_GROUP="test_cpu_$$"
GROUP_PATH="$CGROUP_ROOT/$TEST_GROUP"

mkdir -p "$GROUP_PATH"

if [[ ! -d "$GROUP_PATH" ]]; then
    echo "✗ 创建cgroup失败"
    exit 1
fi

echo "✓ 已创建cgroup: $TEST_GROUP"
echo "  路径: $GROUP_PATH"
echo ""

# 基准测试（无限制）
echo "步骤 4: 基准测试（无限制）..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "运行CPU密集型程序（4线程，10秒）..."
"$PROGRAMS_DIR/cpu_hog" 4 10 | tee "$RESULTS_DIR/baseline.txt"

BASELINE_RATE=$(grep "平均速率" "$RESULTS_DIR/baseline.txt" | awk '{print $2}')
echo ""
echo "基准速率: $BASELINE_RATE k迭代/秒"
echo ""

# CPU quota测试
echo "步骤 5: CPU quota限制测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ $CGROUP_V2 -eq 1 ]]; then
    # cgroup v2
    echo "设置CPU限制为50% (500000/1000000)..."

    # 确保cpu控制器启用
    echo "+cpu" > "$CGROUP_ROOT/cgroup.subtree_control" 2>/dev/null

    echo "50000 100000" > "$GROUP_PATH/cpu.max"

    if [[ $? -ne 0 ]]; then
        echo "⚠ 设置cpu.max失败"
    else
        echo "✓ CPU quota已设置"
    fi

    cat "$GROUP_PATH/cpu.max"
else
    # cgroup v1
    echo "设置CPU限制为50%..."

    # CFS quota: 50000us out of 100000us period = 50%
    echo 100000 > "$GROUP_PATH/cpu.cfs_period_us"
    echo 50000 > "$GROUP_PATH/cpu.cfs_quota_us"

    echo "✓ CPU quota已设置"
    echo "  Period: $(cat $GROUP_PATH/cpu.cfs_period_us) us"
    echo "  Quota: $(cat $GROUP_PATH/cpu.cfs_quota_us) us"
fi

echo ""
echo "在cgroup中运行程序..."

if [[ $CGROUP_V2 -eq 1 ]]; then
    # cgroup v2: 使用cgroup.procs
    (
        echo $$ > "$GROUP_PATH/cgroup.procs"
        "$PROGRAMS_DIR/cpu_hog" 4 10
    ) | tee "$RESULTS_DIR/quota-50.txt"
else
    # cgroup v1: 使用tasks
    (
        echo $$ > "$GROUP_PATH/tasks"
        "$PROGRAMS_DIR/cpu_hog" 4 10
    ) | tee "$RESULTS_DIR/quota-50.txt"
fi

QUOTA_RATE=$(grep "平均速率" "$RESULTS_DIR/quota-50.txt" | awk '{print $2}')
echo ""
echo "限制后速率: $QUOTA_RATE k迭代/秒"
echo "预期减少: ~50%"
echo "实际减少: $(echo "scale=2; (1 - $QUOTA_RATE / $BASELINE_RATE) * 100" | bc)%"
echo ""

# CPU shares测试
echo "步骤 6: CPU shares测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

GROUP_A="$CGROUP_ROOT/test_cpu_a_$$"
GROUP_B="$CGROUP_ROOT/test_cpu_b_$$"

mkdir -p "$GROUP_A" "$GROUP_B"

if [[ $CGROUP_V2 -eq 1 ]]; then
    echo "设置权重: A=1024, B=2048 (比例 1:2)..."
    echo 100 > "$GROUP_A/cpu.weight"
    echo 200 > "$GROUP_B/cpu.weight"
else
    echo "设置shares: A=1024, B=2048 (比例 1:2)..."
    echo 1024 > "$GROUP_A/cpu.shares"
    echo 2048 > "$GROUP_B/cpu.shares"
fi

echo "✓ CPU权重已设置"
echo ""

echo "启动两个竞争进程..."

# 启动进程A
(
    if [[ $CGROUP_V2 -eq 1 ]]; then
        echo $$ > "$GROUP_A/cgroup.procs"
    else
        echo $$ > "$GROUP_A/tasks"
    fi
    "$PROGRAMS_DIR/cpu_hog" 2 10
) > "$RESULTS_DIR/shares-a.txt" 2>&1 &
PID_A=$!

# 启动进程B
(
    if [[ $CGROUP_V2 -eq 1 ]]; then
        echo $$ > "$GROUP_B/cgroup.procs"
    else
        echo $$ > "$GROUP_B/tasks"
    fi
    "$PROGRAMS_DIR/cpu_hog" 2 10
) > "$RESULTS_DIR/shares-b.txt" 2>&1 &
PID_B=$!

echo "进程A (PID $PID_A): 低权重"
echo "进程B (PID $PID_B): 高权重"
echo ""

# 等待完成
wait $PID_A
wait $PID_B

RATE_A=$(grep "平均速率" "$RESULTS_DIR/shares-a.txt" | awk '{print $2}')
RATE_B=$(grep "平均速率" "$RESULTS_DIR/shares-b.txt" | awk '{print $2}')

echo "结果:"
echo "  进程A速率: $RATE_A k迭代/秒"
echo "  进程B速率: $RATE_B k迭代/秒"
echo "  比例: $(echo "scale=2; $RATE_B / $RATE_A" | bc) (预期 ~2:1)"
echo ""

# CPU统计
echo "步骤 7: CPU使用统计..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ $CGROUP_V2 -eq 1 ]]; then
    echo "cgroup v2 CPU统计:"
    cat "$GROUP_PATH/cpu.stat"
else
    echo "cgroup v1 CPU统计:"
    if [[ -f "$GROUP_PATH/cpuacct.usage" ]]; then
        echo "总CPU时间: $(cat $GROUP_PATH/cpuacct.usage) ns"
    fi
    if [[ -f "$GROUP_PATH/cpu.stat" ]]; then
        cat "$GROUP_PATH/cpu.stat"
    fi
fi

echo ""

# 清理
echo "清理cgroup..."
rmdir "$GROUP_A" "$GROUP_B" "$GROUP_PATH" 2>/dev/null
echo "✓ 清理完成"
echo ""

# 生成报告
{
    echo "Cgroup CPU测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo ""
    echo "系统信息:"
    echo "  Cgroup版本: $([[ $CGROUP_V2 -eq 1 ]] && echo 'v2' || echo 'v1')"
    echo "  Cgroup根目录: $CGROUP_ROOT"
    echo ""
    echo "测试结果:"
    echo "  基准速率: $BASELINE_RATE k迭代/秒"
    echo "  50% quota限制: $QUOTA_RATE k迭代/秒 (减少 $(echo "scale=2; (1 - $QUOTA_RATE / $BASELINE_RATE) * 100" | bc)%)"
    echo "  Shares测试:"
    echo "    低权重进程: $RATE_A k迭代/秒"
    echo "    高权重进程: $RATE_B k迭代/秒"
    echo "    比例: $(echo "scale=2; $RATE_B / $RATE_A" | bc) (预期 2:1)"
    echo ""
    echo "详细日志:"
    echo "  基准测试: $RESULTS_DIR/baseline.txt"
    echo "  Quota测试: $RESULTS_DIR/quota-50.txt"
    echo "  Shares A: $RESULTS_DIR/shares-a.txt"
    echo "  Shares B: $RESULTS_DIR/shares-b.txt"
    echo ""
} | tee "$RESULTS_DIR/summary.txt"

echo "========================================"
echo "测试完成"
echo "========================================"
echo ""
echo "✓ CPU cgroup测试完成"
echo ""
echo "结果目录: $RESULTS_DIR"
echo ""
