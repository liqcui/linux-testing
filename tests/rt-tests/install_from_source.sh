#!/bin/bash
# install_from_source.sh - 从源码安装 rt-tests（实时性能测试工具）

set -e

echo "========================================"
echo "从源码安装 rt-tests"
echo "========================================"
echo ""

# 检查权限
if [[ $EUID -ne 0 ]]; then
   echo "此脚本需要 root 权限"
   echo "请使用: sudo $0"
   exit 1
fi

BUILD_DIR="/tmp/rt-tests-build-$$"
INSTALL_PREFIX="/usr/local"

echo "配置:"
echo "  构建目录: $BUILD_DIR"
echo "  安装路径: $INSTALL_PREFIX"
echo ""

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

# 安装编译依赖
echo "步骤 1: 安装编译依赖..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

case $DISTRO in
    ubuntu|debian)
        apt-get update
        apt-get install -y \
            build-essential \
            git \
            libnuma-dev \
            python3
        ;;
    rhel|centos|rocky|almalinux)
        yum install -y \
            gcc \
            make \
            git \
            numactl-devel \
            python3
        ;;
    fedora)
        dnf install -y \
            gcc \
            make \
            git \
            numactl-devel \
            python3
        ;;
    *)
        echo "警告: 未知发行版 $DISTRO"
        echo "尝试继续..."
        ;;
esac

echo "✓ 依赖安装完成"
echo ""

# 创建构建目录
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# 克隆 rt-tests 源码
echo "步骤 2: 下载 rt-tests 源码..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

git clone git://git.kernel.org/pub/scm/utils/rt-tests/rt-tests.git
cd rt-tests

echo "✓ 源码下载完成"
echo ""

# 编译
echo "步骤 3: 编译 rt-tests..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

CPU_COUNT=$(nproc)
echo "使用 $CPU_COUNT 个 CPU 核心编译..."
echo ""

make -j $CPU_COUNT

echo ""
echo "✓ 编译完成"
echo ""

# 安装
echo "步骤 4: 安装 rt-tests..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

make install prefix=$INSTALL_PREFIX

echo "✓ 安装完成"
echo ""

# 验证安装
echo "步骤 5: 验证安装..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

TOOLS=(cyclictest pi_stress hwlatdetect signaltest hackbench)
FOUND=0

for tool in "${TOOLS[@]}"; do
    if command -v "$tool" &>/dev/null; then
        VERSION=$($tool --version 2>&1 | head -1 || echo "")
        LOCATION=$(which $tool)
        echo "✓ $tool"
        echo "  路径: $LOCATION"
        if [[ -n "$VERSION" ]]; then
            echo "  版本: $VERSION"
        fi
        FOUND=$((FOUND + 1))
    else
        echo "✗ $tool - 未找到"
    fi
done

echo ""

if [[ $FOUND -eq 0 ]]; then
    echo "✗ 安装失败：未找到任何工具"
    exit 1
fi

echo "✓ 成功安装 $FOUND 个工具"
echo ""

# 清理构建目录
echo "步骤 6: 清理构建目录..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd /
rm -rf "$BUILD_DIR"

echo "✓ 清理完成"
echo ""

# 测试 cyclictest
echo "步骤 7: 测试 cyclictest..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "运行 5 秒测试..."
echo ""

cyclictest -t 1 -p 80 -i 1000 -n -D 5s || {
    echo ""
    echo "警告: cyclictest 需要 root 权限才能设置实时优先级"
    echo "使用: sudo cyclictest -t 1 -p 80 -i 1000 -n -D 5s"
}

echo ""
echo "========================================"
echo "安装成功！"
echo "========================================"
echo ""
echo "已安装的工具:"
for tool in "${TOOLS[@]}"; do
    if command -v "$tool" &>/dev/null; then
        echo "  - $tool ($(which $tool))"
    fi
done
echo ""
echo "快速开始:"
echo "  # 基础延迟测试（需要 root）"
echo "  sudo cyclictest -t 4 -p 99 -i 1000 -n -D 60s"
echo ""
echo "  # 运行测试脚本"
echo "  cd scripts"
echo "  sudo ./test_cyclictest.sh"
echo ""
echo "下一步:"
echo "  1. 运行测试脚本验证功能"
echo "  2. 查看 README.md 了解详细用法"
echo "  3. 考虑安装 PREEMPT_RT 实时内核以获得更好性能"
echo ""
