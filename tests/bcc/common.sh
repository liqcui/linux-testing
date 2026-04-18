#!/bin/bash
# BCC 测试公共函数和配置

# 设置 BCC 工具默认路径
BCC_TOOLS_PATH="${BCC_TOOLS_PATH:-/usr/share/bcc/tools}"

# 检查并设置 PATH
if [[ -d "$BCC_TOOLS_PATH" ]]; then
    # 将 BCC 工具路径添加到 PATH（如果还没有）
    if [[ ":$PATH:" != *":$BCC_TOOLS_PATH:"* ]]; then
        export PATH="$BCC_TOOLS_PATH:$PATH"
    fi
fi

# 查找 BCC 工具的函数
find_bcc_tool() {
    local tool_name="$1"
    local tool_path=""

    # 方法1: 在 PATH 中查找
    if command -v "$tool_name" >/dev/null 2>&1; then
        tool_path=$(command -v "$tool_name")
        echo "$tool_path"
        return 0
    fi

    # 方法2: 在标准路径中查找
    local search_paths=(
        "/usr/share/bcc/tools"
        "/usr/local/share/bcc/tools"
        "/opt/bcc/tools"
    )

    for path in "${search_paths[@]}"; do
        if [[ -f "$path/$tool_name" && -x "$path/$tool_name" ]]; then
            tool_path="$path/$tool_name"
            echo "$tool_path"
            return 0
        fi
    done

    # 未找到
    return 1
}

# 检查 BCC 工具是否安装
check_bcc_installed() {
    # 检查是否安装了 bcc-tools 包
    if command -v execsnoop >/dev/null 2>&1; then
        return 0
    fi

    # 检查标准安装路径
    if [[ -d "/usr/share/bcc/tools" ]] && [[ -f "/usr/share/bcc/tools/execsnoop" ]]; then
        return 0
    fi

    return 1
}

# 显示 BCC 工具未安装的帮助信息
show_bcc_install_help() {
    echo "错误: BCC 工具未安装"
    echo ""
    echo "安装方法:"
    echo ""

    if [[ -f /etc/redhat-release ]]; then
        echo "  RHEL/CentOS/Fedora:"
        echo "    sudo dnf install bcc-tools python3-bcc"
        echo ""
        echo "  工具将安装到: /usr/share/bcc/tools/"
    elif [[ -f /etc/debian_version ]]; then
        echo "  Ubuntu/Debian:"
        echo "    sudo apt-get update"
        echo "    sudo apt-get install bpfcc-tools python3-bpfcc"
        echo ""
        echo "  工具将安装到: /usr/sbin/ 或 /usr/share/bcc/tools/"
    else
        echo "  通用方法 - 从源码安装:"
        echo "    git clone https://github.com/iovisor/bcc.git"
        echo "    cd bcc"
        echo "    mkdir build && cd build"
        echo "    cmake .."
        echo "    make"
        echo "    sudo make install"
    fi
    echo ""
    echo "安装后，工具路径将自动设置为: /usr/share/bcc/tools"
}

# 检查内核函数是否存在
check_kernel_function() {
    local func_name="$1"

    # 检查 /proc/kallsyms
    if grep -qw "$func_name" /proc/kallsyms 2>/dev/null; then
        return 0
    fi

    # 检查 available_filter_functions (需要 root)
    if [[ -f /sys/kernel/debug/tracing/available_filter_functions ]]; then
        if grep -qw "$func_name" /sys/kernel/debug/tracing/available_filter_functions 2>/dev/null; then
            return 0
        fi
    fi

    return 1
}

# 获取内核版本
get_kernel_version() {
    local version=$(uname -r | cut -d. -f1-2)
    echo "$version"
}

# 检查内核版本是否 >= 指定版本
kernel_version_ge() {
    local required="$1"
    local current=$(get_kernel_version)

    local current_major=$(echo "$current" | cut -d. -f1)
    local current_minor=$(echo "$current" | cut -d. -f2)
    local required_major=$(echo "$required" | cut -d. -f1)
    local required_minor=$(echo "$required" | cut -d. -f2)

    if [[ $current_major -gt $required_major ]]; then
        return 0
    elif [[ $current_major -eq $required_major ]] && [[ $current_minor -ge $required_minor ]]; then
        return 0
    else
        return 1
    fi
}

# 导出函数供其他脚本使用
export -f find_bcc_tool
export -f check_bcc_installed
export -f show_bcc_install_help
export -f check_kernel_function
export -f get_kernel_version
export -f kernel_version_ge
