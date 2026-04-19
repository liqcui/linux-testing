#!/bin/bash
# test_avc.sh - SELinux AVC (访问向量缓存) 测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results/avc-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "SELinux AVC 测试"
echo "========================================"
echo ""

# 检查权限
if [[ $EUID -ne 0 ]]; then
   echo "错误: 此脚本需要 root 权限"
   echo "使用: sudo $0"
   exit 1
fi

mkdir -p "$RESULTS_DIR"

# 检查SELinux状态
echo "步骤 1: 检查SELinux状态..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ! command -v sestatus &> /dev/null; then
    echo "✗ SELinux工具未安装"
    exit 1
fi

SELINUX_ENABLED=$(sestatus | grep "SELinux status" | awk '{print $3}')
SELINUX_MODE=$(getenforce 2>/dev/null || echo "Disabled")

echo "SELinux状态: $SELINUX_ENABLED"
echo "当前模式: $SELINUX_MODE"
echo ""

if [[ "$SELINUX_ENABLED" != "enabled" ]]; then
    echo "✗ SELinux未启用，无法进行AVC测试"
    exit 1
fi

# 检查AVC统计接口
echo "步骤 2: 检查AVC接口..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

AVC_STATS_PATH=""

# 尝试不同的AVC统计路径
if [[ -f /sys/fs/selinux/avc/cache_stats ]]; then
    AVC_STATS_PATH="/sys/fs/selinux/avc/cache_stats"
elif [[ -f /selinux/avc/cache_stats ]]; then
    AVC_STATS_PATH="/selinux/avc/cache_stats"
elif [[ -f /sys/kernel/security/selinux/avc/cache_stats ]]; then
    AVC_STATS_PATH="/sys/kernel/security/selinux/avc/cache_stats"
fi

if [[ -z "$AVC_STATS_PATH" ]]; then
    echo "⚠ AVC统计接口不可用"
    echo ""
    echo "可能原因:"
    echo "  1. 内核未启用AVC统计"
    echo "  2. selinuxfs未挂载"
    echo ""
    AVC_AVAILABLE=0
else
    echo "✓ AVC统计接口: $AVC_STATS_PATH"
    AVC_AVAILABLE=1
    echo ""
fi

# 显示初始AVC统计
if [[ $AVC_AVAILABLE -eq 1 ]]; then
    echo "初始AVC统计:"
    cat "$AVC_STATS_PATH" | tee "$RESULTS_DIR/avc-initial.txt"
    echo ""
fi

# 清空审计日志记录点（不清空实际日志）
echo "步骤 3: 准备审计日志..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if command -v ausearch &> /dev/null; then
    echo "✓ auditd工具可用"
    AUDIT_AVAILABLE=1

    # 记录当前时间点
    TEST_START_TIME=$(date +%s)
    echo "测试开始时间: $(date)"
else
    echo "⚠ auditd工具不可用"
    echo ""
    echo "安装命令:"
    echo "  RHEL/CentOS/Fedora: sudo yum install audit"
    echo "  Ubuntu/Debian:      sudo apt-get install auditd"
    AUDIT_AVAILABLE=0
fi

echo ""

# AVC查询性能测试
echo "步骤 4: AVC查询性能测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "测试场景: 重复访问相同文件"
echo "迭代次数: 1000"
echo ""

TEST_FILE="/etc/passwd"

start_time=$(date +%s.%N)

for i in {1..1000}; do
    cat "$TEST_FILE" > /dev/null 2>&1
done

end_time=$(date +%s.%N)
duration=$(echo "$end_time - $start_time" | bc)
avg_time=$(echo "scale=6; $duration / 1000" | bc)

echo "总耗时: ${duration}s"
echo "平均延迟: ${avg_time}s/次"
echo "访问频率: $(echo "scale=2; 1000 / $duration" | bc) 次/秒"
echo ""

if [[ $AVC_AVAILABLE -eq 1 ]]; then
    echo "测试后AVC统计:"
    cat "$AVC_STATS_PATH" | tee "$RESULTS_DIR/avc-after-query.txt"
    echo ""
fi

# AVC缓存压力测试 - 访问不同文件
echo "步骤 5: AVC缓存压力测试 - 多文件访问..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "测试场景: 访问多个不同文件"
echo "文件数量: 100"
echo ""

# 创建临时测试文件
TEST_DIR="/tmp/avc_test_$$"
mkdir -p "$TEST_DIR"

echo "创建测试文件..."
for i in {1..100}; do
    echo "测试数据 $i" > "$TEST_DIR/file_$i"
done

echo "✓ 已创建100个测试文件"
echo ""

start_time=$(date +%s.%N)

for i in {1..100}; do
    cat "$TEST_DIR/file_$i" > /dev/null 2>&1
done

end_time=$(date +%s.%N)
duration=$(echo "$end_time - $start_time" | bc)

echo "总耗时: ${duration}s"
echo "平均延迟: $(echo "scale=6; $duration / 100" | bc)s/文件"
echo ""

if [[ $AVC_AVAILABLE -eq 1 ]]; then
    echo "测试后AVC统计:"
    cat "$AVC_STATS_PATH" | tee "$RESULTS_DIR/avc-after-multifile.txt"
    echo ""
fi

# 清理测试文件
rm -rf "$TEST_DIR"

# AVC上下文切换测试
echo "步骤 6: AVC上下文切换测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "测试场景: 使用runcon切换上下文"
echo ""

# 获取当前上下文
CURRENT_CONTEXT=$(id -Z 2>/dev/null)
echo "当前上下文: $CURRENT_CONTEXT"
echo ""

# 尝试使用不同的上下文执行命令
CONTEXTS=(
    "unconfined_u:unconfined_r:unconfined_t:s0"
    "system_u:system_r:unconfined_t:s0"
)

{
    echo "上下文切换测试"
    echo "========================================"
    echo ""
} > "$RESULTS_DIR/context-switch.txt"

for context in "${CONTEXTS[@]}"; do
    echo "测试上下文: $context"

    runcon "$context" cat /etc/passwd > /dev/null 2>&1
    result=$?

    if [[ $result -eq 0 ]]; then
        echo "  ✓ 执行成功"
    else
        echo "  ✗ 执行失败 (可能被拒绝)"
    fi

    {
        echo "上下文: $context"
        echo "结果: $result"
        echo ""
    } >> "$RESULTS_DIR/context-switch.txt"
done

echo ""

if [[ $AVC_AVAILABLE -eq 1 ]]; then
    echo "测试后AVC统计:"
    cat "$AVC_STATS_PATH" | tee "$RESULTS_DIR/avc-after-context.txt"
    echo ""
fi

# 检查AVC拒绝
echo "步骤 7: 检查AVC拒绝..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ $AUDIT_AVAILABLE -eq 1 ]]; then
    echo "查找测试期间的AVC拒绝..."
    echo ""

    # 使用时间戳查找
    ausearch -m avc -ts $(date -d "@$TEST_START_TIME" +"%m/%d/%Y %H:%M:%S") 2>/dev/null | tee "$RESULTS_DIR/avc-denials.txt"

    if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
        DENIAL_COUNT=$(ausearch -m avc -ts $(date -d "@$TEST_START_TIME" +"%m/%d/%Y %H:%M:%S") 2>/dev/null | grep -c "type=AVC")
        echo ""
        echo "发现 $DENIAL_COUNT 条AVC拒绝记录"
    else
        echo "✓ 未发现AVC拒绝"
    fi
else
    echo "从dmesg查找AVC消息..."
    dmesg | grep -i "avc.*denied" | tail -20 | tee "$RESULTS_DIR/avc-dmesg.txt"

    if [[ ${PIPESTATUS[1]} -eq 0 ]]; then
        echo ""
        echo "发现AVC拒绝记录（显示最近20条）"
    else
        echo ""
        echo "✓ 未发现AVC拒绝"
    fi
fi

echo ""

# AVC统计分析
if [[ $AVC_AVAILABLE -eq 1 ]]; then
    echo "步骤 8: AVC统计分析..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    echo "最终AVC统计:"
    cat "$AVC_STATS_PATH" | tee "$RESULTS_DIR/avc-final.txt"
    echo ""

    # 解析AVC统计
    {
        echo "AVC统计分析"
        echo "========================================"
        echo ""
        echo "原始数据:"
        cat "$AVC_STATS_PATH"
        echo ""
        echo "说明:"
        echo "  lookups   - 查找次数"
        echo "  hits      - 缓存命中"
        echo "  misses    - 缓存未命中"
        echo "  allocations - 分配次数"
        echo "  reclaims  - 回收次数"
        echo "  frees     - 释放次数"
        echo ""
    } > "$RESULTS_DIR/avc-analysis.txt"

    cat "$RESULTS_DIR/avc-analysis.txt"
fi

# 生成总结报告
{
    echo "AVC测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo ""
    echo "系统信息:"
    echo "  SELinux状态: $SELINUX_ENABLED"
    echo "  SELinux模式: $SELINUX_MODE"
    echo "  AVC接口: $([[ $AVC_AVAILABLE -eq 1 ]] && echo '可用' || echo '不可用')"
    echo "  审计工具: $([[ $AUDIT_AVAILABLE -eq 1 ]] && echo '可用' || echo '不可用')"
    echo ""
    echo "测试项目:"
    echo "  ✓ AVC查询性能测试 (1000次)"
    echo "  ✓ 多文件访问测试 (100个文件)"
    echo "  ✓ 上下文切换测试"
    echo "  ✓ AVC拒绝检查"
    if [[ $AVC_AVAILABLE -eq 1 ]]; then
        echo "  ✓ AVC统计分析"
    fi
    echo ""
    echo "性能数据:"
    echo "  单文件重复访问: ${avg_time}s/次"
    echo "  多文件访问: $(echo "scale=6; $duration / 100" | bc)s/文件"
    echo ""
    echo "详细日志:"
    if [[ $AVC_AVAILABLE -eq 1 ]]; then
        echo "  初始统计: $RESULTS_DIR/avc-initial.txt"
        echo "  查询后统计: $RESULTS_DIR/avc-after-query.txt"
        echo "  多文件后统计: $RESULTS_DIR/avc-after-multifile.txt"
        echo "  上下文后统计: $RESULTS_DIR/avc-after-context.txt"
        echo "  最终统计: $RESULTS_DIR/avc-final.txt"
        echo "  统计分析: $RESULTS_DIR/avc-analysis.txt"
    fi
    echo "  上下文切换: $RESULTS_DIR/context-switch.txt"
    if [[ $AUDIT_AVAILABLE -eq 1 ]]; then
        echo "  AVC拒绝: $RESULTS_DIR/avc-denials.txt"
    else
        echo "  dmesg AVC: $RESULTS_DIR/avc-dmesg.txt"
    fi
    echo ""
} | tee "$RESULTS_DIR/summary.txt"

echo "========================================"
echo "测试完成"
echo "========================================"
echo ""
echo "✓ AVC测试完成"
echo ""
echo "结果目录: $RESULTS_DIR"
echo ""
