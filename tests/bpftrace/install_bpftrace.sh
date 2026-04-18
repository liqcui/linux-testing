#!/bin/bash
# install_bpftrace.sh - bpftrace 自动安装脚本

set -e

echo "================================"
echo "bpftrace 自动安装"
echo "================================"
echo ""

# 检测发行版
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
else
    echo "错误: 无法检测操作系统版本"
    exit 1
fi

echo "检测到操作系统: $OS $VER"
echo ""

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
   echo "错误: 此脚本需要 root 权限"
   echo "使用: sudo $0"
   exit 1
fi

# 根据发行版安装
case $OS in
    fedora|rhel|centos|rocky|almalinux)
        echo "使用 DNF/YUM 安装 bpftrace..."
        echo ""

        # 安装依赖
        echo "1. 安装基础依赖..."
        if command -v dnf &> /dev/null; then
            dnf install -y gcc make kernel-devel kernel-headers
            echo ""
            echo "2. 安装 bpftrace..."
            dnf install -y bpftrace
        else
            yum install -y gcc make kernel-devel kernel-headers
            echo ""
            echo "2. 安装 bpftrace..."
            yum install -y bpftrace
        fi
        ;;

    ubuntu|debian)
        echo "使用 APT 安装 bpftrace..."
        echo ""

        # 更新包列表
        echo "1. 更新包列表..."
        apt update
        echo ""

        # 安装依赖
        echo "2. 安装基础依赖..."
        apt install -y gcc make linux-headers-$(uname -r)
        echo ""

        # Ubuntu 19.04+ 或 Debian 10+ 直接安装
        echo "3. 安装 bpftrace..."
        apt install -y bpftrace
        ;;

    arch|manjaro)
        echo "使用 Pacman 安装 bpftrace..."
        echo ""

        pacman -Sy --noconfirm gcc make linux-headers bpftrace
        ;;

    *)
        echo "不支持的发行版: $OS"
        echo ""
        echo "请手动安装 bpftrace:"
        echo "  官方文档: https://github.com/iovisor/bpftrace/blob/master/INSTALL.md"
        exit 1
        ;;
esac

echo ""
echo "================================"
echo "安装完成！"
echo "================================"
echo ""

# 验证安装
if command -v bpftrace &> /dev/null; then
    BPFTRACE_VERSION=$(bpftrace --version 2>&1 | head -1)
    echo "✓ bpftrace 安装成功"
    echo "  版本: $BPFTRACE_VERSION"
    echo ""
else
    echo "✗ bpftrace 安装失败"
    exit 1
fi

# 检查内核版本
KERNEL_VERSION=$(uname -r)
echo "当前内核版本: $KERNEL_VERSION"
echo ""

# 挂载必要的文件系统
echo "配置必要的文件系统..."
echo ""

# 挂载 debugfs
if ! mount | grep -q debugfs; then
    echo "挂载 debugfs..."
    mount -t debugfs none /sys/kernel/debug 2>/dev/null || true
fi

# 挂载 bpf
if ! mount | grep -q bpf; then
    echo "挂载 BPF 文件系统..."
    mkdir -p /sys/fs/bpf
    mount -t bpf none /sys/fs/bpf 2>/dev/null || true
fi

echo ""
echo "下一步:"
echo "  1. 运行环境检查: ./check_bpftrace.sh"
echo "  2. 编译 mock 程序: cd mock_programs && make"
echo "  3. 运行测试: sudo ./test_syscall_count.sh"
echo ""
