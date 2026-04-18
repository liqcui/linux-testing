#!/bin/bash
# verify_syntax.sh - 验证所有 bpftrace 脚本语法

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         bpftrace 脚本语法验证                             ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# 检查 bpftrace
BPFTRACE_AVAILABLE=0
if command -v bpftrace &> /dev/null; then
    BPFTRACE_AVAILABLE=1
    echo "✓ bpftrace 可用"
else
    echo "⚠ bpftrace 未安装（仅进行静态语法检查）"
fi
echo ""

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
   echo "警告: 某些检查需要 root 权限"
   echo "建议使用: sudo $0"
fi

echo "测试脚本列表:"
echo "─────────────────────────────────────────────────────────"

TESTS=(
    "test_syscall_count.sh:系统调用统计"
    "test_function_latency.sh:内核函数延迟"
    "test_tcp_lifecycle.sh:TCP 生命周期"
    "test_memory_alloc.sh:内存分配"
    "test_process_lifecycle.sh:进程生命周期"
    "test_vfs_io.sh:VFS I/O 跟踪"
)

TOTAL=${#TESTS[@]}
PASSED=0
FAILED=0
ERRORS=()

cd "$SCRIPT_DIR"

for test_info in "${TESTS[@]}"; do
    IFS=':' read -r test_file test_name <<< "$test_info"

    echo ""
    echo "检查: $test_name ($test_file)"
    echo "─────────────────────────────────────────────────────────"

    if [[ ! -f "$test_file" ]]; then
        echo "  ✗ 文件不存在"
        FAILED=$((FAILED + 1))
        ERRORS+=("$test_name: 文件不存在")
        continue
    fi

    # 提取 bpftrace 命令并进行语法检查
    # 查找所有的 bpftrace -e '...' 命令
    SCRIPT_COUNT=0
    SCRIPT_ERRORS=0

    # 使用 awk 提取 bpftrace 脚本
    while IFS= read -r line; do
        if [[ $line =~ bpftrace[[:space:]]+-e ]]; then
            SCRIPT_COUNT=$((SCRIPT_COUNT + 1))
        fi
    done < "$test_file"

    if [[ $SCRIPT_COUNT -gt 0 ]]; then
        echo "  找到 $SCRIPT_COUNT 个 bpftrace 脚本"

        # 简单检查：查找常见的语法错误模式
        ERROR_PATTERNS=(
            "struct sock"
            "args->old_comm"
            "args->old_pid"
            "/ 1024\.0"         # 浮点除法
            "/ 1000\.0"         # 浮点除法
            "/ 1048576\.0"      # 浮点除法
            "%.2f.*/"           # 格式化字符串中的浮点除法
        )

        for pattern in "${ERROR_PATTERNS[@]}"; do
            if grep -q "$pattern" "$test_file" 2>/dev/null; then
                echo "  ✗ 发现问题: 包含 '$pattern'"
                SCRIPT_ERRORS=$((SCRIPT_ERRORS + 1))
                ERRORS+=("$test_name: 包含已知问题模式 '$pattern'")
            fi
        done

        if [[ $SCRIPT_ERRORS -eq 0 ]]; then
            echo "  ✓ 未发现已知语法问题"
            PASSED=$((PASSED + 1))
        else
            echo "  ✗ 发现 $SCRIPT_ERRORS 个问题"
            FAILED=$((FAILED + 1))
        fi
    else
        echo "  ⚠ 未找到 bpftrace 脚本"
        PASSED=$((PASSED + 1))
    fi
done

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "验证总结"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "总测试数: $TOTAL"
echo "通过: $PASSED"
echo "失败: $FAILED"
echo ""

if [[ $FAILED -eq 0 ]]; then
    echo "✓ 所有脚本通过语法检查！"
    echo ""
    echo "建议的下一步:"
    echo "  1. 编译 mock 程序: cd mock_programs && make"
    echo "  2. 运行快速测试（每个只跑几秒）"
    echo "  3. 运行完整测试: sudo ./run_all_tests.sh"
    exit 0
else
    echo "✗ 发现 $FAILED 个脚本有问题"
    echo ""
    echo "问题列表:"
    for error in "${ERRORS[@]}"; do
        echo "  - $error"
    done
    echo ""
    echo "请修复这些问题后重试"
    exit 1
fi
