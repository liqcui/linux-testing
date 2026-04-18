#!/bin/bash
# platform_detect.sh - 平台检测和信息收集库
# 提供统一的系统信息检测功能

# 检测系统信息
detect_system() {
    export KERNEL_VERSION=$(uname -r)
    export KERNEL_MAJOR=$(echo $KERNEL_VERSION | cut -d. -f1)
    export KERNEL_MINOR=$(echo $KERNEL_VERSION | cut -d. -f2)
    export ARCH=$(uname -m)
    export OS_TYPE=$(uname -s)

    # 检测发行版
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        export OS_ID=$ID
        export OS_VERSION=$VERSION_ID
        export OS_NAME=$PRETTY_NAME
        export OS_VERSION_CODENAME=${VERSION_CODENAME:-unknown}
    elif [[ -f /etc/redhat-release ]]; then
        export OS_ID="rhel"
        export OS_NAME=$(cat /etc/redhat-release)
    elif [[ -f /etc/debian_version ]]; then
        export OS_ID="debian"
        export OS_NAME="Debian $(cat /etc/debian_version)"
    else
        export OS_ID="unknown"
        export OS_NAME="Unknown Linux"
    fi
}

# 获取包管理器
get_package_manager() {
    if command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    elif command -v zypper &> /dev/null; then
        echo "zypper"
    elif command -v apk &> /dev/null; then
        echo "apk"
    else
        echo "unknown"
    fi
}

# 检测发行版系列
get_distro_family() {
    case "$OS_ID" in
        fedora|rhel|centos|rocky|almalinux)
            echo "rhel"
            ;;
        ubuntu|debian|linuxmint|pop)
            echo "debian"
            ;;
        arch|manjaro|endeavour)
            echo "arch"
            ;;
        opensuse*|sles)
            echo "suse"
            ;;
        alpine)
            echo "alpine"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# 检查内核版本是否满足要求
check_kernel_version() {
    local required_major=$1
    local required_minor=$2

    if [[ $KERNEL_MAJOR -gt $required_major ]]; then
        return 0
    elif [[ $KERNEL_MAJOR -eq $required_major ]] && [[ $KERNEL_MINOR -ge $required_minor ]]; then
        return 0
    else
        return 1
    fi
}

# 检查是否在虚拟机中运行
is_virtual_machine() {
    # 方法1: 检查 systemd-detect-virt
    if command -v systemd-detect-virt &> /dev/null; then
        local virt=$(systemd-detect-virt)
        if [[ "$virt" != "none" ]]; then
            export VM_TYPE=$virt
            return 0
        fi
    fi

    # 方法2: 检查 /sys/class/dmi/id/
    if [[ -f /sys/class/dmi/id/product_name ]]; then
        local product=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
        case "$product" in
            *VirtualBox*|*VMware*|*KVM*|*QEMU*|*Hyper-V*|*Xen*)
                export VM_TYPE=$product
                return 0
                ;;
        esac
    fi

    # 方法3: 检查 cpuinfo
    if grep -q "hypervisor" /proc/cpuinfo 2>/dev/null; then
        export VM_TYPE="unknown-hypervisor"
        return 0
    fi

    export VM_TYPE="none"
    return 1
}

# 检查是否在容器中运行
is_container() {
    # 检查 /.dockerenv
    if [[ -f /.dockerenv ]]; then
        export CONTAINER_TYPE="docker"
        return 0
    fi

    # 检查 cgroup
    if grep -q docker /proc/1/cgroup 2>/dev/null; then
        export CONTAINER_TYPE="docker"
        return 0
    fi

    if grep -q lxc /proc/1/cgroup 2>/dev/null; then
        export CONTAINER_TYPE="lxc"
        return 0
    fi

    # 检查 systemd-detect-virt
    if command -v systemd-detect-virt &> /dev/null; then
        local container=$(systemd-detect-virt -c)
        if [[ "$container" != "none" ]]; then
            export CONTAINER_TYPE=$container
            return 0
        fi
    fi

    export CONTAINER_TYPE="none"
    return 1
}

# 获取 CPU 信息
get_cpu_info() {
    export CPU_COUNT=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo)
    export CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
}

# 获取内存信息
get_memory_info() {
    if command -v free &> /dev/null; then
        export TOTAL_MEM_GB=$(free -g | awk '/^Mem:/{print $2}')
        export TOTAL_MEM_MB=$(free -m | awk '/^Mem:/{print $2}')
    elif [[ -f /proc/meminfo ]]; then
        local mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        export TOTAL_MEM_MB=$((mem_kb / 1024))
        export TOTAL_MEM_GB=$((mem_kb / 1024 / 1024))
    fi
}

# 显示系统信息摘要
show_system_info() {
    detect_system
    get_cpu_info
    get_memory_info

    echo "系统信息摘要:"
    echo "  操作系统: $OS_NAME"
    echo "  发行版 ID: $OS_ID"
    echo "  内核版本: $KERNEL_VERSION"
    echo "  架构: $ARCH"
    echo "  CPU: $CPU_MODEL ($CPU_COUNT cores)"
    echo "  内存: ${TOTAL_MEM_GB}GB (${TOTAL_MEM_MB}MB)"
    echo "  包管理器: $(get_package_manager)"
    echo "  发行版系列: $(get_distro_family)"

    if is_virtual_machine; then
        echo "  虚拟化: 是 ($VM_TYPE)"
    else
        echo "  虚拟化: 否"
    fi

    if is_container; then
        echo "  容器: 是 ($CONTAINER_TYPE)"
    else
        echo "  容器: 否"
    fi
}

# 检查必需的工具
check_required_tools() {
    local tools=("$@")
    local missing=()

    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing+=("$tool")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "缺少以下工具: ${missing[*]}"
        return 1
    fi

    return 0
}

# 安装包（自动选择包管理器）
install_package() {
    local packages=("$@")
    local pkg_mgr=$(get_package_manager)

    case "$pkg_mgr" in
        dnf|yum)
            $pkg_mgr install -y "${packages[@]}"
            ;;
        apt)
            apt-get update
            apt-get install -y "${packages[@]}"
            ;;
        pacman)
            pacman -Sy --noconfirm "${packages[@]}"
            ;;
        zypper)
            zypper install -y "${packages[@]}"
            ;;
        apk)
            apk add "${packages[@]}"
            ;;
        *)
            echo "不支持的包管理器: $pkg_mgr"
            return 1
            ;;
    esac
}

# 如果直接运行此脚本，显示系统信息
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    show_system_info
fi
