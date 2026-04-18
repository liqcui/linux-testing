#!/bin/bash
# install_rt_tests.sh - 自动安装 rt-tests 套件

set -e

echo "========================================"
echo "rt-tests 实时性能测试套件安装"
echo "========================================"
echo ""

# 检查权限
if [[ $EUID -ne 0 ]]; then
   echo "此脚本需要 root 权限"
   echo "请使用: sudo $0"
   exit 1
fi

# 检测发行版
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    DISTRO=$ID
else
    echo "无法检测发行版"
    exit 1
fi

echo "检测到系统: $DISTRO"
echo ""

# 尝试从包管理器安装
echo "步骤 1: 尝试从包管理器安装 rt-tests..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

INSTALLED=0

case $DISTRO in
    ubuntu|debian)
        if apt-cache show rt-tests &>/dev/null; then
            apt-get update
            apt-get install -y rt-tests
            INSTALLED=1
        fi
        ;;
    rhel|centos|rocky|almalinux)
        if yum info rt-tests &>/dev/null; then
            yum install -y rt-tests
            INSTALLED=1
        fi
        ;;
    fedora)
        if dnf info rt-tests &>/dev/null; then
            dnf install -y rt-tests
            INSTALLED=1
        fi
        ;;
esac

if [[ $INSTALLED -eq 1 ]]; then
    echo "✓ rt-tests 包已安装，验证工具..."

    # 验证是否是正确的 rt-tests（而非 Request Tracker）
    if command -v cyclictest &>/dev/null; then
        echo "✓ 验证成功：找到 cyclictest"
    else
        echo "✗ 安装的是错误的 rt-tests 包（可能是 Request Tracker）"
        echo "  将从源码编译正确的实时测试工具"
        INSTALLED=0
    fi
fi

if [[ $INSTALLED -eq 0 ]]; then
    echo "从源码编译 rt-tests..."
    echo ""
    echo "步骤 2: 安装编译依赖..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    case $DISTRO in
        ubuntu|debian)
            apt-get update
            apt-get install -y \
                build-essential \
                git \
                libnuma-dev \
                libpthread-stubs0-dev
            ;;
        rhel|centos|rocky|almalinux)
            yum install -y \
                gcc \
                make \
                git \
                numactl-devel \
                glibc-devel
            ;;
        fedora)
            dnf install -y \
                gcc \
                make \
                git \
                numactl-devel \
                glibc-devel
            ;;
    esac

    echo "✓ 依赖安装完成"
    echo ""
    echo "步骤 3: 编译 rt-tests..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    BUILD_DIR="/tmp/rt-tests-build-$$"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    # 克隆源码
    git clone git://git.kernel.org/pub/scm/utils/rt-tests/rt-tests.git
    cd rt-tests

    # 编译
    make -j $(nproc)

    # 安装
    make install

    # 清理
    cd /
    rm -rf "$BUILD_DIR"

    echo "✓ 编译安装完成"
fi

echo ""
echo "步骤 4: 验证安装..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 检查关键工具
TOOLS=(cyclictest pi_stress hwlatdetect signaltest hackbench)
FOUND=0

for tool in "${TOOLS[@]}"; do
    if command -v "$tool" &>/dev/null; then
        VERSION=$($tool --version 2>&1 | head -1 || echo "unknown")
        echo "✓ $tool - $VERSION"
        FOUND=$((FOUND + 1))
    else
        echo "✗ $tool - 未找到"
    fi
done

echo ""

if [[ $FOUND -gt 0 ]]; then
    echo "✓ 找到 $FOUND 个 rt-tests 工具"
else
    echo "✗ 未找到 rt-tests 工具"
    exit 1
fi

echo ""
echo "步骤 5: 安装可选依赖（用于结果可视化）..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 安装 gnuplot
case $DISTRO in
    ubuntu|debian)
        apt-get install -y gnuplot 2>/dev/null || echo "gnuplot 安装失败（可选）"
        ;;
    rhel|centos|rocky|almalinux)
        yum install -y gnuplot 2>/dev/null || echo "gnuplot 安装失败（可选）"
        ;;
    fedora)
        dnf install -y gnuplot 2>/dev/null || echo "gnuplot 安装失败（可选）"
        ;;
esac

if command -v gnuplot &>/dev/null; then
    echo "✓ gnuplot 已安装（可选）"
fi

# 安装 stress-ng（用于负载测试）
case $DISTRO in
    ubuntu|debian)
        apt-get install -y stress-ng 2>/dev/null || echo "stress-ng 安装失败（可选）"
        ;;
    rhel|centos|rocky|almalinux)
        yum install -y stress-ng 2>/dev/null || echo "stress-ng 安装失败（可选）"
        ;;
    fedora)
        dnf install -y stress-ng 2>/dev/null || echo "stress-ng 安装失败（可选）"
        ;;
esac

if command -v stress-ng &>/dev/null; then
    echo "✓ stress-ng 已安装（可选）"
fi

echo ""
echo "步骤 6: 系统配置检查..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 检查实时内核
if uname -a | grep -i "PREEMPT RT" &>/dev/null; then
    echo "✓ 检测到 PREEMPT_RT 实时内核"
elif uname -a | grep -i "PREEMPT" &>/dev/null; then
    echo "⚠ 检测到 PREEMPT 内核（不是完整的 RT 内核）"
else
    echo "⚠ 未检测到实时内核"
    echo "  建议安装 PREEMPT_RT 内核以获得最佳实时性能"
fi

# 检查 CPU 频率调节
if command -v cpupower &>/dev/null; then
    GOVERNOR=$(cpupower frequency-info | grep "current policy" | awk '{print $NF}')
    if [[ "$GOVERNOR" == "performance" ]]; then
        echo "✓ CPU 频率调节器: performance"
    else
        echo "⚠ CPU 频率调节器: $GOVERNOR"
        echo "  建议设置为 performance: sudo cpupower frequency-set -g performance"
    fi
else
    echo "⚠ cpupower 未安装，无法检查 CPU 频率调节"
fi

# 检查实时权限配置
if grep -q "rtprio" /etc/security/limits.conf 2>/dev/null; then
    echo "✓ 实时优先级权限已配置"
else
    echo "⚠ 实时优先级权限未配置"
    echo "  建议添加到 /etc/security/limits.conf:"
    echo "  @realtime soft rtprio 99"
    echo "  @realtime hard rtprio 99"
fi

echo ""
echo "========================================"
echo "rt-tests 安装完成！"
echo "========================================"
echo ""
echo "已安装的工具:"
for tool in "${TOOLS[@]}"; do
    if command -v "$tool" &>/dev/null; then
        echo "  - $tool"
    fi
done
echo ""
echo "快速开始:"
echo "  # 基础延迟测试（60秒）"
echo "  sudo cyclictest -m -a -p 99 -t 4 -i 1000 -n -D 60s"
echo ""
echo "  # 运行预设测试脚本"
echo "  cd scripts"
echo "  sudo ./test_cyclictest.sh"
echo ""
echo "  # 带负载测试"
echo "  sudo ./test_with_load.sh"
echo ""
echo "下一步建议:"
echo "  1. 编译模拟程序: cd mock_programs && make"
echo "  2. 运行基础测试验证安装"
echo "  3. 查看 README.md 了解详细用法"
echo ""
