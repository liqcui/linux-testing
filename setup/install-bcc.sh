#!/bin/bash
# BCC 工具自动安装脚本

set -e

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         BCC 工具自动安装                                  ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# 检查是否以 root 运行
if [ "$EUID" -ne 0 ]; then
    echo "错误: 此脚本需要 root 权限"
    echo "请使用: sudo $0"
    exit 1
fi

# 检测发行版
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
else
    echo "错误: 无法检测操作系统"
    exit 1
fi

echo "检测到操作系统: $PRETTY_NAME"
echo "内核版本: $(uname -r)"
echo ""

# 检查内核版本
KERNEL_MAJOR=$(uname -r | cut -d. -f1)
KERNEL_MINOR=$(uname -r | cut -d. -f2)

if [ "$KERNEL_MAJOR" -lt 4 ] || [ "$KERNEL_MAJOR" -eq 4 -a "$KERNEL_MINOR" -lt 4 ]; then
    echo "警告: 内核版本 $(uname -r) 可能不支持 BCC"
    echo "推荐内核版本 >= 4.9"
    echo ""
    read -p "继续安装? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "========================================="
echo "开始安装 BCC 工具..."
echo "========================================="
echo ""

case "$OS" in
    fedora|rhel|centos)
        echo "使用 DNF 安装 BCC..."
        echo ""

        # 安装 EPEL（CentOS/RHEL 需要）
        if [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
            echo "安装 EPEL 仓库..."
            dnf install -y epel-release
        fi

        # 安装 BCC
        echo "安装 BCC 工具包..."
        dnf install -y bcc-tools

        # 安装 Python 绑定
        echo "安装 Python BCC 绑定..."
        dnf install -y python3-bcc

        # 可选：安装内核调试符号
        echo ""
        read -p "是否安装内核调试符号? (某些工具需要) (y/N) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "安装内核调试符号..."
            dnf install -y kernel-debuginfo-$(uname -r) || {
                echo "警告: 无法安装调试符号，某些功能可能受限"
            }
        fi
        ;;

    ubuntu|debian)
        echo "使用 APT 安装 BCC..."
        echo ""

        # 更新包列表
        echo "更新包列表..."
        apt-get update

        # 安装 BCC
        echo "安装 BCC 工具包..."
        apt-get install -y bpfcc-tools

        # 安装 Python 绑定
        echo "安装 Python BCC 绑定..."
        apt-get install -y python3-bpfcc

        # 安装开发库（可选）
        echo "安装开发库..."
        apt-get install -y libbpfcc-dev

        # 可选：安装内核调试符号
        echo ""
        read -p "是否安装内核调试符号? (某些工具需要) (y/N) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "安装内核调试符号..."
            apt-get install -y linux-image-$(uname -r)-dbgsym || {
                echo "警告: 无法安装调试符号"
                echo "可能需要添加 ddebs 仓库:"
                echo "  https://wiki.ubuntu.com/Debug%20Symbol%20Packages"
            }
        fi
        ;;

    *)
        echo "不支持的操作系统: $OS"
        echo ""
        echo "请手动安装 BCC:"
        echo "  https://github.com/iovisor/bcc/blob/master/INSTALL.md"
        exit 1
        ;;
esac

echo ""
echo "========================================="
echo "配置环境..."
echo "========================================="
echo ""

# 挂载 BPF 文件系统
if ! mount | grep -q bpffs; then
    echo "挂载 BPF 文件系统..."
    mount -t bpf bpf /sys/fs/bpf 2>/dev/null || {
        echo "警告: 无法挂载 BPF 文件系统"
    }
fi

# 添加 BCC 工具到 PATH（如果需要）
BCC_TOOLS_PATH="/usr/share/bcc/tools"
if [ -d "$BCC_TOOLS_PATH" ]; then
    if ! echo $PATH | grep -q "$BCC_TOOLS_PATH"; then
        echo "添加 BCC 工具到 PATH..."
        echo "export PATH=\"\$PATH:$BCC_TOOLS_PATH\"" >> /etc/profile.d/bcc.sh
        chmod +x /etc/profile.d/bcc.sh
        echo "已添加到 /etc/profile.d/bcc.sh"
        echo "请重新登录或运行: source /etc/profile.d/bcc.sh"
    fi
fi

echo ""
echo "========================================="
echo "验证安装..."
echo "========================================="
echo ""

# 验证工具是否可用
BCC_TOOLS=(execsnoop opensnoop biosnoop tcpconnect tcpaccept tcpretrans runqlat profile offcputime memleak)
INSTALLED=0
MISSING=0

for tool in "${BCC_TOOLS[@]}"; do
    if command -v $tool >/dev/null 2>&1; then
        echo "  ✓ $tool"
        ((INSTALLED++))
    else
        echo "  ✗ $tool"
        ((MISSING++))
    fi
done

echo ""
echo "安装结果: $INSTALLED/${#BCC_TOOLS[@]} 工具可用"
echo ""

if [ $INSTALLED -eq ${#BCC_TOOLS[@]} ]; then
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║  ✓ BCC 安装成功！                                         ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    echo "快速开始:"
    echo "  sudo execsnoop          # 跟踪进程执行"
    echo "  sudo opensnoop          # 跟踪文件打开"
    echo "  sudo biosnoop           # 跟踪磁盘 I/O"
    echo "  sudo tcpconnect         # 跟踪 TCP 连接"
    echo ""
    echo "运行测试:"
    echo "  cd tests/bcc"
    echo "  sudo ./check_bcc.sh     # 检查环境"
    echo "  sudo ./test_execsnoop.sh  # 运行测试"
    echo ""
else
    echo "⚠ 安装不完整"
    echo "缺少 $MISSING 个工具"
    echo ""
    echo "可能的原因:"
    echo "1. 包管理器中的 BCC 版本较老"
    echo "2. 需要手动添加工具到 PATH"
    echo "3. 需要从源码编译"
    echo ""
    echo "BCC 工具路径:"
    echo "  /usr/share/bcc/tools/"
    echo "  /usr/sbin/"
    echo ""
fi

echo "更多信息:"
echo "  BCC 文档: https://github.com/iovisor/bcc"
echo "  测试脚本: tests/bcc/"
echo ""

exit 0
