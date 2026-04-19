#!/bin/bash
# test_bind_unbind.sh - 设备绑定/解绑测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRIVER_DIR="$SCRIPT_DIR/../driver"
RESULTS_DIR="$SCRIPT_DIR/../results/bind-unbind-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "设备绑定/解绑测试"
echo "========================================"
echo ""

# 检查权限
if [[ $EUID -ne 0 ]]; then
   echo "错误: 此脚本需要 root 权限"
   echo "使用: sudo $0"
   exit 1
fi

mkdir -p "$RESULTS_DIR"

cd "$DRIVER_DIR"

# 确保模块已编译
if [[ ! -f test_driver.ko ]] || [[ ! -f test_device.ko ]]; then
    echo "编译模块..."
    make
fi

echo "步骤 1: 加载驱动和设备..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 清理
rmmod test_device 2>/dev/null
rmmod test_driver 2>/dev/null

# 加载驱动
insmod test_driver.ko debug_level=1

if [[ $? -ne 0 ]]; then
    echo "✗ 加载驱动失败"
    exit 1
fi

echo "✓ 驱动已加载"

# 加载设备
insmod test_device.ko

if [[ $? -ne 0 ]]; then
    echo "✗ 加载设备失败"
    rmmod test_driver
    exit 1
fi

echo "✓ 设备已加载"
echo ""

sleep 1

# 查找设备
echo "步骤 2: 查找 platform 设备..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

DRIVER_PATH="/sys/bus/platform/drivers/test_driver"

if [[ ! -d "$DRIVER_PATH" ]]; then
    echo "✗ 驱动目录不存在: $DRIVER_PATH"
    rmmod test_device test_driver
    exit 1
fi

echo "驱动路径: $DRIVER_PATH"
echo ""
echo "已绑定的设备:"
ls -1 "$DRIVER_PATH" | grep "test_driver" || echo "  无"
echo ""

# 获取设备列表
DEVICES=($(ls -1 /sys/bus/platform/devices/ | grep "test_driver"))

if [[ ${#DEVICES[@]} -eq 0 ]]; then
    echo "✗ 未找到 test_driver 设备"
    rmmod test_device test_driver
    exit 1
fi

echo "找到 ${#DEVICES[@]} 个设备:"
for dev in "${DEVICES[@]}"; do
    echo "  - $dev"
done
echo ""

# 选择第一个设备进行测试
TEST_DEVICE="${DEVICES[0]}"
DEVICE_PATH="/sys/bus/platform/devices/$TEST_DEVICE"

echo "测试设备: $TEST_DEVICE"
echo ""

# 步骤 3: 单次解绑/绑定测试
echo "步骤 3: 单次解绑/绑定测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 解绑
echo "解绑设备..."
echo "$TEST_DEVICE" > "$DRIVER_PATH/unbind"

if [[ $? -ne 0 ]]; then
    echo "✗ 解绑失败"
else
    echo "✓ 解绑成功"
fi

sleep 0.5

# 检查状态
echo ""
echo "当前绑定状态:"
ls -1 "$DRIVER_PATH" | grep "test_driver" || echo "  无绑定设备（已解绑）"

sleep 0.5

# 重新绑定
echo ""
echo "绑定设备..."
echo "$TEST_DEVICE" > "$DRIVER_PATH/bind"

if [[ $? -ne 0 ]]; then
    echo "✗ 绑定失败"
else
    echo "✓ 绑定成功"
fi

sleep 0.5

# 检查状态
echo ""
echo "当前绑定状态:"
ls -1 "$DRIVER_PATH" | grep "test_driver"

echo ""

# 步骤 4: 循环绑定/解绑测试
echo "步骤 4: 循环绑定/解绑测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

ITERATIONS=100
echo "执行 $ITERATIONS 次循环..."
echo ""

UNBIND_FAILURES=0
BIND_FAILURES=0

for i in $(seq 1 $ITERATIONS); do
    # 解绑
    echo "$TEST_DEVICE" > "$DRIVER_PATH/unbind" 2>/dev/null

    if [[ $? -ne 0 ]]; then
        echo "✗ 解绑失败 at iteration $i"
        UNBIND_FAILURES=$((UNBIND_FAILURES + 1))
        break
    fi

    sleep 0.01

    # 绑定
    echo "$TEST_DEVICE" > "$DRIVER_PATH/bind" 2>/dev/null

    if [[ $? -ne 0 ]]; then
        echo "✗ 绑定失败 at iteration $i"
        BIND_FAILURES=$((BIND_FAILURES + 1))
        break
    fi

    sleep 0.01

    # 每10次显示进度
    if [[ $((i % 10)) -eq 0 ]]; then
        echo "  完成 $i/$ITERATIONS 次迭代..."
    fi
done

echo ""
echo "循环测试完成!"
echo ""

# 测试结果
{
    echo "绑定/解绑测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo "测试设备: $TEST_DEVICE"
    echo "总迭代次数: $ITERATIONS"
    echo "解绑失败: $UNBIND_FAILURES"
    echo "绑定失败: $BIND_FAILURES"
    echo ""
} | tee "$RESULTS_DIR/bind-unbind-summary.txt"

# 步骤 5: 多设备并发测试
if [[ ${#DEVICES[@]} -gt 1 ]]; then
    echo "步骤 5: 多设备并发绑定/解绑测试..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    echo "测试所有 ${#DEVICES[@]} 个设备..."
    echo ""

    CONCURRENT_ITERATIONS=10

    for i in $(seq 1 $CONCURRENT_ITERATIONS); do
        # 解绑所有设备
        for dev in "${DEVICES[@]}"; do
            echo "$dev" > "$DRIVER_PATH/unbind" 2>/dev/null
        done

        sleep 0.1

        # 绑定所有设备
        for dev in "${DEVICES[@]}"; do
            echo "$dev" > "$DRIVER_PATH/bind" 2>/dev/null
        done

        sleep 0.1

        echo "  迭代 $i/$CONCURRENT_ITERATIONS 完成"
    done

    echo ""
    echo "✓ 多设备并发测试完成"
fi

# 保存内核日志
echo ""
echo "保存内核日志..."
dmesg | grep -E "test_driver|test_device" > "$RESULTS_DIR/kernel.log"

# 清理
echo ""
echo "清理..."
rmmod test_device
rmmod test_driver

echo ""
echo "========================================"
echo "测试完成"
echo "========================================"
echo ""

# 最终摘要
if [[ $UNBIND_FAILURES -eq 0 ]] && [[ $BIND_FAILURES -eq 0 ]]; then
    echo "✓ 所有测试通过！"
    echo ""
    echo "结果:"
    echo "  - $ITERATIONS 次绑定/解绑循环全部成功"
    [[ ${#DEVICES[@]} -gt 1 ]] && echo "  - $CONCURRENT_ITERATIONS 次多设备并发测试成功"
    echo "  - 设备绑定机制稳定"
else
    echo "✗ 测试失败"
    echo ""
    echo "问题:"
    [[ $UNBIND_FAILURES -gt 0 ]] && echo "  - 解绑失败: $UNBIND_FAILURES 次"
    [[ $BIND_FAILURES -gt 0 ]] && echo "  - 绑定失败: $BIND_FAILURES 次"
fi

echo ""
echo "详细日志保存在: $RESULTS_DIR"
echo ""
