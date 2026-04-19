#!/bin/bash
# test_memory.sh - stress-ng 内存子系统专项测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/../results/memory_test_$(date +%Y%m%d_%H%M%S)"

mkdir -p "$OUTPUT_DIR"

DURATION=60  # 每个测试60秒
CPU_CORES=$(nproc)

# 前置检查
if [[ $EUID -ne 0 ]]; then
   echo "错误: 此脚本需要 root 权限"
   echo "使用: sudo $0"
   exit 1
fi

echo "=========================================="
echo "stress-ng 内存子系统专项测试"
echo "=========================================="
echo ""
echo "配置:"
echo "  CPU 核心: $CPU_CORES"
echo "  测试时长: ${DURATION}秒/测试"
echo "  输出目录: $OUTPUT_DIR"
echo "=========================================="
echo ""

# 检查工具
if ! command -v stress-ng &> /dev/null; then
    echo "错误: stress-ng 未安装"
    echo "安装: sudo apt-get install stress-ng"
    exit 1
fi

echo "✓ 工具检查完成"
echo ""

# 系统信息
{
    echo "系统信息"
    echo "========================================"
    echo "测试时间: $(date)"
    echo "主机名: $(hostname)"
    echo "内核: $(uname -r)"
    echo "CPU 核心: $CPU_CORES"
    echo "CPU 型号: $(cat /proc/cpuinfo | grep 'model name' | head -1 | cut -d':' -f2 | xargs)"
    echo "总内存: $(free -h | grep Mem | awk '{print $2}')"
    echo "可用内存: $(free -h | grep Mem | awk '{print $7}')"
    echo ""

    # Hugepage配置
    echo "Hugepage配置:"
    cat /proc/meminfo | grep -i huge
    echo ""

    # NUMA配置
    if command -v numactl &> /dev/null; then
        echo "NUMA配置:"
        numactl --hardware
        echo ""
    fi
} | tee "$OUTPUT_DIR/system_info.txt"

# ========== 测试1: VM 内存分配压力测试 ==========
echo "=========================================="
echo "测试1: VM 内存分配压力测试"
echo "=========================================="
echo ""
echo "测试配置:"
echo "  • Worker数: 4"
echo "  • 内存大小: 2GB per worker"
echo "  • 方法: all (所有内存操作方法)"
echo ""

stress-ng --vm 4 \
    --vm-bytes 2G \
    --vm-method all \
    --timeout ${DURATION}s \
    --metrics-brief \
    --times \
    2>&1 | tee "$OUTPUT_DIR/test1_vm_all.log"

echo ""
echo "✓ VM内存分配测试完成"
echo ""
sleep 5

# ========== 测试2: memcpy 内存拷贝带宽测试 ==========
echo "=========================================="
echo "测试2: memcpy 内存拷贝带宽测试"
echo "=========================================="
echo ""
echo "测试配置:"
echo "  • Worker数: $CPU_CORES"
echo "  • 测试重点: 内存带宽性能"
echo ""

stress-ng --memcpy $CPU_CORES \
    --timeout ${DURATION}s \
    --metrics-brief \
    --times \
    2>&1 | tee "$OUTPUT_DIR/test2_memcpy.log"

echo ""
echo "✓ memcpy带宽测试完成"
echo ""
sleep 5

# ========== 测试3: mmap 内存映射压力测试 ==========
echo "=========================================="
echo "测试3: mmap 内存映射压力测试"
echo "=========================================="
echo ""
echo "测试配置:"
echo "  • Worker数: 4"
echo "  • 映射大小: 1GB per worker"
echo "  • 测试重点: 页面错误处理"
echo ""

stress-ng --mmap 4 \
    --mmap-bytes 1G \
    --timeout ${DURATION}s \
    --metrics-brief \
    --times \
    2>&1 | tee "$OUTPUT_DIR/test3_mmap.log"

echo ""
echo "✓ mmap压力测试完成"
echo ""
sleep 5

# ========== 测试4: bigheap 大堆内存测试 ==========
echo "=========================================="
echo "测试4: bigheap 大堆内存测试"
echo "=========================================="
echo ""
echo "测试配置:"
echo "  • Worker数: 2"
echo "  • 增长大小: 64MB"
echo "  • 测试重点: 大页内存性能"
echo ""

stress-ng --bigheap 2 \
    --bigheap-growth 64M \
    --timeout ${DURATION}s \
    --metrics-brief \
    --times \
    2>&1 | tee "$OUTPUT_DIR/test4_bigheap.log"

echo ""
echo "✓ bigheap测试完成"
echo ""
sleep 5

# ========== 测试5: malloc 动态内存分配测试 ==========
echo "=========================================="
echo "测试5: malloc 动态内存分配测试"
echo "=========================================="
echo ""
echo "测试配置:"
echo "  • Worker数: $CPU_CORES"
echo "  • 最大分配: 4GB"
echo "  • 测试重点: 内存分配器性能"
echo ""

stress-ng --malloc $CPU_CORES \
    --malloc-max 4G \
    --timeout ${DURATION}s \
    --metrics-brief \
    --times \
    2>&1 | tee "$OUTPUT_DIR/test5_malloc.log"

echo ""
echo "✓ malloc测试完成"
echo ""
sleep 5

# ========== 测试6: NUMA 内存测试 ==========
if command -v numactl &> /dev/null; then
    echo "=========================================="
    echo "测试6: NUMA 内存访问测试"
    echo "=========================================="
    echo ""
    echo "测试配置:"
    echo "  • 测试: 本地节点 vs 远程节点访问延迟"
    echo ""

    stress-ng --numa 4 \
        --timeout ${DURATION}s \
        --metrics-brief \
        --times \
        2>&1 | tee "$OUTPUT_DIR/test6_numa.log"

    echo ""
    echo "✓ NUMA测试完成"
    echo ""
    sleep 5
else
    echo "跳过NUMA测试 (numactl未安装)"
    echo ""
fi

# ========== 测试7: memory 内存综合压力测试 ==========
echo "=========================================="
echo "测试7: 内存综合压力测试"
echo "=========================================="
echo ""
echo "测试配置:"
echo "  • Worker数: $CPU_CORES"
echo "  • 测试重点: 多种内存操作混合"
echo ""

stress-ng --memory $CPU_CORES \
    --timeout ${DURATION}s \
    --metrics-brief \
    --times \
    2>&1 | tee "$OUTPUT_DIR/test7_memory_comprehensive.log"

echo ""
echo "✓ 内存综合测试完成"
echo ""
sleep 5

# ========== 测试8: stream 内存流带宽测试 ==========
echo "=========================================="
echo "测试8: stream 内存流带宽测试"
echo "=========================================="
echo ""
echo "测试配置:"
echo "  • Worker数: $CPU_CORES"
echo "  • 测试重点: STREAM基准测试 (类似STREAM Benchmark)"
echo ""

stress-ng --stream $CPU_CORES \
    --timeout ${DURATION}s \
    --metrics-brief \
    --times \
    2>&1 | tee "$OUTPUT_DIR/test8_stream.log"

echo ""
echo "✓ stream测试完成"
echo ""
sleep 5

# ========== 测试9: cache 缓存压力测试 ==========
echo "=========================================="
echo "测试9: cache 缓存压力测试"
echo "=========================================="
echo ""
echo "测试配置:"
echo "  • Worker数: $CPU_CORES"
echo "  • 测试重点: CPU缓存性能"
echo ""

stress-ng --cache $CPU_CORES \
    --timeout ${DURATION}s \
    --metrics-brief \
    --times \
    2>&1 | tee "$OUTPUT_DIR/test9_cache.log"

echo ""
echo "✓ cache测试完成"
echo ""

# ========== 生成综合报告 ==========
echo "=========================================="
echo "生成综合测试报告"
echo "=========================================="
echo ""

{
    echo "stress-ng 内存子系统测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo "系统: $(hostname) - $(uname -r)"
    echo "CPU 核心: $CPU_CORES"
    echo "总内存: $(free -h | grep Mem | awk '{print $2}')"
    echo ""

    echo "测试结果汇总"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # 提取各测试的bogo ops/s
    extract_metric() {
        local logfile=$1
        local stressor=$2

        if [ -f "$logfile" ]; then
            # 提取bogo ops/s (real time)
            bogo_real=$(grep "^stress-ng: info:" "$logfile" | grep "$stressor" | awk '{print $(NF-1)}')

            if [ -n "$bogo_real" ]; then
                echo "$bogo_real"
            else
                echo "N/A"
            fi
        else
            echo "N/A"
        fi
    }

    printf "%-25s %20s %s\n" "测试项" "bogo ops/s (real)" "性能评级"
    echo "────────────────────────────────────────────────────────────────────"

    # 评级函数
    get_memory_rating() {
        local test_type=$1
        local bogo_ops=$2

        if [ "$bogo_ops" = "N/A" ]; then
            echo "N/A"
            return
        fi

        case $test_type in
            vm)
                if (( $(echo "$bogo_ops > 2000" | bc -l) )); then
                    echo "★★★★★ 优秀"
                elif (( $(echo "$bogo_ops > 1000" | bc -l) )); then
                    echo "★★★★☆ 良好"
                elif (( $(echo "$bogo_ops > 500" | bc -l) )); then
                    echo "★★★☆☆ 一般"
                else
                    echo "★★☆☆☆ 较差"
                fi
                ;;
            memcpy)
                if (( $(echo "$bogo_ops > 5000" | bc -l) )); then
                    echo "★★★★★ 优秀"
                elif (( $(echo "$bogo_ops > 3000" | bc -l) )); then
                    echo "★★★★☆ 良好"
                elif (( $(echo "$bogo_ops > 1500" | bc -l) )); then
                    echo "★★★☆☆ 一般"
                else
                    echo "★★☆☆☆ 较差"
                fi
                ;;
            mmap)
                if (( $(echo "$bogo_ops > 6000" | bc -l) )); then
                    echo "★★★★★ 优秀"
                elif (( $(echo "$bogo_ops > 4000" | bc -l) )); then
                    echo "★★★★☆ 良好"
                elif (( $(echo "$bogo_ops > 2000" | bc -l) )); then
                    echo "★★★☆☆ 一般"
                else
                    echo "★★☆☆☆ 较差"
                fi
                ;;
            *)
                echo "参考INTERPRETATION_GUIDE.md"
                ;;
        esac
    }

    # VM测试
    vm_ops=$(extract_metric "$OUTPUT_DIR/test1_vm_all.log" "vm")
    printf "%-25s %20s %s\n" "VM内存分配" "$vm_ops" "$(get_memory_rating vm $vm_ops)"

    # memcpy测试
    memcpy_ops=$(extract_metric "$OUTPUT_DIR/test2_memcpy.log" "memcpy")
    printf "%-25s %20s %s\n" "memcpy内存拷贝" "$memcpy_ops" "$(get_memory_rating memcpy $memcpy_ops)"

    # mmap测试
    mmap_ops=$(extract_metric "$OUTPUT_DIR/test3_mmap.log" "mmap")
    printf "%-25s %20s %s\n" "mmap内存映射" "$mmap_ops" "$(get_memory_rating mmap $mmap_ops)"

    # bigheap测试
    bigheap_ops=$(extract_metric "$OUTPUT_DIR/test4_bigheap.log" "bigheap")
    printf "%-25s %20s %s\n" "bigheap大页内存" "$bigheap_ops" "参考INTERPRETATION_GUIDE.md"

    # malloc测试
    malloc_ops=$(extract_metric "$OUTPUT_DIR/test5_malloc.log" "malloc")
    printf "%-25s %20s %s\n" "malloc动态分配" "$malloc_ops" "参考INTERPRETATION_GUIDE.md"

    # NUMA测试
    if [ -f "$OUTPUT_DIR/test6_numa.log" ]; then
        numa_ops=$(extract_metric "$OUTPUT_DIR/test6_numa.log" "numa")
        printf "%-25s %20s %s\n" "NUMA内存访问" "$numa_ops" "参考INTERPRETATION_GUIDE.md"
    fi

    # memory综合测试
    memory_ops=$(extract_metric "$OUTPUT_DIR/test7_memory_comprehensive.log" "memory")
    printf "%-25s %20s %s\n" "内存综合压力" "$memory_ops" "参考INTERPRETATION_GUIDE.md"

    # stream测试
    stream_ops=$(extract_metric "$OUTPUT_DIR/test8_stream.log" "stream")
    printf "%-25s %20s %s\n" "stream内存流带宽" "$stream_ops" "参考INTERPRETATION_GUIDE.md"

    # cache测试
    cache_ops=$(extract_metric "$OUTPUT_DIR/test9_cache.log" "cache")
    printf "%-25s %20s %s\n" "cache缓存压力" "$cache_ops" "参考INTERPRETATION_GUIDE.md"

    echo ""

    echo "关键发现"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # 分析memcpy带宽
    if [ -f "$OUTPUT_DIR/test2_memcpy.log" ]; then
        bandwidth=$(grep "GB/sec" "$OUTPUT_DIR/test2_memcpy.log" | awk '{print $2}')
        if [ -n "$bandwidth" ]; then
            echo "• 内存带宽: ${bandwidth} GB/sec"
            bandwidth_value=$(echo "$bandwidth" | sed 's/[^0-9.]//g')
            if (( $(echo "$bandwidth_value > 15" | bc -l) )); then
                echo "  评估: ★★★★★ 优秀 - DDR4-3200或更好"
            elif (( $(echo "$bandwidth_value > 10" | bc -l) )); then
                echo "  评估: ★★★★☆ 良好 - DDR4-2666"
            elif (( $(echo "$bandwidth_value > 5" | bc -l) )); then
                echo "  评估: ★★★☆☆ 一般 - DDR4-2400或单通道"
            else
                echo "  评估: ★★☆☆☆ 较差 - DDR3或内存故障"
            fi
            echo ""
        fi
    fi

    # 检查swap使用
    echo "• Swap使用情况:"
    free -h | grep Swap
    swap_used=$(free -m | grep Swap | awk '{print $3}')
    if [ "$swap_used" -gt 100 ]; then
        echo "  ⚠ 警告: 检测到Swap使用 (${swap_used}MB)，可能影响性能"
        echo "  建议: 增加物理内存或调整swappiness参数"
    else
        echo "  ✓ Swap使用正常"
    fi
    echo ""

    echo "优化建议"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "详细的性能解读和优化建议请参考:"
    echo "  • INTERPRETATION_GUIDE.md - 内存测试结果解读章节"
    echo ""
    echo "常见优化方向:"
    echo "  1. 启用Transparent Huge Pages (THP)"
    echo "     echo always > /sys/kernel/mm/transparent_hugepage/enabled"
    echo ""
    echo "  2. 调整swappiness (减少swap使用)"
    echo "     echo 10 > /proc/sys/vm/swappiness"
    echo ""
    echo "  3. NUMA优化 (如果是多节点系统)"
    echo "     numactl --cpunodebind=0 --membind=0 <application>"
    echo ""
    echo "  4. 内存频率优化"
    echo "     - 确保BIOS中内存运行在最高频率"
    echo "     - 检查是否启用双通道配置"
    echo ""

    echo "详细日志文件"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    ls -1 "$OUTPUT_DIR"/*.log 2>/dev/null | sed 's/^/  • /'
    echo ""

} | tee "$OUTPUT_DIR/memory_test_report.txt"

cat "$OUTPUT_DIR/memory_test_report.txt"

echo ""
echo "=========================================="
echo "测试完成！"
echo "=========================================="
echo ""
echo "结果保存至: $OUTPUT_DIR"
echo ""
echo "查看报告:"
echo "  cat $OUTPUT_DIR/memory_test_report.txt"
echo ""
echo "查看详细解读:"
echo "  cat ../INTERPRETATION_GUIDE.md"
echo ""
