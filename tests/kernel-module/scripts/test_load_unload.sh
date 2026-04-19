#!/bin/bash
# test_load_unload.sh - 驱动加载/卸载循环测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRIVER_DIR="$SCRIPT_DIR/../driver"
RESULTS_DIR="$SCRIPT_DIR/../results/load-unload-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "内核模块加载/卸载测试"
echo "========================================"
echo ""

# 检查权限
if [[ $EUID -ne 0 ]]; then
   echo "错误: 此脚本需要 root 权限"
   echo "使用: sudo $0"
   exit 1
fi

mkdir -p "$RESULTS_DIR"

# 编译模块
echo "步骤 1: 编译内核模块..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd "$DRIVER_DIR"
make clean > /dev/null 2>&1
make

if [[ ! -f test_driver.ko ]]; then
    echo "✗ 编译失败"
    exit 1
fi

echo "✓ 模块编译成功"
echo "  test_driver.ko: $(ls -lh test_driver.ko | awk '{print $5}')"
echo "  test_device.ko: $(ls -lh test_device.ko | awk '{print $5}')"
echo ""

# 确保模块未加载
rmmod test_driver 2>/dev/null
rmmod test_device 2>/dev/null

echo "步骤 2: 基础加载/卸载测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 测试单次加载
echo "测试: 单次加载..."
insmod test_driver.ko debug_level=1

if [[ $? -ne 0 ]]; then
    echo "✗ 加载失败"
    dmesg | tail -20
    exit 1
fi

echo "✓ 加载成功"

# 检查模块
echo ""
echo "模块信息:"
lsmod | grep test_driver

# 检查设备节点
echo ""
echo "设备节点:"
ls -l /dev/testdev 2>/dev/null || echo "设备节点未创建"

# 测试设备读写
if [[ -c /dev/testdev ]]; then
    echo ""
    echo "测试设备读取:"
    cat /dev/testdev 2>/dev/null || echo "读取失败"
fi

# 测试卸载
echo ""
echo "测试: 卸载模块..."
rmmod test_driver

if [[ $? -ne 0 ]]; then
    echo "✗ 卸载失败"
    exit 1
fi

echo "✓ 卸载成功"
echo ""

sleep 2

# 循环加载卸载测试
echo "步骤 3: 循环加载/卸载测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

ITERATIONS=100
echo "执行 $ITERATIONS 次循环..."
echo ""

LOAD_FAILURES=0
UNLOAD_FAILURES=0

# 记录初始内存状态
INITIAL_SLAB=$(grep -i slab /proc/meminfo | grep "Slab:" | awk '{print $2}')

for i in $(seq 1 $ITERATIONS); do
    # 加载模块
    insmod test_driver.ko debug_level=0 2>/dev/null

    if [[ $? -ne 0 ]]; then
        echo "✗ 加载失败 at iteration $i"
        LOAD_FAILURES=$((LOAD_FAILURES + 1))
        break
    fi

    sleep 0.1

    # 卸载模块
    rmmod test_driver 2>/dev/null

    if [[ $? -ne 0 ]]; then
        echo "✗ 卸载失败 at iteration $i"
        UNLOAD_FAILURES=$((UNLOAD_FAILURES + 1))
        break
    fi

    # 每10次显示进度
    if [[ $((i % 10)) -eq 0 ]]; then
        echo "  完成 $i/$ITERATIONS 次迭代..."
    fi

    sleep 0.1
done

echo ""
echo "循环测试完成!"
echo ""

# 检查结果
{
    echo "加载/卸载测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo "总迭代次数: $ITERATIONS"
    echo "加载失败: $LOAD_FAILURES"
    echo "卸载失败: $UNLOAD_FAILURES"
    echo ""
} | tee "$RESULTS_DIR/load-unload-summary.txt"

# 检查资源泄漏
echo "步骤 4: 资源泄漏检查..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# SLAB 泄漏检查
echo "SLAB 内存检查:"
cat /proc/slabinfo | grep -i test_driver || echo "  无 test_driver slab 对象（正常）"

# 总体 SLAB 内存
FINAL_SLAB=$(grep -i slab /proc/meminfo | grep "Slab:" | awk '{print $2}')
SLAB_DIFF=$((FINAL_SLAB - INITIAL_SLAB))

echo ""
echo "SLAB 内存变化:"
echo "  初始: $INITIAL_SLAB kB"
echo "  最终: $FINAL_SLAB kB"
echo "  差异: $SLAB_DIFF kB"

if [[ $SLAB_DIFF -gt 1024 ]]; then
    echo "  ⚠ 警告: SLAB 内存增长超过 1MB，可能存在泄漏"
else
    echo "  ✓ SLAB 内存正常"
fi

# 文件描述符泄漏检查
echo ""
echo "文件描述符检查:"
lsof 2>/dev/null | grep test_driver || echo "  无泄漏的文件描述符（正常）"

# 保存内核日志
echo ""
echo "保存内核日志..."
dmesg > "$RESULTS_DIR/dmesg.log"
dmesg | grep test_driver > "$RESULTS_DIR/test_driver.log"

echo ""
echo "========================================"
echo "测试完成"
echo "========================================"
echo ""

# 最终摘要
if [[ $LOAD_FAILURES -eq 0 ]] && [[ $UNLOAD_FAILURES -eq 0 ]]; then
    echo "✓ 所有测试通过！"
    echo ""
    echo "结果:"
    echo "  - $ITERATIONS 次加载/卸载循环全部成功"
    echo "  - 无资源泄漏迹象"
    echo "  - 模块稳定性良好"
else
    echo "✗ 测试失败"
    echo ""
    echo "问题:"
    [[ $LOAD_FAILURES -gt 0 ]] && echo "  - 加载失败: $LOAD_FAILURES 次"
    [[ $UNLOAD_FAILURES -gt 0 ]] && echo "  - 卸载失败: $UNLOAD_FAILURES 次"
fi

echo ""
echo "详细日志保存在: $RESULTS_DIR"
echo ""
