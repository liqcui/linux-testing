#!/bin/bash
# test_smep_smap.sh - SMEP/SMAP (Supervisor Mode Execution/Access Protection) 测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results/smep-smap-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "SMEP/SMAP 测试"
echo "========================================"
echo ""

# 检查权限
if [[ $EUID -ne 0 ]]; then
   echo "错误: 此脚本需要 root 权限"
   echo "使用: sudo $0"
   exit 1
fi

mkdir -p "$RESULTS_DIR"

# 检查CPU特性
echo "步骤 1: 检查CPU特性..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "CPU信息:"
grep "model name" /proc/cpuinfo | head -1 | tee "$RESULTS_DIR/cpu-info.txt"
echo ""

# 检查SMEP支持
echo "检查SMEP (Supervisor Mode Execution Prevention):"
if grep -q " smep " /proc/cpuinfo; then
    echo "  ✓ CPU支持SMEP"
    SMEP_SUPPORTED=1
else
    echo "  ✗ CPU不支持SMEP"
    SMEP_SUPPORTED=0
fi

grep "flags.*smep" /proc/cpuinfo | head -1 | tee "$RESULTS_DIR/smep-cpuinfo.txt"
echo ""

# 检查SMAP支持
echo "检查SMAP (Supervisor Mode Access Prevention):"
if grep -q " smap " /proc/cpuinfo; then
    echo "  ✓ CPU支持SMAP"
    SMAP_SUPPORTED=1
else
    echo "  ✗ CPU不支持SMAP"
    SMAP_SUPPORTED=0
fi

grep "flags.*smap" /proc/cpuinfo | head -1 | tee "$RESULTS_DIR/smap-cpuinfo.txt"
echo ""

# 检查内核配置
echo "步骤 2: 检查内核配置..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ -f /proc/config.gz ]]; then
    echo "检查SMEP/SMAP相关配置:"
    zcat /proc/config.gz | grep -E "CONFIG_X86_INTEL_MEMORY_PROTECTION|CONFIG_X86_SMAP" | tee "$RESULTS_DIR/kernel-config.txt"
elif [[ -f /boot/config-$(uname -r) ]]; then
    echo "检查SMEP/SMAP相关配置:"
    grep -E "CONFIG_X86_INTEL_MEMORY_PROTECTION|CONFIG_X86_SMAP" /boot/config-$(uname -r) | tee "$RESULTS_DIR/kernel-config.txt"
else
    echo "⚠ 无法找到内核配置文件"
fi

echo ""

# 检查内核命令行
echo "步骤 3: 检查内核命令行参数..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cat /proc/cmdline | tee "$RESULTS_DIR/cmdline.txt"
echo ""

SMEP_DISABLED=0
SMAP_DISABLED=0

if cat /proc/cmdline | grep -q "nosmep"; then
    echo "⚠ SMEP已通过nosmep参数禁用"
    SMEP_DISABLED=1
fi

if cat /proc/cmdline | grep -q "nosmap"; then
    echo "⚠ SMAP已通过nosmap参数禁用"
    SMAP_DISABLED=1
fi

if [[ $SMEP_DISABLED -eq 0 ]] && [[ $SMAP_DISABLED -eq 0 ]]; then
    echo "✓ 未发现禁用SMEP/SMAP的参数"
fi

echo ""

# 检查CR4寄存器状态（通过dmesg）
echo "步骤 4: 检查CR4寄存器状态..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "从dmesg中查找SMEP/SMAP信息:"
dmesg | grep -i "smep\|smap" | tee "$RESULTS_DIR/dmesg-smep-smap.txt"

if [[ $(dmesg | grep -c -i "smep\|smap") -eq 0 ]]; then
    echo "⚠ dmesg中未找到SMEP/SMAP信息"
fi

echo ""

# SMEP原理说明
echo "步骤 5: SMEP/SMAP原理..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "SMEP (Supervisor Mode Execution Prevention)"
    echo "========================================"
    echo ""
    echo "功能:"
    echo "  - 防止内核执行用户空间代码"
    echo "  - 通过CR4寄存器第20位控制"
    echo "  - 违反时触发Page Fault (#PF)"
    echo ""
    echo "攻击场景:"
    echo "  - 内核漏洞利用中的ret2usr攻击"
    echo "  - 通过内核漏洞跳转到用户空间shellcode"
    echo ""
    echo "绕过方法:"
    echo "  - ROP (Return-Oriented Programming)"
    echo "  - 修改CR4寄存器禁用SMEP"
    echo "  - 利用内核空间代码片段"
    echo ""

    echo "SMAP (Supervisor Mode Access Prevention)"
    echo "========================================"
    echo ""
    echo "功能:"
    echo "  - 防止内核访问用户空间数据"
    echo "  - 通过CR4寄存器第21位控制"
    echo "  - 违反时触发Page Fault (#PF)"
    echo ""
    echo "例外:"
    echo "  - EFLAGS.AC=1时允许访问（用于合法的用户空间访问）"
    echo "  - 使用STAC/CLAC指令控制AC位"
    echo ""
    echo "攻击场景:"
    echo "  - 内核通过指针访问用户控制的数据"
    echo "  - 信息泄漏攻击"
    echo ""

} | tee "$RESULTS_DIR/smep-smap-principles.txt"

# 检查其他内存保护特性
echo "步骤 6: 其他内存保护特性..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "检查NX (No-Execute) 位:"
if grep -q " nx " /proc/cpuinfo; then
    echo "  ✓ CPU支持NX"
else
    echo "  ✗ CPU不支持NX"
fi

echo ""
echo "检查PXN (Privileged Execute Never) - ARM:"
if grep -q "pxn" /proc/cpuinfo; then
    echo "  ✓ CPU支持PXN"
else
    echo "  ⚠ CPU不支持PXN（或非ARM架构）"
fi

echo ""
echo "检查UMIP (User Mode Instruction Prevention):"
if grep -q " umip " /proc/cpuinfo; then
    echo "  ✓ CPU支持UMIP"
else
    echo "  ⚠ CPU不支持UMIP"
fi

echo ""

# 保护状态评估
echo "步骤 7: 保护状态评估..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "内存保护特性评估"
    echo "========================================"
    echo ""

    echo "CPU支持:"
    echo "  SMEP: $([[ $SMEP_SUPPORTED -eq 1 ]] && echo '✓ 支持' || echo '✗ 不支持')"
    echo "  SMAP: $([[ $SMAP_SUPPORTED -eq 1 ]] && echo '✓ 支持' || echo '✗ 不支持')"
    echo "  NX:   $(grep -q ' nx ' /proc/cpuinfo && echo '✓ 支持' || echo '✗ 不支持')"
    echo "  UMIP: $(grep -q ' umip ' /proc/cpuinfo && echo '✓ 支持' || echo '⚠ 不支持')"
    echo ""

    echo "内核启用状态:"
    if [[ $SMEP_SUPPORTED -eq 1 ]] && [[ $SMEP_DISABLED -eq 0 ]]; then
        echo "  SMEP: ✓ 启用"
    elif [[ $SMEP_SUPPORTED -eq 1 ]] && [[ $SMEP_DISABLED -eq 1 ]]; then
        echo "  SMEP: ✗ 已禁用（高风险）"
    else
        echo "  SMEP: - CPU不支持"
    fi

    if [[ $SMAP_SUPPORTED -eq 1 ]] && [[ $SMAP_DISABLED -eq 0 ]]; then
        echo "  SMAP: ✓ 启用"
    elif [[ $SMAP_SUPPORTED -eq 1 ]] && [[ $SMAP_DISABLED -eq 1 ]]; then
        echo "  SMAP: ✗ 已禁用（高风险）"
    else
        echo "  SMAP: - CPU不支持"
    fi

    echo ""
    echo "风险评估:"
    if [[ $SMEP_SUPPORTED -eq 0 ]] && [[ $SMAP_SUPPORTED -eq 0 ]]; then
        echo "  ⚠ 严重: CPU不支持SMEP/SMAP"
        echo "    - 易受ret2usr攻击"
        echo "    - 易受用户空间数据访问攻击"
    elif [[ $SMEP_DISABLED -eq 1 ]] || [[ $SMAP_DISABLED -eq 1 ]]; then
        echo "  ⚠ 高风险: SMEP/SMAP已禁用"
        echo "    - 建议从内核命令行移除nosmep/nosmap"
    else
        echo "  ✓ 低风险: SMEP/SMAP都已启用"
    fi

    echo ""
    echo "建议:"
    if [[ $SMEP_DISABLED -eq 1 ]]; then
        echo "  - 从/etc/default/grub移除nosmep参数"
    fi
    if [[ $SMAP_DISABLED -eq 1 ]]; then
        echo "  - 从/etc/default/grub移除nosmap参数"
    fi
    if [[ $SMEP_SUPPORTED -eq 0 ]] || [[ $SMAP_SUPPORTED -eq 0 ]]; then
        echo "  - 考虑升级到支持SMEP/SMAP的CPU（Ivy Bridge+/Broadwell+）"
    fi

} | tee "$RESULTS_DIR/protection-assessment.txt"

echo ""

# 检查已知绕过缓解措施
echo "步骤 8: 绕过缓解措施..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "SMEP/SMAP绕过缓解"
    echo "========================================"
    echo ""

    echo "常见绕过技术:"
    echo "  1. CR4寄存器修改 - 通过ROP修改CR4禁用SMEP/SMAP"
    echo "  2. Ret2dir - 利用物理内存映射"
    echo "  3. JOP (Jump-Oriented Programming)"
    echo ""

    echo "额外缓解措施:"
    echo ""

    # 检查KPTI
    if grep -q "pti" /proc/cpuinfo || dmesg | grep -q "page.*table.*isolation"; then
        echo "  ✓ KPTI (页表隔离) 已启用"
        echo "    - 缓解用户空间页表操作"
    else
        echo "  ⚠ KPTI未启用或不支持"
    fi

    echo ""

    # 检查CFI
    if [[ -f /proc/config.gz ]]; then
        if zcat /proc/config.gz | grep -q "CONFIG_CFI_CLANG=y"; then
            echo "  ✓ CFI (控制流完整性) 已启用"
        else
            echo "  ⚠ CFI未启用"
        fi
    fi

    echo ""

    # 检查栈保护
    if [[ -f /proc/config.gz ]]; then
        STACK_PROT=$(zcat /proc/config.gz | grep "CONFIG_STACKPROTECTOR_STRONG")
        if [[ -n "$STACK_PROT" ]]; then
            echo "  ✓ 栈保护已启用"
            echo "    $STACK_PROT"
        fi
    fi

} | tee "$RESULTS_DIR/bypass-mitigation.txt"

echo ""

# 生成报告
{
    echo "SMEP/SMAP测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo ""
    echo "系统信息:"
    echo "  内核版本: $(uname -r)"
    echo "  CPU: $(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
    echo ""
    echo "CPU特性:"
    echo "  SMEP支持: $([[ $SMEP_SUPPORTED -eq 1 ]] && echo '是' || echo '否')"
    echo "  SMAP支持: $([[ $SMAP_SUPPORTED -eq 1 ]] && echo '是' || echo '否')"
    echo ""
    echo "内核状态:"
    echo "  SMEP: $([[ $SMEP_DISABLED -eq 0 ]] && echo '启用' || echo '禁用')"
    echo "  SMAP: $([[ $SMAP_DISABLED -eq 0 ]] && echo '启用' || echo '禁用')"
    echo ""
    echo "详细日志:"
    echo "  CPU信息: $RESULTS_DIR/cpu-info.txt"
    echo "  SMEP CPU标志: $RESULTS_DIR/smep-cpuinfo.txt"
    echo "  SMAP CPU标志: $RESULTS_DIR/smap-cpuinfo.txt"
    echo "  内核配置: $RESULTS_DIR/kernel-config.txt"
    echo "  dmesg日志: $RESULTS_DIR/dmesg-smep-smap.txt"
    echo "  原理说明: $RESULTS_DIR/smep-smap-principles.txt"
    echo "  防护评估: $RESULTS_DIR/protection-assessment.txt"
    echo "  绕过缓解: $RESULTS_DIR/bypass-mitigation.txt"
    echo ""
} | tee "$RESULTS_DIR/summary.txt"

echo "========================================"
echo "测试完成"
echo "========================================"
echo ""
echo "✓ SMEP/SMAP测试完成"
echo ""
echo "结果目录: $RESULTS_DIR"
echo ""
