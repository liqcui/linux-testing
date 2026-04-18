#!/bin/bash
# 块设备I/O性能测试脚本

set -e

OUTPUT_DIR="./results/block"
mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TEST_FILE="./test_io_$TIMESTAMP.dat"
TEST_SIZE=100  # MB

echo "========================================="
echo "块设备 I/O 性能测试"
echo "时间: $(date)"
echo "测试文件: $TEST_FILE"
echo "测试大小: ${TEST_SIZE}MB"
echo "========================================="

# 1. 缓存写入测试
echo ""
echo "[1/6] 测试缓存写入（无真实磁盘I/O）..."
perf stat -e 'block:*' -o "$OUTPUT_DIR/block_cached_$TIMESTAMP.txt" \
    dd if=/dev/zero of="$TEST_FILE" bs=1M count=$TEST_SIZE 2>&1 | tee -a "$OUTPUT_DIR/block_cached_$TIMESTAMP.txt"
echo "✓ 结果保存到: $OUTPUT_DIR/block_cached_$TIMESTAMP.txt"

# 2. Direct I/O 写入测试
echo ""
echo "[2/6] 测试 Direct I/O 写入（真实磁盘I/O）..."
rm -f "$TEST_FILE"
perf stat -e 'block:*' -o "$OUTPUT_DIR/block_direct_write_$TIMESTAMP.txt" \
    dd if=/dev/zero of="$TEST_FILE" bs=1M count=$TEST_SIZE oflag=direct 2>&1 | tee -a "$OUTPUT_DIR/block_direct_write_$TIMESTAMP.txt"
echo "✓ 结果保存到: $OUTPUT_DIR/block_direct_write_$TIMESTAMP.txt"

# 3. Direct I/O 读取测试
echo ""
echo "[3/6] 测试 Direct I/O 读取..."
# 清空缓存
sync
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || echo "⚠ 无法清空缓存（需要 root 权限）"
perf stat -e 'block:*' -o "$OUTPUT_DIR/block_direct_read_$TIMESTAMP.txt" \
    dd if="$TEST_FILE" of=/dev/null bs=1M iflag=direct 2>&1 | tee -a "$OUTPUT_DIR/block_direct_read_$TIMESTAMP.txt"
echo "✓ 结果保存到: $OUTPUT_DIR/block_direct_read_$TIMESTAMP.txt"

# 4. fsync 同步写入测试
echo ""
echo "[4/6] 测试 fsync 同步写入..."
rm -f "$TEST_FILE"
perf stat -e 'block:*' -o "$OUTPUT_DIR/block_fsync_$TIMESTAMP.txt" \
    dd if=/dev/zero of="$TEST_FILE" bs=1M count=$TEST_SIZE conv=fsync 2>&1 | tee -a "$OUTPUT_DIR/block_fsync_$TIMESTAMP.txt"
echo "✓ 结果保存到: $OUTPUT_DIR/block_fsync_$TIMESTAMP.txt"

# 5. 详细 I/O 事件跟踪
echo ""
echo "[5/6] 记录详细的块 I/O 事件..."
rm -f "$TEST_FILE"
perf record -e 'block:*' -a -o "$OUTPUT_DIR/block_events_$TIMESTAMP.data" \
    dd if=/dev/zero of="$TEST_FILE" bs=1M count=10 oflag=direct 2>&1
perf script -i "$OUTPUT_DIR/block_events_$TIMESTAMP.data" > "$OUTPUT_DIR/block_events_$TIMESTAMP.txt"
echo "✓ 结果保存到: $OUTPUT_DIR/block_events_$TIMESTAMP.txt"

# 6. 生成报告
echo ""
echo "[6/6] 生成测试报告..."
{
    echo "块设备 I/O 性能测试报告"
    echo "======================"
    echo "测试时间: $(date)"
    echo "主机名: $(hostname)"
    echo "测试文件: $TEST_FILE"
    echo "测试大小: ${TEST_SIZE}MB"
    echo ""

    echo "## 系统信息"
    echo ""
    echo "### 磁盘信息"
    df -h .
    echo ""
    lsblk
    echo ""

    echo "## 性能对比"
    echo ""

    echo "### 1. 缓存写入"
    grep "bytes" "$OUTPUT_DIR/block_cached_$TIMESTAMP.txt" | tail -1
    grep "block:block_bio_queue" "$OUTPUT_DIR/block_cached_$TIMESTAMP.txt" || echo "块事件: 0 (全部在缓存中)"
    echo ""

    echo "### 2. Direct I/O 写入"
    grep "bytes" "$OUTPUT_DIR/block_direct_write_$TIMESTAMP.txt" | tail -1
    grep "block:block_bio_queue" "$OUTPUT_DIR/block_direct_write_$TIMESTAMP.txt" || echo "块事件: 未记录"
    echo ""

    echo "### 3. Direct I/O 读取"
    grep "bytes" "$OUTPUT_DIR/block_direct_read_$TIMESTAMP.txt" | tail -1
    grep "block:block_bio_queue" "$OUTPUT_DIR/block_direct_read_$TIMESTAMP.txt" || echo "块事件: 未记录"
    echo ""

    echo "### 4. fsync 同步写入"
    grep "bytes" "$OUTPUT_DIR/block_fsync_$TIMESTAMP.txt" | tail -1
    grep "block:block_bio_queue" "$OUTPUT_DIR/block_fsync_$TIMESTAMP.txt" || echo "块事件: 未记录"
    echo ""

    echo "## 块事件统计"
    echo ""
    if [ -f "$OUTPUT_DIR/block_events_$TIMESTAMP.txt" ]; then
        echo "bio_queue 事件数: $(grep -c 'block:block_bio_queue' "$OUTPUT_DIR/block_events_$TIMESTAMP.txt" 2>/dev/null || echo 0)"
        echo "rq_issue 事件数: $(grep -c 'block:block_rq_issue' "$OUTPUT_DIR/block_events_$TIMESTAMP.txt" 2>/dev/null || echo 0)"
        echo "rq_complete 事件数: $(grep -c 'block:block_rq_complete' "$OUTPUT_DIR/block_events_$TIMESTAMP.txt" 2>/dev/null || echo 0)"
    fi

    echo ""
    echo "## 内存使用"
    echo ""
    free -h

} > "$OUTPUT_DIR/report_$TIMESTAMP.txt"

echo "✓ 报告保存到: $OUTPUT_DIR/report_$TIMESTAMP.txt"

# 清理测试文件
echo ""
echo "清理测试文件..."
rm -f "$TEST_FILE"
# rm -f "$OUTPUT_DIR"/*.data  # 可选：删除 perf 数据文件

echo ""
echo "========================================="
echo "测试完成！"
echo "所有结果保存在: $OUTPUT_DIR"
echo "========================================="
