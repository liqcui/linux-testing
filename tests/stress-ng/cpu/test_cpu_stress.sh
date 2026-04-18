#!/bin/bash
# test_cpu_stress.sh - CPU压力测试（多种算法）

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "================================"
echo "stress-ng CPU 压力测试"
echo "================================"
echo ""

# 检查 stress-ng
if ! command -v stress-ng &> /dev/null; then
    echo "错误: stress-ng 未安装"
    echo "安装命令:"
    echo "  Ubuntu/Debian: sudo apt install stress-ng"
    echo "  RHEL/CentOS:   sudo yum install stress-ng"
    echo "  Fedora:        sudo dnf install stress-ng"
    exit 1
fi

CPU_COUNT=$(nproc)
echo "系统 CPU 核心数: $CPU_COUNT"
echo ""

echo "测试场景 1: 所有 CPU 算法测试（60秒）"
echo "========================================="
echo ""
echo "运行参数:"
echo "  --cpu $CPU_COUNT          # 使用所有CPU核心"
echo "  --cpu-method all          # 测试所有CPU算法"
echo "  --timeout 60s             # 运行60秒"
echo "  --metrics-brief           # 简要指标输出"
echo ""

stress-ng --cpu $CPU_COUNT --cpu-method all --timeout 60s --metrics-brief

echo ""
echo ""
echo "测试场景 2: 特定 CPU 算法测试"
echo "============================="
echo ""

CPU_METHODS=("ackermann" "bitops" "cfloat" "correlate" "crc16" "fibonacci" "fft" "int8" "int64" "matrix" "pi" "prime" "sqrt")

for method in "${CPU_METHODS[@]}"; do
    echo ""
    echo "测试: $method 算法"
    echo "-------------------"

    stress-ng --cpu $CPU_COUNT --cpu-method $method --timeout 10s --metrics-brief 2>&1 | \
        grep -E "stress-ng|bogo ops|real time|usr time|sys time" | head -10

    sleep 2
done

echo ""
echo ""
echo "测试场景 3: CPU 负载分级测试"
echo "============================"
echo ""

LOAD_LEVELS=(25 50 75 100)

for load in "${LOAD_LEVELS[@]}"; do
    CPU_WORKERS=$((CPU_COUNT * load / 100))
    if [[ $CPU_WORKERS -lt 1 ]]; then
        CPU_WORKERS=1
    fi

    echo ""
    echo "测试: ${load}% CPU 负载 ($CPU_WORKERS workers)"
    echo "-------------------------------------------"

    stress-ng --cpu $CPU_WORKERS --cpu-method matrix --timeout 15s --metrics-brief

    sleep 3
done

echo ""
echo ""
echo "测试场景 4: CPU 缓存压力测试"
echo "============================"
echo ""

echo "L1 缓存压力测试（cache-size 32K）:"
echo "-----------------------------------"
stress-ng --cpu $CPU_COUNT --cpu-method matrix --cache-size 32K --timeout 20s --metrics-brief

echo ""
echo ""
echo "L2 缓存压力测试（cache-size 256K）:"
echo "------------------------------------"
stress-ng --cpu $CPU_COUNT --cpu-method matrix --cache-size 256K --timeout 20s --metrics-brief

echo ""
echo ""
echo "L3 缓存压力测试（cache-size 8M）:"
echo "-----------------------------------"
stress-ng --cpu $CPU_COUNT --cpu-method matrix --cache-size 8M --timeout 20s --metrics-brief

echo ""
echo ""
echo "================================"
echo "测试完成！"
echo "================================"
echo ""
echo "结果指标说明:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. bogo ops (bogus operations)"
echo "   - 完成的操作数（非真实操作，用于性能测量）"
echo "   - 数值越高表示性能越好"
echo ""
echo "2. bogo ops/s (real time)"
echo "   - 每秒操作数（实际时间）"
echo "   - 衡量实际吞吐量"
echo ""
echo "3. bogo ops/s (usr+sys time)"
echo "   - 每秒操作数（用户+系统时间）"
echo "   - 衡量 CPU 使用效率"
echo ""
echo "4. CPU used %"
echo "   - CPU 使用率"
echo "   - 100% 表示满负载"
echo ""
echo "5. real time / usr time / sys time"
echo "   - real: 实际经过的时间"
echo "   - usr:  用户态时间"
echo "   - sys:  内核态时间"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "测试算法说明:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "• ackermann    - 阿克曼函数（递归计算）"
echo "• bitops       - 位运算操作"
echo "• cfloat       - 复数浮点运算"
echo "• correlate    - 相关性计算"
echo "• crc16        - CRC16 校验和"
echo "• fibonacci    - 斐波那契数列"
echo "• fft          - 快速傅里叶变换"
echo "• int8/int64   - 整数运算"
echo "• matrix       - 矩阵乘法"
echo "• pi           - 圆周率计算"
echo "• prime        - 质数计算"
echo "• sqrt         - 平方根计算"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "典型输出示例:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "stress-ng: info:  [12345] dispatching hogs: 8 cpu"
echo "stress-ng: info:  [12345] successful run completed in 60.00s"
echo "stress-ng: info:  [12345] stressor       bogo ops real time  usr time  sys time   bogo ops/s"
echo "stress-ng: info:  [12345]                           (secs)    (secs)    (secs)   (real time)"
echo "stress-ng: info:  [12345] cpu              125600     60.00    479.50      0.20      2093.33"
echo ""
echo "解读:"
echo "  - 8个CPU核心工作"
echo "  - 运行60秒完成125600次操作"
echo "  - 用户态时间479.50秒（8核并行）"
echo "  - 每秒2093次操作"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
