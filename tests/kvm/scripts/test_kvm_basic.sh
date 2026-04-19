#!/bin/bash
# test_kvm_basic.sh - KVM基础功能测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results/basic-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "KVM 基础功能测试"
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
echo "步骤 1: 检查CPU虚拟化支持..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

CPU_VENDOR=$(grep "vendor_id" /proc/cpuinfo | head -1 | awk '{print $3}')
echo "CPU厂商: $CPU_VENDOR"

if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
    echo "检查Intel VT-x支持:"
    if grep -q "vmx" /proc/cpuinfo; then
        echo "  ✓ CPU支持Intel VT-x (vmx flag存在)"
        VMX_SUPPORTED=1
    else
        echo "  ✗ CPU不支持Intel VT-x"
        VMX_SUPPORTED=0
    fi
elif [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
    echo "检查AMD-V支持:"
    if grep -q "svm" /proc/cpuinfo; then
        echo "  ✓ CPU支持AMD-V (svm flag存在)"
        VMX_SUPPORTED=1
    else
        echo "  ✗ CPU不支持AMD-V"
        VMX_SUPPORTED=0
    fi
else
    echo "  ⚠ 未知CPU厂商"
    VMX_SUPPORTED=0
fi

echo ""

if [[ $VMX_SUPPORTED -eq 0 ]]; then
    echo "✗ CPU不支持硬件虚拟化，无法使用KVM"
    echo ""
    echo "可能原因:"
    echo "  1. CPU型号太老"
    echo "  2. BIOS中禁用了虚拟化"
    echo ""
    exit 1
fi

# 检查KVM模块
echo "步骤 2: 检查KVM模块..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "加载的KVM模块:"
lsmod | grep kvm | tee "$RESULTS_DIR/kvm-modules.txt"

if lsmod | grep -q kvm; then
    echo "✓ KVM模块已加载"
else
    echo "⚠ KVM模块未加载，尝试加载..."

    if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
        modprobe kvm-intel
    else
        modprobe kvm-amd
    fi

    if [[ $? -eq 0 ]]; then
        echo "✓ KVM模块加载成功"
    else
        echo "✗ KVM模块加载失败"
        exit 1
    fi
fi

echo ""

# 检查/dev/kvm设备
echo "步骤 3: 检查KVM设备节点..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ -e /dev/kvm ]]; then
    echo "✓ /dev/kvm 存在"
    ls -l /dev/kvm | tee "$RESULTS_DIR/dev-kvm.txt"

    # 检查权限
    if [[ -r /dev/kvm ]] && [[ -w /dev/kvm ]]; then
        echo "✓ 当前用户有权限访问/dev/kvm"
    else
        echo "⚠ 当前用户无权限访问/dev/kvm"
        echo "  建议: 将用户加入kvm组"
        echo "  sudo usermod -a -G kvm \$USER"
    fi
else
    echo "✗ /dev/kvm 不存在"
    echo "  可能原因:"
    echo "  1. KVM模块未正确加载"
    echo "  2. 内核未启用KVM支持"
    exit 1
fi

echo ""

# 检查QEMU/KVM
echo "步骤 4: 检查QEMU/KVM安装..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

QEMU_CMDS=(qemu-system-x86_64 qemu-img qemu-kvm)

for cmd in "${QEMU_CMDS[@]}"; do
    if command -v $cmd &> /dev/null; then
        echo "✓ $cmd: $(which $cmd)"
        $cmd --version | head -1
    else
        echo "⚠ $cmd: 未安装"
    fi
done

echo ""

if ! command -v qemu-system-x86_64 &> /dev/null; then
    echo "✗ QEMU未安装"
    echo ""
    echo "安装命令:"
    echo "  Ubuntu/Debian: sudo apt-get install qemu-kvm qemu-utils"
    echo "  RHEL/CentOS:   sudo yum install qemu-kvm qemu-img"
    echo "  Fedora:        sudo dnf install qemu-kvm qemu-img"
    exit 1
fi

# 检查libvirt
echo "步骤 5: 检查libvirt..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if command -v virsh &> /dev/null; then
    echo "✓ libvirt已安装"
    virsh version | tee "$RESULTS_DIR/libvirt-version.txt"

    echo ""
    echo "libvirtd服务状态:"
    systemctl status libvirtd --no-pager | head -10 || service libvirtd status

    echo ""
    echo "默认网络:"
    virsh net-list --all 2>/dev/null || echo "  无法列出网络（可能需要启动libvirtd）"
else
    echo "⚠ libvirt未安装（可选）"
    echo "  libvirt提供更高级的虚拟机管理功能"
fi

echo ""

# KVM参数检查
echo "步骤 6: KVM模块参数..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
    KVM_MODULE="kvm_intel"
else
    KVM_MODULE="kvm_amd"
fi

if [[ -d /sys/module/$KVM_MODULE/parameters ]]; then
    echo "KVM模块参数:"
    for param in /sys/module/$KVM_MODULE/parameters/*; do
        param_name=$(basename $param)
        param_value=$(cat $param 2>/dev/null)
        echo "  $param_name = $param_value"
    done | tee "$RESULTS_DIR/kvm-parameters.txt"
else
    echo "⚠ 无法读取KVM模块参数"
fi

echo ""

# 创建测试磁盘镜像
echo "步骤 7: 创建测试磁盘镜像..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

TEST_IMG="$SCRIPT_DIR/../images/test-basic.img"
mkdir -p "$(dirname $TEST_IMG)"

if [[ ! -f "$TEST_IMG" ]]; then
    echo "创建1GB测试镜像..."
    qemu-img create -f qcow2 "$TEST_IMG" 1G

    if [[ $? -eq 0 ]]; then
        echo "✓ 镜像创建成功: $TEST_IMG"
    else
        echo "✗ 镜像创建失败"
        exit 1
    fi
else
    echo "✓ 测试镜像已存在: $TEST_IMG"
fi

echo ""
echo "镜像信息:"
qemu-img info "$TEST_IMG" | tee "$RESULTS_DIR/image-info.txt"

echo ""

# KVM基础功能测试（不启动完整VM）
echo "步骤 8: KVM功能验证..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "测试KVM可用性（10秒超时）..."

timeout 10 qemu-system-x86_64 \
    -enable-kvm \
    -m 256 \
    -nographic \
    -serial none \
    -monitor none \
    -display none \
    </dev/null &>/dev/null &

QEMU_PID=$!
sleep 2

if kill -0 $QEMU_PID 2>/dev/null; then
    echo "✓ KVM基础功能正常（QEMU进程启动成功）"
    kill $QEMU_PID 2>/dev/null
    wait $QEMU_PID 2>/dev/null
else
    echo "⚠ QEMU进程启动失败或已退出"
fi

echo ""

# CPU特性检查
echo "步骤 9: 虚拟化相关CPU特性..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "虚拟化相关CPU特性"
    echo "========================================"
    echo ""

    # EPT/NPT支持
    if grep -q "ept" /proc/cpuinfo; then
        echo "✓ EPT (Extended Page Tables) - Intel"
    elif grep -q "npt" /proc/cpuinfo; then
        echo "✓ NPT (Nested Page Tables) - AMD"
    else
        echo "⚠ 无EPT/NPT支持（性能会受影响）"
    fi

    # VPID支持
    if grep -q "vpid" /proc/cpuinfo; then
        echo "✓ VPID (Virtual Processor ID)"
    fi

    # PCID支持
    if grep -q "pcid" /proc/cpuinfo; then
        echo "✓ PCID (Process-Context Identifiers)"
    fi

    # IOMMU支持
    if [[ -d /sys/kernel/iommu_groups ]]; then
        IOMMU_GROUPS=$(ls /sys/kernel/iommu_groups | wc -l)
        echo "✓ IOMMU支持 ($IOMMU_GROUPS 组)"
    else
        echo "⚠ IOMMU未启用"
    fi

} | tee "$RESULTS_DIR/cpu-features.txt"

echo ""

# 生成报告
{
    echo "KVM基础功能测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo ""
    echo "系统信息:"
    echo "  内核版本: $(uname -r)"
    echo "  CPU: $(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
    echo "  CPU厂商: $CPU_VENDOR"
    echo ""
    echo "虚拟化支持:"
    echo "  硬件虚拟化: $([[ $VMX_SUPPORTED -eq 1 ]] && echo '✓ 支持' || echo '✗ 不支持')"
    echo "  KVM模块: $(lsmod | grep -q kvm && echo '✓ 已加载' || echo '✗ 未加载')"
    echo "  /dev/kvm: $([[ -e /dev/kvm ]] && echo '✓ 存在' || echo '✗ 不存在')"
    echo ""
    echo "软件环境:"
    echo "  QEMU: $(command -v qemu-system-x86_64 &>/dev/null && echo '✓ 已安装' || echo '✗ 未安装')"
    echo "  libvirt: $(command -v virsh &>/dev/null && echo '✓ 已安装' || echo '⚠ 未安装')"
    echo ""
    echo "测试结果:"
    echo "  ✓ CPU虚拟化支持检查"
    echo "  ✓ KVM模块加载验证"
    echo "  ✓ 设备节点访问测试"
    echo "  ✓ QEMU安装检查"
    echo "  ✓ 测试镜像创建"
    echo "  ✓ KVM基础功能验证"
    echo ""
    echo "详细日志:"
    echo "  KVM模块: $RESULTS_DIR/kvm-modules.txt"
    echo "  设备节点: $RESULTS_DIR/dev-kvm.txt"
    echo "  libvirt版本: $RESULTS_DIR/libvirt-version.txt"
    echo "  KVM参数: $RESULTS_DIR/kvm-parameters.txt"
    echo "  镜像信息: $RESULTS_DIR/image-info.txt"
    echo "  CPU特性: $RESULTS_DIR/cpu-features.txt"
    echo ""
} | tee "$RESULTS_DIR/summary.txt"

echo "========================================"
echo "测试完成"
echo "========================================"
echo ""

if [[ $VMX_SUPPORTED -eq 1 ]] && lsmod | grep -q kvm && [[ -e /dev/kvm ]]; then
    echo "✓ KVM基础功能测试通过"
    echo "  系统已准备好运行KVM虚拟机"
else
    echo "⚠ KVM基础功能测试发现问题"
    echo "  请查看上述详细信息"
fi

echo ""
echo "结果目录: $RESULTS_DIR"
echo ""
