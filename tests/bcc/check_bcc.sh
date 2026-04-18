#!/bin/bash
# BCC 工具安装和环境检查脚本

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         BCC 工具环境检查                                  ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# 检查是否以 root 运行
if [ "$EUID" -ne 0 ]; then
    echo "警告: 某些检查需要 root 权限"
    echo "建议使用: sudo $0"
    echo ""
fi

echo "========================================="
echo "1. 系统信息"
echo "========================================="
echo ""

echo "内核版本:"
uname -r
KERNEL_VERSION=$(uname -r | cut -d. -f1-2)
echo ""

echo "发行版信息:"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "$PRETTY_NAME"
else
    cat /etc/redhat-release 2>/dev/null || echo "未知"
fi
echo ""

echo "========================================="
echo "2. 内核 BPF 支持检查"
echo "========================================="
echo ""

echo "检查内核配置..."
if [ -f /boot/config-$(uname -r) ]; then
    echo "✓ 内核配置文件存在"
    echo ""

    echo "关键配置项:"
    for config in CONFIG_BPF CONFIG_BPF_SYSCALL CONFIG_BPF_JIT CONFIG_HAVE_EBPF_JIT CONFIG_BPF_EVENTS; do
        value=$(grep "^$config=" /boot/config-$(uname -r) 2>/dev/null || echo "$config is not set")
        if [[ $value == *"=y"* ]]; then
            echo "  ✓ $config=y"
        else
            echo "  ✗ $value"
        fi
    done
else
    echo "⚠ 内核配置文件不存在: /boot/config-$(uname -r)"
    echo "  尝试检查 /proc/config.gz..."
    if [ -f /proc/config.gz ]; then
        zcat /proc/config.gz | grep -E "CONFIG_BPF|CONFIG_BPF_SYSCALL" | head -5
    else
        echo "  /proc/config.gz 也不存在"
    fi
fi
echo ""

echo "检查 BPF 文件系统..."
if mount | grep -q bpffs; then
    echo "✓ BPF 文件系统已挂载"
    mount | grep bpffs
else
    echo "✗ BPF 文件系统未挂载"
    echo "  可以手动挂载: mount -t bpf bpf /sys/fs/bpf"
fi
echo ""

echo "========================================="
echo "3. BCC 工具安装检查"
echo "========================================="
echo ""

# BCC 工具列表
BCC_TOOLS=(
    "execsnoop"
    "opensnoop"
    "biosnoop"
    "tcpconnect"
    "tcpaccept"
    "tcpretrans"
    "runqlat"
    "profile"
    "offcputime"
    "memleak"
)

INSTALLED=0
MISSING=0

echo "检查 BCC 工具..."
for tool in "${BCC_TOOLS[@]}"; do
    if command -v $tool >/dev/null 2>&1; then
        echo "  ✓ $tool"
        ((INSTALLED++))
    else
        echo "  ✗ $tool (未安装)"
        ((MISSING++))
    fi
done
echo ""

echo "安装情况: $INSTALLED/$((INSTALLED + MISSING)) 工具可用"
echo ""

if [ $MISSING -gt 0 ]; then
    echo "安装 BCC 工具:"
    echo ""

    if [ -f /etc/redhat-release ]; then
        echo "  RHEL/CentOS/Fedora:"
        echo "    sudo dnf install bcc-tools"
        echo ""
        echo "  或者从源码安装:"
        echo "    git clone https://github.com/iovisor/bcc.git"
        echo "    cd bcc"
        echo "    mkdir build && cd build"
        echo "    cmake .."
        echo "    make && sudo make install"
    elif [ -f /etc/debian_version ]; then
        echo "  Ubuntu/Debian:"
        echo "    sudo apt-get update"
        echo "    sudo apt-get install bpfcc-tools libbpfcc-dev"
        echo ""
        echo "  Ubuntu 18.04+ 从源码安装:"
        echo "    sudo apt-get install bison build-essential cmake flex git libedit-dev"
        echo "    sudo apt-get install libllvm6.0 llvm-6.0-dev libclang-6.0-dev python zlib1g-dev libelf-dev"
        echo "    git clone https://github.com/iovisor/bcc.git"
        echo "    cd bcc && mkdir build && cd build"
        echo "    cmake .."
        echo "    make && sudo make install"
    fi
    echo ""
fi

echo "========================================="
echo "4. Python 绑定检查"
echo "========================================="
echo ""

if python3 -c "import bcc" 2>/dev/null; then
    echo "✓ Python BCC 绑定已安装"
    python3 -c "import bcc; print('  版本:', bcc.__version__ if hasattr(bcc, '__version__') else '未知')"
else
    echo "✗ Python BCC 绑定未安装"
    echo ""
    echo "安装方法:"
    echo "  pip3 install bcc"
    echo "  或"
    echo "  dnf install python3-bcc  (RHEL/Fedora)"
    echo "  apt-get install python3-bpfcc  (Ubuntu/Debian)"
fi
echo ""

echo "========================================="
echo "5. 调试符号检查"
echo "========================================="
echo ""

if [ -d /usr/lib/debug ]; then
    echo "✓ 调试符号目录存在: /usr/lib/debug"

    # 检查内核调试符号
    KERNEL_DEBUG="/usr/lib/debug/lib/modules/$(uname -r)"
    if [ -d "$KERNEL_DEBUG" ]; then
        echo "✓ 内核调试符号已安装"
    else
        echo "✗ 内核调试符号未安装"
        echo ""
        echo "安装方法:"
        if [ -f /etc/redhat-release ]; then
            echo "  sudo debuginfo-install kernel"
            echo "  或"
            echo "  sudo dnf install kernel-debuginfo-$(uname -r)"
        else
            echo "  sudo apt-get install linux-image-$(uname -r)-dbgsym"
        fi
    fi
else
    echo "⚠ 调试符号目录不存在"
fi
echo ""

echo "========================================="
echo "6. 快速功能测试"
echo "========================================="
echo ""

if [ "$EUID" -eq 0 ]; then
    if command -v execsnoop >/dev/null 2>&1; then
        echo "测试 execsnoop..."
        timeout 2 execsnoop > /tmp/bcc_test.txt 2>&1 &
        TEST_PID=$!

        sleep 0.5
        ls / > /dev/null 2>&1

        wait $TEST_PID 2>/dev/null

        if [ -s /tmp/bcc_test.txt ]; then
            echo "✓ execsnoop 工作正常"
            echo "  捕获到 $(wc -l < /tmp/bcc_test.txt) 个事件"
        else
            echo "✗ execsnoop 没有捕获到事件"
            echo "  可能原因: 内核不支持或权限不足"
        fi
        rm -f /tmp/bcc_test.txt
    else
        echo "⊘ execsnoop 未安装，跳过测试"
    fi
else
    echo "⊘ 需要 root 权限进行功能测试"
    echo "  运行: sudo $0"
fi
echo ""

echo "========================================="
echo "总结"
echo "========================================="
echo ""

if [ $INSTALLED -eq ${#BCC_TOOLS[@]} ]; then
    echo "✓ BCC 环境完全就绪！"
    echo "✓ 所有 10 个工具都已安装"
    echo ""
    echo "可以开始使用:"
    echo "  cd tests/bcc"
    echo "  sudo ./test_execsnoop.sh"
    echo "  sudo ./test_opensnoop.sh"
    echo "  ..."
elif [ $INSTALLED -gt 0 ]; then
    echo "⚠ BCC 环境部分就绪"
    echo "✓ $INSTALLED 个工具已安装"
    echo "✗ $MISSING 个工具未安装"
    echo ""
    echo "建议安装缺少的工具（见上文）"
else
    echo "✗ BCC 环境未就绪"
    echo "需要先安装 BCC 工具"
    echo ""
    echo "安装指南:"
    echo "  https://github.com/iovisor/bcc/blob/master/INSTALL.md"
fi
echo ""

echo "内核要求:"
if [[ $(uname -r | cut -d. -f1) -ge 5 ]] || [[ $(uname -r | cut -d. -f1) -eq 4 && $(uname -r | cut -d. -f2) -ge 9 ]]; then
    echo "✓ 内核版本 $(uname -r) 满足要求 (>= 4.9)"
elif [[ $(uname -r | cut -d. -f1) -eq 4 && $(uname -r | cut -d. -f2) -ge 4 ]]; then
    echo "⚠ 内核版本 $(uname -r) 基本满足 (>= 4.4)，但推荐 >= 4.9"
else
    echo "✗ 内核版本 $(uname -r) 太老，建议升级到 >= 4.9"
fi
echo ""

echo "完成！"
