#!/bin/bash
# test_stream.sh - STREAM内存带宽测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRAMS_DIR="$SCRIPT_DIR/../programs"
RESULTS_DIR="$SCRIPT_DIR/../results/stream-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "STREAM 内存带宽测试"
echo "========================================"
echo ""

mkdir -p "$RESULTS_DIR"

# 检查编译器
echo "步骤 1: 检查编译环境..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if command -v gcc &> /dev/null; then
    echo "✓ GCC: $(gcc --version | head -1)"
    COMPILER="gcc"
elif command -v clang &> /dev/null; then
    echo "✓ Clang: $(clang --version | head -1)"
    COMPILER="clang"
else
    echo "✗ 未找到C编译器（需要gcc或clang）"
    exit 1
fi

echo ""

# STREAM原理说明
echo "步骤 2: STREAM测试原理..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "STREAM Benchmark 原理"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  测量可持续内存带宽（Sustainable Memory Bandwidth）"
    echo "  评估系统内存子系统性能"
    echo ""
    echo "四个核心操作:"
    echo "  1. Copy:   a[i] = b[i]                (2个数组)"
    echo "     - 测试简单内存复制带宽"
    echo "     - 每个元素: 1次读 + 1次写 = 2次内存访问"
    echo ""
    echo "  2. Scale:  a[i] = q * b[i]            (2个数组)"
    echo "     - 测试内存带宽 + 简单浮点运算"
    echo "     - 每个元素: 1次读 + 1次写 = 2次内存访问"
    echo ""
    echo "  3. Add:    a[i] = b[i] + c[i]         (3个数组)"
    echo "     - 测试多数组读取带宽"
    echo "     - 每个元素: 2次读 + 1次写 = 3次内存访问"
    echo ""
    echo "  4. Triad:  a[i] = b[i] + q * c[i]     (3个数组)"
    echo "     - 综合测试（最接近实际应用）"
    echo "     - 每个元素: 2次读 + 1次写 = 3次内存访问"
    echo ""
    echo "设计要点:"
    echo "  - 数组大小必须 >> 最大缓存大小"
    echo "  - 避免数据驻留在缓存中"
    echo "  - 测试真实的DRAM带宽"
    echo ""
    echo "内存层次:"
    echo "  L1 Cache:  ~32-64 KB   (最快, ~1-2 cycle延迟)"
    echo "  L2 Cache:  ~256-512 KB (~10 cycle延迟)"
    echo "  L3 Cache:  ~8-64 MB    (~40-70 cycle延迟)"
    echo "  DRAM:      GB级别      (最慢, ~100+ cycle延迟)"
    echo ""
    echo "  STREAM数组大小通常设置为80-160MB"
    echo "  确保超出所有缓存层次"
    echo ""
} | tee "$RESULTS_DIR/principles.txt"

# 编译STREAM
echo "步骤 3: 编译STREAM程序..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd "$PROGRAMS_DIR"

# 不同优化级别
VERSIONS=(
    "stream_baseline:无优化"
    "stream_O2:O2优化"
    "stream_O3:O3优化"
    "stream_omp:OpenMP多线程"
)

{
    echo "编译配置"
    echo "========================================"
    echo ""
} > "$RESULTS_DIR/compile.txt"

for version_info in "${VERSIONS[@]}"; do
    IFS=':' read -r binary desc <<< "$version_info"

    echo "编译: $desc ($binary)"

    case $binary in
        stream_baseline)
            $COMPILER -o $binary stream.c -lm
            CFLAGS="默认"
            ;;
        stream_O2)
            $COMPILER -O2 -o $binary stream.c -lm
            CFLAGS="-O2"
            ;;
        stream_O3)
            $COMPILER -O3 -march=native -o $binary stream.c -lm
            CFLAGS="-O3 -march=native"
            ;;
        stream_omp)
            $COMPILER -O3 -march=native -fopenmp -o $binary stream.c -lm
            CFLAGS="-O3 -march=native -fopenmp"
            ;;
    esac

    if [[ $? -eq 0 ]]; then
        echo "  ✓ 编译成功: $binary"
        {
            echo "$desc:"
            echo "  二进制: $binary"
            echo "  编译选项: $CFLAGS"
            echo ""
        } >> "$RESULTS_DIR/compile.txt"
    else
        echo "  ✗ 编译失败: $binary"
    fi
done

echo ""

# 系统信息
echo "步骤 4: 收集系统信息..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "系统信息"
    echo "========================================"
    echo ""

    echo "CPU信息:"
    echo "  型号: $(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
    echo "  核心数: $(grep -c processor /proc/cpuinfo)"
    echo "  物理核心: $(grep "cpu cores" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"

    echo ""
    echo "缓存信息:"
    if [[ -f /sys/devices/system/cpu/cpu0/cache/index0/size ]]; then
        echo "  L1d: $(cat /sys/devices/system/cpu/cpu0/cache/index0/size 2>/dev/null || echo '未知')"
        echo "  L1i: $(cat /sys/devices/system/cpu/cpu0/cache/index1/size 2>/dev/null || echo '未知')"
        echo "  L2:  $(cat /sys/devices/system/cpu/cpu0/cache/index2/size 2>/dev/null || echo '未知')"
        echo "  L3:  $(cat /sys/devices/system/cpu/cpu0/cache/index3/size 2>/dev/null || echo '未知')"
    else
        lscpu | grep -i cache || echo "  缓存信息不可用"
    fi

    echo ""
    echo "内存信息:"
    MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    echo "  总内存: $((MEM_TOTAL / 1024)) MB"

    echo ""
    echo "NUMA信息:"
    if command -v numactl &> /dev/null; then
        numactl --hardware 2>/dev/null || echo "  非NUMA系统或numactl未安装"
    else
        echo "  numactl未安装"
    fi

} | tee "$RESULTS_DIR/sysinfo.txt"

echo ""

# 运行测试
echo "步骤 5: 运行STREAM测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

for version_info in "${VERSIONS[@]}"; do
    IFS=':' read -r binary desc <<< "$version_info"

    if [[ ! -f "$PROGRAMS_DIR/$binary" ]]; then
        echo "⚠ 跳过 $desc: 程序不存在"
        continue
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "测试: $desc"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # 设置OpenMP线程数
    if [[ $binary == "stream_omp" ]]; then
        export OMP_NUM_THREADS=$(nproc)
        echo "OpenMP线程数: $OMP_NUM_THREADS"
        echo ""
    fi

    # 运行测试
    "$PROGRAMS_DIR/$binary" | tee "$RESULTS_DIR/${binary}.txt"

    echo ""
    echo ""
done

# 结果对比
echo "步骤 6: 结果对比分析..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "STREAM测试结果对比"
    echo "========================================"
    echo ""
    echo "配置                Copy        Scale       Add         Triad"
    echo "----------------------------------------------------------------"

    for version_info in "${VERSIONS[@]}"; do
        IFS=':' read -r binary desc <<< "$version_info"
        result_file="$RESULTS_DIR/${binary}.txt"

        if [[ -f $result_file ]]; then
            # 提取Triad带宽
            copy=$(grep "^Copy:" "$result_file" | awk '{print $2}')
            scale=$(grep "^Scale:" "$result_file" | awk '{print $2}')
            add=$(grep "^Add:" "$result_file" | awk '{print $2}')
            triad=$(grep "^Triad:" "$result_file" | awk '{print $2}')

            printf "%-18s  %-10s  %-10s  %-10s  %-10s\n" \
                "$desc" "$copy" "$scale" "$add" "$triad"
        fi
    done

    echo ""
    echo "单位: MB/s"
    echo ""

} | tee "$RESULTS_DIR/comparison.txt"

# 性能分析
echo "步骤 7: 性能分析..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "性能分析"
    echo "========================================"
    echo ""

    # 提取最佳Triad性能
    best_triad=0
    best_config=""

    for version_info in "${VERSIONS[@]}"; do
        IFS=':' read -r binary desc <<< "$version_info"
        result_file="$RESULTS_DIR/${binary}.txt"

        if [[ -f $result_file ]]; then
            triad=$(grep "^Triad:" "$result_file" | awk '{print $2}')
            if (( $(echo "$triad > $best_triad" | bc -l) )); then
                best_triad=$triad
                best_config=$desc
            fi
        fi
    done

    echo "最佳配置: $best_config"
    echo "Triad带宽: $best_triad MB/s"
    echo ""

    # 理论带宽估算
    echo "理论带宽估算:"
    echo "  假设DDR4-3200内存:"
    echo "    理论峰值: 25.6 GB/s (单通道)"
    echo "    双通道:   51.2 GB/s"
    echo "    四通道:   102.4 GB/s"
    echo ""
    echo "  实际可达: 60-80% 理论峰值"
    echo ""

    # 性能建议
    echo "性能优化建议:"
    echo "  1. 编译优化"
    echo "     - 使用-O3优化级别"
    echo "     - 使用-march=native针对当前CPU优化"
    echo ""
    echo "  2. 多线程"
    echo "     - 启用OpenMP并行化"
    echo "     - 设置合适的线程数（通常=物理核心数）"
    echo ""
    echo "  3. NUMA优化"
    echo "     - 在NUMA系统上绑定到单个节点"
    echo "     - numactl --cpunodebind=0 --membind=0 ./stream"
    echo ""
    echo "  4. Huge Pages"
    echo "     - 使用大页减少TLB miss"
    echo "     - echo 1024 > /proc/sys/vm/nr_hugepages"
    echo ""
    echo "  5. CPU频率"
    echo "     - 禁用节能模式"
    echo "     - cpupower frequency-set -g performance"
    echo ""

} | tee "$RESULTS_DIR/analysis.txt"

# 生成报告
{
    echo "STREAM测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo ""
    echo "系统信息:"
    echo "  内核: $(uname -r)"
    echo "  CPU: $(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
    echo "  内存: $((MEM_TOTAL / 1024)) MB"
    echo ""
    echo "测试配置:"
    echo "  数组大小: 10M elements (约80MB per array)"
    echo "  迭代次数: 10次"
    echo "  数据类型: double (8 bytes)"
    echo ""
    echo "测试完成:"
    for version_info in "${VERSIONS[@]}"; do
        IFS=':' read -r binary desc <<< "$version_info"
        if [[ -f "$RESULTS_DIR/${binary}.txt" ]]; then
            echo "  ✓ $desc"
        fi
    done
    echo ""
    echo "结果文件:"
    echo "  原理说明: $RESULTS_DIR/principles.txt"
    echo "  系统信息: $RESULTS_DIR/sysinfo.txt"
    echo "  编译配置: $RESULTS_DIR/compile.txt"
    echo "  结果对比: $RESULTS_DIR/comparison.txt"
    echo "  性能分析: $RESULTS_DIR/analysis.txt"
    echo ""
    for version_info in "${VERSIONS[@]}"; do
        IFS=':' read -r binary desc <<< "$version_info"
        if [[ -f "$RESULTS_DIR/${binary}.txt" ]]; then
            echo "  $desc: $RESULTS_DIR/${binary}.txt"
        fi
    done
    echo ""

} | tee "$RESULTS_DIR/summary.txt"

echo ""
echo "========================================"
echo "测试完成"
echo "========================================"
echo ""
echo "✓ STREAM内存带宽测试完成"
echo ""
echo "最佳性能: $best_triad MB/s ($best_config)"
echo ""
echo "结果目录: $RESULTS_DIR"
echo ""
