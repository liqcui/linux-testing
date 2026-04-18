#!/bin/bash
# Linux 性能测试工具安装脚本
# 支持 RHEL/CentOS 和 Debian/Ubuntu

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$(cd "$SCRIPT_DIR/../tools" && pwd)"

echo "========================================="
echo "Linux 性能测试工具安装"
echo "========================================="
echo ""

# 检测系统类型
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS="rhel"
    else
        OS=$(uname -s)
    fi
    echo "检测到系统: $OS"
}

# 检查是否有 root 权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "错误: 需要 root 权限来安装软件包"
        echo "请使用: sudo $0"
        exit 1
    fi
}

# 安装 perf
install_perf() {
    echo ""
    echo ">>> 安装 perf (Linux 性能分析工具)"
    echo "========================================"

    if command -v perf >/dev/null 2>&1; then
        echo "✓ perf 已安装: $(perf --version 2>&1 | head -1)"
        return 0
    fi

    case $OS in
        rhel|centos|fedora|almalinux|rocky)
            echo "使用 yum/dnf 安装 perf..."
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y perf
            else
                yum install -y perf
            fi
            ;;
        ubuntu|debian)
            echo "使用 apt 安装 perf..."
            apt update
            apt install -y linux-tools-common linux-tools-generic linux-tools-$(uname -r) || \
            apt install -y linux-tools-$(uname -r) || \
            apt install -y linux-perf
            ;;
        *)
            echo "⚠ 不支持的系统: $OS"
            echo "请手动安装 perf"
            return 1
            ;;
    esac

    if command -v perf >/dev/null 2>&1; then
        echo "✓ perf 安装成功"
        perf --version
    else
        echo "✗ perf 安装失败"
        return 1
    fi
}

# 安装 stress-ng
install_stress_ng() {
    echo ""
    echo ">>> 安装 stress-ng (压力测试工具)"
    echo "========================================"

    if command -v stress-ng >/dev/null 2>&1; then
        echo "✓ stress-ng 已安装: $(stress-ng --version 2>&1 | head -1)"
        return 0
    fi

    case $OS in
        rhel|centos|fedora|almalinux|rocky)
            echo "使用 yum/dnf 安装 stress-ng..."
            # EPEL 仓库可能需要
            if ! rpm -q epel-release >/dev/null 2>&1; then
                echo "安装 EPEL 仓库..."
                if command -v dnf >/dev/null 2>&1; then
                    dnf install -y epel-release
                else
                    yum install -y epel-release
                fi
            fi

            if command -v dnf >/dev/null 2>&1; then
                dnf install -y stress-ng
            else
                yum install -y stress-ng
            fi
            ;;
        ubuntu|debian)
            echo "使用 apt 安装 stress-ng..."
            apt update
            apt install -y stress-ng
            ;;
        *)
            echo "⚠ 不支持的系统: $OS"
            echo "请手动安装 stress-ng"
            return 1
            ;;
    esac

    if command -v stress-ng >/dev/null 2>&1; then
        echo "✓ stress-ng 安装成功"
        stress-ng --version | head -1
    else
        echo "✗ stress-ng 安装失败"
        return 1
    fi
}

# 编译安装 packetdrill
install_packetdrill() {
    echo ""
    echo ">>> 编译安装 packetdrill (TCP 测试工具)"
    echo "========================================"

    PACKETDRILL_DIR="$TOOLS_DIR/packetdrill"

    if [ -f "$PACKETDRILL_DIR/gtests/net/packetdrill/packetdrill" ]; then
        echo "✓ packetdrill 已存在: $PACKETDRILL_DIR/gtests/net/packetdrill/packetdrill"
        return 0
    fi

    # 安装编译依赖
    echo "安装编译依赖..."
    case $OS in
        rhel|centos|fedora|almalinux|rocky)
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y git gcc make flex bison
            else
                yum install -y git gcc make flex bison
            fi
            ;;
        ubuntu|debian)
            apt update
            apt install -y git gcc make flex bison
            ;;
        *)
            echo "⚠ 请手动安装: git gcc make flex bison"
            ;;
    esac

    # 克隆并编译
    echo "克隆 packetdrill 仓库..."
    cd "$TOOLS_DIR"
    if [ -d "packetdrill" ]; then
        echo "目录已存在，更新仓库..."
        cd packetdrill
        git pull
    else
        git clone https://github.com/google/packetdrill.git
        cd packetdrill
    fi

    echo "编译 packetdrill..."
    cd gtests/net/packetdrill
    ./configure
    make

    if [ -f "packetdrill" ]; then
        echo "✓ packetdrill 编译成功"
        echo "  位置: $(pwd)/packetdrill"

        # 创建软链接
        ln -sf "$(pwd)/packetdrill" "$TOOLS_DIR/packetdrill-bin" 2>/dev/null || true
        echo "  软链接: $TOOLS_DIR/packetdrill-bin"
    else
        echo "✗ packetdrill 编译失败"
        return 1
    fi
}

# 安装其他有用的工具
install_optional_tools() {
    echo ""
    echo ">>> 安装可选工具"
    echo "========================================"

    local tools=(
        "iftop:网络流量监控"
        "iotop:磁盘I/O监控"
        "htop:进程监控"
        "sysstat:系统统计(iostat, sar)"
        "net-tools:网络工具(ifconfig, netstat)"
        "iproute2:现代网络工具(ip, ss)"
    )

    for tool_info in "${tools[@]}"; do
        IFS=':' read -r tool desc <<< "$tool_info"

        if command -v "$tool" >/dev/null 2>&1; then
            echo "✓ $tool ($desc) - 已安装"
            continue
        fi

        echo ""
        read -p "是否安装 $tool ($desc)? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            case $OS in
                rhel|centos|fedora|almalinux|rocky)
                    if command -v dnf >/dev/null 2>&1; then
                        dnf install -y "$tool" || echo "⚠ $tool 安装失败"
                    else
                        yum install -y "$tool" || echo "⚠ $tool 安装失败"
                    fi
                    ;;
                ubuntu|debian)
                    apt install -y "$tool" || echo "⚠ $tool 安装失败"
                    ;;
            esac
        fi
    done
}

# 配置系统参数
configure_system() {
    echo ""
    echo ">>> 配置系统参数"
    echo "========================================"

    # 允许普通用户使用 perf
    echo "配置 perf 权限..."
    if [ -f /proc/sys/kernel/perf_event_paranoid ]; then
        current=$(cat /proc/sys/kernel/perf_event_paranoid)
        echo "  当前 perf_event_paranoid: $current"
        echo "  建议值: -1 (允许所有用户)"

        read -p "是否修改为 -1? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sysctl -w kernel.perf_event_paranoid=-1
            echo "kernel.perf_event_paranoid = -1" >> /etc/sysctl.d/99-perf.conf
            echo "✓ 已配置（重启后生效）"
        fi
    fi

    # 创建工具快捷方式
    echo ""
    echo "创建工具快捷脚本..."
    cat > "$TOOLS_DIR/perf-helper.sh" << 'EOF'
#!/bin/bash
# Perf 辅助脚本

case "$1" in
    net)
        perf trace -e 'net:*' "${@:2}"
        ;;
    sched)
        perf sched record -a "${@:2}"
        ;;
    block)
        perf stat -e 'block:*' "${@:2}"
        ;;
    *)
        echo "用法: $0 {net|sched|block} [命令]"
        echo "示例:"
        echo "  $0 net ping -c 1 google.com"
        echo "  $0 sched sleep 10"
        echo "  $0 block dd if=/dev/zero of=test bs=1M count=100"
        ;;
esac
EOF
    chmod +x "$TOOLS_DIR/perf-helper.sh"
    echo "✓ 创建: $TOOLS_DIR/perf-helper.sh"
}

# 验证安装
verify_installation() {
    echo ""
    echo "========================================="
    echo "验证安装"
    echo "========================================="

    local all_ok=true

    echo ""
    echo "必需工具:"
    if command -v perf >/dev/null 2>&1; then
        echo "  ✓ perf: $(perf --version 2>&1 | head -1)"
    else
        echo "  ✗ perf: 未安装"
        all_ok=false
    fi

    echo ""
    echo "推荐工具:"
    if command -v stress-ng >/dev/null 2>&1; then
        echo "  ✓ stress-ng: $(stress-ng --version 2>&1 | head -1)"
    else
        echo "  ✗ stress-ng: 未安装"
    fi

    if [ -f "$TOOLS_DIR/packetdrill/gtests/net/packetdrill/packetdrill" ]; then
        echo "  ✓ packetdrill: $TOOLS_DIR/packetdrill/gtests/net/packetdrill/packetdrill"
    else
        echo "  ✗ packetdrill: 未安装"
    fi

    echo ""
    echo "可选工具:"
    for tool in iftop iotop htop iostat ss ip; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo "  ✓ $tool"
        else
            echo "  - $tool (未安装)"
        fi
    done

    echo ""
    if [ "$all_ok" = true ]; then
        echo "✓ 核心工具安装成功！"
        return 0
    else
        echo "⚠ 部分核心工具安装失败"
        return 1
    fi
}

# 生成使用文档
generate_usage_doc() {
    echo ""
    echo "========================================="
    echo "生成使用文档"
    echo "========================================="

    cat > "$TOOLS_DIR/README.md" << 'EOF'
# 工具使用说明

## 已安装工具

### Perf - Linux 性能分析工具
```bash
# 查看所有可用事件
perf list

# 网络事件跟踪
perf trace -e 'net:*' ping -c 1 google.com

# 调度分析
perf sched record -a sleep 10
perf sched latency

# 块设备分析
perf stat -e 'block:*' dd if=/dev/zero of=test bs=1M count=100
```

### Stress-ng - 压力测试工具
```bash
# CPU 压力测试
stress-ng --cpu 4 --timeout 10s

# 内存压力测试
stress-ng --vm 2 --vm-bytes 1G --timeout 10s

# I/O 压力测试
stress-ng --io 4 --timeout 10s
```

### Packetdrill - TCP 测试工具
```bash
# 运行测试
cd tools/packetdrill/gtests/net/packetdrill
./packetdrill test.pkt

# 详细输出
./packetdrill --verbose test.pkt
```

## 工具位置

- Perf 辅助脚本: `tools/perf-helper.sh`
- Packetdrill: `tools/packetdrill/gtests/net/packetdrill/packetdrill`
- Packetdrill 软链接: `tools/packetdrill-bin`

## 快速使用

```bash
# 使用 perf 辅助脚本
./tools/perf-helper.sh net ping -c 1 google.com
./tools/perf-helper.sh sched sleep 10
./tools/perf-helper.sh block dd if=/dev/zero of=test bs=1M count=100
```
EOF

    echo "✓ 文档生成: $TOOLS_DIR/README.md"
}

# 主函数
main() {
    detect_os
    check_root

    echo ""
    echo "将安装以下工具:"
    echo "  1. perf (必需)"
    echo "  2. stress-ng (推荐)"
    echo "  3. packetdrill (推荐)"
    echo "  4. 其他可选工具"
    echo ""
    read -p "继续安装? [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ -n $REPLY ]]; then
        echo "安装已取消"
        exit 0
    fi

    # 安装核心工具
    install_perf
    install_stress_ng
    install_packetdrill

    # 安装可选工具
    install_optional_tools

    # 配置系统
    configure_system

    # 验证安装
    verify_installation

    # 生成文档
    generate_usage_doc

    echo ""
    echo "========================================="
    echo "安装完成！"
    echo "========================================="
    echo ""
    echo "下一步:"
    echo "  1. 查看工具文档: cat $TOOLS_DIR/README.md"
    echo "  2. 运行测试: cd .. && ./scripts/run-all-tests.sh"
    echo ""
}

main "$@"
