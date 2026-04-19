#!/bin/bash
# test_stack_protection.sh - 栈保护和CFI测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results/stack-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "栈保护和CFI测试"
echo "========================================"
echo ""

# 检查权限
if [[ $EUID -ne 0 ]]; then
   echo "错误: 此脚本需要 root 权限"
   echo "使用: sudo $0"
   exit 1
fi

mkdir -p "$RESULTS_DIR"

# 检查内核栈保护
echo "步骤 1: 检查内核栈保护配置..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ -f /proc/config.gz ]]; then
    CONFIG_FILE="/proc/config.gz"
    CONFIG_CMD="zcat $CONFIG_FILE"
elif [[ -f /boot/config-$(uname -r) ]]; then
    CONFIG_FILE="/boot/config-$(uname -r)"
    CONFIG_CMD="cat $CONFIG_FILE"
else
    echo "✗ 无法找到内核配置文件"
    CONFIG_FILE=""
fi

if [[ -n "$CONFIG_FILE" ]]; then
    echo "检查CONFIG_STACKPROTECTOR相关选项:"
    $CONFIG_CMD | grep "CONFIG_STACKPROTECTOR" | tee "$RESULTS_DIR/stack-config.txt"

    echo ""
    echo "解释:"
    if $CONFIG_CMD | grep -q "CONFIG_STACKPROTECTOR_STRONG=y"; then
        echo "  ✓ CONFIG_STACKPROTECTOR_STRONG=y (推荐)"
        echo "    - 保护所有有缓冲区或地址引用的函数"
        STACK_STRONG=1
    elif $CONFIG_CMD | grep -q "CONFIG_STACKPROTECTOR=y"; then
        echo "  ⚠ CONFIG_STACKPROTECTOR=y (基础保护)"
        echo "    - 仅保护部分函数"
        STACK_STRONG=0
    else
        echo "  ✗ 栈保护未启用"
        STACK_STRONG=0
    fi
fi

echo ""

# 检查CFI
echo "步骤 2: 检查CFI (Control Flow Integrity)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ -n "$CONFIG_FILE" ]]; then
    echo "检查CFI相关配置:"
    $CONFIG_CMD | grep -E "CONFIG_CFI|CONFIG_SHADOW_CALL_STACK" | tee "$RESULTS_DIR/cfi-config.txt"

    echo ""
    if $CONFIG_CMD | grep -q "CONFIG_CFI_CLANG=y"; then
        echo "  ✓ CONFIG_CFI_CLANG=y (Clang CFI)"
        CFI_ENABLED=1
    elif $CONFIG_CMD | grep -q "CONFIG_SHADOW_CALL_STACK=y"; then
        echo "  ✓ CONFIG_SHADOW_CALL_STACK=y (影子栈)"
        CFI_ENABLED=1
    else
        echo "  ⚠ CFI未启用"
        CFI_ENABLED=0
    fi
fi

echo ""

# 检查CET (Control-flow Enforcement Technology)
echo "步骤 3: 检查Intel CET支持..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "检查CPU特性:"
if grep -qi "cet\|ibt\|shstk" /proc/cpuinfo; then
    echo "  ✓ CPU支持CET特性"
    grep -i "cet\|ibt\|shstk" /proc/cpuinfo | head -3
    CET_SUPPORTED=1
else
    echo "  ⚠ CPU不支持CET（需要Tiger Lake或更新的处理器）"
    CET_SUPPORTED=0
fi

echo ""

if [[ $CET_SUPPORTED -eq 1 ]]; then
    echo "CET特性说明:"
    echo "  - IBT (Indirect Branch Tracking): 间接分支跟踪"
    echo "  - Shadow Stack: 影子栈保护返回地址"
fi

echo ""

# 检查其他栈保护机制
echo "步骤 4: 其他栈保护机制..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ -n "$CONFIG_FILE" ]]; then
    echo "检查FORTIFY_SOURCE:"
    $CONFIG_CMD | grep "CONFIG_FORTIFY_SOURCE" | tee -a "$RESULTS_DIR/stack-config.txt"

    echo ""
    echo "检查VMAP栈:"
    $CONFIG_CMD | grep "CONFIG_VMAP_STACK" | tee -a "$RESULTS_DIR/stack-config.txt"

    echo ""
    echo "检查栈随机化:"
    $CONFIG_CMD | grep "CONFIG_RANDOMIZE_KSTACK_OFFSET" | tee -a "$RESULTS_DIR/stack-config.txt"
fi

echo ""

# 用户空间程序栈保护检查
echo "步骤 5: 用户空间栈保护检查..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 检查系统库
echo "检查系统关键库的保护:"
LIBS=("/lib/x86_64-linux-gnu/libc.so.6" "/lib64/libc.so.6" "/usr/lib/libc.so.6")

for lib in "${LIBS[@]}"; do
    if [[ -f "$lib" ]]; then
        echo ""
        echo "库: $lib"

        # 检查栈保护
        if readelf -s "$lib" 2>/dev/null | grep -q "__stack_chk_fail"; then
            echo "  ✓ 包含栈保护符号 (__stack_chk_fail)"
        else
            echo "  ⚠ 未发现栈保护符号"
        fi

        # 检查RELRO
        if readelf -l "$lib" 2>/dev/null | grep -q "GNU_RELRO"; then
            echo "  ✓ RELRO (重定位只读保护)"
        fi

        # 检查NX
        if readelf -l "$lib" 2>/dev/null | grep "GNU_STACK" | grep -q "RW"; then
            echo "  ✓ NX (栈不可执行)"
        fi

        break
    fi
done

echo ""

# 栈保护原理
echo "步骤 6: 栈保护原理..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "栈保护机制原理"
    echo "========================================"
    echo ""

    echo "Stack Canary (栈金丝雀):"
    echo "  - 在栈帧返回地址前插入随机值"
    echo "  - 函数返回前检查canary是否被修改"
    echo "  - 检测到修改则调用__stack_chk_fail()"
    echo "  - 防止栈溢出覆盖返回地址"
    echo ""

    echo "栈保护级别:"
    echo "  CONFIG_STACKPROTECTOR:"
    echo "    - 基础保护，仅保护部分函数"
    echo "  CONFIG_STACKPROTECTOR_STRONG:"
    echo "    - 强保护，保护所有有缓冲区的函数"
    echo "  CONFIG_STACKPROTECTOR_ALL:"
    echo "    - 全保护，保护所有函数（性能影响大）"
    echo ""

    echo "CFI (Control Flow Integrity):"
    echo "  - 验证间接调用目标的合法性"
    echo "  - 防止ROP/JOP攻击"
    echo "  - 包含前向边CFI和后向边CFI"
    echo ""

    echo "影子栈 (Shadow Stack):"
    echo "  - 单独的只读栈存储返回地址"
    echo "  - 函数返回时验证返回地址一致性"
    echo "  - 硬件支持：Intel CET, ARM PAC"
    echo ""

    echo "VMAP栈:"
    echo "  - 使用虚拟内存映射栈"
    echo "  - 栈前后有guard pages"
    echo "  - 检测栈溢出"
    echo ""

} | tee "$RESULTS_DIR/principles.txt"

# 已知绕过方法
echo "步骤 7: 绕过方法和缓解..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "栈保护绕过方法"
    echo "========================================"
    echo ""

    echo "常见绕过技术:"
    echo "  1. Canary泄漏 - 通过格式化字符串漏洞泄漏canary"
    echo "  2. Canary爆破 - 逐字节爆破canary值"
    echo "  3. 覆盖其他变量 - 跳过canary修改局部变量"
    echo "  4. 线程本地存储攻击 - 修改TLS中的canary值"
    echo ""

    echo "CFI绕过:"
    echo "  1. 代码重用攻击 - 使用合法的gadgets"
    echo "  2. 数据导向编程 - 修改数据而非控制流"
    echo ""

    echo "缓解措施:"
    echo "  - 使用ASLR增加猜测难度"
    echo "  - 启用RELRO防止GOT覆盖"
    echo "  - 使用CFI增强控制流保护"
    echo "  - 启用影子栈硬件支持"
    echo "  - 减少格式化字符串漏洞"
    echo ""

} | tee "$RESULTS_DIR/bypass-methods.txt"

echo ""

# 保护评估
echo "步骤 8: 保护状态评估..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "栈保护评估"
    echo "========================================"
    echo ""

    echo "内核保护:"
    if [[ $STACK_STRONG -eq 1 ]]; then
        echo "  ✓ 强栈保护已启用"
    else
        echo "  ⚠ 强栈保护未启用"
    fi

    if [[ $CFI_ENABLED -eq 1 ]]; then
        echo "  ✓ CFI已启用"
    else
        echo "  ⚠ CFI未启用"
    fi

    if [[ $CET_SUPPORTED -eq 1 ]]; then
        echo "  ✓ CPU支持CET"
    else
        echo "  ⚠ CPU不支持CET"
    fi

    echo ""
    echo "风险评估:"
    if [[ $STACK_STRONG -eq 0 ]] && [[ $CFI_ENABLED -eq 0 ]]; then
        echo "  ⚠ 高风险: 缺少栈保护和CFI"
        echo "    - 易受栈溢出攻击"
        echo "    - 易受ROP攻击"
    elif [[ $STACK_STRONG -eq 1 ]] && [[ $CFI_ENABLED -eq 0 ]]; then
        echo "  ⚠ 中等风险: 有栈保护但无CFI"
        echo "    - 对ROP攻击防护较弱"
    else
        echo "  ✓ 低风险: 完整的栈和控制流保护"
    fi

    echo ""
    echo "建议:"
    if [[ $STACK_STRONG -eq 0 ]]; then
        echo "  - 重新编译内核启用CONFIG_STACKPROTECTOR_STRONG"
    fi
    if [[ $CFI_ENABLED -eq 0 ]]; then
        echo "  - 考虑使用支持CFI的内核版本"
    fi
    if [[ $CET_SUPPORTED -eq 0 ]]; then
        echo "  - 考虑升级到支持CET的CPU（Tiger Lake+）"
    fi

} | tee "$RESULTS_DIR/assessment.txt"

echo ""

# 生成报告
{
    echo "栈保护和CFI测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo ""
    echo "系统信息:"
    echo "  内核版本: $(uname -r)"
    echo "  CPU: $(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
    echo ""
    echo "保护特性:"
    echo "  栈保护: $([[ $STACK_STRONG -eq 1 ]] && echo '强保护' || echo '基础/未启用')"
    echo "  CFI: $([[ $CFI_ENABLED -eq 1 ]] && echo '已启用' || echo '未启用')"
    echo "  CET支持: $([[ $CET_SUPPORTED -eq 1 ]] && echo '是' || echo '否')"
    echo ""
    echo "详细日志:"
    echo "  栈保护配置: $RESULTS_DIR/stack-config.txt"
    echo "  CFI配置: $RESULTS_DIR/cfi-config.txt"
    echo "  原理说明: $RESULTS_DIR/principles.txt"
    echo "  绕过方法: $RESULTS_DIR/bypass-methods.txt"
    echo "  评估报告: $RESULTS_DIR/assessment.txt"
    echo ""
} | tee "$RESULTS_DIR/summary.txt"

echo "========================================"
echo "测试完成"
echo "========================================"
echo ""
echo "✓ 栈保护和CFI测试完成"
echo ""
echo "结果目录: $RESULTS_DIR"
echo ""
