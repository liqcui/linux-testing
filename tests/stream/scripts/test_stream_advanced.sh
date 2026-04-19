#!/bin/bash
# test_stream_advanced.sh - STREAM高级参数化测试
# 多线程配置、NUMA测试、详细性能分析

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRAMS_DIR="$SCRIPT_DIR/../programs"
RESULTS_DIR="$SCRIPT_DIR/../results/stream-advanced-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "STREAM 高级参数化测试"
echo "========================================"
echo ""

mkdir -p "$RESULTS_DIR"

# 检查编译器
if command -v gcc &> /dev/null; then
    COMPILER="gcc"
elif command -v clang &> /dev/null; then
    COMPILER="clang"
else
    echo "✗ 未找到C编译器"
    exit 1
fi

# 检查OpenMP支持
echo "步骤 1: 检查OpenMP支持..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

$COMPILER -fopenmp -x c - -o /tmp/test_omp <<'EOF' 2>/dev/null
#include <omp.h>
int main() { return 0; }
EOF

if [[ $? -eq 0 ]]; then
    echo "✓ OpenMP支持可用"
    OMP_AVAILABLE=1
    rm -f /tmp/test_omp
else
    echo "⚠ OpenMP不可用，将跳过多线程测试"
    OMP_AVAILABLE=0
fi

echo ""

# 获取系统信息
CPU_CORES=$(nproc)
echo "CPU核心数: $CPU_CORES"

# 检查NUMA
if command -v numactl &> /dev/null; then
    NUMA_NODES=$(numactl --hardware 2>/dev/null | grep "available:" | awk '{print $2}')
    if [[ -n "$NUMA_NODES" ]] && [[ $NUMA_NODES -gt 1 ]]; then
        echo "NUMA节点数: $NUMA_NODES"
        NUMA_AVAILABLE=1
    else
        echo "非NUMA系统"
        NUMA_AVAILABLE=0
    fi
else
    echo "numactl未安装，跳过NUMA测试"
    NUMA_AVAILABLE=0
fi

echo ""

# 编译不同版本
echo "步骤 2: 编译STREAM程序..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd "$PROGRAMS_DIR"

# 自定义数组大小（确保超出所有缓存）
# 200M elements × 8 bytes = 1.6 GB per array
ARRAY_SIZE=200000000
NTIMES=10

{
    echo "STREAM编译配置"
    echo "========================================"
    echo ""
    echo "数组大小: $ARRAY_SIZE elements"
    echo "每个数组内存: $((ARRAY_SIZE * 8 / 1024 / 1024)) MB"
    echo "总内存需求: $((ARRAY_SIZE * 8 * 3 / 1024 / 1024)) MB (3个数组)"
    echo "迭代次数: $NTIMES"
    echo ""
} | tee "$RESULTS_DIR/config.txt"

# 编译优化版本
COMPILE_OPTIONS=(
    "stream_O2:-O2"
    "stream_O3:-O3"
    "stream_O3_native:-O3 -march=native"
    "stream_O3_omp:-O3 -march=native -fopenmp"
)

for opt_info in "${COMPILE_OPTIONS[@]}"; do
    IFS=':' read -r binary opts <<< "$opt_info"

    echo "编译: $binary ($opts)"

    $COMPILER $opts -DSTREAM_ARRAY_SIZE=$ARRAY_SIZE -DNTIMES=$NTIMES \
        stream.c -o $binary -lm 2>/dev/null

    if [[ $? -eq 0 ]]; then
        echo "  ✓ 成功"
    else
        echo "  ✗ 失败"
    fi
done

echo ""

# 单线程基准测试
echo "步骤 3: 单线程基准测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ -f "$PROGRAMS_DIR/stream_O3_native" ]]; then
    export OMP_NUM_THREADS=1
    echo "运行单线程测试..."
    "$PROGRAMS_DIR/stream_O3_native" | tee "$RESULTS_DIR/stream_single_thread.txt"
    echo ""
fi

# 多线程参数化测试
if [[ $OMP_AVAILABLE -eq 1 ]] && [[ -f "$PROGRAMS_DIR/stream_O3_omp" ]]; then
    echo "步骤 4: 多线程参数化测试..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # 测试不同线程数
    THREAD_COUNTS=(1 2 4 8)

    # 添加更多线程配置（如果核心数足够）
    if [[ $CPU_CORES -ge 16 ]]; then
        THREAD_COUNTS+=(16)
    fi
    if [[ $CPU_CORES -ge 32 ]]; then
        THREAD_COUNTS+=(32)
    fi
    if [[ $CPU_CORES -ge 64 ]]; then
        THREAD_COUNTS+=(64)
    fi

    # 添加核心数本身
    if [[ ! " ${THREAD_COUNTS[@]} " =~ " ${CPU_CORES} " ]]; then
        THREAD_COUNTS+=($CPU_CORES)
    fi

    # 排序
    THREAD_COUNTS=($(echo "${THREAD_COUNTS[@]}" | tr ' ' '\n' | sort -n | uniq))

    {
        echo "多线程参数化测试结果"
        echo "========================================"
        echo ""
        echo "线程数  Copy(MB/s)  Scale(MB/s)  Add(MB/s)   Triad(MB/s)  加速比"
        echo "------  ----------  -----------  ----------  -----------  ------"
    } | tee "$RESULTS_DIR/multithread_results.txt"

    BASELINE_TRIAD=""

    for threads in "${THREAD_COUNTS[@]}"; do
        export OMP_NUM_THREADS=$threads

        echo ""
        echo "测试 $threads 线程..."

        result_file="$RESULTS_DIR/stream_${threads}threads.txt"
        "$PROGRAMS_DIR/stream_O3_omp" > "$result_file" 2>&1

        # 提取结果
        copy=$(grep "^Copy:" "$result_file" | awk '{print $2}')
        scale=$(grep "^Scale:" "$result_file" | awk '{print $2}')
        add=$(grep "^Add:" "$result_file" | awk '{print $2}')
        triad=$(grep "^Triad:" "$result_file" | awk '{print $2}')

        # 计算加速比
        if [[ -z "$BASELINE_TRIAD" ]]; then
            BASELINE_TRIAD=$triad
            speedup="1.00"
        else
            speedup=$(echo "scale=2; $triad / $BASELINE_TRIAD" | bc)
        fi

        printf "%-6s  %-10s  %-11s  %-10s  %-11s  %s\n" \
            "$threads" "$copy" "$scale" "$add" "$triad" "${speedup}x" | \
            tee -a "$RESULTS_DIR/multithread_results.txt"
    done

    echo "" | tee -a "$RESULTS_DIR/multithread_results.txt"

    # 并行效率分析
    {
        echo ""
        echo "并行效率分析:"
        echo "----------------------------------------"
        echo ""

        for threads in "${THREAD_COUNTS[@]}"; do
            if [[ $threads -eq 1 ]]; then
                continue
            fi

            result_file="$RESULTS_DIR/stream_${threads}threads.txt"
            triad=$(grep "^Triad:" "$result_file" | awk '{print $2}')

            speedup=$(echo "scale=2; $triad / $BASELINE_TRIAD" | bc)
            efficiency=$(echo "scale=1; ($speedup / $threads) * 100" | bc)

            printf "%2d线程: 加速比=%.2fx, 并行效率=%.1f%%\n" \
                $threads $speedup $efficiency
        done
        echo ""
    } | tee -a "$RESULTS_DIR/multithread_results.txt"

    echo ""
fi

# NUMA测试
if [[ $NUMA_AVAILABLE -eq 1 ]] && [[ -f "$PROGRAMS_DIR/stream_O3_omp" ]]; then
    echo "步骤 5: NUMA节点测试..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    export OMP_NUM_THREADS=$CPU_CORES

    {
        echo "NUMA节点测试结果"
        echo "========================================"
        echo ""
        echo "配置                        Copy(MB/s)  Scale(MB/s)  Add(MB/s)   Triad(MB/s)"
        echo "--------------------------  ----------  -----------  ----------  -----------"
    } | tee "$RESULTS_DIR/numa_results.txt"

    # 测试1: NUMA本地访问 (node 0)
    echo "测试NUMA本地访问 (Node 0)..."
    numactl --cpunodebind=0 --membind=0 "$PROGRAMS_DIR/stream_O3_omp" \
        > "$RESULTS_DIR/stream_numa_local.txt" 2>&1

    copy=$(grep "^Copy:" "$RESULTS_DIR/stream_numa_local.txt" | awk '{print $2}')
    scale=$(grep "^Scale:" "$RESULTS_DIR/stream_numa_local.txt" | awk '{print $2}')
    add=$(grep "^Add:" "$RESULTS_DIR/stream_numa_local.txt" | awk '{print $2}')
    triad=$(grep "^Triad:" "$RESULTS_DIR/stream_numa_local.txt" | awk '{print $2}')

    printf "%-26s  %-10s  %-11s  %-10s  %s\n" \
        "NUMA本地 (CPU=0, Mem=0)" "$copy" "$scale" "$add" "$triad" | \
        tee -a "$RESULTS_DIR/numa_results.txt"

    NUMA_LOCAL_TRIAD=$triad

    # 测试2: NUMA远程访问 (CPU在node 0, 内存在node 1)
    if [[ $NUMA_NODES -ge 2 ]]; then
        echo "测试NUMA远程访问 (CPU=0, Mem=1)..."
        numactl --cpunodebind=0 --membind=1 "$PROGRAMS_DIR/stream_O3_omp" \
            > "$RESULTS_DIR/stream_numa_remote.txt" 2>&1

        copy=$(grep "^Copy:" "$RESULTS_DIR/stream_numa_remote.txt" | awk '{print $2}')
        scale=$(grep "^Scale:" "$RESULTS_DIR/stream_numa_remote.txt" | awk '{print $2}')
        add=$(grep "^Add:" "$RESULTS_DIR/stream_numa_remote.txt" | awk '{print $2}')
        triad=$(grep "^Triad:" "$RESULTS_DIR/stream_numa_remote.txt" | awk '{print $2}')

        printf "%-26s  %-10s  %-11s  %-10s  %s\n" \
            "NUMA远程 (CPU=0, Mem=1)" "$copy" "$scale" "$add" "$triad" | \
            tee -a "$RESULTS_DIR/numa_results.txt"

        # 性能损失分析
        {
            echo ""
            echo "NUMA性能影响分析:"
            echo "----------------------------------------"

            penalty=$(echo "scale=1; (1 - $triad / $NUMA_LOCAL_TRIAD) * 100" | bc)
            echo "远程访问性能损失: ${penalty}%"

            echo ""
            echo "建议:"
            if (( $(echo "$penalty > 20" | bc -l) )); then
                echo "  ⚠️  NUMA远程访问性能损失较大 (>${penalty}%)"
                echo "  - 使用numactl绑定CPU和内存到同一节点"
                echo "  - 或启用内存交错模式: numactl --interleave=all"
            elif (( $(echo "$penalty > 10" | bc -l) )); then
                echo "  ℹ️  NUMA远程访问有一定性能影响 (${penalty}%)"
                echo "  - 考虑NUMA感知的内存分配"
            else
                echo "  ✓  NUMA影响较小 (<10%)"
            fi
            echo ""
        } | tee -a "$RESULTS_DIR/numa_results.txt"
    fi

    # 测试3: NUMA交错模式
    echo "测试NUMA交错模式..."
    numactl --interleave=all "$PROGRAMS_DIR/stream_O3_omp" \
        > "$RESULTS_DIR/stream_numa_interleave.txt" 2>&1

    copy=$(grep "^Copy:" "$RESULTS_DIR/stream_numa_interleave.txt" | awk '{print $2}')
    scale=$(grep "^Scale:" "$RESULTS_DIR/stream_numa_interleave.txt" | awk '{print $2}')
    add=$(grep "^Add:" "$RESULTS_DIR/stream_numa_interleave.txt" | awk '{print $2}')
    triad=$(grep "^Triad:" "$RESULTS_DIR/stream_numa_interleave.txt" | awk '{print $2}')

    printf "%-26s  %-10s  %-11s  %-10s  %s\n" \
        "NUMA交错 (interleave=all)" "$copy" "$scale" "$add" "$triad" | \
        tee -a "$RESULTS_DIR/numa_results.txt"

    echo "" | tee -a "$RESULTS_DIR/numa_results.txt"
    echo ""
fi

# 生成详细分析
echo "步骤 6: 生成详细分析..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd "$SCRIPT_DIR"
if [[ -f "analyze_stream.sh" ]]; then
    ./analyze_stream.sh "$RESULTS_DIR"
    echo ""
fi

# 生成总报告
{
    echo "STREAM高级参数化测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo ""

    echo "系统配置:"
    echo "  CPU核心数: $CPU_CORES"
    if [[ $NUMA_AVAILABLE -eq 1 ]]; then
        echo "  NUMA节点数: $NUMA_NODES"
    else
        echo "  NUMA: 非NUMA系统"
    fi
    echo ""

    echo "测试配置:"
    echo "  数组大小: $ARRAY_SIZE elements ($(($ARRAY_SIZE * 8 / 1024 / 1024)) MB per array)"
    echo "  迭代次数: $NTIMES"
    echo "  编译优化: -O3 -march=native -fopenmp"
    echo ""

    echo "测试完成:"
    if [[ -f "$RESULTS_DIR/stream_single_thread.txt" ]]; then
        echo "  ✓ 单线程基准测试"
    fi
    if [[ -f "$RESULTS_DIR/multithread_results.txt" ]]; then
        echo "  ✓ 多线程参数化测试 (${THREAD_COUNTS[@]})"
    fi
    if [[ -f "$RESULTS_DIR/numa_results.txt" ]]; then
        echo "  ✓ NUMA节点测试"
    fi
    echo ""

    echo "关键结果:"
    if [[ -n "$BASELINE_TRIAD" ]]; then
        echo "  单线程Triad: $BASELINE_TRIAD MB/s"
    fi

    if [[ ${#THREAD_COUNTS[@]} -gt 0 ]]; then
        # 找最大值
        max_threads=${THREAD_COUNTS[-1]}
        max_result="$RESULTS_DIR/stream_${max_threads}threads.txt"
        if [[ -f "$max_result" ]]; then
            max_triad=$(grep "^Triad:" "$max_result" | awk '{print $2}')
            speedup=$(echo "scale=2; $max_triad / $BASELINE_TRIAD" | bc)
            echo "  最大线程($max_threads)Triad: $max_triad MB/s (${speedup}x加速)"
        fi
    fi

    if [[ -n "$NUMA_LOCAL_TRIAD" ]]; then
        echo "  NUMA本地Triad: $NUMA_LOCAL_TRIAD MB/s"
    fi
    echo ""

    echo "结果文件:"
    echo "  配置信息: $RESULTS_DIR/config.txt"
    echo "  单线程结果: $RESULTS_DIR/stream_single_thread.txt"
    if [[ -f "$RESULTS_DIR/multithread_results.txt" ]]; then
        echo "  多线程对比: $RESULTS_DIR/multithread_results.txt"
    fi
    if [[ -f "$RESULTS_DIR/numa_results.txt" ]]; then
        echo "  NUMA测试: $RESULTS_DIR/numa_results.txt"
    fi
    if [[ -f "$RESULTS_DIR/detailed_analysis.txt" ]]; then
        echo "  详细分析: $RESULTS_DIR/detailed_analysis.txt"
    fi
    echo ""

} | tee "$RESULTS_DIR/report.txt"

echo ""
echo "========================================"
echo "测试完成"
echo "========================================"
echo ""
echo "✓ STREAM高级参数化测试完成"
echo ""
echo "查看报告: cat $RESULTS_DIR/report.txt"
if [[ -f "$RESULTS_DIR/multithread_results.txt" ]]; then
    echo "查看多线程结果: cat $RESULTS_DIR/multithread_results.txt"
fi
if [[ -f "$RESULTS_DIR/numa_results.txt" ]]; then
    echo "查看NUMA结果: cat $RESULTS_DIR/numa_results.txt"
fi
if [[ -f "$RESULTS_DIR/detailed_analysis.txt" ]]; then
    echo "查看详细分析: cat $RESULTS_DIR/detailed_analysis.txt"
fi
echo ""
echo "结果目录: $RESULTS_DIR"
echo ""
