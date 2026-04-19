#!/bin/bash
# test_kaslr.sh - KASLR (Kernel Address Space Layout Randomization) 测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results/kaslr-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "KASLR 测试"
echo "========================================"
echo ""

# 检查权限
if [[ $EUID -ne 0 ]]; then
   echo "错误: 此脚本需要 root 权限"
   echo "使用: sudo $0"
   exit 1
fi

mkdir -p "$RESULTS_DIR"

# 检查KASLR状态
echo "步骤 1: 检查KASLR启用状态..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "内核命令行参数:"
cat /proc/cmdline | tee "$RESULTS_DIR/cmdline.txt"
echo ""

KASLR_DISABLED=0
if cat /proc/cmdline | grep -q "nokaslr"; then
    echo "✗ KASLR已禁用（发现nokaslr参数）"
    KASLR_DISABLED=1
elif cat /proc/cmdline | grep -q "kaslr"; then
    echo "✓ KASLR已显式启用"
else
    echo "⚠ 未发现KASLR相关参数（可能使用默认配置）"
fi

echo ""

# 检查dmesg中的KASLR信息
echo "dmesg中的KASLR信息:"
dmesg | grep -i kaslr | tee "$RESULTS_DIR/dmesg-kaslr.txt"

if [[ $(dmesg | grep -c -i kaslr) -eq 0 ]]; then
    echo "⚠ dmesg中未找到KASLR信息"
else
    echo ""
fi

echo ""

# 检查内核配置
echo "步骤 2: 检查内核配置..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ -f /proc/config.gz ]]; then
    echo "检查CONFIG_RANDOMIZE_BASE:"
    zcat /proc/config.gz | grep "CONFIG_RANDOMIZE_BASE" | tee "$RESULTS_DIR/kernel-config.txt"

    echo ""
    echo "其他相关配置:"
    zcat /proc/config.gz | grep -E "CONFIG_RANDOMIZE|CONFIG_RELOCATABLE" | tee -a "$RESULTS_DIR/kernel-config.txt"
elif [[ -f /boot/config-$(uname -r) ]]; then
    echo "检查CONFIG_RANDOMIZE_BASE:"
    grep "CONFIG_RANDOMIZE_BASE" /boot/config-$(uname -r) | tee "$RESULTS_DIR/kernel-config.txt"

    echo ""
    echo "其他相关配置:"
    grep -E "CONFIG_RANDOMIZE|CONFIG_RELOCATABLE" /boot/config-$(uname -r) | tee -a "$RESULTS_DIR/kernel-config.txt"
else
    echo "⚠ 无法找到内核配置文件"
fi

echo ""

# 查看内核符号地址
echo "步骤 3: 查看内核符号地址..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ -f /proc/kallsyms ]]; then
    echo "内核符号示例（_text, _stext）:"
    grep -E "^\w+ [Tt] _s?text$" /proc/kallsyms | tee "$RESULTS_DIR/kernel-symbols.txt"

    TEXT_ADDR=$(grep "T _text$" /proc/kallsyms | awk '{print $1}')
    STEXT_ADDR=$(grep "T _stext$" /proc/kallsyms | awk '{print $1}')

    echo ""
    echo "_text地址: 0x$TEXT_ADDR"
    echo "_stext地址: 0x$STEXT_ADDR"

    # 检查地址范围
    if [[ "$TEXT_ADDR" =~ ^ffffffff8 ]]; then
        echo ""
        echo "✓ 内核地址在高地址空间（0xffffffff8xxxxxxx）"
    elif [[ "$TEXT_ADDR" =~ ^00000000 ]]; then
        echo ""
        echo "⚠ 内核符号地址全为0（可能被保护）"
    fi
else
    echo "✗ /proc/kallsyms 不可访问"
fi

echo ""

# 检查kptr_restrict
echo "步骤 4: 检查指针限制..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ -f /proc/sys/kernel/kptr_restrict ]]; then
    KPTR_VALUE=$(cat /proc/sys/kernel/kptr_restrict)
    echo "kptr_restrict值: $KPTR_VALUE"

    case $KPTR_VALUE in
        0)
            echo "  0 = 禁用（内核指针可见）"
            ;;
        1)
            echo "  1 = 部分隐藏（非特权用户无法查看）"
            ;;
        2)
            echo "  2 = 完全隐藏（所有用户无法查看）"
            ;;
    esac
else
    echo "⚠ kptr_restrict不可用"
fi

echo ""

# 检查dmesg_restrict
if [[ -f /proc/sys/kernel/dmesg_restrict ]]; then
    DMESG_VALUE=$(cat /proc/sys/kernel/dmesg_restrict)
    echo "dmesg_restrict值: $DMESG_VALUE"

    case $DMESG_VALUE in
        0)
            echo "  0 = 所有用户可读取dmesg"
            ;;
        1)
            echo "  1 = 仅特权用户可读取"
            ;;
    esac
else
    echo "⚠ dmesg_restrict不可用"
fi

echo ""

# 内存布局分析
echo "步骤 5: 内存布局分析..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ -f /proc/iomem ]]; then
    echo "物理内存布局（内核部分）:"
    grep -E "Kernel|kernel" /proc/iomem | tee "$RESULTS_DIR/iomem.txt"
else
    echo "⚠ /proc/iomem不可访问"
fi

echo ""

# 虚拟内存布局
echo "虚拟内存区域示例:"
cat /proc/self/maps | head -10 | tee "$RESULTS_DIR/maps-example.txt"
echo "..."

echo ""

# 模拟地址泄漏攻击
echo "步骤 6: 模拟地址泄漏场景..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "地址泄漏测试"
    echo "========================================"
    echo ""

    # 尝试读取内核符号
    echo "尝试读取内核符号地址:"
    if grep -q "0000000000000000" /proc/kallsyms 2>/dev/null; then
        echo "  ✓ 内核符号被保护（显示为0）"
    else
        echo "  ⚠ 内核符号可见"
        grep "T _text$" /proc/kallsyms 2>/dev/null || echo "  无法读取_text"
    fi

    echo ""

    # 检查模块地址
    echo "内核模块地址:"
    if [[ -f /proc/modules ]]; then
        head -5 /proc/modules
    fi

    echo ""

    # 检查系统调用表
    echo "系统调用表地址:"
    grep "sys_call_table" /proc/kallsyms 2>/dev/null || echo "  无法读取sys_call_table"

} | tee "$RESULTS_DIR/address-leak.txt"

echo ""

# KASLR熵值估算
echo "步骤 7: KASLR熵值分析..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ -n "$TEXT_ADDR" ]] && [[ ! "$TEXT_ADDR" =~ ^00000000 ]]; then
    # 提取随机化部分（假设基址为0xffffffff80000000）
    BASE="ffffffff80000000"
    echo "假设基址: 0x$BASE"
    echo "实际_text: 0x$TEXT_ADDR"

    # 计算偏移
    OFFSET=$((16#$TEXT_ADDR - 16#$BASE))
    echo "偏移量: 0x$(printf '%x' $OFFSET)"

    echo ""
    echo "分析:"
    echo "  - 内核通常按2MB对齐"
    echo "  - x86_64架构KASLR熵约为9-10位"
    echo "  - 可能的地址空间约512-1024个位置"
else
    echo "⚠ 无法计算KASLR熵（地址不可见或为0）"
fi

echo ""

# 绕过KASLR的方法
echo "步骤 8: KASLR防护评估..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "KASLR防护评估"
    echo "========================================"
    echo ""

    echo "已知的KASLR绕过技术:"
    echo "  1. 内核信息泄漏（/proc/kallsyms, dmesg等）"
    echo "  2. 侧信道攻击（缓存时序攻击）"
    echo "  3. 物理内存读取"
    echo "  4. 内核模块加载地址泄漏"
    echo ""

    echo "当前系统防护:"
    if [[ $KPTR_VALUE -ge 1 ]]; then
        echo "  ✓ kptr_restrict启用"
    else
        echo "  ✗ kptr_restrict禁用（高风险）"
    fi

    if [[ $(cat /proc/sys/kernel/dmesg_restrict 2>/dev/null) -eq 1 ]]; then
        echo "  ✓ dmesg_restrict启用"
    else
        echo "  ✗ dmesg_restrict禁用"
    fi

    if [[ $KASLR_DISABLED -eq 0 ]]; then
        echo "  ✓ KASLR启用"
    else
        echo "  ✗ KASLR禁用（严重风险）"
    fi

    echo ""
    echo "建议:"
    if [[ $KPTR_VALUE -lt 2 ]]; then
        echo "  - 设置 sysctl kernel.kptr_restrict=2"
    fi
    if [[ $(cat /proc/sys/kernel/dmesg_restrict 2>/dev/null) -ne 1 ]]; then
        echo "  - 设置 sysctl kernel.dmesg_restrict=1"
    fi
    if [[ $KASLR_DISABLED -eq 1 ]]; then
        echo "  - 从内核命令行移除nokaslr参数"
    fi

} | tee "$RESULTS_DIR/protection-assessment.txt"

echo ""

# 生成报告
{
    echo "KASLR测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo ""
    echo "系统信息:"
    echo "  内核版本: $(uname -r)"
    echo "  架构: $(uname -m)"
    echo ""
    echo "KASLR状态:"
    if [[ $KASLR_DISABLED -eq 1 ]]; then
        echo "  状态: ✗ 禁用"
    else
        echo "  状态: ✓ 启用"
    fi
    if [[ -n "$TEXT_ADDR" ]] && [[ ! "$TEXT_ADDR" =~ ^00000000 ]]; then
        echo "  _text地址: 0x$TEXT_ADDR"
    else
        echo "  _text地址: 不可见（受保护）"
    fi
    echo ""
    echo "保护设置:"
    echo "  kptr_restrict: ${KPTR_VALUE:-未知}"
    echo "  dmesg_restrict: $(cat /proc/sys/kernel/dmesg_restrict 2>/dev/null || echo '未知')"
    echo ""
    echo "风险评估:"
    if [[ $KASLR_DISABLED -eq 1 ]]; then
        echo "  ⚠ 高风险: KASLR已禁用"
    elif [[ $KPTR_VALUE -eq 0 ]]; then
        echo "  ⚠ 中等风险: 内核指针未保护"
    else
        echo "  ✓ 低风险: KASLR和指针保护都已启用"
    fi
    echo ""
    echo "详细日志:"
    echo "  命令行: $RESULTS_DIR/cmdline.txt"
    echo "  dmesg: $RESULTS_DIR/dmesg-kaslr.txt"
    echo "  内核配置: $RESULTS_DIR/kernel-config.txt"
    echo "  内核符号: $RESULTS_DIR/kernel-symbols.txt"
    echo "  地址泄漏测试: $RESULTS_DIR/address-leak.txt"
    echo "  防护评估: $RESULTS_DIR/protection-assessment.txt"
    echo ""
} | tee "$RESULTS_DIR/summary.txt"

echo "========================================"
echo "测试完成"
echo "========================================"
echo ""
echo "✓ KASLR测试完成"
echo ""
echo "结果目录: $RESULTS_DIR"
echo ""
