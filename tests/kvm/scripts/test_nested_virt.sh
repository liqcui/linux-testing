#!/bin/bash
# test_nested_virt.sh - 嵌套虚拟化测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results/nested-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "嵌套虚拟化测试"
echo "========================================"
echo ""

# 检查权限
if [[ $EUID -ne 0 ]]; then
   echo "错误: 此脚本需要 root 权限"
   echo "使用: sudo $0"
   exit 1
fi

mkdir -p "$RESULTS_DIR"

# 检查CPU虚拟化支持
echo "步骤 1: 检查嵌套虚拟化支持..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

CPU_VENDOR=$(grep "vendor_id" /proc/cpuinfo | head -1 | awk '{print $3}')

if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
    KVM_MODULE="kvm_intel"
    NESTED_PARAM="nested"
elif [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
    KVM_MODULE="kvm_amd"
    NESTED_PARAM="nested"
else
    echo "✗ 未知CPU厂商: $CPU_VENDOR"
    exit 1
fi

echo "CPU厂商: $CPU_VENDOR"
echo "KVM模块: $KVM_MODULE"
echo ""

# 检查嵌套虚拟化参数
echo "步骤 2: 检查嵌套虚拟化参数..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

NESTED_PATH="/sys/module/$KVM_MODULE/parameters/$NESTED_PARAM"

if [[ -f "$NESTED_PATH" ]]; then
    NESTED_VALUE=$(cat "$NESTED_PATH")
    echo "嵌套虚拟化参数: $NESTED_VALUE"

    if [[ "$NESTED_VALUE" == "Y" ]] || [[ "$NESTED_VALUE" == "1" ]]; then
        echo "✓ 嵌套虚拟化已启用"
        NESTED_ENABLED=1
    else
        echo "⚠ 嵌套虚拟化未启用"
        NESTED_ENABLED=0
    fi
else
    echo "⚠ 无法读取嵌套虚拟化参数"
    NESTED_ENABLED=0
fi

echo ""

# 启用嵌套虚拟化
if [[ $NESTED_ENABLED -eq 0 ]]; then
    echo "步骤 3: 启用嵌套虚拟化..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    echo "尝试启用嵌套虚拟化..."

    # 卸载KVM模块
    echo "卸载KVM模块..."
    rmmod $KVM_MODULE 2>/dev/null
    rmmod kvm 2>/dev/null

    sleep 1

    # 重新加载并启用nested
    echo "重新加载KVM模块（启用nested）..."
    modprobe $KVM_MODULE nested=1

    if [[ $? -eq 0 ]]; then
        # 验证
        NESTED_VALUE=$(cat "$NESTED_PATH" 2>/dev/null)
        if [[ "$NESTED_VALUE" == "Y" ]] || [[ "$NESTED_VALUE" == "1" ]]; then
            echo "✓ 嵌套虚拟化已成功启用"
            NESTED_ENABLED=1
        else
            echo "✗ 嵌套虚拟化启用失败"
            echo ""
            echo "持久化设置方法:"
            echo "  1. 创建 /etc/modprobe.d/kvm.conf"
            echo "  2. 添加内容: options $KVM_MODULE nested=1"
            echo "  3. 重新加载模块或重启系统"
        fi
    else
        echo "✗ KVM模块重新加载失败"
    fi

    echo ""
fi

# 嵌套虚拟化原理说明
echo "步骤 4: 嵌套虚拟化原理..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "嵌套虚拟化原理"
    echo "========================================"
    echo ""
    echo "架构层次:"
    echo "  L0: 物理主机 (Hypervisor)"
    echo "  L1: 第一层虚拟机 (Guest OS with KVM)"
    echo "  L2: 第二层虚拟机 (Nested Guest)"
    echo ""
    echo "工作机制:"
    echo "  - L0将VMX/SVM指令虚拟化给L1"
    echo "  - L1认为自己有硬件虚拟化支持"
    echo "  - L1可以创建L2虚拟机"
    echo ""
    echo "Intel实现 (VMX):"
    echo "  - VMCS shadowing: 减少VM exits"
    echo "  - EPT shadowing: 嵌套页表"
    echo "  - VPID支持: TLB优化"
    echo ""
    echo "AMD实现 (SVM):"
    echo "  - NPT (Nested Page Tables)"
    echo "  - VMCB (Virtual Machine Control Block)"
    echo ""
    echo "性能影响:"
    echo "  - L2性能约为L1的70-90%"
    echo "  - 额外的VM exit开销"
    echo "  - 页表遍历层次增加"
    echo ""
    echo "应用场景:"
    echo "  - 云计算平台（用户需要运行虚拟机）"
    echo "  - 开发测试环境"
    echo "  - 安全研究（恶意软件分析）"
    echo ""
} | tee "$RESULTS_DIR/principles.txt"

# 测试配置
echo "步骤 5: 嵌套虚拟化配置检查..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "嵌套虚拟化配置"
    echo "========================================"
    echo ""

    echo "KVM模块参数:"
    if [[ -d /sys/module/$KVM_MODULE/parameters ]]; then
        for param in /sys/module/$KVM_MODULE/parameters/*; do
            param_name=$(basename $param)
            param_value=$(cat $param 2>/dev/null)
            echo "  $param_name = $param_value"
        done
    fi

    echo ""
    echo "CPU特性（L1视角）:"

    # 检查CPU是否暴露虚拟化特性
    if grep -q "vmx\|svm" /proc/cpuinfo; then
        echo "  ✓ CPU flags包含虚拟化支持（vmx/svm）"
    else
        echo "  ⚠ CPU flags不包含虚拟化支持"
    fi

    # EPT/NPT
    if grep -q "ept\|npt" /proc/cpuinfo; then
        echo "  ✓ 支持EPT/NPT（嵌套页表）"
    fi

    # VPID
    if grep -q "vpid" /proc/cpuinfo; then
        echo "  ✓ 支持VPID"
    fi

} | tee "$RESULTS_DIR/nested-config.txt"

echo ""

# L1虚拟机配置示例
echo "步骤 6: L1虚拟机配置示例..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "L1虚拟机QEMU启动参数"
    echo "========================================"
    echo ""
    echo "关键参数:"
    echo "  -cpu host                    # 暴露所有CPU特性给L1"
    echo "  -enable-kvm                  # 启用KVM加速"
    echo "  -smp cpus=4                  # 多核支持"
    echo ""
    echo "完整示例:"
    echo "qemu-system-x86_64 \\"
    echo "    -enable-kvm \\"
    echo "    -cpu host \\"
    echo "    -smp cpus=4,cores=2,threads=2 \\"
    echo "    -m 4096 \\"
    echo "    -drive file=l1-guest.qcow2,format=qcow2 \\"
    echo "    -net nic -net user \\"
    echo "    -nographic"
    echo ""
    echo "libvirt XML配置:"
    echo "<cpu mode='host-passthrough' check='none'/>"
    echo ""
    echo "或者:"
    echo "<cpu mode='host-model'>"
    echo "  <feature policy='require' name='vmx'/>"
    echo "</cpu>"
    echo ""
} | tee "$RESULTS_DIR/l1-config.txt"

# L2虚拟机配置示例
{
    echo ""
    echo "L2虚拟机配置（在L1中运行）"
    echo "========================================"
    echo ""
    echo "在L1中检查KVM支持:"
    echo "  lsmod | grep kvm"
    echo "  ls -l /dev/kvm"
    echo ""
    echo "L2启动命令（在L1中执行）:"
    echo "qemu-system-x86_64 \\"
    echo "    -enable-kvm \\"
    echo "    -cpu host \\"
    echo "    -m 1024 \\"
    echo "    -drive file=l2-guest.qcow2,format=qcow2 \\"
    echo "    -nographic"
    echo ""
} | tee -a "$RESULTS_DIR/l1-config.txt"

echo ""

# 性能对比
echo "步骤 7: 嵌套虚拟化性能考虑..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "性能对比"
    echo "========================================"
    echo ""
    echo "性能层次:"
    echo "  物理机 (L0):     100%"
    echo "  L1虚拟机:        90-95%"
    echo "  L2虚拟机:        70-85%"
    echo ""
    echo "性能损失来源:"
    echo "  1. VM exit处理 - L2的VM exit需要L1和L0处理"
    echo "  2. 页表遍历 - 多层地址转换（GVA->GPA->HPA）"
    echo "  3. TLB效率 - 多层虚拟化降低TLB命中率"
    echo "  4. I/O虚拟化 - 额外的模拟层"
    echo ""
    echo "优化建议:"
    echo "  - 启用EPT/NPT（嵌套页表）"
    echo "  - 使用virtio驱动（半虚拟化）"
    echo "  - 减少vCPU数量"
    echo "  - 使用huge pages"
    echo "  - 启用VPID支持"
    echo ""
} | tee "$RESULTS_DIR/performance.txt"

echo ""

# 验证方法
echo "步骤 8: 嵌套虚拟化验证方法..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "嵌套虚拟化验证"
    echo "========================================"
    echo ""
    echo "L0主机验证:"
    echo "  1. 检查nested参数:"
    echo "     cat /sys/module/$KVM_MODULE/parameters/nested"
    echo "     # 应该显示 Y 或 1"
    echo ""
    echo "  2. 查看KVM模块信息:"
    echo "     modinfo $KVM_MODULE | grep nested"
    echo ""
    echo "L1虚拟机内验证:"
    echo "  1. 检查CPU特性:"
    echo "     grep -E 'vmx|svm' /proc/cpuinfo"
    echo "     # 应该有vmx或svm flag"
    echo ""
    echo "  2. 检查KVM设备:"
    echo "     ls -l /dev/kvm"
    echo "     # 设备应该存在"
    echo ""
    echo "  3. 尝试加载KVM模块:"
    echo "     sudo modprobe kvm_intel  # 或 kvm_amd"
    echo "     lsmod | grep kvm"
    echo ""
    echo "  4. 测试创建L2:"
    echo "     qemu-system-x86_64 -enable-kvm -m 512 -nographic ..."
    echo ""
} | tee "$RESULTS_DIR/verification.txt"

echo ""

# 故障排查
{
    echo "故障排查"
    echo "========================================"
    echo ""
    echo "问题: L1中没有vmx/svm flag"
    echo "解决:"
    echo "  - 确认L0启用了nested=1"
    echo "  - L1使用-cpu host或-cpu host-passthrough"
    echo "  - 检查libvirt XML: <cpu mode='host-passthrough'/>"
    echo ""
    echo "问题: L1中/dev/kvm不存在"
    echo "解决:"
    echo "  - 在L1中安装qemu-kvm"
    echo "  - 在L1中加载KVM模块: modprobe kvm_intel"
    echo ""
    echo "问题: L2性能很差"
    echo "解决:"
    echo "  - 启用EPT/NPT"
    echo "  - 减少嵌套层次（避免L3）"
    echo "  - 使用virtio设备"
    echo "  - 分配足够的内存和CPU"
    echo ""
    echo "问题: 无法启动L2"
    echo "解决:"
    echo "  - 检查L1的KVM模块是否加载"
    echo "  - 查看L1的dmesg错误信息"
    echo "  - 确认L1有足够资源"
    echo ""
} | tee "$RESULTS_DIR/troubleshooting.txt"

echo ""

# 生成报告
{
    echo "嵌套虚拟化测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo ""
    echo "系统信息:"
    echo "  内核版本: $(uname -r)"
    echo "  CPU: $(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
    echo "  CPU厂商: $CPU_VENDOR"
    echo ""
    echo "嵌套虚拟化状态:"
    echo "  KVM模块: $KVM_MODULE"
    echo "  Nested参数: $([[ $NESTED_ENABLED -eq 1 ]] && echo '✓ 已启用' || echo '✗ 未启用')"
    echo ""
    echo "测试结果:"
    echo "  ✓ 嵌套虚拟化支持检查"
    echo "  ✓ KVM模块参数验证"
    if [[ $NESTED_ENABLED -eq 1 ]]; then
        echo "  ✓ 嵌套虚拟化已启用"
    else
        echo "  ⚠ 嵌套虚拟化未启用（可手动启用）"
    fi
    echo ""
    echo "配置建议:"
    if [[ $NESTED_ENABLED -eq 0 ]]; then
        echo "  持久化启用嵌套虚拟化:"
        echo "    echo 'options $KVM_MODULE nested=1' | sudo tee /etc/modprobe.d/kvm.conf"
        echo "    sudo modprobe -r $KVM_MODULE"
        echo "    sudo modprobe $KVM_MODULE"
    else
        echo "  ✓ 系统已准备好运行嵌套虚拟机"
    fi
    echo ""
    echo "详细日志:"
    echo "  原理说明: $RESULTS_DIR/principles.txt"
    echo "  配置信息: $RESULTS_DIR/nested-config.txt"
    echo "  L1配置: $RESULTS_DIR/l1-config.txt"
    echo "  性能分析: $RESULTS_DIR/performance.txt"
    echo "  验证方法: $RESULTS_DIR/verification.txt"
    echo "  故障排查: $RESULTS_DIR/troubleshooting.txt"
    echo ""
} | tee "$RESULTS_DIR/summary.txt"

echo "========================================"
echo "测试完成"
echo "========================================"
echo ""

if [[ $NESTED_ENABLED -eq 1 ]]; then
    echo "✓ 嵌套虚拟化测试通过"
    echo "  系统支持在虚拟机中运行虚拟机"
else
    echo "⚠ 嵌套虚拟化需要手动启用"
    echo "  参考上述配置建议"
fi

echo ""
echo "结果目录: $RESULTS_DIR"
echo ""
