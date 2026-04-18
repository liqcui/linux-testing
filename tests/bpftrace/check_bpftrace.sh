#!/bin/bash
# check_bpftrace.sh - bpftrace 环境检查脚本

echo "================================"
echo "bpftrace 环境检查"
echo "================================"
echo ""

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_pass() {
    echo -e "${GREEN}[✓]${NC} $1"
}

check_fail() {
    echo -e "${RED}[✗]${NC} $1"
}

check_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

OVERALL_STATUS=0

# 1. 检查内核版本
echo "1. 检查内核版本"
echo "----------------"
KERNEL_VERSION=$(uname -r)
KERNEL_MAJOR=$(echo $KERNEL_VERSION | cut -d. -f1)
KERNEL_MINOR=$(echo $KERNEL_VERSION | cut -d. -f2)

echo "   当前内核: $KERNEL_VERSION"

if [[ $KERNEL_MAJOR -gt 4 ]] || [[ $KERNEL_MAJOR -eq 4 && $KERNEL_MINOR -ge 9 ]]; then
    check_pass "内核版本 >= 4.9 (支持 BPF)"
else
    check_fail "内核版本过低，需要 >= 4.9"
    OVERALL_STATUS=1
fi
echo ""

# 2. 检查 bpftrace 安装
echo "2. 检查 bpftrace 安装"
echo "--------------------"
if command -v bpftrace &> /dev/null; then
    BPFTRACE_VERSION=$(bpftrace --version 2>&1 | head -1)
    check_pass "bpftrace 已安装: $BPFTRACE_VERSION"
else
    check_fail "bpftrace 未安装"
    echo ""
    echo "   安装方法:"
    echo "   Fedora/RHEL/CentOS:"
    echo "     sudo dnf install bpftrace"
    echo ""
    echo "   Ubuntu/Debian:"
    echo "     sudo apt install bpftrace"
    echo ""
    OVERALL_STATUS=1
fi
echo ""

# 3. 检查 root 权限
echo "3. 检查权限"
echo "-----------"
if [[ $EUID -eq 0 ]]; then
    check_pass "以 root 权限运行"
else
    check_warn "当前非 root 用户 (大部分 bpftrace 功能需要 root)"
    echo "   使用 'sudo' 运行 bpftrace 脚本"
fi
echo ""

# 4. 检查 BPF 文件系统
echo "4. 检查 BPF 文件系统"
echo "-------------------"
if mount | grep -q bpf; then
    check_pass "BPF 文件系统已挂载"
    mount | grep bpf | head -1 | sed 's/^/   /'
else
    check_warn "BPF 文件系统未挂载"
    echo "   挂载命令: sudo mount -t bpf none /sys/fs/bpf"
fi
echo ""

# 5. 检查 debugfs
echo "5. 检查 debugfs"
echo "--------------"
if mount | grep -q debugfs; then
    check_pass "debugfs 已挂载"
    mount | grep debugfs | head -1 | sed 's/^/   /'
else
    check_warn "debugfs 未挂载 (某些跟踪点可能不可用)"
    echo "   挂载命令: sudo mount -t debugfs none /sys/kernel/debug"
fi
echo ""

# 6. 检查 tracepoints
echo "6. 检查 tracepoints"
echo "------------------"
if [[ -d /sys/kernel/debug/tracing/events ]]; then
    TRACEPOINT_COUNT=$(find /sys/kernel/debug/tracing/events -name "enable" 2>/dev/null | wc -l)
    if [[ $TRACEPOINT_COUNT -gt 0 ]]; then
        check_pass "Tracepoints 可用 (找到 $TRACEPOINT_COUNT 个)"
    else
        check_warn "Tracepoints 目录存在但为空"
    fi
else
    check_warn "无法访问 tracepoints (可能需要 root 权限)"
fi
echo ""

# 7. 检查 kprobes 支持
echo "7. 检查 kprobes 支持"
echo "-------------------"
if [[ -f /sys/kernel/debug/kprobes/list ]]; then
    check_pass "kprobes 已启用"
else
    check_warn "无法访问 kprobes (可能需要 root 权限)"
fi
echo ""

# 8. 检查 BTF (BPF Type Format)
echo "8. 检查 BTF 支持"
echo "---------------"
if [[ -f /sys/kernel/btf/vmlinux ]]; then
    check_pass "BTF 可用 (支持 CO-RE)"
    BTF_SIZE=$(ls -lh /sys/kernel/btf/vmlinux | awk '{print $5}')
    echo "   BTF 数据大小: $BTF_SIZE"
else
    check_warn "BTF 不可用 (CO-RE 功能受限)"
    echo "   某些高级功能可能无法使用"
fi
echo ""

# 9. 测试简单的 bpftrace 命令
echo "9. 测试 bpftrace 基本功能"
echo "-------------------------"
if command -v bpftrace &> /dev/null; then
    if [[ $EUID -eq 0 ]]; then
        # 测试简单的跟踪
        TEST_OUTPUT=$(timeout 2 bpftrace -e 'BEGIN { printf("test\\n"); exit(); }' 2>&1)
        if echo "$TEST_OUTPUT" | grep -q "test"; then
            check_pass "bpftrace 基本功能正常"
        else
            check_fail "bpftrace 运行异常"
            echo "$TEST_OUTPUT" | sed 's/^/   /'
            OVERALL_STATUS=1
        fi
    else
        check_warn "需要 root 权限才能测试运行"
    fi
else
    check_fail "bpftrace 未安装，无法测试"
fi
echo ""

# 10. 检查编译环境
echo "10. 检查编译环境"
echo "---------------"
if command -v gcc &> /dev/null; then
    GCC_VERSION=$(gcc --version | head -1)
    check_pass "GCC 已安装: $GCC_VERSION"
else
    check_fail "GCC 未安装 (mock 程序需要)"
    OVERALL_STATUS=1
fi

if command -v make &> /dev/null; then
    check_pass "Make 已安装"
else
    check_fail "Make 未安装 (mock 程序需要)"
    OVERALL_STATUS=1
fi
echo ""

# 总结
echo "================================"
if [[ $OVERALL_STATUS -eq 0 ]]; then
    echo -e "${GREEN}环境检查通过！${NC}"
    echo ""
    echo "可以开始运行 bpftrace 测试:"
    echo "  cd mock_programs && make"
    echo "  sudo ../test_syscall_count.sh"
    echo "  sudo ../test_function_latency.sh"
    echo "  sudo ../test_tcp_lifecycle.sh"
    echo "  sudo ../test_memory_alloc.sh"
    echo "  sudo ../test_process_lifecycle.sh"
    echo "  sudo ../test_vfs_io.sh"
else
    echo -e "${RED}环境检查发现问题！${NC}"
    echo "请根据上述提示修复问题后再运行测试"
fi
echo "================================"

exit $OVERALL_STATUS
