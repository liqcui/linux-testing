#!/bin/bash
# test_i2c.sh - I2C设备综合测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results/i2c-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "I2C设备测试"
echo "========================================"
echo ""

# 检查权限
if [[ $EUID -ne 0 ]]; then
   echo "错误: 此脚本需要 root 权限"
   echo "使用: sudo $0"
   exit 1
fi

mkdir -p "$RESULTS_DIR"

# 检查i2c-tools是否安装
echo "步骤 1: 检查依赖..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ! command -v i2cdetect &> /dev/null; then
    echo "✗ i2c-tools 未安装"
    echo ""
    echo "安装命令:"
    echo "  Ubuntu/Debian: sudo apt-get install i2c-tools"
    echo "  RHEL/CentOS:   sudo yum install i2c-tools"
    echo "  Fedora:        sudo dnf install i2c-tools"
    exit 1
fi

echo "✓ i2c-tools 已安装"
echo "  i2cdetect: $(which i2cdetect)"
echo "  i2cget:    $(which i2cget)"
echo "  i2cset:    $(which i2cset)"
echo ""

# 加载I2C驱动
echo "步骤 2: 加载I2C驱动..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

modprobe i2c-dev 2>/dev/null
if [[ $? -eq 0 ]]; then
    echo "✓ i2c-dev 模块已加载"
else
    echo "⚠ i2c-dev 可能已加载或不需要"
fi
echo ""

# 列出I2C总线
echo "步骤 3: 检测I2C总线..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

I2C_BUSES=($(ls /dev/i2c-* 2>/dev/null | sed 's/\/dev\/i2c-//'))

if [[ ${#I2C_BUSES[@]} -eq 0 ]]; then
    echo "✗ 未发现I2C总线"
    echo ""
    echo "可能原因:"
    echo "  1. 硬件不支持I2C"
    echo "  2. I2C驱动未加载"
    echo "  3. I2C总线被禁用"
    echo ""
    echo "排查方法:"
    echo "  lsmod | grep i2c"
    echo "  dmesg | grep i2c"
    exit 1
fi

echo "找到 ${#I2C_BUSES[@]} 个I2C总线:"
for bus in "${I2C_BUSES[@]}"; do
    echo "  - /dev/i2c-$bus"
done
echo ""

# 扫描每个总线
echo "步骤 4: 扫描I2C设备..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "I2C总线扫描报告"
    echo "========================================"
    echo ""
    echo "扫描时间: $(date)"
    echo ""
} > "$RESULTS_DIR/scan-report.txt"

TOTAL_DEVICES=0

for bus in "${I2C_BUSES[@]}"; do
    echo "扫描总线 $bus..."

    # 保存原始扫描结果
    i2cdetect -y $bus > "$RESULTS_DIR/bus-${bus}-scan.txt" 2>&1

    # 显示扫描结果
    echo ""
    i2cdetect -y $bus
    echo ""

    # 统计设备
    DEVICES=$(i2cdetect -y $bus 2>/dev/null | grep -E '[0-9a-f]{2}' | grep -oE '[0-9a-f]{2}' | grep -vE '^[0-9]0$' | wc -l)
    TOTAL_DEVICES=$((TOTAL_DEVICES + DEVICES))

    echo "总线 $bus: 发现 $DEVICES 个设备"
    echo ""

    {
        echo "总线 $bus:"
        echo "--------"
        i2cdetect -y $bus 2>/dev/null
        echo ""
    } >> "$RESULTS_DIR/scan-report.txt"
done

echo "所有总线共发现 $TOTAL_DEVICES 个设备"
echo ""

# 选择测试总线
if [[ ${#I2C_BUSES[@]} -gt 0 ]]; then
    TEST_BUS="${I2C_BUSES[0]}"
else
    echo "✗ 无可用总线进行测试"
    exit 1
fi

echo "步骤 5: 设备读写测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "测试总线: $TEST_BUS"
echo ""

# 获取该总线上的设备地址
DEVICE_ADDRS=($(i2cdetect -y $TEST_BUS 2>/dev/null | grep -oE '(0x)?[0-9a-f]{2}' | grep -v '00' | grep -v '^[0-9]$' | sort -u))

if [[ ${#DEVICE_ADDRS[@]} -eq 0 ]]; then
    echo "⚠ 总线 $TEST_BUS 上无设备，跳过读写测试"
    echo ""
else
    echo "发现 ${#DEVICE_ADDRS[@]} 个设备地址:"
    for addr in "${DEVICE_ADDRS[@]}"; do
        echo "  - $addr"
    done
    echo ""

    # 对每个设备尝试读取
    {
        echo "设备读取测试"
        echo "========================================"
        echo ""
    } > "$RESULTS_DIR/read-test.txt"

    READ_SUCCESS=0
    READ_FAILED=0

    for addr in "${DEVICE_ADDRS[@]}"; do
        # 转换为十进制（如果需要）
        if [[ $addr =~ ^0x ]]; then
            addr_hex=$addr
        else
            addr_hex="0x$addr"
        fi

        echo "测试设备 $addr_hex..."

        # 尝试读取寄存器0x00
        result=$(i2cget -y $TEST_BUS $addr_hex 0x00 2>&1)

        if [[ $? -eq 0 ]]; then
            echo "  ✓ 读取成功: $result"
            READ_SUCCESS=$((READ_SUCCESS + 1))

            {
                echo "设备 $addr_hex:"
                echo "  寄存器 0x00: $result"
            } >> "$RESULTS_DIR/read-test.txt"
        else
            echo "  ✗ 读取失败"
            READ_FAILED=$((READ_FAILED + 1))

            {
                echo "设备 $addr_hex:"
                echo "  读取失败: $result"
            } >> "$RESULTS_DIR/read-test.txt"
        fi
    done

    echo ""
    echo "读取测试结果:"
    echo "  成功: $READ_SUCCESS"
    echo "  失败: $READ_FAILED"
    echo ""
fi

# 压力测试：批量扫描
echo "步骤 6: 批量地址扫描测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "扫描地址范围: 0x03-0x77"
echo ""

{
    echo "批量地址扫描"
    echo "========================================"
    echo ""
    echo "总线: $TEST_BUS"
    echo "范围: 0x03-0x77"
    echo ""
} > "$RESULTS_DIR/bulk-scan.txt"

FOUND_COUNT=0

for addr in $(seq 3 119); do
    addr_hex=$(printf "0x%02x" $addr)

    result=$(i2cget -y $TEST_BUS $addr_hex 0x00 2>&1)

    if [[ $? -eq 0 ]]; then
        echo "✓ 设备发现: $addr_hex"
        FOUND_COUNT=$((FOUND_COUNT + 1))

        echo "  地址 $addr_hex: 存在" >> "$RESULTS_DIR/bulk-scan.txt"
    fi
done

echo ""
echo "批量扫描完成: 发现 $FOUND_COUNT 个设备"
echo ""

# 性能测试
echo "步骤 7: 性能测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ ${#DEVICE_ADDRS[@]} -gt 0 ]]; then
    TEST_ADDR="${DEVICE_ADDRS[0]}"

    echo "测试设备: $TEST_ADDR"
    echo "测试次数: 100"
    echo ""

    start_time=$(date +%s.%N)

    for i in {1..100}; do
        i2cget -y $TEST_BUS $TEST_ADDR 0x00 &>/dev/null
    done

    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc)
    avg_time=$(echo "scale=3; $duration / 100" | bc)

    echo "总耗时: ${duration}s"
    echo "平均延迟: ${avg_time}s/次"
    echo ""

    {
        echo "性能测试结果"
        echo "========================================"
        echo ""
        echo "设备: $TEST_ADDR"
        echo "操作: 读取寄存器0x00"
        echo "次数: 100"
        echo "总耗时: ${duration}s"
        echo "平均延迟: ${avg_time}s"
        echo ""
    } > "$RESULTS_DIR/performance.txt"
else
    echo "⚠ 无可用设备进行性能测试"
    echo ""
fi

# 生成总结报告
{
    echo "I2C测试总结"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo ""
    echo "硬件信息:"
    echo "  I2C总线数量: ${#I2C_BUSES[@]}"
    echo "  总设备数量: $TOTAL_DEVICES"
    echo ""
    echo "测试结果:"
    if [[ ${#DEVICE_ADDRS[@]} -gt 0 ]]; then
        echo "  读取成功: $READ_SUCCESS"
        echo "  读取失败: $READ_FAILED"
        echo "  批量扫描: $FOUND_COUNT 个设备"
    else
        echo "  未执行设备测试（无设备）"
    fi
    echo ""
    echo "详细日志:"
    echo "  扫描报告: $RESULTS_DIR/scan-report.txt"
    echo "  读取测试: $RESULTS_DIR/read-test.txt"
    echo "  批量扫描: $RESULTS_DIR/bulk-scan.txt"
    if [[ ${#DEVICE_ADDRS[@]} -gt 0 ]]; then
        echo "  性能测试: $RESULTS_DIR/performance.txt"
    fi
    echo ""
} | tee "$RESULTS_DIR/summary.txt"

echo "========================================"
echo "测试完成"
echo "========================================"
echo ""

if [[ $TOTAL_DEVICES -gt 0 ]]; then
    echo "✓ I2C测试通过"
    echo ""
    echo "发现设备: $TOTAL_DEVICES"
    echo "结果目录: $RESULTS_DIR"
else
    echo "⚠ I2C测试完成，但未发现设备"
    echo ""
    echo "可能原因:"
    echo "  1. 系统无I2C设备"
    echo "  2. 设备未正确连接"
    echo "  3. 驱动未加载"
fi

echo ""
