#!/bin/bash
# test_gpio.sh - GPIO综合测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRAMS_DIR="$SCRIPT_DIR/../programs"
RESULTS_DIR="$SCRIPT_DIR/../results/gpio-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "GPIO测试"
echo "========================================"
echo ""

# 检查权限
if [[ $EUID -ne 0 ]]; then
   echo "错误: 此脚本需要 root 权限"
   echo "使用: sudo $0"
   exit 1
fi

mkdir -p "$RESULTS_DIR"

# 检查libgpiod工具
echo "步骤 1: 检查依赖..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

HAVE_LIBGPIOD=0
if command -v gpiodetect &> /dev/null; then
    echo "✓ libgpiod 工具已安装"
    HAVE_LIBGPIOD=1
else
    echo "⚠ libgpiod 工具未安装（可选）"
    echo ""
    echo "安装命令:"
    echo "  Ubuntu/Debian: sudo apt-get install gpiod"
    echo "  RHEL/CentOS:   sudo yum install libgpiod-utils"
    echo "  Fedora:        sudo dnf install libgpiod-utils"
    echo ""
fi

# 编译测试程序
echo "编译测试程序..."
cd "$PROGRAMS_DIR"

if [[ ! -f gpio_test.c ]]; then
    echo "✗ 找不到 gpio_test.c"
    exit 1
fi

gcc -o gpio_test gpio_test.c

if [[ $? -ne 0 ]]; then
    echo "✗ 编译失败"
    exit 1
fi

echo "✓ 编译成功: gpio_test"
echo ""

# 检测GPIO芯片
echo "步骤 2: 检测GPIO芯片..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ $HAVE_LIBGPIOD -eq 1 ]]; then
    echo "使用libgpiod检测:"
    gpiodetect | tee "$RESULTS_DIR/gpio-chips.txt"
    echo ""

    # 获取第一个芯片的详细信息
    FIRST_CHIP=$(gpiodetect | head -1 | awk '{print $1}')
    if [[ -n "$FIRST_CHIP" ]]; then
        echo "芯片 $FIRST_CHIP 详细信息:"
        gpioinfo "$FIRST_CHIP" | head -20
        gpioinfo "$FIRST_CHIP" > "$RESULTS_DIR/gpio-info.txt"
        echo ""
    fi
fi

# 检查sysfs接口
echo "检查sysfs接口:"
if [[ -d /sys/class/gpio ]]; then
    echo "✓ /sys/class/gpio 存在"
    ls -la /sys/class/gpio/ | head -10
else
    echo "✗ /sys/class/gpio 不存在"
    echo "GPIO子系统可能未启用"
    exit 1
fi
echo ""

# 选择测试GPIO
echo "步骤 3: 选择测试GPIO..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 尝试使用常见的GPIO编号
TEST_GPIOS=(17 18 27 22 23 24 25)
TEST_GPIO=""

for gpio in "${TEST_GPIOS[@]}"; do
    # 尝试导出
    echo "$gpio" > /sys/class/gpio/export 2>/dev/null
    sleep 0.1

    if [[ -d "/sys/class/gpio/gpio$gpio" ]]; then
        TEST_GPIO=$gpio
        echo "✓ 使用GPIO$gpio进行测试"
        break
    fi
done

if [[ -z "$TEST_GPIO" ]]; then
    echo "⚠ 无法自动选择GPIO"
    echo "请手动指定GPIO编号（或直接按Enter跳过交互测试）:"
    read -p "GPIO编号: " TEST_GPIO

    if [[ -z "$TEST_GPIO" ]]; then
        echo "跳过交互测试"
        TEST_GPIO=""
    else
        echo "$TEST_GPIO" > /sys/class/gpio/export 2>/dev/null
        sleep 0.1
    fi
fi

echo ""

# GPIO导出/取消导出测试
if [[ -n "$TEST_GPIO" ]]; then
    echo "步骤 4: GPIO导出/取消导出测试..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # 取消导出（如果已导出）
    echo "$TEST_GPIO" > /sys/class/gpio/unexport 2>/dev/null
    sleep 0.2

    # 测试导出
    "$PROGRAMS_DIR/gpio_test" -g $TEST_GPIO -o export -V
    if [[ $? -ne 0 ]]; then
        echo "✗ GPIO导出失败"
        exit 1
    fi

    echo ""

    # 设置为输出
    echo "out" > /sys/class/gpio/gpio$TEST_GPIO/direction
    echo "✓ GPIO$TEST_GPIO 设置为输出模式"
    echo ""

    # GPIO读写测试
    echo "步骤 5: GPIO读写测试..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    {
        echo "GPIO读写测试"
        echo "========================================"
        echo ""
    } > "$RESULTS_DIR/readwrite-test.txt"

    echo "写入高电平..."
    "$PROGRAMS_DIR/gpio_test" -g $TEST_GPIO -o write -v 1 | tee -a "$RESULTS_DIR/readwrite-test.txt"
    sleep 0.1

    echo "读取状态..."
    "$PROGRAMS_DIR/gpio_test" -g $TEST_GPIO -o read | tee -a "$RESULTS_DIR/readwrite-test.txt"
    echo ""

    echo "写入低电平..."
    "$PROGRAMS_DIR/gpio_test" -g $TEST_GPIO -o write -v 0 | tee -a "$RESULTS_DIR/readwrite-test.txt"
    sleep 0.1

    echo "读取状态..."
    "$PROGRAMS_DIR/gpio_test" -g $TEST_GPIO -o read | tee -a "$RESULTS_DIR/readwrite-test.txt"
    echo ""

    # GPIO翻转测试
    echo "步骤 6: GPIO翻转性能测试..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    "$PROGRAMS_DIR/gpio_test" -g $TEST_GPIO -o toggle -V | tee "$RESULTS_DIR/toggle-test.txt"
    echo ""

    # 使用libgpiod测试（如果可用）
    if [[ $HAVE_LIBGPIOD -eq 1 ]] && [[ -n "$FIRST_CHIP" ]]; then
        echo "步骤 7: libgpiod工具测试..."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        # 需要取消sysfs导出才能使用libgpiod
        echo "$TEST_GPIO" > /sys/class/gpio/unexport 2>/dev/null
        sleep 0.2

        {
            echo "libgpiod工具测试"
            echo "========================================"
            echo ""
        } > "$RESULTS_DIR/libgpiod-test.txt"

        # 查看GPIO信息
        echo "GPIO信息:"
        gpioinfo "$FIRST_CHIP" | grep -A 2 "line.*$TEST_GPIO:" | tee -a "$RESULTS_DIR/libgpiod-test.txt"
        echo ""

        # gpioset测试
        echo "设置GPIO为高电平 (1秒)..."
        timeout 1 gpioset "$FIRST_CHIP" $TEST_GPIO=1 2>&1 | tee -a "$RESULTS_DIR/libgpiod-test.txt"
        echo ""

        echo "设置GPIO为低电平 (1秒)..."
        timeout 1 gpioset "$FIRST_CHIP" $TEST_GPIO=0 2>&1 | tee -a "$RESULTS_DIR/libgpiod-test.txt"
        echo ""

        # gpioget测试
        echo "读取GPIO状态:"
        gpioget "$FIRST_CHIP" $TEST_GPIO 2>&1 | tee -a "$RESULTS_DIR/libgpiod-test.txt"
        echo ""
    fi

    # 清理
    echo "$TEST_GPIO" > /sys/class/gpio/unexport 2>/dev/null
fi

# 批量GPIO测试
echo "步骤 8: 批量GPIO可用性扫描..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "GPIO可用性扫描"
    echo "========================================"
    echo ""
} > "$RESULTS_DIR/gpio-scan.txt"

AVAILABLE_GPIOS=()

for gpio in {0..64}; do
    echo "$gpio" > /sys/class/gpio/export 2>/dev/null
    sleep 0.01

    if [[ -d "/sys/class/gpio/gpio$gpio" ]]; then
        AVAILABLE_GPIOS+=($gpio)
        echo "  GPIO$gpio: 可用" >> "$RESULTS_DIR/gpio-scan.txt"

        # 读取方向
        direction=$(cat /sys/class/gpio/gpio$gpio/direction 2>/dev/null)
        echo "    方向: $direction" >> "$RESULTS_DIR/gpio-scan.txt"

        # 清理
        echo "$gpio" > /sys/class/gpio/unexport 2>/dev/null
    fi
done

echo "发现 ${#AVAILABLE_GPIOS[@]} 个可用GPIO:"
for gpio in "${AVAILABLE_GPIOS[@]}"; do
    echo "  - GPIO$gpio"
done
echo ""

{
    echo ""
    echo "总计: ${#AVAILABLE_GPIOS[@]} 个可用GPIO"
} >> "$RESULTS_DIR/gpio-scan.txt"

# 生成总结报告
{
    echo "GPIO测试总结"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo ""
    echo "系统信息:"
    if [[ $HAVE_LIBGPIOD -eq 1 ]]; then
        echo "  libgpiod: 已安装"
        echo "  GPIO芯片: $(gpiodetect | wc -l)"
    else
        echo "  libgpiod: 未安装"
    fi
    echo "  可用GPIO: ${#AVAILABLE_GPIOS[@]}"
    echo ""
    if [[ -n "$TEST_GPIO" ]]; then
        echo "测试GPIO: GPIO$TEST_GPIO"
        echo ""
        echo "测试项目:"
        echo "  ✓ GPIO导出/取消导出"
        echo "  ✓ GPIO读写操作"
        echo "  ✓ GPIO翻转性能"
        if [[ $HAVE_LIBGPIOD -eq 1 ]]; then
            echo "  ✓ libgpiod工具测试"
        fi
        echo "  ✓ GPIO批量扫描"
    else
        echo "测试项目:"
        echo "  ✓ GPIO芯片检测"
        echo "  ✓ GPIO批量扫描"
        echo "  ⚠ 跳过交互测试（无可用GPIO）"
    fi
    echo ""
    echo "详细日志:"
    echo "  芯片信息: $RESULTS_DIR/gpio-chips.txt"
    if [[ -n "$TEST_GPIO" ]]; then
        echo "  读写测试: $RESULTS_DIR/readwrite-test.txt"
        echo "  翻转测试: $RESULTS_DIR/toggle-test.txt"
        if [[ $HAVE_LIBGPIOD -eq 1 ]]; then
            echo "  libgpiod: $RESULTS_DIR/libgpiod-test.txt"
        fi
    fi
    echo "  GPIO扫描: $RESULTS_DIR/gpio-scan.txt"
    echo ""
} | tee "$RESULTS_DIR/summary.txt"

echo "========================================"
echo "测试完成"
echo "========================================"
echo ""

if [[ ${#AVAILABLE_GPIOS[@]} -gt 0 ]]; then
    echo "✓ GPIO测试完成"
    echo ""
    echo "发现GPIO: ${#AVAILABLE_GPIOS[@]}"
    if [[ -n "$TEST_GPIO" ]]; then
        echo "测试GPIO: GPIO$TEST_GPIO"
    fi
else
    echo "⚠ GPIO测试完成，但未发现可用GPIO"
fi

echo "结果目录: $RESULTS_DIR"
echo ""
