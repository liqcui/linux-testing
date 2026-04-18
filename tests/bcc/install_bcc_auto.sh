#!/bin/bash
# install_bcc_auto.sh - BCC 工具智能安装脚本
# 自动检测平台，优先使用包管理器，失败则从源码编译

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         BCC 工具智能安装脚本                              ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
   error "此脚本需要 root 权限"
   echo "使用: sudo $0"
   exit 1
fi

# 检测系统信息
info "检测系统信息..."
echo ""

KERNEL_VERSION=$(uname -r)
ARCH=$(uname -m)
OS_TYPE=$(uname -s)

echo "  操作系统: $OS_TYPE"
echo "  架构: $ARCH"
echo "  内核版本: $KERNEL_VERSION"

if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_ID=$ID
    OS_VERSION=$VERSION_ID
    OS_NAME=$PRETTY_NAME
    echo "  发行版: $OS_NAME"
else
    warning "无法检测发行版信息"
    OS_ID="unknown"
fi

echo ""

# 检查内核版本
KERNEL_MAJOR=$(echo $KERNEL_VERSION | cut -d. -f1)
KERNEL_MINOR=$(echo $KERNEL_VERSION | cut -d. -f2)

info "检查内核版本要求..."
if [[ $KERNEL_MAJOR -lt 4 ]] || [[ $KERNEL_MAJOR -eq 4 && $KERNEL_MINOR -lt 4 ]]; then
    error "内核版本 $KERNEL_VERSION 太旧"
    echo "  BCC 需要内核 >= 4.4（推荐 >= 4.9）"
    exit 1
elif [[ $KERNEL_MAJOR -eq 4 && $KERNEL_MINOR -lt 9 ]]; then
    warning "内核版本 $KERNEL_VERSION 满足最低要求，但推荐 >= 4.9"
else
    success "内核版本满足要求 (>= 4.9)"
fi
echo ""

# 检查是否已安装
if command -v execsnoop &> /dev/null || [[ -f /usr/share/bcc/tools/execsnoop ]]; then
    warning "BCC 工具似乎已经安装"

    read -p "是否重新安装? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "保持现有安装"
        exit 0
    fi
fi

INSTALL_METHOD=""
FROM_SOURCE=0

# 函数：尝试包管理器安装
try_package_install() {
    local pkg_manager=$1
    local install_cmd=$2

    info "尝试使用 $pkg_manager 安装..."

    if eval "$install_cmd"; then
        # 验证安装
        if [[ -f /usr/share/bcc/tools/execsnoop ]] || command -v execsnoop &> /dev/null; then
            INSTALL_METHOD="$pkg_manager"
            return 0
        fi
    fi

    return 1
}

# 函数：从源码安装
install_from_source() {
    info "准备从源码编译安装 BCC..."
    echo ""

    warning "源码编译需要较长时间（15-45分钟）"
    read -p "是否继续? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "用户取消安装"
        exit 1
    fi

    BUILD_DIR="/tmp/bcc-build-$$"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    info "安装编译依赖..."

    case $OS_ID in
        fedora|rhel|centos|rocky|almalinux)
            if command -v dnf &> /dev/null; then
                PKG_MANAGER="dnf"
            else
                PKG_MANAGER="yum"
            fi

            $PKG_MANAGER install -y \
                git cmake gcc gcc-c++ make \
                bison flex \
                elfutils-libelf-devel \
                zlib-devel \
                llvm-devel clang-devel \
                python3 python3-devel \
                kernel-devel kernel-headers \
                libbpf-devel \
                binutils-devel || true
            ;;

        ubuntu|debian)
            apt-get update
            apt-get install -y \
                git cmake build-essential \
                bison flex \
                libelf-dev \
                zlib1g-dev \
                llvm-dev libclang-dev \
                python3 python3-dev \
                linux-headers-$(uname -r) \
                libbpf-dev \
                binutils-dev || true
            ;;

        arch|manjaro)
            pacman -Sy --noconfirm \
                git cmake gcc make \
                bison flex \
                elfutils \
                zlib \
                llvm clang \
                python3 \
                linux-headers \
                binutils || true
            ;;

        *)
            error "未知发行版，请手动安装依赖"
            echo "参考: https://github.com/iovisor/bcc/blob/master/INSTALL.md"
            exit 1
            ;;
    esac

    # 克隆源码
    info "克隆 BCC 源码..."
    if ! git clone https://github.com/iovisor/bcc.git; then
        error "克隆源码失败"
        exit 1
    fi

    cd bcc

    # 获取最新稳定版本
    LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "master")
    info "检出版本: $LATEST_TAG"
    git checkout $LATEST_TAG 2>/dev/null || true

    # 创建构建目录
    mkdir -p build
    cd build

    # CMake 配置
    info "配置构建..."
    if ! cmake ..; then
        error "CMake 配置失败"
        exit 1
    fi

    # 编译
    info "开始编译（这可能需要15-45分钟）..."
    NPROC=$(nproc 2>/dev/null || echo 2)
    info "使用 $NPROC 个并行任务"

    if ! make -j$NPROC; then
        error "编译失败"
        exit 1
    fi

    # 安装
    info "安装 BCC..."
    if ! make install; then
        error "安装失败"
        exit 1
    fi

    # 安装 Python 绑定
    info "安装 Python 绑定..."
    cd ../
    if [[ -f setup.py ]]; then
        python3 setup.py install || warning "Python 绑定安装失败"
    fi

    # 清理
    info "清理临时文件..."
    cd /
    rm -rf "$BUILD_DIR"

    FROM_SOURCE=1
    INSTALL_METHOD="source"

    success "从源码安装完成"
}

# 主安装逻辑
echo "========================================="
echo "开始安装 BCC 工具"
echo "========================================="
echo ""

case $OS_ID in
    fedora|rhel|centos|rocky|almalinux)
        info "检测到 RHEL 系发行版"

        if command -v dnf &> /dev/null; then
            PKG_CMD="dnf install -y bcc-tools python3-bcc kernel-devel kernel-headers"
            if try_package_install "DNF" "$PKG_CMD"; then
                success "使用 DNF 安装成功"
            else
                warning "DNF 安装失败，尝试从源码安装"
                install_from_source
            fi
        else
            PKG_CMD="yum install -y bcc-tools python3-bcc kernel-devel kernel-headers"
            if try_package_install "YUM" "$PKG_CMD"; then
                success "使用 YUM 安装成功"
            else
                warning "YUM 安装失败，尝试从源码安装"
                install_from_source
            fi
        fi
        ;;

    ubuntu|debian)
        info "检测到 Debian 系发行版"

        PKG_CMD="apt-get update && apt-get install -y bpfcc-tools python3-bpfcc linux-headers-\$(uname -r)"
        if try_package_install "APT" "$PKG_CMD"; then
            success "使用 APT 安装成功"
        else
            warning "APT 安装失败，尝试从源码安装"
            install_from_source
        fi
        ;;

    arch|manjaro)
        info "检测到 Arch 系发行版"

        PKG_CMD="pacman -Sy --noconfirm bcc bcc-tools python-bcc linux-headers"
        if try_package_install "Pacman" "$PKG_CMD"; then
            success "使用 Pacman 安装成功"
        else
            warning "Pacman 安装失败，尝试从源码安装"
            install_from_source
        fi
        ;;

    opensuse*|sles)
        info "检测到 openSUSE/SLES"

        PKG_CMD="zypper install -y bcc-tools python3-bcc kernel-devel"
        if try_package_install "Zypper" "$PKG_CMD"; then
            success "使用 Zypper 安装成功"
        else
            warning "Zypper 安装失败，尝试从源码安装"
            install_from_source
        fi
        ;;

    *)
        warning "未识别的发行版: $OS_ID"
        info "直接尝试从源码安装"
        install_from_source
        ;;
esac

echo ""
echo "========================================="
echo "验证安装"
echo "========================================="
echo ""

# 验证工具安装
BCC_TOOLS_PATH=""
if [[ -d /usr/share/bcc/tools ]]; then
    BCC_TOOLS_PATH="/usr/share/bcc/tools"
elif [[ -d /usr/local/share/bcc/tools ]]; then
    BCC_TOOLS_PATH="/usr/local/share/bcc/tools"
fi

if [[ -n "$BCC_TOOLS_PATH" ]]; then
    success "BCC 工具已安装"
    echo "  路径: $BCC_TOOLS_PATH"
    TOOL_COUNT=$(ls -1 $BCC_TOOLS_PATH | wc -l)
    echo "  工具数量: $TOOL_COUNT"
    echo "  安装方式: $INSTALL_METHOD"
else
    error "BCC 工具安装失败"
    exit 1
fi

# 验证 Python 绑定
if python3 -c "import bcc" 2>/dev/null; then
    success "Python BCC 绑定已安装"
    PYTHON_BCC_VER=$(python3 -c "import bcc; print(bcc.__version__ if hasattr(bcc, '__version__') else '未知')" 2>/dev/null)
    echo "  版本: $PYTHON_BCC_VER"
else
    warning "Python BCC 绑定未安装或无法导入"
    echo "  某些工具可能无法正常工作"
fi

echo ""

# 配置环境
info "配置系统环境..."
echo ""

# 挂载 debugfs
if ! mount | grep -q debugfs; then
    info "挂载 debugfs..."
    mkdir -p /sys/kernel/debug
    mount -t debugfs none /sys/kernel/debug 2>/dev/null || warning "无法挂载 debugfs"
fi

# 挂载 bpf
if ! mount | grep -q bpffs; then
    info "挂载 BPF 文件系统..."
    mkdir -p /sys/fs/bpf
    mount -t bpf none /sys/fs/bpf 2>/dev/null || warning "无法挂载 BPF 文件系统"
fi

# 添加到 PATH
if [[ -n "$BCC_TOOLS_PATH" ]]; then
    info "配置 PATH 环境变量..."
    echo "export PATH=\"$BCC_TOOLS_PATH:\$PATH\"" > /etc/profile.d/bcc-tools.sh
    chmod +x /etc/profile.d/bcc-tools.sh
    success "已添加 $BCC_TOOLS_PATH 到系统 PATH"
    echo "  配置文件: /etc/profile.d/bcc-tools.sh"
fi

echo ""
echo "========================================="
echo "安装总结"
echo "========================================="
echo ""

success "BCC 工具已成功安装"
echo ""
echo "系统信息:"
echo "  操作系统: $OS_NAME"
echo "  内核版本: $KERNEL_VERSION"
echo "  架构: $ARCH"
echo ""
echo "BCC 信息:"
echo "  工具路径: $BCC_TOOLS_PATH"
echo "  安装方式: $INSTALL_METHOD"
echo "  工具数量: $TOOL_COUNT"
echo ""
echo "下一步:"
echo "  1. 重新加载 shell 或运行:"
echo "     source /etc/profile.d/bcc-tools.sh"
echo ""
echo "  2. 运行环境检查:"
echo "     cd $(dirname $0)"
echo "     sudo ./check_bcc.sh"
echo ""
echo "  3. 编译测试程序:"
echo "     cd mock_programs && make"
echo ""
echo "  4. 运行测试:"
echo "     sudo ./test_execsnoop.sh"
echo "     sudo ./test_opensnoop.sh"
echo ""

success "安装完成！"
