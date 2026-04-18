#!/bin/bash
# install_bpftrace_auto.sh - bpftrace 智能安装脚本
# 自动检测平台，优先使用包管理器，失败则从源码编译

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
echo "║         bpftrace 智能安装脚本                             ║"
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

# 检测发行版
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

# 检查内核版本是否满足要求
KERNEL_MAJOR=$(echo $KERNEL_VERSION | cut -d. -f1)
KERNEL_MINOR=$(echo $KERNEL_VERSION | cut -d. -f2)

info "检查内核版本要求..."
if [[ $KERNEL_MAJOR -lt 4 ]] || [[ $KERNEL_MAJOR -eq 4 && $KERNEL_MINOR -lt 9 ]]; then
    error "内核版本 $KERNEL_VERSION 太旧"
    echo "  bpftrace 需要内核 >= 4.9"
    echo "  建议升级内核后再安装"
    exit 1
else
    success "内核版本满足要求 (>= 4.9)"
fi
echo ""

# 检查是否已安装
if command -v bpftrace &> /dev/null; then
    INSTALLED_VERSION=$(bpftrace --version 2>&1 | head -1)
    warning "bpftrace 已经安装: $INSTALLED_VERSION"

    read -p "是否重新安装? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "保持现有安装"
        exit 0
    fi
fi

# 安装方法选择
INSTALL_METHOD=""
FROM_SOURCE=0

# 函数：尝试使用包管理器安装
try_package_install() {
    local pkg_manager=$1
    local install_cmd=$2

    info "尝试使用 $pkg_manager 安装..."

    if eval "$install_cmd"; then
        if command -v bpftrace &> /dev/null; then
            INSTALL_METHOD="$pkg_manager"
            return 0
        fi
    fi

    return 1
}

# 函数：从源码安装
install_from_source() {
    info "准备从源码编译安装 bpftrace..."
    echo ""

    warning "源码编译需要较长时间（10-30分钟）"
    read -p "是否继续? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "用户取消安装"
        exit 1
    fi

    # 创建临时目录
    BUILD_DIR="/tmp/bpftrace-build-$$"
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
                bcc-devel \
                systemtap-sdt-devel \
                kernel-devel kernel-headers \
                libbpf-devel || true
            ;;

        ubuntu|debian)
            apt-get update
            apt-get install -y \
                git cmake build-essential \
                bison flex \
                libelf-dev \
                zlib1g-dev \
                llvm-dev libclang-dev \
                libbpfcc-dev \
                systemtap-sdt-dev \
                linux-headers-$(uname -r) \
                libbpf-dev || true
            ;;

        arch|manjaro)
            pacman -Sy --noconfirm \
                git cmake gcc make \
                bison flex \
                elfutils \
                zlib \
                llvm clang \
                bcc \
                systemtap \
                linux-headers || true
            ;;

        *)
            error "未知发行版，请手动安装依赖"
            echo "参考: https://github.com/iovisor/bpftrace/blob/master/INSTALL.md"
            exit 1
            ;;
    esac

    # 克隆源码
    info "克隆 bpftrace 源码..."
    if ! git clone https://github.com/iovisor/bpftrace.git; then
        error "克隆源码失败"
        exit 1
    fi

    cd bpftrace

    # 获取最新稳定版本
    LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "master")
    info "检出版本: $LATEST_TAG"
    git checkout $LATEST_TAG 2>/dev/null || true

    # 创建构建目录
    mkdir -p build
    cd build

    # CMake 配置
    info "配置构建..."
    if ! cmake -DCMAKE_BUILD_TYPE=Release ..; then
        error "CMake 配置失败"
        echo ""
        echo "可能的原因:"
        echo "  1. 缺少依赖库"
        echo "  2. LLVM/Clang 版本不兼容"
        echo "  3. 内核头文件缺失"
        exit 1
    fi

    # 编译
    info "开始编译（这可能需要10-30分钟）..."
    NPROC=$(nproc 2>/dev/null || echo 2)
    info "使用 $NPROC 个并行任务"

    if ! make -j$NPROC; then
        error "编译失败"
        exit 1
    fi

    # 安装
    info "安装 bpftrace..."
    if ! make install; then
        error "安装失败"
        exit 1
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
echo "开始安装 bpftrace"
echo "========================================="
echo ""

case $OS_ID in
    fedora|rhel|centos|rocky|almalinux)
        info "检测到 RHEL 系发行版"

        if command -v dnf &> /dev/null; then
            PKG_CMD="dnf install -y gcc make kernel-devel kernel-headers bpftrace"
            if try_package_install "DNF" "$PKG_CMD"; then
                success "使用 DNF 安装成功"
            else
                warning "DNF 安装失败，尝试从源码安装"
                install_from_source
            fi
        else
            PKG_CMD="yum install -y gcc make kernel-devel kernel-headers bpftrace"
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

        # 检查版本
        if [[ $OS_ID == "ubuntu" ]]; then
            MAJOR_VER=$(echo $OS_VERSION | cut -d. -f1)
            if [[ $MAJOR_VER -lt 19 ]]; then
                warning "Ubuntu < 19.04 可能没有 bpftrace 包"
            fi
        fi

        PKG_CMD="apt-get update && apt-get install -y gcc make linux-headers-\$(uname -r) bpftrace"
        if try_package_install "APT" "$PKG_CMD"; then
            success "使用 APT 安装成功"
        else
            warning "APT 安装失败，尝试从源码安装"
            install_from_source
        fi
        ;;

    arch|manjaro)
        info "检测到 Arch 系发行版"

        PKG_CMD="pacman -Sy --noconfirm gcc make linux-headers bpftrace"
        if try_package_install "Pacman" "$PKG_CMD"; then
            success "使用 Pacman 安装成功"
        else
            warning "Pacman 安装失败，尝试从源码安装"
            install_from_source
        fi
        ;;

    opensuse*|sles)
        info "检测到 openSUSE/SLES"

        PKG_CMD="zypper install -y gcc make kernel-devel bpftrace"
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

# 验证安装
if command -v bpftrace &> /dev/null; then
    BPFTRACE_VERSION=$(bpftrace --version 2>&1 | head -1)
    BPFTRACE_PATH=$(command -v bpftrace)

    success "bpftrace 安装成功"
    echo "  版本: $BPFTRACE_VERSION"
    echo "  路径: $BPFTRACE_PATH"
    echo "  安装方式: $INSTALL_METHOD"

    if [[ $FROM_SOURCE -eq 1 ]]; then
        echo "  编译时间: $(date)"
    fi
else
    error "bpftrace 安装失败"
    echo ""
    echo "请查看上面的错误信息，或访问:"
    echo "  https://github.com/iovisor/bpftrace/blob/master/INSTALL.md"
    exit 1
fi

echo ""

# 配置系统环境
info "配置系统环境..."
echo ""

# 挂载必要的文件系统
if ! mount | grep -q debugfs; then
    info "挂载 debugfs..."
    mkdir -p /sys/kernel/debug
    mount -t debugfs none /sys/kernel/debug 2>/dev/null || warning "无法挂载 debugfs"
fi

if ! mount | grep -q bpf; then
    info "挂载 BPF 文件系统..."
    mkdir -p /sys/fs/bpf
    mount -t bpf none /sys/fs/bpf 2>/dev/null || warning "无法挂载 BPF 文件系统"
fi

# 检查关键内核配置
info "检查内核 BPF 支持..."

if [[ -f /boot/config-$(uname -r) ]]; then
    CONFIG_FILE="/boot/config-$(uname -r)"
elif [[ -f /proc/config.gz ]]; then
    CONFIG_FILE="/proc/config.gz"
    cat() { zcat "$@"; }
else
    CONFIG_FILE=""
fi

if [[ -n "$CONFIG_FILE" ]]; then
    REQUIRED_CONFIGS=(
        "CONFIG_BPF=y"
        "CONFIG_BPF_SYSCALL=y"
        "CONFIG_BPF_JIT=y"
    )

    for config in "${REQUIRED_CONFIGS[@]}"; do
        if grep -q "^$config" $CONFIG_FILE 2>/dev/null; then
            echo "  ✓ $config"
        else
            warning "$config 未启用"
        fi
    done
else
    warning "无法检查内核配置"
fi

echo ""
echo "========================================="
echo "安装总结"
echo "========================================="
echo ""

success "bpftrace 已成功安装"
echo ""
echo "系统信息:"
echo "  操作系统: $OS_NAME"
echo "  内核版本: $KERNEL_VERSION"
echo "  架构: $ARCH"
echo ""
echo "bpftrace 信息:"
echo "  版本: $BPFTRACE_VERSION"
echo "  路径: $BPFTRACE_PATH"
echo "  安装方式: $INSTALL_METHOD"
echo ""
echo "下一步:"
echo "  1. 运行环境检查:"
echo "     cd $(dirname $0)"
echo "     sudo ./check_bpftrace.sh"
echo ""
echo "  2. 编译测试程序:"
echo "     cd mock_programs && make"
echo ""
echo "  3. 运行测试:"
echo "     sudo ../test_syscall_count.sh"
echo "     sudo ../test_function_latency.sh"
echo ""
echo "  4. 或运行所有测试:"
echo "     sudo ../run_all_tests.sh"
echo ""

success "安装完成！"
