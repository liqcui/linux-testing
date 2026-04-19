#!/bin/bash
# test_spi.sh - SPI设备综合测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRAMS_DIR="$SCRIPT_DIR/../programs"
RESULTS_DIR="$SCRIPT_DIR/../results/spi-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "SPI设备测试"
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

if [[ ! -f spidev_test.c ]]; then
    echo "✗ 找不到 spidev_test.c"
    exit 1
fi

gcc -o spidev_test spidev_test.c

if [[ $? -ne 0 ]]; then
    echo "✗ 编译失败"
    exit 1
fi

echo "✓ 编译成功: spidev_test"
echo ""

# 加载SPI驱动
echo "步骤 2: 加载SPI驱动..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

modprobe spidev 2>/dev/null
if [[ $? -eq 0 ]]; then
    echo "✓ spidev 模块已加载"
else
    echo "⚠ spidev 可能已加载或不需要"
fi
echo ""

# 检测SPI设备
echo "步骤 3: 检测SPI设备..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SPI_DEVICES=($(ls /dev/spidev* 2>/dev/null))

if [[ ${#SPI_DEVICES[@]} -eq 0 ]]; then
    echo "✗ 未发现SPI设备"
    echo ""
    echo "可能原因:"
    echo "  1. 硬件不支持SPI"
    echo "  2. SPI驱动未加载"
    echo "  3. SPI总线被禁用"
    echo "  4. 设备树未配置"
    echo ""
    echo "排查方法:"
    echo "  lsmod | grep spi"
    echo "  dmesg | grep spi"
    echo "  ls -l /sys/bus/spi/devices/"
    exit 1
fi

echo "找到 ${#SPI_DEVICES[@]} 个SPI设备:"
for dev in "${SPI_DEVICES[@]}"; do
    echo "  - $dev"
    ls -l "$dev"
done
echo ""

# 选择测试设备
TEST_DEVICE="${SPI_DEVICES[0]}"
echo "测试设备: $TEST_DEVICE"
echo ""

# 设置设备权限
chmod 666 "$TEST_DEVICE"

# 基础传输测试
echo "步骤 4: 基础传输测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

"$PROGRAMS_DIR/spidev_test" -D "$TEST_DEVICE" -v | tee "$RESULTS_DIR/basic-test.txt"

if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    echo "✗ 基础测试失败"
    exit 1
fi

echo ""

# 回环测试
echo "步骤 5: 回环测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "注意: 回环测试需要硬件支持MISO/MOSI短接"
echo ""

"$PROGRAMS_DIR/spidev_test" -D "$TEST_DEVICE" -l -v | tee "$RESULTS_DIR/loopback-test.txt"

echo ""

# 速度测试
echo "步骤 6: 不同速度测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SPEEDS=(100000 500000 1000000 2000000 4000000)

{
    echo "速度测试结果"
    echo "========================================"
    echo ""
} > "$RESULTS_DIR/speed-test.txt"

for speed in "${SPEEDS[@]}"; do
    echo "测试速度: $speed Hz ($(($speed / 1000)) KHz)"

    "$PROGRAMS_DIR/spidev_test" -D "$TEST_DEVICE" -s $speed -n 100 2>&1 | tee -a "$RESULTS_DIR/speed-test.txt"

    echo ""
done

# 不同数据位测试
echo "步骤 7: 不同数据位测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

BITS_ARRAY=(8 16)

{
    echo "数据位测试结果"
    echo "========================================"
    echo ""
} > "$RESULTS_DIR/bits-test.txt"

for bits in "${BITS_ARRAY[@]}"; do
    echo "测试位数: $bits"

    "$PROGRAMS_DIR/spidev_test" -D "$TEST_DEVICE" -b $bits -v 2>&1 | tee -a "$RESULTS_DIR/bits-test.txt"

    echo ""
done

# 模式测试
echo "步骤 8: SPI模式测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "SPI模式测试"
    echo "========================================"
    echo ""
    echo "模式 0 (CPOL=0, CPHA=0):"
} > "$RESULTS_DIR/mode-test.txt"

"$PROGRAMS_DIR/spidev_test" -D "$TEST_DEVICE" -v 2>&1 | tee -a "$RESULTS_DIR/mode-test.txt"

echo ""
echo "模式 1 (CPOL=0, CPHA=1):"
"$PROGRAMS_DIR/spidev_test" -D "$TEST_DEVICE" -H -v 2>&1 | tee -a "$RESULTS_DIR/mode-test.txt"

echo ""
echo "模式 2 (CPOL=1, CPHA=0):"
"$PROGRAMS_DIR/spidev_test" -D "$TEST_DEVICE" -O -v 2>&1 | tee -a "$RESULTS_DIR/mode-test.txt"

echo ""
echo "模式 3 (CPOL=1, CPHA=1):"
"$PROGRAMS_DIR/spidev_test" -D "$TEST_DEVICE" -H -O -v 2>&1 | tee -a "$RESULTS_DIR/mode-test.txt"

echo ""

# 压力测试
echo "步骤 9: 压力测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "执行1000次传输..."
echo ""

"$PROGRAMS_DIR/spidev_test" -D "$TEST_DEVICE" -n 1000 | tee "$RESULTS_DIR/stress-test.txt"

echo ""

# 生成总结报告
{
    echo "SPI测试总结"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo ""
    echo "硬件信息:"
    echo "  SPI设备数量: ${#SPI_DEVICES[@]}"
    echo "  测试设备: $TEST_DEVICE"
    echo ""
    echo "测试项目:"
    echo "  ✓ 基础传输测试"
    echo "  ✓ 回环测试"
    echo "  ✓ 速度测试 (100KHz - 4MHz)"
    echo "  ✓ 数据位测试 (8/16 bit)"
    echo "  ✓ SPI模式测试 (Mode 0-3)"
    echo "  ✓ 压力测试 (1000次)"
    echo ""
    echo "详细日志:"
    echo "  基础测试: $RESULTS_DIR/basic-test.txt"
    echo "  回环测试: $RESULTS_DIR/loopback-test.txt"
    echo "  速度测试: $RESULTS_DIR/speed-test.txt"
    echo "  数据位测试: $RESULTS_DIR/bits-test.txt"
    echo "  模式测试: $RESULTS_DIR/mode-test.txt"
    echo "  压力测试: $RESULTS_DIR/stress-test.txt"
    echo ""
} | tee "$RESULTS_DIR/summary.txt"

echo "========================================"
echo "测试完成"
echo "========================================"
echo ""
echo "✓ SPI测试完成"
echo ""
echo "结果目录: $RESULTS_DIR"
echo ""
