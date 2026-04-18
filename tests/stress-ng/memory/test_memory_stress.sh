#!/bin/bash
# test_memory_stress.sh - 内存压力测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "================================"
echo "stress-ng 内存压力测试"
echo "================================"
echo ""

# 检查 stress-ng
if ! command -v stress-ng &> /dev/null; then
    echo "错误: stress-ng 未安装"
    exit 1
fi

CPU_COUNT=$(nproc)
TOTAL_MEM_MB=$(free -m | awk '/^Mem:/{print $2}')
TEST_MEM_MB=$((TOTAL_MEM_MB * 80 / 100))  # 使用80%内存

echo "系统信息:"
echo "  CPU 核心数: $CPU_COUNT"
echo "  总内存: ${TOTAL_MEM_MB} MB"
echo "  测试内存: ${TEST_MEM_MB} MB (80%)"
echo ""

echo "测试场景 1: 虚拟内存压力测试（所有方法）"
echo "========================================="
echo ""
echo "运行参数:"
echo "  --vm 4                    # 4个内存工作进程"
echo "  --vm-bytes ${TEST_MEM_MB}M    # 每个进程分配的内存"
echo "  --vm-method all           # 所有内存测试方法"
echo "  --timeout 60s             # 运行60秒"
echo "  --metrics-brief           # 简要指标"
echo ""

stress-ng --vm 4 --vm-bytes ${TEST_MEM_MB}M --vm-method all --timeout 60s --metrics-brief

echo ""
echo ""
echo "测试场景 2: 特定内存方法测试"
echo "============================"
echo ""

VM_METHODS=("flip" "memset" "memcpy" "memmove" "mmap" "zero" "matrix" "prime")

for method in "${VM_METHODS[@]}"; do
    echo ""
    echo "测试: $method 方法"
    echo "-------------------"

    stress-ng --vm 2 --vm-bytes 512M --vm-method $method --timeout 10s --metrics-brief 2>&1 | \
        grep -E "stress-ng|bogo ops|real time|usr time|sys time" | head -10

    sleep 2
done

echo ""
echo ""
echo "测试场景 3: 内存分配/释放压力"
echo "============================"
echo ""

echo "测试: malloc 压力（快速分配/释放）"
echo "-----------------------------------"
stress-ng --malloc 4 --malloc-bytes 256M --malloc-max 1G --timeout 30s --metrics-brief

echo ""
echo ""
echo "测试: mmap 压力"
echo "---------------"
stress-ng --mmap 4 --mmap-bytes 256M --timeout 30s --metrics-brief

echo ""
echo ""
echo "测试场景 4: 内存页面压力"
echo "======================="
echo ""

echo "测试: 页面故障压力"
echo "------------------"
stress-ng --page-in 2 --timeout 30s --metrics-brief

echo ""
echo ""
echo "测试场景 5: 内存带宽测试"
echo "======================="
echo ""

echo "测试: 顺序写入"
echo "-------------"
stress-ng --vm 2 --vm-bytes 512M --vm-method write64 --timeout 20s --metrics-brief

echo ""
echo ""
echo "测试: 随机读写"
echo "-------------"
stress-ng --vm 2 --vm-bytes 512M --vm-method randlist --timeout 20s --metrics-brief

echo ""
echo ""
echo "测试场景 6: 内存泄漏模拟"
echo "======================="
echo ""

echo "测试: 内存持续增长（不释放）"
echo "---------------------------"
stress-ng --vm 2 --vm-bytes 128M --vm-hang 1000 --timeout 15s --metrics-brief

echo ""
echo ""
echo "测试场景 7: NUMA 内存测试（如果支持）"
echo "===================================="
echo ""

if [[ -f /sys/devices/system/node/node1/meminfo ]]; then
    echo "检测到 NUMA 架构"
    echo ""

    echo "测试: NUMA 本地内存访问"
    echo "----------------------"
    numactl --cpunodebind=0 --membind=0 stress-ng --vm 2 --vm-bytes 256M --timeout 15s --metrics-brief

    echo ""
    echo ""
    echo "测试: NUMA 远程内存访问"
    echo "----------------------"
    numactl --cpunodebind=0 --membind=1 stress-ng --vm 2 --vm-bytes 256M --timeout 15s --metrics-brief
else
    echo "未检测到 NUMA 架构，跳过 NUMA 测试"
fi

echo ""
echo ""
echo "================================"
echo "测试完成！"
echo "================================"
echo ""
echo "结果指标说明:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. VM (Virtual Memory) 测试"
echo "   --vm N              # N个虚拟内存工作进程"
echo "   --vm-bytes SIZE     # 每个进程分配的内存大小"
echo "   --vm-method METHOD  # 内存测试方法"
echo ""
echo "2. 内存方法说明:"
echo "   • flip      - 位翻转操作"
echo "   • memset    - 内存设置（写入固定值）"
echo "   • memcpy    - 内存复制"
echo "   • memmove   - 内存移动（可重叠）"
echo "   • mmap      - 内存映射"
echo "   • zero      - 清零操作"
echo "   • matrix    - 矩阵运算（内存密集）"
echo "   • prime     - 质数计算（内存+CPU）"
echo "   • write64   - 64位写入"
echo "   • randlist  - 随机链表遍历"
echo ""
echo "3. 性能指标:"
echo "   • bogo ops        - 完成的操作数"
echo "   • bogo ops/s      - 每秒操作数（衡量吞吐量）"
echo "   • page faults     - 页面故障次数"
echo "   • page faults/s   - 每秒页面故障"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "典型输出示例:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "stress-ng: info:  [12345] dispatching hogs: 4 vm"
echo "stress-ng: info:  [12345] successful run completed in 60.00s"
echo "stress-ng: info:  [12345] stressor       bogo ops real time  usr time  sys time   bogo ops/s"
echo "stress-ng: info:  [12345] vm                 8420     60.00    180.25     38.50       140.33"
echo "stress-ng: info:  [12345] vm               page faults: 2048000 page faults/sec: 34133.33"
echo ""
echo "解读:"
echo "  - 4个VM进程"
echo "  - 60秒完成8420次操作"
echo "  - 用户态180秒，系统态38秒"
echo "  - 每秒140次操作"
echo "  - 产生204万次页面故障（内存压力大）"
echo "  - 每秒3.4万次页面故障"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "故障排查:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "• 如果出现 OOM (Out of Memory):"
echo "  - 减小 --vm-bytes 值"
echo "  - 减少 --vm 进程数"
echo "  - 检查系统内存: free -h"
echo ""
echo "• 如果性能异常低:"
echo "  - 检查是否触发 swap: vmstat 1"
echo "  - 查看内存压力: dmesg | grep -i memory"
echo "  - 监控内存使用: watch -n1 free -h"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
