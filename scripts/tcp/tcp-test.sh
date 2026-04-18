#!/bin/bash
# TCP 协议栈测试脚本（使用 packetdrill）

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PACKETDRILL="$PROJECT_ROOT/tools/packetdrill/gtests/net/packetdrill/packetdrill"
PACKETDRILL_BIN="$PROJECT_ROOT/tools/packetdrill-bin"
OUTPUT_DIR="$PROJECT_ROOT/results/tcp"
TEST_DIR="$PROJECT_ROOT/tests/tcp"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$OUTPUT_DIR"

echo "========================================="
echo "TCP 协议栈测试"
echo "时间: $(date)"
echo "========================================="

# 查找 packetdrill
find_packetdrill() {
    if [ -x "$PACKETDRILL" ]; then
        echo "$PACKETDRILL"
    elif [ -x "$PACKETDRILL_BIN" ]; then
        echo "$PACKETDRILL_BIN"
    elif command -v packetdrill >/dev/null 2>&1; then
        command -v packetdrill
    else
        echo ""
    fi
}

PACKETDRILL_CMD=$(find_packetdrill)

if [ -z "$PACKETDRILL_CMD" ]; then
    echo "✗ packetdrill 未找到"
    echo "  请运行: sudo ./setup/install-tools.sh"
    exit 1
fi

echo "使用 packetdrill: $PACKETDRILL_CMD"
echo ""

# 查找所有测试文件
TEST_FILES=$(find "$TEST_DIR" -name "*.pkt" 2>/dev/null | sort)

if [ -z "$TEST_FILES" ]; then
    echo "⚠ 未找到测试文件 ($TEST_DIR/*.pkt)"
    exit 1
fi

# 运行测试
total=0
passed=0
failed=0

for test_file in $TEST_FILES; do
    total=$((total + 1))
    test_name=$(basename "$test_file")

    echo ""
    echo "[$total] 测试: $test_name"
    echo "----------------------------------------"

    output_file="$OUTPUT_DIR/${test_name%.pkt}_$TIMESTAMP.txt"

    if "$PACKETDRILL_CMD" "$test_file" > "$output_file" 2>&1; then
        echo "✓ 通过"
        passed=$((passed + 1))
        echo "PASSED" >> "$output_file"
    else
        echo "✗ 失败"
        failed=$((failed + 1))
        echo "FAILED" >> "$output_file"
        echo ""
        echo "错误输出:"
        tail -20 "$output_file"
    fi

    echo "  结果保存: $output_file"
done

# 生成报告
echo ""
echo "========================================="
echo "[报告] 生成测试报告..."
{
    echo "TCP 协议栈测试报告"
    echo "=================="
    echo "测试时间: $(date)"
    echo "主机名: $(hostname)"
    echo ""

    echo "## 测试统计"
    echo ""
    echo "总测试数: $total"
    echo "通过: $passed"
    echo "失败: $failed"
    echo "成功率: $(awk "BEGIN {printf \"%.1f\", $passed*100/$total}")%"
    echo ""

    echo "## 测试详情"
    echo ""

    for test_file in $TEST_FILES; do
        test_name=$(basename "$test_file")
        output_file="$OUTPUT_DIR/${test_name%.pkt}_$TIMESTAMP.txt"

        echo "### $test_name"
        if grep -q "PASSED" "$output_file" 2>/dev/null; then
            echo "状态: ✓ 通过"
        else
            echo "状态: ✗ 失败"
            echo ""
            echo "错误信息:"
            echo '```'
            grep -A 5 "error" "$output_file" 2>/dev/null || echo "详见: $output_file"
            echo '```'
        fi
        echo ""
    done

    echo "## 系统信息"
    echo ""
    echo "内核版本: $(uname -r)"
    echo "系统: $(uname -s)"
    echo ""

} > "$OUTPUT_DIR/report_$TIMESTAMP.txt"

echo "✓ 报告保存: $OUTPUT_DIR/report_$TIMESTAMP.txt"

echo ""
echo "========================================="
echo "测试完成！"
echo "========================================="
echo "总测试数: $total"
echo "通过: $passed"
echo "失败: $failed"
echo "========================================="

exit $failed
