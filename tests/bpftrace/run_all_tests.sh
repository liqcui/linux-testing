#!/bin/bash
# run_all_tests.sh - bpftrace 全部测试运行脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "bpftrace 全部测试套件"
echo "========================================"
echo ""

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
   echo "错误: 此脚本需要 root 权限"
   echo "使用: sudo $0"
   exit 1
fi

# 检查 bpftrace
if ! command -v bpftrace &> /dev/null; then
    echo "错误: bpftrace 未安装"
    echo "运行安装脚本: sudo ./install_bpftrace.sh"
    exit 1
fi

# 编译 mock 程序
echo "准备测试环境..."
echo "----------------"
cd "$SCRIPT_DIR/mock_programs"
if ! make all 2>&1; then
    echo "错误: mock 程序编译失败"
    exit 1
fi
echo ""

cd "$SCRIPT_DIR"

# 测试列表
TESTS=(
    "test_syscall_count.sh:系统调用统计"
    "test_function_latency.sh:内核函数延迟"
    "test_tcp_lifecycle.sh:TCP 生命周期"
    "test_memory_alloc.sh:内存分配跟踪"
    "test_process_lifecycle.sh:进程生命周期"
    "test_vfs_io.sh:VFS I/O 跟踪"
)

# 运行测试
TOTAL=${#TESTS[@]}
PASSED=0
FAILED=0

for i in "${!TESTS[@]}"; do
    IFS=':' read -r test_script test_name <<< "${TESTS[$i]}"

    echo ""
    echo "========================================"
    echo "测试 $((i+1))/$TOTAL: $test_name"
    echo "========================================"
    echo ""

    if [[ -f "$test_script" ]]; then
        if bash "$test_script"; then
            PASSED=$((PASSED + 1))
            echo ""
            echo "✓ 测试通过: $test_name"
        else
            FAILED=$((FAILED + 1))
            echo ""
            echo "✗ 测试失败: $test_name"
        fi
    else
        echo "错误: 测试脚本不存在: $test_script"
        FAILED=$((FAILED + 1))
    fi

    # 测试间隔
    if [[ $((i+1)) -lt $TOTAL ]]; then
        echo ""
        echo "等待 5 秒后继续下一个测试..."
        sleep 5
    fi
done

# 总结
echo ""
echo "========================================"
echo "测试总结"
echo "========================================"
echo "总测试数: $TOTAL"
echo "通过: $PASSED"
echo "失败: $FAILED"
echo ""

if [[ $FAILED -eq 0 ]]; then
    echo "✓ 所有测试通过！"
    exit 0
else
    echo "✗ 有 $FAILED 个测试失败"
    exit 1
fi
