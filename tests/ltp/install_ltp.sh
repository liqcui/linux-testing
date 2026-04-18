#!/bin/bash
# install_ltp.sh - 自动安装 LTP

set -e

echo "========================================"
echo "LTP (Linux Test Project) 自动安装脚本"
echo "========================================"
echo ""

# 检查是否以 root 运行
if [[ $EUID -ne 0 ]]; then
   echo "此脚本需要 root 权限"
   echo "请使用: sudo $0"
   exit 1
fi

# 默认安装路径
INSTALL_PREFIX="${LTP_INSTALL_PREFIX:-/opt/ltp}"
BUILD_DIR="/tmp/ltp-build-$$"

echo "配置:"
echo "  安装路径: $INSTALL_PREFIX"
echo "  构建目录: $BUILD_DIR"
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

# 安装依赖
echo "步骤 1: 安装依赖包..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

case $DISTRO in
    ubuntu|debian)
        apt-get update
        apt-get install -y \
            autoconf automake make gcc git \
            bison flex m4 \
            libc6-dev \
            libacl1-dev \
            libaio-dev \
            libcap-dev \
            libkeyutils-dev \
            libnuma-dev \
            libselinux1-dev \
            libssl-dev
        ;;
    rhel|centos|rocky|almalinux)
        yum install -y \
            autoconf automake make gcc git \
            bison flex m4 \
            glibc-devel \
            libacl-devel \
            libaio-devel \
            libcap-devel \
            keyutils-libs-devel \
            numactl-devel \
            libselinux-devel \
            openssl-devel
        ;;
    fedora)
        dnf install -y \
            autoconf automake make gcc git \
            bison flex m4 \
            glibc-devel \
            libacl-devel \
            libaio-devel \
            libcap-devel \
            keyutils-libs-devel \
            numactl-devel \
            libselinux-devel \
            openssl-devel
        ;;
    *)
        echo "不支持的发行版: $DISTRO"
        echo "请手动安装依赖"
        exit 1
        ;;
esac

echo ""
echo "✓ 依赖安装完成"
echo ""

# 创建构建目录
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# 克隆或更新 LTP
echo "步骤 2: 下载 LTP 源码..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -d ltp/.git ]]; then
    echo "LTP 源码已存在，更新中..."
    cd ltp
    git pull
else
    echo "克隆 LTP 仓库..."
    git clone https://github.com/linux-test-project/ltp.git
    cd ltp
fi

echo ""
echo "✓ 源码下载完成"
echo ""

# 构建 LTP
echo "步骤 3: 构建 LTP..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

make autotools
./configure --prefix="$INSTALL_PREFIX"

# 显示配置摘要
echo ""
echo "配置摘要:"
./configure --prefix="$INSTALL_PREFIX" 2>&1 | grep -A 20 "^Configuration:"
echo ""

# 编译（使用所有 CPU 核心）
CPU_COUNT=$(nproc)
echo "使用 $CPU_COUNT 个 CPU 核心编译..."
make -j "$CPU_COUNT"

echo ""
echo "✓ 编译完成"
echo ""

# 安装
echo "步骤 4: 安装 LTP..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

make install

echo ""
echo "✓ 安装完成"
echo ""

# 验证安装
echo "步骤 5: 验证安装..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -x "$INSTALL_PREFIX/runltp" ]]; then
    echo "✓ runltp 脚本存在"
else
    echo "✗ runltp 脚本不存在"
    exit 1
fi

# 统计测试用例数量
TESTCASE_COUNT=$(find "$INSTALL_PREFIX/testcases/bin" -type f -executable 2>/dev/null | wc -l)
SCENARIO_COUNT=$(ls "$INSTALL_PREFIX/runtest/" 2>/dev/null | wc -l)

echo "✓ 找到 $TESTCASE_COUNT 个测试程序"
echo "✓ 找到 $SCENARIO_COUNT 个测试场景"
echo ""

# 创建快速访问链接（可选）
if [[ ! -e /usr/local/bin/runltp ]]; then
    ln -s "$INSTALL_PREFIX/runltp" /usr/local/bin/runltp
    echo "✓ 创建符号链接: /usr/local/bin/runltp"
fi

# 清理构建目录
echo ""
echo "步骤 6: 清理..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd /
rm -rf "$BUILD_DIR"
echo "✓ 清理完成"
echo ""

# 完成
echo "========================================"
echo "LTP 安装成功！"
echo "========================================"
echo ""
echo "安装信息:"
echo "  安装路径:     $INSTALL_PREFIX"
echo "  测试用例数:   $TESTCASE_COUNT"
echo "  测试场景数:   $SCENARIO_COUNT"
echo ""
echo "快速开始:"
echo "  查看帮助:     $INSTALL_PREFIX/runltp --help"
echo "  运行快速测试: cd $INSTALL_PREFIX && sudo ./runltp -f syscalls"
echo "  查看场景列表: ls $INSTALL_PREFIX/runtest/"
echo ""
echo "示例命令:"
echo "  cd $INSTALL_PREFIX"
echo "  sudo ./runltp -f syscalls -l syscalls.log -o syscalls.out"
echo "  sudo ./runltp -f mm -l mm.log -o mm.out"
echo "  sudo ./runltp -f fs -l fs.log -o fs.out"
echo ""
