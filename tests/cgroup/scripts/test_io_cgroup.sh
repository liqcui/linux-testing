#!/bin/bash
# test_io_cgroup.sh - cgroup I/O限制测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRAMS_DIR="$SCRIPT_DIR/../programs"
RESULTS_DIR="$SCRIPT_DIR/../results/io-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "Cgroup I/O 限制测试"
echo "========================================"
echo ""

# 检查权限
if [[ $EUID -ne 0 ]]; then
   echo "错误: 此脚本需要 root 权限"
   echo "使用: sudo $0"
   exit 1
fi

mkdir -p "$RESULTS_DIR"

# 编译测试程序
echo "步骤 1: 编译测试程序..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd "$PROGRAMS_DIR"
make io_hog &>/dev/null

if [[ ! -f io_hog ]]; then
    echo "✗ 编译失败"
    exit 1
fi

echo "✓ 编译成功: io_hog"
echo ""

# 检测cgroup版本
echo "步骤 2: 检测cgroup版本..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

CGROUP_V2=0
if [[ -f /sys/fs/cgroup/cgroup.controllers ]]; then
    echo "✓ 检测到 cgroup v2"
    CGROUP_V2=1
    CGROUP_ROOT="/sys/fs/cgroup"
elif [[ -d /sys/fs/cgroup/blkio ]]; then
    echo "✓ 检测到 cgroup v1"
    CGROUP_V2=0
    CGROUP_ROOT="/sys/fs/cgroup/blkio"
else
    echo "✗ 无法检测到cgroup"
    exit 1
fi

echo "Cgroup根目录: $CGROUP_ROOT"
echo ""

# 获取测试设备
echo "步骤 3: 获取测试设备信息..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 获取/tmp所在的设备
TEST_PATH="/tmp"
DEVICE=$(df "$TEST_PATH" | tail -1 | awk '{print $1}')
DEVICE_MAJOR_MINOR=$(ls -l "$DEVICE" | awk '{print $5, $6}' | tr -d ',')

echo "测试路径: $TEST_PATH"
echo "设备: $DEVICE"
echo "主次设备号: $DEVICE_MAJOR_MINOR"
echo ""

# 创建测试cgroup
echo "步骤 4: 创建测试cgroup..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

TEST_GROUP="test_io_$$"
GROUP_PATH="$CGROUP_ROOT/$TEST_GROUP"

mkdir -p "$GROUP_PATH"

if [[ ! -d "$GROUP_PATH" ]]; then
    echo "✗ 创建cgroup失败"
    exit 1
fi

echo "✓ 已创建cgroup: $TEST_GROUP"
echo "  路径: $GROUP_PATH"
echo ""

# 基准测试（无限制）
echo "步骤 5: 基准测试（无限制）..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "写入500MB数据..."
"$PROGRAMS_DIR/io_hog" 500 0 "$TEST_PATH" | tee "$RESULTS_DIR/baseline.txt"

BASELINE_THROUGHPUT=$(grep "吞吐量" "$RESULTS_DIR/baseline.txt" | awk '{print $2}')
echo ""
echo "基准吞吐量: $BASELINE_THROUGHPUT MB/s"
echo ""

# I/O带宽限制测试
echo "步骤 6: I/O带宽限制测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ $CGROUP_V2 -eq 1 ]]; then
    # cgroup v2
    echo "设置写入带宽限制为10MB/s..."

    # 确保io控制器启用
    echo "+io" > "$CGROUP_ROOT/cgroup.subtree_control" 2>/dev/null

    # 格式: MAJ:MIN rbps wbps
    echo "$DEVICE_MAJOR_MINOR wbps=$((10 * 1024 * 1024))" > "$GROUP_PATH/io.max" 2>/dev/null

    if [[ $? -ne 0 ]]; then
        echo "⚠ 设置io.max失败"
        echo "注意: cgroup v2 I/O控制需要内核支持和正确的设备配置"
    else
        echo "✓ I/O带宽限制已设置"
        cat "$GROUP_PATH/io.max"
    fi
else
    # cgroup v1
    echo "设置写入带宽限制为10MB/s..."

    # 格式: MAJ:MIN BYTES_PER_SECOND
    echo "$DEVICE_MAJOR_MINOR $((10 * 1024 * 1024))" > "$GROUP_PATH/blkio.throttle.write_bps_device" 2>/dev/null

    if [[ $? -ne 0 ]]; then
        echo "⚠ 设置blkio限制失败"
        echo "可能原因:"
        echo "  1. 设备不支持I/O限制"
        echo "  2. 设备号格式不正确"
        echo "  3. 需要块设备（不支持分区）"
    else
        echo "✓ I/O带宽限制已设置"
        cat "$GROUP_PATH/blkio.throttle.write_bps_device"
    fi
fi

echo ""
echo "在cgroup中运行程序..."

{
    if [[ $CGROUP_V2 -eq 1 ]]; then
        echo $$ > "$GROUP_PATH/cgroup.procs"
    else
        echo $$ > "$GROUP_PATH/tasks"
    fi

    "$PROGRAMS_DIR/io_hog" 100 0 "$TEST_PATH"
} | tee "$RESULTS_DIR/limited-10mbs.txt"

LIMITED_THROUGHPUT=$(grep "吞吐量" "$RESULTS_DIR/limited-10mbs.txt" | awk '{print $2}')
echo ""
echo "限制后吞吐量: $LIMITED_THROUGHPUT MB/s"
echo "预期限制: ~10 MB/s"
echo ""

# I/O权重测试
echo "步骤 7: I/O权重测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

GROUP_A="$CGROUP_ROOT/test_io_a_$$"
GROUP_B="$CGROUP_ROOT/test_io_b_$$"

mkdir -p "$GROUP_A" "$GROUP_B"

if [[ $CGROUP_V2 -eq 1 ]]; then
    echo "设置I/O权重: A=50, B=200 (比例 1:4)..."
    echo "default 50" > "$GROUP_A/io.weight" 2>/dev/null
    echo "default 200" > "$GROUP_B/io.weight" 2>/dev/null

    if [[ $? -ne 0 ]]; then
        echo "⚠ 设置io.weight失败"
    else
        echo "✓ I/O权重已设置"
    fi
else
    echo "设置I/O权重: A=100, B=400 (比例 1:4)..."
    echo 100 > "$GROUP_A/blkio.weight" 2>/dev/null
    echo 400 > "$GROUP_B/blkio.weight" 2>/dev/null

    if [[ $? -ne 0 ]]; then
        echo "⚠ 设置blkio.weight失败"
        echo "注意: CFQ调度器才支持权重"
    else
        echo "✓ I/O权重已设置"
    fi
fi

echo ""
echo "启动两个竞争进程..."

# 启动进程A
(
    if [[ $CGROUP_V2 -eq 1 ]]; then
        echo $$ > "$GROUP_A/cgroup.procs"
    else
        echo $$ > "$GROUP_A/tasks"
    fi
    "$PROGRAMS_DIR/io_hog" 200 0 "$TEST_PATH"
) > "$RESULTS_DIR/weight-a.txt" 2>&1 &
PID_A=$!

sleep 1

# 启动进程B
(
    if [[ $CGROUP_V2 -eq 1 ]]; then
        echo $$ > "$GROUP_B/cgroup.procs"
    else
        echo $$ > "$GROUP_B/tasks"
    fi
    "$PROGRAMS_DIR/io_hog" 200 0 "$TEST_PATH"
) > "$RESULTS_DIR/weight-b.txt" 2>&1 &
PID_B=$!

echo "进程A (PID $PID_A): 低权重"
echo "进程B (PID $PID_B): 高权重"
echo ""

# 等待完成
wait $PID_A
wait $PID_B

THROUGHPUT_A=$(grep "吞吐量" "$RESULTS_DIR/weight-a.txt" | awk '{print $2}')
THROUGHPUT_B=$(grep "吞吐量" "$RESULTS_DIR/weight-b.txt" | awk '{print $2}')

echo "结果:"
echo "  进程A吞吐量: $THROUGHPUT_A MB/s"
echo "  进程B吞吐量: $THROUGHPUT_B MB/s"

if [[ -n "$THROUGHPUT_A" ]] && [[ -n "$THROUGHPUT_B" ]]; then
    RATIO=$(echo "scale=2; $THROUGHPUT_B / $THROUGHPUT_A" | bc 2>/dev/null)
    echo "  比例: $RATIO (预期 ~4:1)"
else
    echo "  ⚠ 无法计算比例"
fi

echo ""

# I/O统计
echo "步骤 8: I/O使用统计..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ $CGROUP_V2 -eq 1 ]]; then
    echo "cgroup v2 I/O统计:"
    if [[ -f "$GROUP_PATH/io.stat" ]]; then
        cat "$GROUP_PATH/io.stat" | head -10
    fi
else
    echo "cgroup v1 I/O统计:"
    if [[ -f "$GROUP_PATH/blkio.throttle.io_service_bytes" ]]; then
        echo "服务字节数:"
        cat "$GROUP_PATH/blkio.throttle.io_service_bytes" | head -10
    fi
    if [[ -f "$GROUP_PATH/blkio.throttle.io_serviced" ]]; then
        echo ""
        echo "服务次数:"
        cat "$GROUP_PATH/blkio.throttle.io_serviced" | head -10
    fi
fi

echo ""

# 清理
echo "清理cgroup..."
rmdir "$GROUP_A" "$GROUP_B" "$GROUP_PATH" 2>/dev/null
echo "✓ 清理完成"
echo ""

# 生成报告
{
    echo "Cgroup I/O测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo ""
    echo "系统信息:"
    echo "  Cgroup版本: $([[ $CGROUP_V2 -eq 1 ]] && echo 'v2' || echo 'v1')"
    echo "  Cgroup根目录: $CGROUP_ROOT"
    echo "  测试设备: $DEVICE"
    echo "  设备号: $DEVICE_MAJOR_MINOR"
    echo ""
    echo "测试结果:"
    echo "  基准吞吐量: $BASELINE_THROUGHPUT MB/s"
    echo "  10MB/s限制: $LIMITED_THROUGHPUT MB/s"
    echo "  权重测试:"
    echo "    低权重进程: $THROUGHPUT_A MB/s"
    echo "    高权重进程: $THROUGHPUT_B MB/s"
    if [[ -n "$RATIO" ]]; then
        echo "    比例: $RATIO (预期 4:1)"
    fi
    echo ""
    echo "注意事项:"
    echo "  - I/O限制需要块设备支持"
    echo "  - 权重功能需要特定I/O调度器(CFQ/BFQ)"
    echo "  - 某些文件系统可能不完全支持I/O控制"
    echo ""
    echo "详细日志:"
    echo "  基准测试: $RESULTS_DIR/baseline.txt"
    echo "  限制测试: $RESULTS_DIR/limited-10mbs.txt"
    echo "  权重 A: $RESULTS_DIR/weight-a.txt"
    echo "  权重 B: $RESULTS_DIR/weight-b.txt"
    echo ""
} | tee "$RESULTS_DIR/summary.txt"

echo "========================================"
echo "测试完成"
echo "========================================"
echo ""
echo "✓ I/O cgroup测试完成"
echo ""
echo "结果目录: $RESULTS_DIR"
echo ""
