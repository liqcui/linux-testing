#!/bin/bash
# test_mls.sh - SELinux MLS/MCS (多级安全/多类别安全) 测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results/mls-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "SELinux MLS/MCS 测试"
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
echo "步骤 1: 检查SELinux和MLS状态..."
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
    echo "✗ SELinux未启用，无法进行MLS测试"
    exit 1
fi

# 检查MLS支持
echo "检查MLS支持..."
sestatus -v | tee "$RESULTS_DIR/sestatus.txt"
echo ""

POLICY_TYPE=$(sestatus | grep "Loaded policy name" | awk '{print $4}')
echo "策略类型: $POLICY_TYPE"

MLS_ENABLED=0
if [[ "$POLICY_TYPE" == "mls" ]]; then
    echo "✓ MLS策略已启用"
    MLS_ENABLED=1
elif [[ "$POLICY_TYPE" == "targeted" ]]; then
    echo "⚠ 当前使用targeted策略（支持MCS但不是完整MLS）"
    echo ""
    echo "MCS (Multi-Category Security) 是 MLS 的简化版本"
    echo "仅支持类别(categories)，不支持多级别(levels)"
    MLS_ENABLED=0
else
    echo "⚠ 当前策略: $POLICY_TYPE"
    echo "不确定是否支持MLS/MCS"
    MLS_ENABLED=0
fi

echo ""

# 检查当前上下文的敏感度级别
echo "步骤 2: 检查当前上下文..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

CURRENT_CONTEXT=$(id -Z 2>/dev/null)
echo "当前进程上下文: $CURRENT_CONTEXT"
echo ""

# 解析上下文
IFS=':' read -ra CONTEXT_PARTS <<< "$CURRENT_CONTEXT"
if [[ ${#CONTEXT_PARTS[@]} -ge 4 ]]; then
    echo "上下文组成:"
    echo "  用户: ${CONTEXT_PARTS[0]}"
    echo "  角色: ${CONTEXT_PARTS[1]}"
    echo "  类型: ${CONTEXT_PARTS[2]}"
    echo "  级别: ${CONTEXT_PARTS[3]}"
else
    echo "⚠ 无法解析上下文"
fi

echo ""

# 创建测试文件
echo "步骤 3: 创建测试文件..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

TEST_DIR="/tmp/mls_test_$$"
mkdir -p "$TEST_DIR"

echo "测试目录: $TEST_DIR"
echo ""

# 创建不同级别的测试文件
echo "创建测试文件..."

echo "低级别数据" > "$TEST_DIR/low_data"
echo "中级别数据" > "$TEST_DIR/medium_data"
echo "高级别数据" > "$TEST_DIR/high_data"

echo "✓ 已创建测试文件"
echo ""

# 显示文件上下文
echo "文件初始上下文:"
ls -Z "$TEST_DIR"
echo ""

# MCS类别测试
echo "步骤 4: MCS类别测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if command -v chcat &> /dev/null; then
    echo "✓ chcat工具可用"

    # 尝试设置类别
    echo "设置文件类别..."

    chcat -l -- +c0 "$TEST_DIR/low_data" 2>&1
    chcat -l -- +c50 "$TEST_DIR/medium_data" 2>&1
    chcat -l -- +c100 "$TEST_DIR/high_data" 2>&1

    echo ""
    echo "设置类别后的文件上下文:"
    ls -Z "$TEST_DIR"
else
    echo "⚠ chcat工具不可用"
    echo ""
    echo "安装命令:"
    echo "  RHEL/CentOS/Fedora: sudo yum install policycoreutils-python-utils"
fi

echo ""

# runcon测试
echo "步骤 5: runcon上下文切换测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "runcon测试结果"
    echo "========================================"
    echo ""
} > "$RESULTS_DIR/runcon-tests.txt"

# 测试不同级别的访问
TEST_CONTEXTS=(
    "s0:c0"
    "s0:c50"
    "s0:c100"
    "s0"
)

for level in "${TEST_CONTEXTS[@]}"; do
    echo "测试级别: $level"
    echo ""

    # 尝试读取低级别文件
    echo "  读取 low_data..."
    runcon -l "$level" cat "$TEST_DIR/low_data" > /dev/null 2>&1
    result=$?
    if [[ $result -eq 0 ]]; then
        echo "    ✓ 成功"
    else
        echo "    ✗ 失败 (返回码: $result)"
    fi

    # 尝试读取中级别文件
    echo "  读取 medium_data..."
    runcon -l "$level" cat "$TEST_DIR/medium_data" > /dev/null 2>&1
    result=$?
    if [[ $result -eq 0 ]]; then
        echo "    ✓ 成功"
    else
        echo "    ✗ 失败 (返回码: $result)"
    fi

    # 尝试读取高级别文件
    echo "  读取 high_data..."
    runcon -l "$level" cat "$TEST_DIR/high_data" > /dev/null 2>&1
    result=$?
    if [[ $result -eq 0 ]]; then
        echo "    ✓ 成功"
    else
        echo "    ✗ 失败 (返回码: $result)"
    fi

    {
        echo "级别: $level"
        echo "  low_data: $([[ $result -eq 0 ]] && echo '成功' || echo '失败')"
        echo "  medium_data: $([[ $result -eq 0 ]] && echo '成功' || echo '失败')"
        echo "  high_data: $([[ $result -eq 0 ]] && echo '成功' || echo '失败')"
        echo ""
    } >> "$RESULTS_DIR/runcon-tests.txt"

    echo ""
done

# 信息流控制测试
echo "步骤 6: 信息流控制测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "测试场景: 低级别进程写入高级别文件"
echo ""

# 尝试从低级别写入高级别
runcon -l s0:c0 sh -c "echo '尝试写入' >> $TEST_DIR/high_data" 2>&1
result=$?

if [[ $result -eq 0 ]]; then
    echo "⚠ 写入成功（可能违反信息流控制）"
else
    echo "✓ 写入失败（符合信息流控制策略）"
fi

echo ""

echo "测试场景: 高级别进程读取低级别文件"
echo ""

# 尝试从高级别读取低级别
runcon -l s0:c100 cat "$TEST_DIR/low_data" > /dev/null 2>&1
result=$?

if [[ $result -eq 0 ]]; then
    echo "✓ 读取成功（向下读取通常允许）"
else
    echo "⚠ 读取失败"
fi

echo ""

# 检查AVC拒绝
echo "步骤 7: 检查AVC拒绝..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if command -v ausearch &> /dev/null; then
    echo "查找MLS相关的AVC拒绝..."
    ausearch -m avc -ts recent 2>/dev/null | grep -i "mls\|mcs\|category\|sensitivity" | tee "$RESULTS_DIR/mls-avc.txt"

    if [[ ${PIPESTATUS[1]} -eq 0 ]]; then
        echo ""
        echo "发现MLS/MCS相关的AVC记录"
    else
        echo "✓ 未发现MLS/MCS相关的AVC拒绝"
    fi
else
    echo "从dmesg查找MLS相关消息..."
    dmesg | grep -i "avc.*denied" | grep -i "mls\|mcs\|category" | tail -20 | tee "$RESULTS_DIR/mls-dmesg.txt"

    if [[ ${PIPESTATUS[1]} -eq 0 ]]; then
        echo ""
        echo "发现MLS相关的AVC记录"
    else
        echo ""
        echo "✓ 未发现MLS相关的AVC拒绝"
    fi
fi

echo ""

# 类别范围测试
echo "步骤 8: 类别范围测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "测试类别范围访问..."
echo ""

# 测试范围
RANGES=(
    "s0:c0.c10"     # 类别0-10
    "s0:c0.c50"     # 类别0-50
    "s0:c0.c100"    # 类别0-100
)

for range in "${RANGES[@]}"; do
    echo "测试范围: $range"

    runcon -l "$range" cat "$TEST_DIR/low_data" > /dev/null 2>&1
    result=$?

    if [[ $result -eq 0 ]]; then
        echo "  ✓ 访问成功"
    else
        echo "  ✗ 访问失败 (返回码: $result)"
    fi
done

echo ""

# 清理测试文件
echo "清理测试文件..."
rm -rf "$TEST_DIR"
echo "✓ 清理完成"
echo ""

# 生成总结报告
{
    echo "MLS/MCS测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo ""
    echo "系统信息:"
    echo "  SELinux状态: $SELINUX_ENABLED"
    echo "  SELinux模式: $SELINUX_MODE"
    echo "  策略类型: $POLICY_TYPE"
    echo "  MLS支持: $([[ $MLS_ENABLED -eq 1 ]] && echo '是' || echo '否（仅MCS）')"
    echo ""
    echo "当前上下文: $CURRENT_CONTEXT"
    echo ""
    echo "测试项目:"
    echo "  ✓ 上下文检查"
    echo "  ✓ 文件类别设置"
    echo "  ✓ runcon上下文切换"
    echo "  ✓ 信息流控制验证"
    echo "  ✓ 类别范围测试"
    echo "  ✓ AVC拒绝检查"
    echo ""
    if [[ $MLS_ENABLED -eq 0 ]]; then
        echo "注意事项:"
        echo "  当前系统使用 $POLICY_TYPE 策略"
        if [[ "$POLICY_TYPE" == "targeted" ]]; then
            echo "  - 支持MCS (Multi-Category Security)"
            echo "  - 不支持完整的MLS (Multi-Level Security)"
            echo "  - 若需完整MLS，需要安装并启用MLS策略包"
        fi
        echo ""
        echo "启用MLS策略:"
        echo "  1. 安装: sudo yum install selinux-policy-mls"
        echo "  2. 配置: 编辑 /etc/selinux/config，设置 SELINUXTYPE=mls"
        echo "  3. 重新标记: sudo touch /.autorelabel"
        echo "  4. 重启系统"
        echo ""
    fi
    echo "详细日志:"
    echo "  SELinux状态: $RESULTS_DIR/sestatus.txt"
    echo "  runcon测试: $RESULTS_DIR/runcon-tests.txt"
    if command -v ausearch &> /dev/null; then
        echo "  MLS AVC: $RESULTS_DIR/mls-avc.txt"
    else
        echo "  dmesg AVC: $RESULTS_DIR/mls-dmesg.txt"
    fi
    echo ""
} | tee "$RESULTS_DIR/summary.txt"

echo "========================================"
echo "测试完成"
echo "========================================"
echo ""

if [[ $MLS_ENABLED -eq 1 ]]; then
    echo "✓ MLS测试完成"
else
    echo "✓ MCS测试完成（当前策略不支持完整MLS）"
fi

echo ""
echo "结果目录: $RESULTS_DIR"
echo ""
